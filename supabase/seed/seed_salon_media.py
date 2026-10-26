#!/usr/bin/env python3
"""Adds photos and posts to the fake salons from fake_salons_seed.sql, or removes them.

It signs in as each seeded salon with the app's public (anon) key and uploads
exactly the way the app does, so storage and table policies apply as normal.
No service-role key is used.

Photos come from the Pixabay API, or Pexels if only a Pexels key is set. Both
licences allow free use without attribution, and Pixabay asks for photos to be
downloaded rather than hotlinked, which is what this does. The photographer
and source page of every photo used is written to
seed_salon_media_credits.json next to this script.

Needs, in the project's .env (gitignored):
    SUPABASE_URL, SUPABASE_ANON_KEY, and PIXABAY_API_KEY or PEXELS_API_KEY
and in the environment:
    SEED_SALON_PASSWORD   the seeded salons' password

With --photos <folder>, photos you downloaded yourself are used instead: one
subfolder per category (interior, hair, barber, nails, lashes, brows, waxing,
tanning, skin, massage, makeup); missing folders fall back to related ones.

With --placeholders no photo API is needed: gradient images showing the salon
or service name and an SF Symbol are rendered locally by
render_placeholders.swift (needs Xcode's swiftc).

Usage (from the project root, macOS: uses `sips` to resize):
    python3 supabase/seed/seed_salon_media.py upload [--placeholders | --photos <folder>]   # finished salons are skipped, half-done ones redone
    python3 supabase/seed/seed_salon_media.py purge                     # deletes the seeded salons' files and posts
To swap placeholders for real photos later, run `purge` then `upload`.
Run `purge` before fake_salons_cleanup.sql: storage files can't be removed from SQL.
"""
import json
import os
import random
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.parse
import urllib.request
import uuid
from pathlib import Path

SALON_COUNT = 20
EMAIL = "seed-salon-{:02d}@seed.myglo.test"
ROOT = Path(__file__).resolve().parents[2]
CREDITS = Path(__file__).with_name("seed_salon_media_credits.json")
UA = "myglo-seed/1.0"

# Photo search terms per salon kind (the kind is worked out from the services).
QUERIES = {
    "hair": ["hairdresser styling hair", "hair salon", "balayage hair", "hair blow dry"],
    "barber": ["barber haircut", "barbershop", "beard trim barber"],
    "nails": ["manicure nails", "nail art", "gel nails"],
    "lashes": ["eyelash extensions", "eyebrow shaping", "lash lift"],
    "beauty": ["beauty salon treatment", "waxing beauty", "beauty therapist"],
    "skin": ["facial treatment", "skincare facial", "esthetician"],
    "massage": ["massage therapy", "spa massage", "hot stone massage"],
    "makeup": ["makeup artist", "bridal makeup", "makeup brushes"],
    "multi": ["beauty salon", "hair salon", "manicure nails"],
}
INTERIOR = ["beauty salon interior", "hair salon interior", "spa interior"]

# Pixabay's search is loose, so a photo is only used when its tags include one
# of these words (default: any word of the query) and none of the BLOCKED ones.
REQUIRED_TAGS = {
    "balayage hair": ["hair", "hairstyle", "hairdresser"],
    "eyelash extensions": ["eyelash", "lash"],
    "lash lift": ["eyelash", "lash"],
    "eyebrow shaping": ["eyebrow", "brow"],
    "waxing beauty": ["wax", "hair removal", "depilation"],
    "beauty salon interior": ["salon", "interior"],
    "hair salon interior": ["salon", "hairdresser", "barber"],
    "spa interior": ["spa", "massage", "wellness"],
    "beauty spa treatment": ["spa", "beauty", "treatment"],
    "makeup brushes": ["makeup", "make-up", "cosmetics"],
}
BLOCKED_TAGS = {"3 d", "3d", "render", "illustration", "graffiti", "bathroom", "bathtub", "flower", "plant",
                "child", "children", "kid", "kids", "baby", "boy", "toddler", "teen", "teenager", "nude", "naked",
                "erotic", "sexy", "lingerie", "underwear", "bikini", "logo", "text", "halloween", "zombie", "blood"}

