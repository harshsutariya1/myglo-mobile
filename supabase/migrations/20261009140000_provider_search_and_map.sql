-- Read-only discovery queries for clients: text search across providers and
-- their services, and the providers to pin on the map.
--
-- Both return only public profile fields (never email or phone). Where a
-- provider works matters for privacy: a studio address is public, but a
-- provider who only does mobile visits is usually working from home, so for
-- them the location is snapped to a ~1 km grid, flagged as approximate, and
-- the street address is left out. Distances are measured from that same
-- point, so they can't be used to narrow it down.
--
-- The caller's location (p_latitude / p_longitude) is only used to sort and
-- measure distance for that request; it isn't stored.

-- ---------------------------------------------------------------------------
-- 1. The point a client may see for a provider.
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION private.public_provider_point(p_coordinates public.geography, p_offers_studio boolean)
 RETURNS public.geography
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO ''
AS $function$
    SELECT CASE
        WHEN p_coordinates IS NULL THEN NULL
        WHEN coalesce(p_offers_studio, true) THEN p_coordinates
        ELSE public.st_setsrid(public.st_makepoint(
                 round(public.st_x(p_coordinates::public.geometry)::numeric, 2)::double precision,
                 round(public.st_y(p_coordinates::public.geometry)::numeric, 2)::double precision), 4326)::public.geography
    END;
$function$;

REVOKE ALL ON FUNCTION private.public_provider_point(public.geography, boolean) FROM PUBLIC;

