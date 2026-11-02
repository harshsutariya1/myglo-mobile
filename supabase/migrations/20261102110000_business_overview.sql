-- Business Tools overview, second pass: everything the provider's business
-- page shows comes from this one call.
--
-- New columns, on top of this month's completed bookings, cash collected and
-- card earnings:
--   * previous_completed_bookings, previous_earned_cents: the same figures
--     for last month (provider's calendar month, by appointment start), so
--     the page can compare. Earned = cash recorded as paid + card earnings
--     after Myglo's fee, counted as in get_provider_financials.
--   * upcoming_week_bookings: confirmed appointments starting in the next
--     seven days.
--   * pending_requests, next_reply_by: requests still waiting for the
--     provider, and the earliest reply deadline among them (respond_by, or
--     the start time for requests made before respond_by existed). Requests
--     past their deadline are left out; the expiry job closes them.
--   * reviews_awaiting_reply: visible reviews of the provider without a
--     public reply.
--   * on_its_way_cents: card shares not yet transferred (scheduled,
--     processing or held), as on the Financials screen.
--
-- Still SECURITY INVOKER with explicit provider_id filters: the existing
-- bookings, settlements and reviews RLS policies apply on top. The
-- (provider_id, starts_at), pending-deadline, settlements-provider and
-- reviews-provider indexes cover every lookup. The return type changes, so
-- the function is dropped and recreated with the same grants; older app
-- builds ignore the new columns.

DROP FUNCTION public.get_provider_business_stats();

CREATE FUNCTION public.get_provider_business_stats()
RETURNS TABLE (
    period_start                date,
    time_zone                   text,
    completed_bookings          integer,
    cash_collected_cents        bigint,
    card_earned_cents           bigint,
    previous_completed_bookings integer,
    previous_earned_cents       bigint,
    upcoming_week_bookings      integer,
    pending_requests            integer,
    next_reply_by               timestamptz,
    reviews_awaiting_reply      integer,
    on_its_way_cents            bigint
)
LANGUAGE plpgsql
STABLE
SECURITY INVOKER
SET search_path TO ''
AS $function$
DECLARE
    v_uid       uuid := auth.uid();
    v_now       timestamptz := now();
    v_tz        text;
    v_month     date;
    v_from      timestamptz;
    v_to        timestamptz;
    v_prev_from timestamptz;
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'not_authenticated' USING ERRCODE = '42501';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = v_uid AND p.role = 'provider') THEN
        RAISE EXCEPTION 'providers_only' USING ERRCODE = '42501';
    END IF;

    SELECT s.time_zone INTO v_tz FROM public.provider_booking_settings s WHERE s.provider_id = v_uid;
    v_tz := coalesce(v_tz, 'Australia/Brisbane');
    v_month := date_trunc('month', v_now AT TIME ZONE v_tz)::date;
    v_from := v_month::timestamp AT TIME ZONE v_tz;
    v_to := (v_month + interval '1 month') AT TIME ZONE v_tz;
    v_prev_from := (v_month - interval '1 month') AT TIME ZONE v_tz;

    RETURN QUERY
    WITH months AS (
        SELECT b.starts_at >= v_from AS this_month,
               count(*) FILTER (WHERE b.status = 'completed') AS completed,
               coalesce(sum(b.total_cents) FILTER (WHERE b.payment_method = 'cash' AND b.payment_status = 'paid'), 0) AS cash
        FROM public.bookings b
        WHERE b.provider_id = v_uid
          AND b.starts_at >= v_prev_from
          AND b.starts_at < v_to
        GROUP BY 1
    ),
    card AS (
        SELECT sb.starts_at >= v_from AS this_month,
               sum(s.kept_cents - s.platform_fee_cents) AS earned
        FROM public.booking_settlements s
        JOIN public.bookings sb ON sb.id = s.booking_id
        WHERE s.provider_id = v_uid
          AND sb.starts_at >= v_prev_from
          AND sb.starts_at < v_to
          AND s.status NOT IN ('not_applicable', 'reversed')
        GROUP BY 1
    ),
    requests AS (
        SELECT count(*) AS waiting, min(coalesce(b.respond_by, b.starts_at)) AS reply_by
        FROM public.bookings b
        WHERE b.provider_id = v_uid
          AND b.status = 'pending'
          AND coalesce(b.respond_by, b.starts_at) > v_now
    )
    SELECT v_month,
           v_tz,
           coalesce((SELECT m.completed FROM months m WHERE m.this_month), 0)::integer,
           coalesce((SELECT m.cash FROM months m WHERE m.this_month), 0)::bigint,
           coalesce((SELECT c.earned FROM card c WHERE c.this_month), 0)::bigint,
           coalesce((SELECT m.completed FROM months m WHERE NOT m.this_month), 0)::integer,
           (coalesce((SELECT m.cash FROM months m WHERE NOT m.this_month), 0)
             + coalesce((SELECT c.earned FROM card c WHERE NOT c.this_month), 0))::bigint,
           (SELECT count(*) FROM public.bookings b
            WHERE b.provider_id = v_uid
              AND b.status = 'confirmed'
              AND b.starts_at >= v_now
              AND b.starts_at < v_now + interval '7 days')::integer,
           (SELECT r.waiting FROM requests r)::integer,
           (SELECT r.reply_by FROM requests r),
           (SELECT count(*) FROM public.reviews rv
            WHERE rv.provider_id = v_uid
              AND rv.hidden_at IS NULL
              AND nullif(btrim(rv.reply), '') IS NULL)::integer,
           coalesce((SELECT sum(s.transfer_cents) FROM public.booking_settlements s
                     WHERE s.provider_id = v_uid
                       AND s.status IN ('scheduled', 'processing', 'held')), 0)::bigint;
END;
$function$;

COMMENT ON FUNCTION public.get_provider_business_stats() IS
    'The signed-in provider''s business overview: this and last month''s completed bookings and earnings (cash plus card after Myglo''s fee) in their time zone, the next seven days'' appointments, waiting requests, unanswered reviews and card shares on their way (security invoker: RLS applies).';

REVOKE ALL ON FUNCTION public.get_provider_business_stats() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_provider_business_stats() TO authenticated;