CAPTIONS = {
    "hair": ["Fresh cut, fresh start ✂️", "Soft, lived-in blonde for summer ☀️", "Gloss and blow-dry finish",
             "Before the beach, after the salon 🌊", "Colour transformation of the week", "Curls, loved and defined"],
    "barber": ["Clean fade, sharp lines", "Beard sculpted to perfection", "Saturday chair is booked out, grab a weekday spot",
               "Skin fade + beard combo", "Hot towel shave season", "Fresh for the weekend"],
    "nails": ["Summer nails are here 💅", "BIAB for strong, natural nails", "Chrome for the win ✨",
              "Soft pink for the minimalists", "Nail art of the week", "Pedi season, Gold Coast style"],
    "lashes": ["Classic set, natural finish", "Volume lashes that stay fluffy", "Laminated brows, zero effort mornings",
               "Lash lift + tint glow-up", "Brow shaping before and after", "Wake up ready"],
    "beauty": ["Smooth and ready for the beach", "Spray tan glow ☀️", "Express facial between errands",
               "Brow and lash tint refresh", "Your summer prep checklist", "Treat yourself Tuesday"],
    "skin": ["Glass-skin goals", "LED therapy for calm, happy skin", "Peel season is here",
             "Dermaplaning for that smooth finish", "Hydration first, always", "Skin consult slots open this week"],
    "massage": ["Melt the week away", "Hot stones, slow breaths", "Remedial relief for desk necks",
                "Your hour of quiet", "Post-surf recovery massage 🌊", "Book in, switch off"],
    "makeup": ["Bridal glow for a beach wedding 💍", "Soft glam for formal season", "Golden hour skin ✨",
               "Bridal party ready by 9am", "Makeup lesson favourites", "Trial day for our next bride"],
    "multi": ["Hair, brows and nails in one visit", "Fresh cut for the school holidays", "Gel mani + brow tidy combo",
              "Colour refresh for spring", "Lash lift Thursday", "Your local glow-up spot"],
}


def load_env():
    env = {}
    for line in (ROOT / ".env").read_text().splitlines():
        line = line.strip()
        if line and not line.startswith("#") and "=" in line:
            key, value = line.split("=", 1)
            env[key.strip()] = value.strip().strip('"').strip("'")
    return env


# Pixabay allows 100 API requests a minute; its image server throttles downloads
# far harder, so downloads are spaced out and a block is waited out patiently.
PIXABAY_API_INTERVAL = 0.8
PIXABAY_DOWNLOAD_INTERVAL = 12
PIXABAY_BLOCK_WAIT = 600
UNIQUE_PHOTO_BUDGET = 80
DOWNLOAD_CACHE = Path(tempfile.gettempdir()) / "myglo-seed-photo-cache"
_last_pixabay = 0.0