-- ---------------------------------------------------------------------------
-- 2. Search.
--
-- Every word of the query must appear somewhere in the provider's business
-- or owner name, address, or one of their services' names or categories.
-- Name matches rank first, then service matches, then address matches; ties
-- go to the nearest provider when the caller shares a location.
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.search_providers(
    p_query text,
    p_latitude double precision DEFAULT NULL,
    p_longitude double precision DEFAULT NULL,
    p_limit integer DEFAULT 30)
 RETURNS TABLE(
    provider_id uuid,
    provider_name text,
    profile_pic text,
    cover_photo text,
    address_text text,
    approximate_location boolean,
    distance_km double precision,
    categories text[],
    service_count integer,
    min_price numeric,
    matched_services jsonb,
    accepts_bookings boolean,
    offers_studio boolean,
    offers_mobile boolean)
 LANGUAGE plpgsql
 STABLE
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
    v_query    text := left(lower(btrim(regexp_replace(coalesce(p_query, ''), '\s+', ' ', 'g'))), 80);
    v_limit    integer := least(greatest(coalesce(p_limit, 30), 1), 50);
    v_words    text[];
    v_patterns text[];
    v_contains text;
    v_prefix   text;
    v_origin   public.geography;
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Not authorized' USING ERRCODE = '42501';
    END IF;
    IF char_length(v_query) < 2 THEN
        RETURN;
    END IF;

    -- LIKE patterns with the wildcards in the user's text escaped.
    SELECT array_agg(w ORDER BY ord) INTO v_words
    FROM (
        SELECT DISTINCT ON (w) w, ord
        FROM unnest(string_to_array(v_query, ' ')) WITH ORDINALITY AS t(w, ord)
        WHERE w <> ''
        ORDER BY w, ord
    ) words;
    v_words := v_words[1:6];
    v_patterns := ARRAY(
        SELECT '%' || replace(replace(replace(w, '\', '\\'), '%', '\%'), '_', '\_') || '%'
        FROM unnest(v_words) AS w);
    v_prefix := replace(replace(replace(v_query, '\', '\\'), '%', '\%'), '_', '\_') || '%';
    v_contains := '%' || v_prefix;

    IF p_latitude BETWEEN -90 AND 90 AND p_longitude BETWEEN -180 AND 180 THEN
        v_origin := public.st_setsrid(public.st_makepoint(p_longitude, p_latitude), 4326)::public.geography;
    END IF;

    RETURN QUERY
    WITH candidates AS (
        SELECT pr.id,
               coalesce(nullif(btrim(pr.provider_name), ''),
                        nullif(btrim(concat_ws(' ', btrim(pr.first_name), btrim(pr.last_name))), ''),
                        'Provider') AS display_name,
               pr.profile_pic,
               pr.cover_photos[1] AS cover_photo,
               pr.address_text,
               coalesce(bs.offers_studio, true) AS studio,
               coalesce(bs.offers_mobile, false) AS mobile,
               coalesce(bs.accepts_bookings, true) AS accepting,
               private.public_provider_point(pr.coordinates, bs.offers_studio) AS point,
               lower(concat_ws(' ',
                   pr.provider_name, pr.first_name, pr.last_name,
                   CASE WHEN coalesce(bs.offers_studio, true) THEN pr.address_text END,
                   (SELECT string_agg(concat_ws(' ', s.name, s.category), ' ')
                    FROM public.services s WHERE s.provider_id = pr.id))) AS haystack
        FROM public.profiles pr
        LEFT JOIN public.provider_booking_settings bs ON bs.provider_id = pr.id
        WHERE pr.role = 'provider'
    ),
    matches AS (
        SELECT c.*,
               st.service_count,
               st.min_price,
               st.categories,
               ms.matched,
               (CASE
                    WHEN lower(c.display_name) = v_query THEN 100
                    WHEN lower(c.display_name) LIKE v_prefix THEN 60
                    WHEN lower(c.display_name) LIKE v_contains THEN 40
                    ELSE 0
                END
                + CASE WHEN ms.matched IS NOT NULL THEN 25 ELSE 0 END
                + CASE WHEN c.studio AND lower(coalesce(c.address_text, '')) LIKE v_contains THEN 10 ELSE 0 END
               ) AS score,
               CASE WHEN v_origin IS NOT NULL AND c.point IS NOT NULL
                    THEN round((public.st_distance(c.point, v_origin) / 1000)::numeric, 1)::double precision
               END AS km
        FROM candidates c
        CROSS JOIN LATERAL (
            SELECT count(*)::integer AS service_count,
                   min(s.price) AS min_price,
                   coalesce(array_agg(DISTINCT btrim(s.category))
                                FILTER (WHERE nullif(btrim(s.category), '') IS NOT NULL), '{}'::text[]) AS categories
            FROM public.services s
            WHERE s.provider_id = c.id
        ) st
        LEFT JOIN LATERAL (
            SELECT jsonb_agg(jsonb_build_object(
                       'id', m.id,
                       'name', m.name,
                       'category', m.category,
                       'price', m.price,
                       'duration_minutes', m.duration_minutes)
                   ORDER BY m.rank DESC, m.name) AS matched
            FROM (
                SELECT s.id, s.name, s.category, s.price, s.duration_minutes,
                       CASE WHEN lower(s.name) LIKE v_contains THEN 2
                            WHEN lower(s.name) LIKE ANY (v_patterns) THEN 1
                            ELSE 0 END AS rank
                FROM public.services s
                WHERE s.provider_id = c.id
                  AND (lower(s.name) LIKE ANY (v_patterns)
                       OR lower(coalesce(s.category, '')) LIKE ANY (v_patterns))
                ORDER BY rank DESC, s.name
                LIMIT 3
            ) m
        ) ms ON true
        WHERE c.haystack LIKE ALL (v_patterns)
    )
    SELECT m.id,
           m.display_name,
           m.profile_pic,
           m.cover_photo,
           CASE WHEN m.studio THEN m.address_text END,
           NOT m.studio,
           m.km,
           m.categories,
           m.service_count,
           m.min_price,
           m.matched,
           m.accepting,
           m.studio,
           m.mobile
    FROM matches m
    ORDER BY m.score DESC, m.km ASC NULLS LAST, lower(m.display_name)
    LIMIT v_limit;
END;
$function$;

-- ---------------------------------------------------------------------------
-- 3. Map: providers within p_radius_m of a point, nearest first.
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.map_providers(
    p_latitude double precision,
    p_longitude double precision,
    p_radius_m double precision DEFAULT 20000,
    p_limit integer DEFAULT 200)
 RETURNS TABLE(
    provider_id uuid,
    provider_name text,
    profile_pic text,
    cover_photo text,
    address_text text,
    latitude double precision,
    longitude double precision,
    approximate_location boolean,
    distance_km double precision,
    categories text[],
    service_count integer,
    min_price numeric,
    accepts_bookings boolean,
    offers_studio boolean,
    offers_mobile boolean)
 LANGUAGE plpgsql
 STABLE
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
    v_radius double precision := least(greatest(coalesce(p_radius_m, 20000), 500), 100000);
    v_limit  integer := least(greatest(coalesce(p_limit, 200), 1), 300);
    v_origin public.geography;
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Not authorized' USING ERRCODE = '42501';
    END IF;
    IF p_latitude IS NULL OR p_longitude IS NULL
       OR p_latitude NOT BETWEEN -90 AND 90 OR p_longitude NOT BETWEEN -180 AND 180 THEN
        RAISE EXCEPTION 'invalid_location' USING ERRCODE = '22023';
    END IF;
    v_origin := public.st_setsrid(public.st_makepoint(p_longitude, p_latitude), 4326)::public.geography;

    RETURN QUERY
    WITH nearby AS (
        SELECT pr.id,
               coalesce(nullif(btrim(pr.provider_name), ''),
                        nullif(btrim(concat_ws(' ', btrim(pr.first_name), btrim(pr.last_name))), ''),
                        'Provider') AS display_name,
               pr.profile_pic,
               pr.cover_photos[1] AS cover_photo,
               pr.address_text,
               coalesce(bs.offers_studio, true) AS studio,
               coalesce(bs.offers_mobile, false) AS mobile,
               coalesce(bs.accepts_bookings, true) AS accepting,
               private.public_provider_point(pr.coordinates, bs.offers_studio) AS point
        FROM public.profiles pr
        LEFT JOIN public.provider_booking_settings bs ON bs.provider_id = pr.id
        WHERE pr.role = 'provider'
          AND pr.coordinates IS NOT NULL
          AND public.st_dwithin(pr.coordinates, v_origin, v_radius)
    )
    SELECT n.id,
           n.display_name,
           n.profile_pic,
           n.cover_photo,
           CASE WHEN n.studio THEN n.address_text END,
           public.st_y(n.point::public.geometry),
           public.st_x(n.point::public.geometry),
           NOT n.studio,
           round((public.st_distance(n.point, v_origin) / 1000)::numeric, 1)::double precision,
           st.categories,
           st.service_count,
           st.min_price,
           n.accepting,
           n.studio,
           n.mobile
    FROM nearby n
    CROSS JOIN LATERAL (
        SELECT count(*)::integer AS service_count,
               min(s.price) AS min_price,
               coalesce(array_agg(DISTINCT btrim(s.category))
                            FILTER (WHERE nullif(btrim(s.category), '') IS NOT NULL), '{}'::text[]) AS categories
        FROM public.services s
        WHERE s.provider_id = n.id
    ) st
    ORDER BY public.st_distance(n.point, v_origin)
    LIMIT v_limit;
END;
$function$;

REVOKE ALL ON FUNCTION public.search_providers(text, double precision, double precision, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.search_providers(text, double precision, double precision, integer) TO authenticated;
REVOKE ALL ON FUNCTION public.map_providers(double precision, double precision, double precision, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.map_providers(double precision, double precision, double precision, integer) TO authenticated;
