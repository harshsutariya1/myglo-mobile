-- Cash bookings: always a request, never a fee.
--
-- Business rules (decided 2026-10-07):
--   * A cash booking is always a request the provider has to accept, whatever
--     their "approve each booking" setting says. That setting, and the
--     provider's late-cancellation / no-show fee, apply only to bookings paid
--     in the app (card, wallets, Afterpay; not live yet).
--   * Cash bookings carry no fees at all: no late-cancellation or no-show fee
--     and no Myglo commission. The free-cancellation window still applies, so
--     a late cash cancellation is recorded as late, with nothing owed.
--   * Clients never pay a Myglo fee. Myglo's commission is charged to the
--     provider, on bookings paid in the app only (computed server-side and
--     stored on each booking, as before).
--
-- What changes
--   1. create_booking applies the rules above. Its signature, grants and
--      error keys are unchanged; only the status, approval / fee snapshots
--      and commission it writes differ for cash.
--   2. Existing cash bookings are normalised to no fees (a no-op on current
--      data: every cash booking already has zero fees).
--   3. CHECK constraints make a fee on a cash booking impossible, so
--      cancel_booking and mark_booking_no_show (which charge the snapshot
--      percentage) can only ever record A$0 for cash.
--   4. Column comments document what the provider settings now govern.
--
-- Not changed: bookings already confirmed stay confirmed; requests keep
-- expiring at their start time if the provider doesn't respond.

-- ---------------------------------------------------------------------------
-- 1. Booking creation.
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.create_booking(
    p_booking_id           uuid,
    p_provider_id          uuid,
    p_service_ids          uuid[],
    p_starts_at            timestamptz,
    p_location_type        text,
    p_client_phone         text,
    p_expected_total_cents integer,
    p_payment_method       text             DEFAULT 'cash',
    p_address              jsonb            DEFAULT NULL,
    p_latitude             double precision DEFAULT NULL,
    p_longitude            double precision DEFAULT NULL,
    p_access_notes         text             DEFAULT NULL,
    p_client_notes         text             DEFAULT NULL)