def request(method, url, headers=None, body=None, timeout=60):
    global _last_pixabay
    data = body if isinstance(body, (bytes, type(None))) else json.dumps(body).encode()
    headers = {"User-Agent": UA, **(headers or {})}
    if data is not None and not any(k.lower() == "content-type" for k in headers):
        headers["Content-Type"] = "application/json"
    req = urllib.request.Request(url, data=data, method=method, headers=headers)
    parsed = urllib.parse.urlparse(url)
    pixabay = parsed.hostname == "pixabay.com"
    download = pixabay and parsed.path.startswith("/get/")
    attempts = 13 if download else 5
    for attempt in range(attempts):
        if pixabay:
            interval = PIXABAY_DOWNLOAD_INTERVAL if download else PIXABAY_API_INTERVAL
            time.sleep(max(0.0, _last_pixabay + interval - time.time()))
            _last_pixabay = time.time()
        try:
            with urllib.request.urlopen(req, timeout=timeout) as resp:
                raw = resp.read()
                return json.loads(raw) if raw and "json" in resp.headers.get("Content-Type", "") else raw
        except urllib.error.HTTPError as e:
            detail = e.read().decode(errors="replace")[:300]
            if e.code == 429 and attempt < attempts - 1:
                hinted = int(e.headers.get("Retry-After") or e.headers.get("X-RateLimit-Reset") or 0)
                wait = hinted + 5 if hinted > 0 else (PIXABAY_BLOCK_WAIT if download else 65)
                print(f"  rate limited, waiting {wait}s", file=sys.stderr)
                time.sleep(wait)
                continue
            if e.code in (500, 502, 503, 504) and attempt < 2:
                time.sleep(3 * (attempt + 1))
                continue
            raise RuntimeError(f"{method} {url.split('?')[0]} -> {e.code}: {detail}") from None
        except (urllib.error.URLError, TimeoutError):
            if attempt < 2:
                time.sleep(3 * (attempt + 1))
                continue
            raise


class Session:
    """A signed-in seeded salon, talking to Supabase like the app does."""

    def __init__(self, env, email, password):
        self.url = env["SUPABASE_URL"].rstrip("/")
        self.key = env["SUPABASE_ANON_KEY"]
        auth = request("POST", f"{self.url}/auth/v1/token?grant_type=password",
                       {"apikey": self.key}, {"email": email, "password": password})
        self.token = auth["access_token"]
        self.uid = auth["user"]["id"]

    def headers(self, extra=None):
        return {"apikey": self.key, "Authorization": f"Bearer {self.token}", **(extra or {})}

    def rest(self, method, path, body=None, prefer=None):
        extra = {"Prefer": prefer} if prefer else {}
        return request(method, f"{self.url}/rest/v1/{path}", self.headers(extra), body)

    def upload(self, bucket, path, jpeg: bytes, upsert=False):
        request("POST", f"{self.url}/storage/v1/object/{bucket}/{path}",
                self.headers({"Content-Type": "image/jpeg", "x-upsert": "true" if upsert else "false",
                              "cache-control": "max-age=31536000"}), jpeg)
        return f"{self.url}/storage/v1/object/public/{bucket}/{path}"

    def list_files(self, bucket, prefix):
        return request("POST", f"{self.url}/storage/v1/object/list/{bucket}", self.headers(),
                       {"prefix": prefix, "limit": 1000, "offset": 0})

    def remove(self, bucket, paths):
        if paths:
            request("DELETE", f"{self.url}/storage/v1/object/{bucket}", self.headers(), {"prefixes": paths})


def search_pixabay(api_key, query):
    url = "https://pixabay.com/api/?" + urllib.parse.urlencode(
        {"key": api_key, "q": query, "image_type": "photo", "safesearch": "true", "per_page": 50, "min_width": 1000})
    hits = request("GET", url).get("hits", [])
    required = REQUIRED_TAGS.get(query, query.split())
    photos = []
    for h in hits:
        tags = [t.strip().lower() for t in h.get("tags", "").split(",")]
        if any(t in BLOCKED_TAGS for t in tags) or not any(r in t for r in required for t in tags):
            continue
        photos.append({"id": f"pixabay-{h['id']}", "download": h["largeImageURL"], "photographer": h.get("user"),
                       "page": h.get("pageURL")})
    return photos


def search_pexels(api_key, query):
    url = "https://api.pexels.com/v1/search?" + urllib.parse.urlencode({"query": query, "per_page": 40, "size": "medium"})
    photos = request("GET", url, {"Authorization": api_key}).get("photos", [])
    return [{"id": f"pexels-{p['id']}", "download": p["src"]["large2x"], "photographer": p.get("photographer"),
             "page": p.get("url")} for p in photos]


