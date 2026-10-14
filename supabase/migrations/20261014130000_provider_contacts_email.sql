-- Contacts: a client's email, when they've chosen to make it public.
--
-- The email comes from the public_profiles view, which already masks it
-- unless the client turned on "show email" (profiles.is_email_public), so a
-- provider only ever sees what the client chose to share. Phone numbers are
-- unchanged: the one the client gave on their latest booking, which the
-- provider can already read on booking_details.
--
-- Adding a result column changes the function's return type, so it's dropped
-- and re-created (same arguments, grants restated). Still SECURITY INVOKER:
-- the bookings RLS policy applies as before.

DROP FUNCTION public.get_provider_contacts(text, timestamptz, uuid, integer, uuid);

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
    client_email           text,
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
           pp.email,
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
    'The signed-in provider''s clients (anyone who has booked with them), most recent appointment first, keyset paged on (last_starts_at, client_id), optionally filtered by name or phone, or to one client (p_client_id); client_email only when the client made it public (security invoker: RLS applies).';

REVOKE ALL ON FUNCTION public.get_provider_contacts(text, timestamptz, uuid, integer, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_provider_contacts(text, timestamptz, uuid, integer, uuid) TO authenticated;
