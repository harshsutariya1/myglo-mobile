-- Business Tools "Contacts": every client who has booked with the signed-in
-- provider, one row per client, aggregated in the database so the app never
-- downloads every booking to build the list.
--
-- Who is a contact: any client with at least one booking with the provider,
-- whatever its outcome (requests, upcoming, completed, cancelled…). Bookings
-- whose client deleted their account (client_id set to NULL) are left out:
-- they can't be grouped and that person is no longer a Myglo client. The
-- bookings themselves stay in the provider's appointment history.
--
-- Name and phone are the ones the client gave on their most recent booking
-- (bookings snapshot both); the photo comes from the masked public_profiles
-- view, as in booking_details. Nothing is exposed that the provider can't
-- already read on booking_details.
--
-- Status follows booking_details: a request still pending after its start
-- time counts as expired.
--
-- Wall-clock values (*_local) are in each booking's own time zone (Gold
-- Coast, AEST, for every provider at launch), matching booking_details.
--
-- SECURITY INVOKER: both functions run with the caller's privileges, so the
-- "Parties can view their bookings" RLS policy still applies on top of the
-- explicit provider_id filter. No table grants or policies change. The
-- (provider_id, starts_at) index covers the provider filter.

CREATE FUNCTION public.get_provider_contacts(
    p_search          text        DEFAULT NULL,
    p_after_last_at   timestamptz DEFAULT NULL,
    p_after_client_id uuid        DEFAULT NULL,
    p_limit           integer     DEFAULT 30,
    p_client_id       uuid        DEFAULT NULL
)
RETURNS TABLE (
    client_id              uuid,
    client_name            text,
    client_avatar_url      text,
    client_phone           text,
    time_zone              text,
    booking_count          integer,
    completed_count        integer,
    upcoming_count         integer,
    total_paid_cents       bigint,
    first_booked_at        timestamptz,
    last_starts_at         timestamptz,
    last_visit_local       timestamp,
    next_starts_at_local   timestamp
)
LANGUAGE plpgsql
STABLE
SECURITY INVOKER
SET search_path TO ''
AS $function$
DECLARE
    v_uid     uuid    := auth.uid();
    v_limit   integer := least(greatest(coalesce(p_limit, 30), 1), 100);
    v_search  text    := left(nullif(btrim(coalesce(p_search, '')), ''), 100);
    v_pattern text;
    v_digits  text;
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'not_authenticated' USING ERRCODE = '42501';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = v_uid AND p.role = 'provider') THEN
        RAISE EXCEPTION 'providers_only' USING ERRCODE = '42501';
    END IF;
    IF (p_after_last_at IS NULL) <> (p_after_client_id IS NULL) THEN
        RAISE EXCEPTION 'invalid_cursor' USING ERRCODE = '22023';
    END IF;

    IF v_search IS NOT NULL THEN
        -- Matched literally: LIKE wildcards in the search are escaped.
        v_pattern := '%' || replace(replace(replace(v_search, '\', '\\'), '%', '\%'), '_', '\_') || '%';
        -- Phone numbers also match on their digits alone, so "0412 345"
        -- finds "0412345678" (three digits at least, to avoid noise).
        v_digits := regexp_replace(v_search, '\D', '', 'g');
        IF length(v_digits) < 3 THEN
            v_digits := NULL;
        END IF;
    END IF;

    RETURN QUERY
    WITH mine AS (
        SELECT b.id,
               b.client_id AS cid,
               b.client_name AS cname,
               b.client_phone AS cphone,
               b.time_zone AS tz,
               b.starts_at,
               b.ends_at,
               b.total_cents,
               b.payment_status,
               b.created_at,
               CASE WHEN b.status = 'pending' AND b.starts_at <= now() THEN 'expired' ELSE b.status END AS st
        FROM public.bookings b
        WHERE b.provider_id = v_uid
          AND b.client_id IS NOT NULL
          AND (p_client_id IS NULL OR b.client_id = p_client_id)
    ),
    latest AS (
        SELECT DISTINCT ON (m.cid) m.cid, m.cname, m.cphone, m.tz
        FROM mine m
        ORDER BY m.cid, m.created_at DESC, m.id DESC
    ),
    totals AS (
        SELECT m.cid,
               count(*)::integer AS n_bookings,
               (count(*) FILTER (WHERE m.st = 'completed'))::integer AS n_completed,
               (count(*) FILTER (WHERE m.st = 'pending' OR (m.st = 'confirmed' AND m.ends_at > now())))::integer
                   AS n_upcoming,
               coalesce(sum(m.total_cents) FILTER (WHERE m.payment_status = 'paid'), 0)::bigint AS paid_cents,
               min(m.created_at) AS first_at,
               max(m.starts_at) AS last_at,
               max(m.starts_at AT TIME ZONE m.tz) FILTER (WHERE m.st = 'completed') AS last_visit,
               min(m.starts_at AT TIME ZONE m.tz)
                   FILTER (WHERE m.st = 'pending' OR (m.st = 'confirmed' AND m.ends_at > now())) AS next_local
        FROM mine m
        GROUP BY m.cid
    )
    SELECT t.cid,
           l.cname,
           pp.profile_pic,
           l.cphone,
           l.tz,
           t.n_bookings,
           t.n_completed,
           t.n_upcoming,
           t.paid_cents,
           t.first_at,
           t.last_at,
           t.last_visit,
           t.next_local
    FROM totals t
    JOIN latest l ON l.cid = t.cid
    LEFT JOIN public.public_profiles pp ON pp.id = t.cid
    WHERE (v_pattern IS NULL
           OR l.cname ILIKE v_pattern ESCAPE '\'
           OR l.cphone ILIKE v_pattern ESCAPE '\'
           OR (v_digits IS NOT NULL AND regexp_replace(l.cphone, '\D', '', 'g') LIKE '%' || v_digits || '%'))
      AND (p_after_last_at IS NULL OR (t.last_at, t.cid) < (p_after_last_at, p_after_client_id))
    -- Most recent appointment first (an upcoming one counts), so active
    -- clients lead; client_id keeps the order total for keyset paging.
    ORDER BY t.last_at DESC, t.cid DESC
    LIMIT v_limit;
END;
$function$;

COMMENT ON FUNCTION public.get_provider_contacts(text, timestamptz, uuid, integer, uuid) IS
    'The signed-in provider''s clients (anyone who has booked with them), most recent appointment first, keyset paged on (last_starts_at, client_id), optionally filtered by name or phone, or to one client (p_client_id) (security invoker: RLS applies).';

REVOKE ALL ON FUNCTION public.get_provider_contacts(text, timestamptz, uuid, integer, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_provider_contacts(text, timestamptz, uuid, integer, uuid) TO authenticated;

CREATE FUNCTION public.count_provider_contacts()
RETURNS integer
LANGUAGE plpgsql
STABLE
SECURITY INVOKER
SET search_path TO ''
AS $function$
DECLARE
    v_uid uuid := auth.uid();
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'not_authenticated' USING ERRCODE = '42501';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = v_uid AND p.role = 'provider') THEN
        RAISE EXCEPTION 'providers_only' USING ERRCODE = '42501';
    END IF;

    RETURN (
        SELECT count(DISTINCT b.client_id)::integer
        FROM public.bookings b
        WHERE b.provider_id = v_uid
          AND b.client_id IS NOT NULL
    );
END;
$function$;

COMMENT ON FUNCTION public.count_provider_contacts() IS
    'How many clients have booked with the signed-in provider; the same people get_provider_contacts lists (security invoker: RLS applies).';

REVOKE ALL ON FUNCTION public.count_provider_contacts() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.count_provider_contacts() TO authenticated;
