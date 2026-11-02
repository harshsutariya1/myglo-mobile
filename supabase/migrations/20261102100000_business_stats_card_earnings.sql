-- Business Tools overview: add what the provider earned from card bookings
-- this month, so the overview's money tile works for card-only providers
-- (it showed "Cash collected", always $0 for them).
--
-- card_earned_cents follows get_provider_financials exactly, so the overview
-- and the Financials screen agree: each settlement's kept amount minus the
-- Myglo fee, for this month's appointments (by start time, in the provider's
-- time zone), leaving out settlements that don't apply or were reversed.
--
-- Still SECURITY INVOKER: the "Providers can view own settlements" and
-- booking RLS policies apply on top of the explicit provider_id filters.
-- Adding an output column changes the return type, so the function is
-- dropped and recreated (in this migration's transaction) with the same
-- grants. Older app builds ignore the new column.

DROP FUNCTION public.get_provider_business_stats();

CREATE FUNCTION public.get_provider_business_stats()
RETURNS TABLE (
    period_start         date,
    time_zone            text,
    completed_bookings   integer,
    cash_collected_cents bigint,
    card_earned_cents    bigint
)
LANGUAGE plpgsql
STABLE
SECURITY INVOKER
SET search_path TO ''
AS $function$
DECLARE
    v_uid   uuid := auth.uid();
    v_tz    text;
    v_month date;
    v_from  timestamptz;
    v_to    timestamptz;
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'not_authenticated' USING ERRCODE = '42501';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = v_uid AND p.role = 'provider') THEN
        RAISE EXCEPTION 'providers_only' USING ERRCODE = '42501';
    END IF;

    SELECT s.time_zone INTO v_tz FROM public.provider_booking_settings s WHERE s.provider_id = v_uid;
    v_tz := coalesce(v_tz, 'Australia/Brisbane');
    v_month := date_trunc('month', now() AT TIME ZONE v_tz)::date;
    v_from := v_month::timestamp AT TIME ZONE v_tz;
    v_to := (v_month + interval '1 month') AT TIME ZONE v_tz;

    RETURN QUERY
    SELECT v_month,
           v_tz,
           (count(*) FILTER (WHERE b.status = 'completed'))::integer,
           coalesce(sum(b.total_cents) FILTER (WHERE b.payment_method = 'cash' AND b.payment_status = 'paid'), 0)::bigint,
           coalesce((
               SELECT sum(s.kept_cents - s.platform_fee_cents)
               FROM public.booking_settlements s
               JOIN public.bookings sb ON sb.id = s.booking_id
               WHERE s.provider_id = v_uid
                 AND sb.starts_at >= v_from AND sb.starts_at < v_to
                 AND s.status NOT IN ('not_applicable', 'reversed')), 0)::bigint
    FROM public.bookings b
    WHERE b.provider_id = v_uid
      AND b.starts_at >= v_from
      AND b.starts_at < v_to;
END;
$function$;

COMMENT ON FUNCTION public.get_provider_business_stats() IS
    'The signed-in provider''s completed bookings, cash recorded as paid and card earnings after Myglo''s fee for the current month in their time zone (security invoker: RLS applies).';

REVOKE ALL ON FUNCTION public.get_provider_business_stats() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_provider_business_stats() TO authenticated;