class PhotoPool:
    """Stock photos per search term, handed out without repeats where possible."""

    def __init__(self, search, workdir):
        self.search = search
        self.workdir = workdir
        self.cache = {}
        self.used = set()
        self.credits = {}

    def _search(self, query):
        if query not in self.cache:
            photos = self.search(query)
            random.shuffle(photos)
            self.cache[query] = photos
        return self.cache[query]

    def take(self, queries):
        options = [p for q in queries for p in self._search(q)]
        if not options:
            raise RuntimeError(f"No photo results for {queries}")
        # Past the download budget, reuse photos already fetched for these queries.
        if len(self.used) >= UNIQUE_PHOTO_BUDGET:
            options = [p for p in options if p["id"] in self.used] or options
        fresh = [p for p in options if p["id"] not in self.used]
        photo = random.choice(fresh or options)
        self.used.add(photo["id"])
        return photo

    @staticmethod
    def _dimensions(path):
        info = subprocess.run(["sips", "-g", "pixelWidth", "-g", "pixelHeight", str(path)],
                              check=True, capture_output=True, text=True).stdout
        return [int(line.split(":")[1]) for line in info.splitlines() if "pixel" in line]

    def jpeg(self, photo, size, square=False):
        """Downloads the photo and shrinks it (longest side at most `size`) with macOS sips."""
        path = Path(self.workdir) / f"{uuid.uuid4()}.jpg"
        if "file" in photo:
            path.write_bytes(Path(photo["file"]).read_bytes())
        else:
            # Originals are cached across runs, so a retry never downloads a photo twice.
            cached = DOWNLOAD_CACHE / f"{photo['id']}.jpg"
            if not cached.exists():
                DOWNLOAD_CACHE.mkdir(exist_ok=True)
                cached.write_bytes(request("GET", photo["download"], timeout=120))
            path.write_bytes(cached.read_bytes())
        if square:
            side = min(self._dimensions(path))
            subprocess.run(["sips", "-s", "format", "jpeg", "--cropToHeightWidth", str(side), str(side), str(path)],
                           check=True, capture_output=True)
        resize = ["-Z", str(size)] if max(self._dimensions(path)) > size else []
        subprocess.run(["sips", "-s", "format", "jpeg", "-s", "formatOptions", "80", *resize, str(path)],
                       check=True, capture_output=True)
        if photo.get("page"):
            self.credits[photo["id"]] = {"photographer": photo["photographer"], "page": photo["page"]}
        return path.read_bytes()


def salon_kind(categories):
    cats = set(categories)
    if len(cats) >= 5:
        return "multi"
    for cat, kind in (("Barbering", "barber"), ("Nails", "nails"), ("Massage", "massage"), ("Makeup", "makeup"),
                      ("Lashes", "lashes"), ("Waxing", "beauty"), ("Hair", "hair"), ("Skin", "skin")):
        if cat in cats:
            return kind
    return "multi"


SERVICE_QUERIES = {
    "Hair": ["hair salon", "hairdresser styling hair"], "Barbering": ["barber haircut"],
    "Nails": ["manicure nails"], "Lashes": ["eyelash extensions"], "Brows": ["eyebrow shaping"],
    "Waxing": ["waxing beauty"], "Tanning": ["beauty spa treatment"], "Skin": ["facial treatment"],
    "Massage": ["massage therapy"], "Makeup": ["makeup artist"],
}


class StockMedia:
    """Real photos from a stock photo API."""

    def __init__(self, search, workdir):
        self.pool = PhotoPool(search, workdir)

    def avatar(self, salon):
        return self.pool.jpeg(self.pool.take(INTERIOR + QUERIES[salon["kind"]][:1]), 600, square=True)

    def cover(self, salon, index):
        return self.pool.jpeg(self.pool.take(INTERIOR if index == 0 else QUERIES[salon["kind"]]), 1600)

    def service(self, salon, service):
        return self.pool.jpeg(self.pool.take(SERVICE_QUERIES.get(service["category"], QUERIES[salon["kind"]])), 800)

    def post(self, salon, caption, index):
        return self.pool.jpeg(self.pool.take(QUERIES[salon["kind"]]), 1080)

    def finish(self):
        existing = json.loads(CREDITS.read_text()) if CREDITS.exists() else {}
        existing.update(self.pool.credits)
        CREDITS.write_text(json.dumps(existing, indent=1, ensure_ascii=False) + "\n")


