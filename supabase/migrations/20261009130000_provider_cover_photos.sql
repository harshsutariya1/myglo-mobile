-- Cover photos for provider profiles: up to five images shown as a swipeable
-- banner on the provider's profile, first one first.
--
-- The photos live in a public `cover-photos` bucket under the provider's own
-- folder (`<uid>/<file>`); `profiles.cover_photos` holds their public URLs in
-- display order. A trigger checks every URL points into the owner's folder,
-- so a profile can't show someone else's images.

-- ---------------------------------------------------------------------------
-- 1. Column and validation.
-- ---------------------------------------------------------------------------

ALTER TABLE public.profiles
    ADD COLUMN cover_photos text[] NOT NULL DEFAULT '{}'::text[];

ALTER TABLE public.profiles
    ADD CONSTRAINT profiles_cover_photos_limit CHECK (cardinality(cover_photos) <= 5);

COMMENT ON COLUMN public.profiles.cover_photos IS
    'Public URLs of up to five cover photos (cover-photos bucket, owner''s folder), in display order. Providers only.';

CREATE OR REPLACE FUNCTION private.validate_cover_photos()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
DECLARE
    v_url    text;
    v_folder text := '/storage/v1/object/public/cover-photos/' || NEW.id::text || '/';
BEGIN
    IF cardinality(NEW.cover_photos) = 0 THEN
        RETURN NEW;
    END IF;
    IF NEW.role IS DISTINCT FROM 'provider' THEN
        RAISE EXCEPTION 'Only providers can have cover photos' USING ERRCODE = '42501';
    END IF;
    IF array_position(NEW.cover_photos, NULL) IS NOT NULL
       OR cardinality(NEW.cover_photos) <> (SELECT count(DISTINCT u) FROM unnest(NEW.cover_photos) u) THEN
        RAISE EXCEPTION 'invalid_cover_photos' USING ERRCODE = '22023';
    END IF;

    FOREACH v_url IN ARRAY NEW.cover_photos LOOP
        IF char_length(v_url) > 600
           OR v_url !~ '^https://[^/?#]+/'
           OR strpos(v_url, v_folder) = 0
           OR split_part(substr(v_url, strpos(v_url, v_folder) + char_length(v_folder)), '?', 1) !~ '^[A-Za-z0-9._-]+$' THEN
            RAISE EXCEPTION 'invalid_cover_photos' USING ERRCODE = '22023';
        END IF;
    END LOOP;
    RETURN NEW;
END;
$function$;

REVOKE ALL ON FUNCTION private.validate_cover_photos() FROM PUBLIC;

CREATE TRIGGER validate_cover_photos
    BEFORE INSERT OR UPDATE OF cover_photos ON public.profiles
    FOR EACH ROW EXECUTE FUNCTION private.validate_cover_photos();

-- ---------------------------------------------------------------------------
-- 2. Expose them on the public profile view (column appended, so existing
--    selects are unaffected). Options are restated: CREATE OR REPLACE VIEW
--    would otherwise reset them.
-- ---------------------------------------------------------------------------

CREATE OR REPLACE VIEW public.public_profiles
WITH (security_invoker = false, security_barrier = true)
AS
SELECT id,
    role,
    first_name,
    last_name,
    profile_pic,
    bio,
    followers_count,
    following_count,
    provider_name,
    address_text,
    coordinates,
    created_at,
    updated_at,
        CASE
            WHEN is_email_public THEN email
            ELSE NULL::text
        END AS email,
        CASE
            WHEN is_phone_public THEN phone_number
            ELSE NULL::text
        END AS phone_number,
    cover_photos
   FROM public.profiles;

-- ---------------------------------------------------------------------------
-- 3. Storage: public reads by URL; providers manage their own folder only.
-- ---------------------------------------------------------------------------

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('cover-photos', 'cover-photos', true, 5242880, ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/heic'])
ON CONFLICT (id) DO NOTHING;

-- Listing / removing needs SELECT; keep it to the owner's folder.
CREATE POLICY "Provider can view own Cover Photos" ON storage.objects
    FOR SELECT TO authenticated
    USING (bucket_id = 'cover-photos' AND (storage.foldername(name))[1] = (SELECT auth.uid())::text);

-- Providers only, into their own folder, with a cap so the folder can't grow
-- without bound (five slots plus room for in-flight replacements).
CREATE POLICY "Provider can upload Cover Photos" ON storage.objects
    FOR INSERT TO authenticated
    WITH CHECK (
        bucket_id = 'cover-photos'
        AND (storage.foldername(name))[1] = (SELECT auth.uid())::text
        AND EXISTS (
            SELECT 1 FROM public.profiles pr
            WHERE pr.id = (SELECT auth.uid()) AND pr.role = 'provider')
        AND (
            SELECT count(*) FROM storage.objects o
            WHERE o.bucket_id = 'cover-photos'
              AND (storage.foldername(o.name))[1] = (SELECT auth.uid())::text) < 12
    );

CREATE POLICY "Provider can delete own Cover Photos" ON storage.objects
    FOR DELETE TO authenticated
    USING (bucket_id = 'cover-photos' AND owner_id = (SELECT auth.uid())::text);
