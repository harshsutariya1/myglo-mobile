-- Checks for hiding a provider from the marketplace
-- (20261112120000_provider_marketplace_visibility).
--
-- Run inside a transaction that is rolled back (see supabase/tests/jobs.sql).
-- Needs a bookable provider with a location, working hours and a service;
-- it creates a throwaway client, which the rollback removes. The rule that
-- providers don't delete their own account is checked in
-- supabase/tests/account_deletion.sql.

CREATE FUNCTION pg_temp.act_as(p_uid uuid)
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
    PERFORM set_config('request.jwt.claims', jsonb_build_object(
        'sub', p_uid, 'role', 'authenticated', 'aal', 'aal1', 'session_id', gen_random_uuid())::text, true);
    PERFORM set_config('role', 'authenticated', true);
END;
$$;

CREATE FUNCTION pg_temp.as_owner()
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
    PERFORM set_config('role', 'postgres', true);
    PERFORM set_config('request.jwt.claims', '', true);
END;
$$;

-- Runs p_sql and checks it fails with p_expected as the message.
CREATE FUNCTION pg_temp.expect_error(p_sql text, p_expected text, p_label text)
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
    EXECUTE p_sql;
    RAISE EXCEPTION 'FAIL %: expected "%" but it succeeded', p_label, p_expected;
EXCEPTION
    WHEN OTHERS THEN
        IF SQLERRM LIKE 'FAIL %' THEN RAISE; END IF;
        IF SQLERRM <> p_expected THEN
            RAISE EXCEPTION 'FAIL %: expected "%" got "%"', p_label, p_expected, SQLERRM;
        END IF;
END;
$$;

-- What a client sees of p_provider: on the map, in search, as free times,
-- and as "listed" on the public profile.
CREATE FUNCTION pg_temp.visible(p_provider uuid, p_name text, p_lat double precision, p_lng double precision, p_service uuid)
RETURNS jsonb LANGUAGE plpgsql AS $$
DECLARE
    v_tz text;
BEGIN
    SELECT time_zone INTO v_tz FROM public.provider_booking_settings WHERE provider_id = p_provider;
    RETURN jsonb_build_object(
        'map', EXISTS (SELECT 1 FROM public.map_providers(p_lat, p_lng, 2000, 300) m WHERE m.provider_id = p_provider),
        'search', EXISTS (SELECT 1 FROM public.search_providers(p_name, p_lat, p_lng, 50) s WHERE s.provider_id = p_provider),
        'slots', EXISTS (SELECT 1 FROM public.get_available_slots(
            p_provider, ARRAY[p_service], (now() AT TIME ZONE v_tz)::date + 1, (now() AT TIME ZONE v_tz)::date + 14)),
        'listed', (SELECT pp.is_listed FROM public.public_profiles pp WHERE pp.id = p_provider));
END;
$$;

DO $test$
DECLARE
    v_provider uuid;
    v_other    uuid;
    v_client   uuid := gen_random_uuid();
    v_service  uuid;
    v_price    integer;
    v_duration integer;
    v_name     text;
    v_lat      double precision;
    v_lng      double precision;
    v_slot     timestamptz;
    v_tz       text;
    v_booking  public.bookings;
    v_settings public.provider_booking_settings;
    v_seen     jsonb;
    v_rows     integer;
    v_all      constant jsonb := '{"map": true, "search": true, "slots": true, "listed": true}';
    v_none     constant jsonb := '{"map": false, "search": false, "slots": false, "listed": false}';
