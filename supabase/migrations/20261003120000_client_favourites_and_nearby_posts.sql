-- Client favourites (replaces "following" in the app; the follows table is left
-- in place, unused for now) and a nearby-posts feed for providers' Discover page.

-- 1. favourites: a client's saved providers.
CREATE TABLE IF NOT EXISTS public.favourites (
    client_id   uuid        NOT NULL REFERENCES public.profiles (id) ON DELETE CASCADE,
    provider_id uuid        NOT NULL REFERENCES public.profiles (id) ON DELETE CASCADE,
    created_at  timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (client_id, provider_id),
    CONSTRAINT favourites_not_self CHECK (client_id <> provider_id)
);

COMMENT ON TABLE public.favourites IS 'Providers a client has saved to their favourites.';

-- Newest-first listing per client; reverse lookup per provider.
CREATE INDEX IF NOT EXISTS favourites_client_created_idx ON public.favourites (client_id, created_at DESC);
CREATE INDEX IF NOT EXISTS favourites_provider_idx ON public.favourites (provider_id);

ALTER TABLE public.favourites ENABLE ROW LEVEL SECURITY;

-- Favourites are private to the client who saved them.
REVOKE ALL ON public.favourites FROM anon;
GRANT SELECT, INSERT, DELETE ON public.favourites TO authenticated;

CREATE POLICY "Clients can view own favourites" ON public.favourites
    FOR SELECT TO authenticated
    USING ((SELECT auth.uid()) = client_id);

CREATE POLICY "Clients can add favourites" ON public.favourites
    FOR INSERT TO authenticated
    WITH CHECK ((SELECT auth.uid()) = client_id);

CREATE POLICY "Clients can remove favourites" ON public.favourites
    FOR DELETE TO authenticated
    USING ((SELECT auth.uid()) = client_id);

-- Only a client may favourite, and only a provider may be favourited. Runs as
-- definer because the caller can't read other people's profile rows.
CREATE OR REPLACE FUNCTION public.validate_favourite()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM public.profiles WHERE id = NEW.client_id AND role = 'customer') THEN
        RAISE EXCEPTION 'Only clients can save favourites' USING ERRCODE = '42501';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM public.profiles WHERE id = NEW.provider_id AND role = 'provider') THEN
        RAISE EXCEPTION 'Only providers can be saved as favourites' USING ERRCODE = '23514';
    END IF;
    RETURN NEW;
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.validate_favourite() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS favourites_validate ON public.favourites;
CREATE TRIGGER favourites_validate
    BEFORE INSERT ON public.favourites
    FOR EACH ROW EXECUTE FUNCTION public.validate_favourite();

-- 2. nearby_posts: approved posts by other people near the caller's saved
-- location, newest first, keyset-paginated on created_at.
--
-- "Near" means the author's location, or the location of the provider tagged
-- in the post (clients have no address, so their posts are placed at the
-- salon they tagged). Returns nothing when the caller has no saved location.
-- Runs as definer so it can use the spatial index on profiles; visibility is
-- enforced here instead: approved posts only, never the caller's own.
CREATE INDEX IF NOT EXISTS profiles_coordinates_gix ON public.profiles USING gist (coordinates);

CREATE OR REPLACE FUNCTION public.nearby_posts(
    p_radius_m double precision DEFAULT 25000,
    p_before   timestamptz      DEFAULT NULL,
    p_limit    integer          DEFAULT 18)
 RETURNS SETOF public.posts
 LANGUAGE plpgsql
 STABLE
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
    v_uid    uuid := auth.uid();
    v_origin public.geography;
    v_radius double precision := least(greatest(coalesce(p_radius_m, 25000), 1000), 100000);
    v_limit  integer := least(greatest(coalesce(p_limit, 18), 1), 50);
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'Not authorized' USING ERRCODE = '42501';
    END IF;

    SELECT coordinates INTO v_origin FROM public.profiles WHERE id = v_uid;
    IF v_origin IS NULL THEN
        RETURN;
    END IF;

    RETURN QUERY
    WITH nearby AS (
        SELECT pr.id
        FROM public.profiles pr
        WHERE pr.coordinates IS NOT NULL
          AND public.st_dwithin(pr.coordinates, v_origin, v_radius)
    )
    SELECT p.*
    FROM public.posts p
    WHERE p.tag_status = 'approved'
      AND p.author_id <> v_uid
      AND (p_before IS NULL OR p.created_at < p_before)
      AND (p.author_id IN (SELECT id FROM nearby) OR p.tagged_provider_id IN (SELECT id FROM nearby))
    ORDER BY p.created_at DESC
    LIMIT v_limit;
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.nearby_posts(double precision, timestamptz, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.nearby_posts(double precision, timestamptz, integer) TO authenticated;
