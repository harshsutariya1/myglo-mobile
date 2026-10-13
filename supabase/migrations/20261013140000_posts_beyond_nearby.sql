-- posts_beyond_nearby: approved posts by other people that nearby_posts
-- leaves out, newest first, keyset-paginated on created_at.
--
-- Providers' Discover shows nearby_posts first and then continues with this
-- feed once the nearby posts run out, so it is the exact complement of
-- nearby_posts for the same radius: a post is excluded when its author, or
-- the provider tagged in it, is within the radius of the caller's saved
-- location. When the caller has no saved location nothing is nearby, so
-- every approved post by someone else is returned.
--
-- Runs as definer so it can use the spatial index on profiles (and to match
-- nearby_posts); visibility is enforced here instead: approved posts only,
-- never the caller's own. Only post rows are returned, never coordinates.
CREATE OR REPLACE FUNCTION public.posts_beyond_nearby(
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
    -- Same clamps as nearby_posts, so both feeds agree on what "near" means.
    v_radius double precision := least(greatest(coalesce(p_radius_m, 25000), 1000), 100000);
    v_limit  integer := least(greatest(coalesce(p_limit, 18), 1), 50);
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'Not authorized' USING ERRCODE = '42501';
    END IF;

    SELECT coordinates INTO v_origin FROM public.profiles WHERE id = v_uid;

    RETURN QUERY
    WITH nearby AS (
        SELECT pr.id
        FROM public.profiles pr
        WHERE v_origin IS NOT NULL
          AND pr.coordinates IS NOT NULL
          AND public.st_dwithin(pr.coordinates, v_origin, v_radius)
    )
    SELECT p.*
    FROM public.posts p
    WHERE p.tag_status = 'approved'
      AND p.author_id <> v_uid
      AND (p_before IS NULL OR p.created_at < p_before)
      -- NOT EXISTS rather than NOT IN: tagged_provider_id is often NULL.
      AND NOT EXISTS (SELECT 1 FROM nearby n WHERE n.id = p.author_id)
      AND NOT EXISTS (SELECT 1 FROM nearby n WHERE n.id = p.tagged_provider_id)
    ORDER BY p.created_at DESC
    LIMIT v_limit;
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.posts_beyond_nearby(double precision, timestamptz, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.posts_beyond_nearby(double precision, timestamptz, integer) TO authenticated;