BEGIN
    -- Privileges: the switch is the provider's; the helpers are private.
    IF NOT has_column_privilege('authenticated', 'public.provider_booking_settings', 'hidden_from_marketplace', 'UPDATE')
       OR has_column_privilege('authenticated', 'public.provider_booking_settings', 'hidden_at', 'UPDATE')
       OR has_column_privilege('anon', 'public.provider_booking_settings', 'hidden_from_marketplace', 'UPDATE')
       OR has_function_privilege('authenticated', 'private.is_unlisted(uuid)', 'EXECUTE')
       OR has_function_privilege('authenticated', 'private.is_hidden_provider(uuid)', 'EXECUTE')
       OR has_function_privilege('authenticated', 'private.self_deletion_blockers(uuid)', 'EXECUTE') THEN
        RAISE EXCEPTION 'FAIL: privileges';
    END IF;

    SELECT p.id, p.provider_name,
           public.st_y(p.coordinates::public.geometry), public.st_x(p.coordinates::public.geometry), s.time_zone
    INTO v_provider, v_name, v_lat, v_lng, v_tz
    FROM public.profiles p
    JOIN public.provider_booking_settings s ON s.provider_id = p.id
    WHERE p.role = 'provider' AND s.accepts_bookings AND s.offers_studio AND NOT s.hidden_from_marketplace
      AND p.coordinates IS NOT NULL AND p.address_text IS NOT NULL AND char_length(btrim(p.provider_name)) >= 3
      AND NOT private.is_unbookable(p.id)
      AND EXISTS (SELECT 1 FROM public.provider_working_hours h WHERE h.provider_id = p.id)
      AND EXISTS (SELECT 1 FROM public.services sv WHERE sv.provider_id = p.id AND sv.price >= 20 AND sv.duration_minutes > 0)
    ORDER BY (SELECT count(*) FROM public.provider_working_hours h WHERE h.provider_id = p.id) DESC, p.id
    LIMIT 1;
    SELECT p.id INTO v_other FROM public.profiles p WHERE p.role = 'provider' AND p.id <> v_provider LIMIT 1;
    SELECT sv.id, round(sv.price * 100)::integer, sv.duration_minutes INTO v_service, v_price, v_duration
    FROM public.services sv
    WHERE sv.provider_id = v_provider AND sv.price >= 20 AND sv.duration_minutes > 0
    ORDER BY sv.duration_minutes, sv.id LIMIT 1;
    IF v_provider IS NULL OR v_other IS NULL OR v_service IS NULL THEN
        RAISE EXCEPTION 'needs two providers, one bookable with a location, hours and a service';
    END IF;
    UPDATE public.provider_booking_settings
    SET accepts_cash = true, max_advance_days = 60, min_notice_minutes = 0
    WHERE provider_id = v_provider;

    INSERT INTO auth.users (id, instance_id, aud, role, email)
    VALUES (v_client, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
            'visibility-' || v_client || '@example.test');
    INSERT INTO public.profiles (id, role, email, first_name, last_name, phone_number)
    VALUES (v_client, 'customer', 'visibility-' || v_client || '@example.test', 'Test', 'Client', '0412345678');

    -- Listed: a client finds and can book the provider.
    PERFORM pg_temp.act_as(v_client);
    v_seen := pg_temp.visible(v_provider, v_name, v_lat, v_lng, v_service);
    IF v_seen <> v_all THEN
        RAISE EXCEPTION 'FAIL listed: %', v_seen;
    END IF;

    -- A cash request made while listed, to check it survives hiding.
    PERFORM pg_temp.as_owner();
    SELECT a.slot_start INTO v_slot
    FROM private.available_slots(v_provider, v_duration, (now() AT TIME ZONE v_tz)::date + 2, (now() AT TIME ZONE v_tz)::date + 16) a
    ORDER BY a.slot_start LIMIT 1;
    IF v_slot IS NULL THEN
        RAISE EXCEPTION 'no free slot for the test provider';
    END IF;
    PERFORM pg_temp.act_as(v_client);
    v_booking := public.create_booking(gen_random_uuid(), v_provider, ARRAY[v_service], v_slot, 'studio', '0412345678', v_price, 'cash');
    IF v_booking.status <> 'pending' THEN
        RAISE EXCEPTION 'FAIL request: %', v_booking.status;
    END IF;

    -- Only the provider flips their own switch, and only the switch.
    PERFORM pg_temp.act_as(v_other);
    UPDATE public.provider_booking_settings SET hidden_from_marketplace = true WHERE provider_id = v_provider;
    GET DIAGNOSTICS v_rows = ROW_COUNT;
    IF v_rows <> 0 THEN
        RAISE EXCEPTION 'FAIL: another provider hid this one';
    END IF;
    PERFORM pg_temp.act_as(v_client);
    UPDATE public.provider_booking_settings SET hidden_from_marketplace = true WHERE provider_id = v_provider;
    GET DIAGNOSTICS v_rows = ROW_COUNT;
    IF v_rows <> 0 THEN
        RAISE EXCEPTION 'FAIL: a client hid a provider';
    END IF;
    PERFORM pg_temp.act_as(v_provider);
    PERFORM pg_temp.expect_error(
        format('UPDATE public.provider_booking_settings SET hidden_at = now() WHERE provider_id = %L', v_provider),
        'permission denied for table provider_booking_settings', 'provider wrote hidden_at');

    -- Hide.
    UPDATE public.provider_booking_settings SET hidden_from_marketplace = true WHERE provider_id = v_provider;
    PERFORM pg_temp.as_owner();
    SELECT * INTO v_settings FROM public.provider_booking_settings WHERE provider_id = v_provider;
    IF NOT v_settings.hidden_from_marketplace OR v_settings.hidden_at IS NULL
       OR NOT private.is_hidden_provider(v_provider) OR NOT private.is_unlisted(v_provider)
       OR private.is_unbookable(v_provider) THEN
        RAISE EXCEPTION 'FAIL hide: % / %', v_settings.hidden_from_marketplace, v_settings.hidden_at;
    END IF;

    -- Hidden: gone from the map, search and availability, and not bookable.
    PERFORM pg_temp.act_as(v_client);
    v_seen := pg_temp.visible(v_provider, v_name, v_lat, v_lng, v_service);
    IF v_seen <> v_none THEN
        RAISE EXCEPTION 'FAIL hidden: %', v_seen;
    END IF;
    PERFORM pg_temp.expect_error(
        format('SELECT public.create_booking(gen_random_uuid(), %L, ARRAY[%L::uuid], %L, %L, %L, %s, %L)',
               v_provider, v_service, v_slot + interval '1 day', 'studio', '0412345678', v_price, 'cash'),
        'provider_not_accepting', 'booked a hidden provider');

    -- The client still sees the booking they already have...
    IF NOT EXISTS (SELECT 1 FROM public.bookings b WHERE b.id = v_booking.id) THEN
        RAISE EXCEPTION 'FAIL: the existing booking disappeared for the client';
    END IF;
    -- ...and the hidden provider can still answer it.
    PERFORM pg_temp.act_as(v_provider);
    PERFORM public.respond_to_booking_request(v_booking.id, true, NULL);
    PERFORM pg_temp.as_owner();
    IF (SELECT b.status FROM public.bookings b WHERE b.id = v_booking.id) <> 'confirmed' THEN
        RAISE EXCEPTION 'FAIL: a hidden provider could not accept an existing request';
    END IF;

    -- Unrelated settings changes keep the hidden time.
    PERFORM pg_temp.act_as(v_provider);
    UPDATE public.provider_booking_settings SET buffer_minutes = buffer_minutes WHERE provider_id = v_provider;
    PERFORM pg_temp.as_owner();
    IF (SELECT s.hidden_at FROM public.provider_booking_settings s WHERE s.provider_id = v_provider)
       IS DISTINCT FROM v_settings.hidden_at THEN
        RAISE EXCEPTION 'FAIL: hidden_at moved on an unrelated update';
    END IF;

    -- Show again: back everywhere.
    PERFORM pg_temp.act_as(v_provider);
    UPDATE public.provider_booking_settings SET hidden_from_marketplace = false WHERE provider_id = v_provider;
    PERFORM pg_temp.as_owner();
    IF (SELECT s.hidden_at FROM public.provider_booking_settings s WHERE s.provider_id = v_provider) IS NOT NULL THEN
        RAISE EXCEPTION 'FAIL: hidden_at kept after showing again';
    END IF;
    PERFORM pg_temp.act_as(v_client);
    v_seen := pg_temp.visible(v_provider, v_name, v_lat, v_lng, v_service);
    IF v_seen <> v_all THEN
        RAISE EXCEPTION 'FAIL shown again: %', v_seen;
    END IF;

    -- The app is told whether providers may delete their own account.
    IF (public.get_app_config()->>'provider_self_deletion')::boolean IS DISTINCT FROM
       (SELECT s.provider_self_deletion FROM private.platform_settings s WHERE s.id) THEN
        RAISE EXCEPTION 'FAIL: get_app_config.provider_self_deletion';
    END IF;

    PERFORM pg_temp.as_owner();
    RAISE NOTICE 'marketplace visibility: all checks passed';
END;
$test$;