# Photo folders per salon kind and per service category, for --photos.
KIND_FOLDERS = {
    "hair": ["hair"], "barber": ["barber"], "nails": ["nails"], "lashes": ["lashes", "brows"],
    "beauty": ["waxing", "skin", "brows", "tanning"], "skin": ["skin"], "massage": ["massage"],
    "makeup": ["makeup"], "multi": ["hair", "nails", "brows", "lashes"],
}
CATEGORY_FOLDERS = {
    "Hair": "hair", "Barbering": "barber", "Nails": "nails", "Lashes": "lashes", "Brows": "brows",
    "Waxing": "waxing", "Tanning": "tanning", "Skin": "skin", "Massage": "massage", "Makeup": "makeup",
}
PHOTO_TYPES = {".jpg", ".jpeg", ".png", ".webp", ".heic"}


class FolderMedia:
    """Photos you downloaded yourself, sorted into one subfolder per category."""

    def __init__(self, root, workdir):
        root = Path(root).expanduser()
        if not root.is_dir():
            sys.exit(f"Photo folder not found: {root}")
        self.folders = {}
        for folder in root.iterdir():
            if folder.is_dir():
                files = [f for f in folder.iterdir() if f.suffix.lower() in PHOTO_TYPES]
                if files:
                    self.folders[folder.name.lower()] = [{"id": str(f), "file": str(f)} for f in files]
        if not self.folders:
            sys.exit(f"No photos found in the subfolders of {root}")
        print("Photos per folder: " + ", ".join(f"{k} {len(v)}" for k, v in sorted(self.folders.items())))
        self.pool = PhotoPool(lambda folder: list(self.folders.get(folder, [])), workdir)

    def _take(self, folders, fallback):
        available = [f for f in folders if f in self.folders] or [f for f in fallback if f in self.folders] \
            or list(self.folders)
        return self.pool.take(available)

    def avatar(self, salon):
        return self.pool.jpeg(self._take(["interior"], KIND_FOLDERS[salon["kind"]]), 600, square=True)

    def cover(self, salon, index):
        folders = ["interior"] if index == 0 else KIND_FOLDERS[salon["kind"]]
        return self.pool.jpeg(self._take(folders, KIND_FOLDERS[salon["kind"]]), 1600)

    def service(self, salon, service):
        folder = CATEGORY_FOLDERS.get(service["category"])
        return self.pool.jpeg(self._take([folder] if folder else [], KIND_FOLDERS[salon["kind"]]), 800)

    def post(self, salon, caption, index):
        return self.pool.jpeg(self._take(KIND_FOLDERS[salon["kind"]], ["interior"]), 1080)

    def finish(self):
        pass


