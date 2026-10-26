-- Cities a client can browse from the home screen, for when they don't share
-- their location or there are no salons near it.
--
-- The list is curated: the future admin panel will add, edit and switch off
-- cities. Until then rows are managed with SQL, so clients get no direct
-- table access and read it through list_service_cities() instead, which also
-- tells them how many salons each city has.

-- ---------------------------------------------------------------------------
-- 1. Table.
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.service_cities (
    id          uuid                  PRIMARY KEY DEFAULT gen_random_uuid(),
    name        text                  NOT NULL,
    state       text                  NOT NULL,
    centre      public.geography(Point, 4326) NOT NULL,
    -- How far from the centre counts as "in" the city: providers within it
    -- are listed for the city. Bounded like map_providers' radius.
    radius_m    integer               NOT NULL,
    sort_order  integer               NOT NULL DEFAULT 0,
    is_active   boolean               NOT NULL DEFAULT true,
    created_at  timestamptz           NOT NULL DEFAULT now(),
    updated_at  timestamptz           NOT NULL DEFAULT now(),
    CONSTRAINT service_cities_name_not_blank CHECK (char_length(btrim(name)) BETWEEN 1 AND 80),
    CONSTRAINT service_cities_state_not_blank CHECK (char_length(btrim(state)) BETWEEN 1 AND 40),
    CONSTRAINT service_cities_radius_range CHECK (radius_m BETWEEN 1000 AND 100000)
);

COMMENT ON TABLE public.service_cities IS
    'Curated cities clients can browse providers in. Admin-managed; read through list_service_cities().';

CREATE UNIQUE INDEX IF NOT EXISTS service_cities_name_state_key
    ON public.service_cities (lower(btrim(name)), lower(btrim(state)));

ALTER TABLE public.service_cities ENABLE ROW LEVEL SECURITY;

-- No policies: only list_service_cities() (and the service role) reads it.
REVOKE ALL ON public.service_cities FROM anon, authenticated;

CREATE OR REPLACE FUNCTION private.touch_service_city()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
BEGIN
    NEW.updated_at := now();
    RETURN NEW;
END;
$function$;

REVOKE ALL ON FUNCTION private.touch_service_city() FROM PUBLIC;

DROP TRIGGER IF EXISTS service_cities_touch ON public.service_cities;
CREATE TRIGGER service_cities_touch
    BEFORE UPDATE ON public.service_cities
    FOR EACH ROW EXECUTE FUNCTION private.touch_service_city();

-- ---------------------------------------------------------------------------
-- 2. Launch cities. Gold Coast is where Myglo launches; the others show as
--    "coming soon" until providers sign up there.
-- ---------------------------------------------------------------------------

INSERT INTO public.service_cities (name, state, centre, radius_m, sort_order)
VALUES
    ('Gold Coast', 'QLD',
     public.st_setsrid(public.st_makepoint(153.4000, -28.0167), 4326)::public.geography, 30000, 1),
    ('Brisbane', 'QLD',
     public.st_setsrid(public.st_makepoint(153.0251, -27.4698), 4326)::public.geography, 25000, 2),
    ('Sunshine Coast', 'QLD',
     public.st_setsrid(public.st_makepoint(153.0600, -26.6200), 4326)::public.geography, 30000, 3)
ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------------
-- 3. Read: active cities in display order, each with how many providers
--    are within its radius (the same set map_providers returns for it).
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.list_service_cities()
 RETURNS TABLE(
    city_id        uuid,
    name           text,
    state          text,
    latitude       double precision,
    longitude      double precision,
    radius_m       integer,
    provider_count integer)
 LANGUAGE plpgsql
 STABLE
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Not authorized' USING ERRCODE = '42501';
    END IF;

    RETURN QUERY
    SELECT c.id,
           btrim(c.name),
           btrim(c.state),
           public.st_y(c.centre::public.geometry),
           public.st_x(c.centre::public.geometry),
           c.radius_m,
           (SELECT count(*)::integer
            FROM public.profiles pr
            WHERE pr.role = 'provider'
              AND pr.coordinates IS NOT NULL
              AND public.st_dwithin(pr.coordinates, c.centre, c.radius_m))
    FROM public.service_cities c
    WHERE c.is_active
    ORDER BY c.sort_order, lower(c.name);
END;
$function$;

REVOKE ALL ON FUNCTION public.list_service_cities() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_service_cities() TO authenticated, service_role;
