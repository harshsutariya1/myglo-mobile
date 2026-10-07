-- Business Tools overview: the signed-in provider's numbers for the current
-- month, aggregated in the database so the app never downloads every booking
-- just to count it.
--
-- "This month" is the provider's current calendar month in their own time
-- zone (provider_booking_settings.time_zone; Gold Coast, AEST, for every
-- provider at launch). A booking belongs to the month its appointment starts
-- in, so both numbers describe the same appointments:
--   * completed_bookings:   appointments marked completed.
--   * cash_collected_cents: total of cash bookings recorded as paid (by
--                           complete_booking or record_cash_payment).
--
-- SECURITY INVOKER: runs with the caller's privileges, so the existing
-- "Parties can view their bookings" RLS policy still applies on top of the
-- explicit provider_id filter. No table grants or policies change. The
-- (provider_id, starts_at) index covers the month range.

CREATE FUNCTION public.get_provider_business_stats()
RETURNS TABLE (
    period_start         date,
    time_zone            text,
    completed_bookings   integer,
    cash_collected_cents bigint
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

    RETURN QUERY
    SELECT v_month,
           v_tz,
           (count(*) FILTER (WHERE b.status = 'completed'))::integer,
           coalesce(sum(b.total_cents) FILTER (WHERE b.payment_method = 'cash' AND b.payment_status = 'paid'), 0)::bigint
    FROM public.bookings b
    WHERE b.provider_id = v_uid
      AND b.starts_at >= (v_month::timestamp AT TIME ZONE v_tz)
      AND b.starts_at < ((v_month + interval '1 month') AT TIME ZONE v_tz);
END;
$function$;

COMMENT ON FUNCTION public.get_provider_business_stats() IS
    'The signed-in provider''s completed bookings and cash recorded as paid for the current month in their time zone (security invoker: RLS applies).';

REVOKE ALL ON FUNCTION public.get_provider_business_stats() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_provider_business_stats() TO authenticated;