# Gradient pairs per salon kind, and an SF Symbol per service category.
PALETTES = {
    "hair": [("#F6A6B2", "#B57BD6"), ("#FBD3A5", "#E57B8C"), ("#C9A7EB", "#7B6FD6")],
    "barber": [("#2C3E50", "#4CA1AF"), ("#373B44", "#4286F4"), ("#232526", "#7A8B99")],
    "nails": [("#FFB88C", "#DE6262"), ("#FBC2EB", "#A18CD1"), ("#FF9A9E", "#F6416C")],
    "lashes": [("#D4A5A5", "#8E6E95"), ("#E8CBC0", "#636FA4"), ("#F3D9E1", "#B07BAC")],
    "beauty": [("#F7CE68", "#FB8A6E"), ("#FDDB92", "#D1A3E8"), ("#F9D29D", "#E08E79")],
    "skin": [("#A8E6CF", "#3D9A8B"), ("#D4FC79", "#56AB91"), ("#B8E1DD", "#5A8DA8")],
    "massage": [("#C3B091", "#6B8E6B"), ("#D9C8A9", "#8A9A5B"), ("#B9A38A", "#5F7161")],
    "makeup": [("#F8B195", "#C06C84"), ("#FFDDE1", "#EE9CA7"), ("#E6B8A2", "#9D6B8A")],
    "multi": [("#FAD0C4", "#B993D6"), ("#A1C4FD", "#C2A9E8"), ("#FDCBF1", "#E6A4C4")],
}
SYMBOLS = {
    "Hair": "scissors", "Barbering": "mustache", "Nails": "hand.raised.fingers.spread", "Lashes": "eye",
    "Brows": "eyebrow", "Waxing": "drop", "Tanning": "sun.max", "Skin": "face.smiling", "Massage": "hands.sparkles",
    "Makeup": "paintbrush.pointed",
}
KIND_SYMBOLS = {"hair": "scissors", "barber": "mustache", "nails": "hand.raised.fingers.spread", "lashes": "eye",
                "beauty": "sparkles", "skin": "face.smiling", "massage": "hands.sparkles",
                "makeup": "paintbrush.pointed", "multi": "sparkles"}


class PlaceholderMedia:
    """Generated gradient images (name, caption and an SF Symbol), rendered locally with Swift."""

    def __init__(self, workdir):
        self.workdir = Path(workdir)
        self.binary = self.workdir / "render_placeholders"
        subprocess.run(["swiftc", "-O", "-o", str(self.binary), str(Path(__file__).with_name("render_placeholders.swift"))],
                       check=True)

    def _render(self, salon, style, width, height, title, subtitle, symbol, palette_index):
        palettes = PALETTES[salon["kind"]]
        start, end = palettes[palette_index % len(palettes)]
        path = self.workdir / f"{uuid.uuid4()}.jpg"
        spec = [{"path": str(path), "width": width, "height": height, "title": title, "subtitle": subtitle,
                 "symbol": symbol, "from": start, "to": end, "style": style}]
        subprocess.run([str(self.binary)], input=json.dumps(spec).encode(), check=True)
        return path.read_bytes()

    def avatar(self, salon):
        return self._render(salon, "avatar", 600, 600, salon["name"], None, KIND_SYMBOLS[salon["kind"]], salon["n"])

    def cover(self, salon, index):
        return self._render(salon, "cover", 1600, 900, salon["name"], salon["address"],
                            KIND_SYMBOLS[salon["kind"]], salon["n"] + index)

    def service(self, salon, service):
        return self._render(salon, "card", 800, 800, service["name"], service["category"],
                            SYMBOLS.get(service["category"], KIND_SYMBOLS[salon["kind"]]), salon["n"])

    def post(self, salon, caption, index):
        return self._render(salon, "card", 1080, 1080, caption, salon["name"], KIND_SYMBOLS[salon["kind"]],
                            salon["n"] + index + 1)

    def finish(self):
        pass