RETURNS public.bookings
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
    v_uid          uuid := auth.uid();
    v_existing     public.bookings%ROWTYPE;
    v_booking      public.bookings%ROWTYPE;
    v_client       public.profiles%ROWTYPE;
    v_provider     public.profiles%ROWTYPE;
    v_settings     public.provider_booking_settings%ROWTYPE;
    v_platform     private.platform_settings%ROWTYPE;
    v_duration     integer;
    v_subtotal     integer;
    v_fee          integer := 0;
    v_method       text := coalesce(p_payment_method, '');
    v_approval     boolean;
    v_late_fee_pct smallint;
    v_local_day    date;
    v_ends_at      timestamptz;
    v_address_text text;
    v_address      jsonb;
    v_point        public.geography;
    v_distance     numeric;
    v_phone        text;
    v_client_name  text;
    v_access_notes text := nullif(btrim(p_access_notes), '');
    v_client_notes text := nullif(btrim(p_client_notes), '');
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'not_authenticated' USING ERRCODE = '42501';
    END IF;
    IF p_booking_id IS NULL OR p_provider_id IS NULL OR p_starts_at IS NULL THEN
        RAISE EXCEPTION 'invalid_request' USING ERRCODE = '22023';
    END IF;

    -- Retried request: hand back what the first attempt created.
    SELECT * INTO v_existing FROM public.bookings WHERE id = p_booking_id;
    IF FOUND THEN
        IF v_existing.client_id = v_uid THEN
            RETURN v_existing;
        END IF;
        RAISE EXCEPTION 'invalid_request' USING ERRCODE = '22023';
    END IF;

    SELECT * INTO v_client FROM public.profiles WHERE id = v_uid;
    IF NOT FOUND OR v_client.role <> 'customer' THEN
        RAISE EXCEPTION 'clients_only' USING ERRCODE = '42501';
    END IF;

    SELECT * INTO v_provider FROM public.profiles WHERE id = p_provider_id AND role = 'provider';
    IF NOT FOUND THEN
        RAISE EXCEPTION 'provider_not_found' USING ERRCODE = 'P0002';
    END IF;

    -- One booking write at a time per provider, so the availability check
    -- below can't race another client booking the same time.
    PERFORM pg_advisory_xact_lock(hashtextextended('myglo.booking.provider:' || p_provider_id::text, 0));

    -- A retry that raced its own original (e.g. after a timeout) finds the
    -- booking here rather than seeing its own slot as taken.
    SELECT * INTO v_existing FROM public.bookings WHERE id = p_booking_id;
    IF FOUND THEN
        IF v_existing.client_id = v_uid THEN
            RETURN v_existing;
        END IF;
        RAISE EXCEPTION 'invalid_request' USING ERRCODE = '22023';
    END IF;

    SELECT * INTO v_settings FROM public.provider_booking_settings WHERE provider_id = p_provider_id;
    IF NOT FOUND OR NOT v_settings.accepts_bookings THEN
        RAISE EXCEPTION 'provider_not_accepting' USING ERRCODE = 'P0001';
    END IF;

    IF v_method <> 'cash' THEN
        RAISE EXCEPTION 'payment_method_unavailable' USING ERRCODE = 'P0001';
    END IF;

    -- Cash bookings are always requests the provider accepts, and never carry
    -- a late-cancellation / no-show fee. The provider's approval and fee
    -- settings apply to bookings paid in the app.
    v_approval := v_method = 'cash' OR v_settings.requires_approval;
    v_late_fee_pct := CASE WHEN v_method = 'cash' THEN 0 ELSE v_settings.cancellation_fee_percent END;

    -- Price and length come from the database, never from the client.
    SELECT sum(r.duration_minutes), sum(r.price_cents)
    INTO v_duration, v_subtotal
    FROM private.resolve_services(p_provider_id, p_service_ids) r;

    IF p_expected_total_cents IS DISTINCT FROM v_subtotal THEN
        RAISE EXCEPTION 'price_changed' USING ERRCODE = 'P0001',
            DETAIL = jsonb_build_object('expected_cents', p_expected_total_cents, 'actual_cents', v_subtotal)::text;
    END IF;

    -- Timing rules, then the slot itself, re-verified under the lock.
    IF p_starts_at < now() + make_interval(mins => v_settings.min_notice_minutes) THEN
        RAISE EXCEPTION 'too_soon' USING ERRCODE = 'P0001',
            DETAIL = jsonb_build_object('min_notice_minutes', v_settings.min_notice_minutes)::text;
    END IF;
    v_local_day := (p_starts_at AT TIME ZONE v_settings.time_zone)::date;
    IF v_local_day > (now() AT TIME ZONE v_settings.time_zone)::date + v_settings.max_advance_days THEN
        RAISE EXCEPTION 'too_far_ahead' USING ERRCODE = 'P0001',
            DETAIL = jsonb_build_object('max_advance_days', v_settings.max_advance_days)::text;
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM private.available_slots(p_provider_id, v_duration, v_local_day, v_local_day) a
        WHERE a.slot_start = p_starts_at) THEN
        RAISE EXCEPTION 'slot_unavailable' USING ERRCODE = 'P0001';
    END IF;
    v_ends_at := p_starts_at + make_interval(mins => v_duration);

    -- A client can't be in two places at once, and can't hoard a calendar.
    IF EXISTS (
        SELECT 1 FROM public.bookings b
        WHERE b.client_id = v_uid
          AND b.status IN ('pending', 'confirmed')
          AND tstzrange(b.starts_at, b.ends_at, '[)') && tstzrange(p_starts_at, v_ends_at, '[)')) THEN
        RAISE EXCEPTION 'client_overlap' USING ERRCODE = 'P0001';
    END IF;
    IF (SELECT count(*) FROM public.bookings b
        WHERE b.client_id = v_uid
          AND b.provider_id = p_provider_id
          AND b.status IN ('pending', 'confirmed')
          AND b.starts_at > now()) >= 5 THEN
        RAISE EXCEPTION 'too_many_bookings' USING ERRCODE = 'P0001';
    END IF;

    -- Where the appointment happens.
    IF p_location_type = 'studio' THEN
        v_address_text := nullif(btrim(v_provider.address_text), '');
        IF NOT v_settings.offers_studio OR v_address_text IS NULL THEN
            RAISE EXCEPTION 'studio_unavailable' USING ERRCODE = 'P0001';
        END IF;
    ELSIF p_location_type = 'client' THEN
        IF NOT v_settings.offers_mobile THEN
            RAISE EXCEPTION 'mobile_unavailable' USING ERRCODE = 'P0001';
        END IF;
        v_address_text := private.format_client_address(p_address);
        v_address := jsonb_build_object(
            'line1', btrim(p_address ->> 'line1'),
            'unit', nullif(btrim(coalesce(p_address ->> 'unit', '')), ''),
            'suburb', btrim(p_address ->> 'suburb'),
            'state', upper(btrim(p_address ->> 'state')),
            'postcode', btrim(p_address ->> 'postcode'));
        IF p_latitude IS NULL OR p_longitude IS NULL
           OR p_latitude NOT BETWEEN -90 AND 90 OR p_longitude NOT BETWEEN -180 AND 180 THEN
            RAISE EXCEPTION 'address_invalid' USING ERRCODE = '22023';
        END IF;
        v_point := public.st_setsrid(public.st_makepoint(p_longitude, p_latitude), 4326)::public.geography;
        IF v_provider.coordinates IS NOT NULL THEN
            v_distance := round((public.st_distance(v_provider.coordinates, v_point) / 1000.0)::numeric, 2);
        END IF;
        IF v_settings.travel_radius_km IS NOT NULL THEN
            IF v_distance IS NULL THEN
                RAISE EXCEPTION 'service_area_unavailable' USING ERRCODE = 'P0001';
            END IF;
            IF v_distance > v_settings.travel_radius_km THEN
                RAISE EXCEPTION 'outside_service_area' USING ERRCODE = 'P0001',
                    DETAIL = jsonb_build_object('distance_km', v_distance, 'radius_km', v_settings.travel_radius_km)::text;
            END IF;
        END IF;
    ELSE
        RAISE EXCEPTION 'invalid_request' USING ERRCODE = '22023';
    END IF;

    v_phone := private.normalize_phone(p_client_phone);
    IF char_length(v_client_notes) > 500 OR char_length(v_access_notes) > 300 THEN
        RAISE EXCEPTION 'notes_too_long' USING ERRCODE = '22023';
    END IF;
    v_client_name := nullif(btrim(concat_ws(' ', btrim(v_client.first_name), btrim(v_client.last_name))), '');

    -- Platform commission, charged to the provider (never the client) on
    -- bookings paid in the app only, and free during the provider's fee-free
    -- period. Cash bookings carry no commission.
    SELECT * INTO v_platform FROM private.platform_settings WHERE id;
    IF FOUND AND v_method <> 'cash' AND v_platform.platform_fee_percent > 0
       AND now() >= v_provider.created_at + make_interval(days => v_platform.fee_free_days) THEN
        v_fee := round(v_subtotal * v_platform.platform_fee_percent / 100.0)::integer;
    END IF;

    INSERT INTO public.bookings (
        id, reference, client_id, provider_id, status, starts_at, ends_at, blocked_until, time_zone,
        duration_minutes, buffer_minutes, location_type, address_text, address, access_notes, location,
        distance_km, provider_name, client_name, client_phone, client_notes, subtotal_cents,
        platform_fee_cents, total_cents, payment_method, payment_status, requires_approval,
        cancellation_window_hours, cancellation_fee_percent)
    VALUES (
        p_booking_id, private.new_booking_reference(), v_uid, p_provider_id,
        CASE WHEN v_approval THEN 'pending' ELSE 'confirmed' END,
        p_starts_at, v_ends_at, v_ends_at + make_interval(mins => v_settings.buffer_minutes), v_settings.time_zone,
        v_duration, v_settings.buffer_minutes, p_location_type, v_address_text, v_address,
        CASE WHEN p_location_type = 'client' THEN v_access_notes END, v_point, v_distance,
        coalesce(nullif(btrim(v_provider.provider_name), ''),
                 nullif(btrim(concat_ws(' ', btrim(v_provider.first_name), btrim(v_provider.last_name))), ''),
                 'Provider'),
        coalesce(v_client_name, 'Client'), v_phone, v_client_notes, v_subtotal,
        v_fee, v_subtotal, v_method, 'pending', v_approval,
        v_settings.cancellation_window_hours, v_late_fee_pct)
    RETURNING * INTO v_booking;

    INSERT INTO public.booking_items (booking_id, service_id, position, service_name, category, duration_minutes, price_cents)
    SELECT v_booking.id, r.service_id, r.ord, r.service_name, r.category, r.duration_minutes, r.price_cents
    FROM private.resolve_services(p_provider_id, p_service_ids) r;

    INSERT INTO public.booking_payments (booking_id, method, status, amount_cents, platform_fee_cents)
    VALUES (v_booking.id, v_method, 'pending', v_booking.total_cents, v_booking.platform_fee_cents);

    PERFORM private.on_booking_event(
        v_booking,
        CASE WHEN v_booking.status = 'pending' THEN 'requested' ELSE 'booked' END,
        'client',
        NULL,
        jsonb_build_object('payment_method', v_method, 'payment_status', 'pending', 'total_cents', v_booking.total_cents));

    RETURN v_booking;