def upload(env, password, placeholders=False, photos=None):
    with tempfile.TemporaryDirectory() as tmp:
        if photos:
            media = FolderMedia(photos, tmp)
        elif placeholders:
            media = PlaceholderMedia(tmp)
        elif env.get("PIXABAY_API_KEY"):
            media = StockMedia(lambda q: search_pixabay(env["PIXABAY_API_KEY"], q), tmp)
        elif env.get("PEXELS_API_KEY"):
            media = StockMedia(lambda q: search_pexels(env["PEXELS_API_KEY"], q), tmp)
        else:
            sys.exit("Add PIXABAY_API_KEY (or PEXELS_API_KEY) to .env, or pass --placeholders")

        for n in range(1, SALON_COUNT + 1):
            s = Session(env, EMAIL.format(n), password)
            profile = s.rest("GET", f"profiles?id=eq.{s.uid}&select=provider_name,address_text,profile_pic")[0]
            # Posts are created last, so a salon with posts is finished. One with photos but no
            # posts was interrupted part-way: clear it and start that salon again.
            if s.rest("GET", f"posts?author_id=eq.{s.uid}&select=id&limit=1"):
                print(f"{n:02d} {profile['provider_name']}: already has photos, skipped")
                continue
            if profile["profile_pic"]:
                purge_salon(s)
            services = s.rest("GET", f"services?provider_id=eq.{s.uid}&select=id,name,category&order=created_at")
            salon = {"n": n, "name": profile["provider_name"], "address": profile["address_text"],
                     "kind": salon_kind([sv["category"] for sv in services])}

            avatar = s.upload("profile-pics", f"{s.uid}.jpg", media.avatar(salon), upsert=True) \
                + f"?t={int(time.time() * 1000)}"
            covers = [s.upload("cover-photos", f"{s.uid}/{uuid.uuid4()}.jpg", media.cover(salon, i)) for i in range(3)]
            s.rest("PATCH", f"profiles?id=eq.{s.uid}", {"profile_pic": avatar, "cover_photos": covers},
                   prefer="return=minimal")

            for sv in services:
                url = s.upload("service-images", f"{s.uid}/{uuid.uuid4()}.jpg", media.service(salon, sv))
                s.rest("PATCH", f"services?id=eq.{sv['id']}",
                       {"image_url": f"{url}?t={int(time.time() * 1000)}"}, prefer="return=minimal")

            captions = random.sample(CAPTIONS[salon["kind"]], 4)
            for caption in captions:
                photos = [s.upload("post-media", f"{s.uid}/{uuid.uuid4()}.jpg", media.post(salon, caption, i))
                          for i in range(random.choice((1, 1, 2, 3)))]
                linked = random.choice(services + [None]) if services else None
                s.rest("POST", "posts", {"id": str(uuid.uuid4()), "author_id": s.uid, "media_urls": photos,
                                         "caption": caption, "service_id": linked["id"] if linked else None},
                       prefer="return=minimal")
            print(f"{n:02d} {salon['name']} ({salon['kind']}): avatar, {len(covers)} covers, "
                  f"{len(services)} service images, {len(captions)} posts")
        media.finish()


def purge(env, password):
    for n in range(1, SALON_COUNT + 1):
        try:
            s = Session(env, EMAIL.format(n), password)
        except RuntimeError as e:
            print(f"{n:02d}: cannot sign in ({e}); skipped")
            continue
        print(f"{n:02d}: removed posts and {purge_salon(s)} files")


def purge_salon(s):
    """Deletes one salon's posts and uploaded files; returns how many files were removed."""
    s.rest("DELETE", f"posts?author_id=eq.{s.uid}", prefer="return=minimal")
    removed = 0
    for bucket in ("cover-photos", "service-images", "post-media"):
        names = [f"{s.uid}/{f['name']}" for f in s.list_files(bucket, f"{s.uid}/") if f.get("id")]
        s.remove(bucket, names)
        removed += len(names)
    s.remove("profile-pics", [f"{s.uid}.jpg"])
    s.rest("PATCH", f"profiles?id=eq.{s.uid}", {"profile_pic": None, "cover_photos": []}, prefer="return=minimal")
    s.rest("PATCH", f"services?provider_id=eq.{s.uid}", {"image_url": None}, prefer="return=minimal")
    return removed + 1


def main():
    args = sys.argv[1:]
    valid = args in (["upload"], ["upload", "--placeholders"], ["purge"]) \
        or (len(args) == 3 and args[:2] == ["upload", "--photos"])
    if not valid:
        sys.exit(__doc__)
    password = os.environ.get("SEED_SALON_PASSWORD")
    if not password:
        sys.exit("Set SEED_SALON_PASSWORD to the seeded salons' password.")
    env = load_env()
    if args[0] == "purge":
        purge(env, password)
    else:
        upload(env, password, placeholders="--placeholders" in args,
               photos=args[2] if "--photos" in args else None)


if __name__ == "__main__":
    main()