EXCEPTION
    -- Belt and braces: the exclusion constraint caught an overlap the check
    -- above should already have rejected.
    WHEN exclusion_violation THEN
        RAISE EXCEPTION 'slot_unavailable' USING ERRCODE = 'P0001';
END;
$function$;

-- ---------------------------------------------------------------------------
-- 2. Normalise existing cash bookings.
-- ---------------------------------------------------------------------------

UPDATE public.bookings
SET platform_fee_cents = 0,
    cancellation_fee_percent = 0,
    cancellation_fee_cents = 0,
    updated_at = now()
WHERE payment_method = 'cash'
  AND (platform_fee_cents <> 0 OR cancellation_fee_percent <> 0 OR cancellation_fee_cents <> 0);

UPDATE public.booking_payments
SET platform_fee_cents = 0,
    updated_at = now()
WHERE method = 'cash' AND platform_fee_cents <> 0;

-- ---------------------------------------------------------------------------
-- 3. Guarantees.
-- ---------------------------------------------------------------------------

ALTER TABLE public.bookings
    ADD CONSTRAINT bookings_cash_fee_free CHECK (
        payment_method <> 'cash'
        OR (platform_fee_cents = 0 AND cancellation_fee_percent = 0 AND cancellation_fee_cents = 0));

ALTER TABLE public.booking_payments
    ADD CONSTRAINT booking_payments_cash_fee_free CHECK (method <> 'cash' OR platform_fee_cents = 0);

-- ---------------------------------------------------------------------------
-- 4. Documentation.
-- ---------------------------------------------------------------------------

COMMENT ON COLUMN public.provider_booking_settings.requires_approval IS
    'Whether bookings paid in the app wait for the provider to accept. Cash bookings are always requests.';
COMMENT ON COLUMN public.provider_booking_settings.cancellation_fee_percent IS
    'Late-cancellation / no-show fee on bookings paid in the app. Cash bookings never carry a fee.';
COMMENT ON COLUMN public.bookings.platform_fee_cents IS
    'Myglo commission charged to the provider (never the client). Always 0 for cash bookings.';
COMMENT ON COLUMN public.bookings.cancellation_fee_percent IS
    'Late-cancellation / no-show fee snapshot. Always 0 for cash bookings.';
