-- Checks for card checkout (20261101120000_card_checkout).
--
-- Run inside a transaction that is rolled back (see supabase/tests/jobs.sql).
-- Needs a client and a provider with services, working hours and a studio
-- address (the seed data has them). Stripe is simulated: the test plays the
-- payments function and webhook by calling the service-role functions with
-- the PaymentIntent states Stripe would report.

CREATE FUNCTION pg_temp.act_as(p_uid uuid)
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
    PERFORM set_config('request.jwt.claims', jsonb_build_object(
        'sub', p_uid, 'role', 'authenticated', 'aal', 'aal1')::text, true);
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

CREATE FUNCTION pg_temp.expect_error(p_sql text, p_expected text, p_label text)
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
    EXECUTE p_sql;
    RAISE EXCEPTION 'FAIL %: expected "%" but it succeeded', p_label, p_expected;
EXCEPTION
    WHEN OTHERS THEN
        IF SQLERRM LIKE 'FAIL %' THEN RAISE; END IF;
        IF SQLERRM NOT LIKE p_expected THEN
            RAISE EXCEPTION 'FAIL %: expected "%" got "%"', p_label, p_expected, SQLERRM;
        END IF;
END;
$$;

-- The provider's first free start time at least p_days_ahead days out
-- (run as the owner: available_slots is private).
CREATE FUNCTION pg_temp.next_slot(p_provider uuid, p_duration integer, p_days_ahead integer DEFAULT 2)
RETURNS timestamptz LANGUAGE plpgsql AS $$
DECLARE
    v_tz   text;
    v_day  date;
    v_slot timestamptz;
BEGIN
    SELECT time_zone INTO v_tz FROM public.provider_booking_settings WHERE provider_id = p_provider;
    FOR i IN p_days_ahead..p_days_ahead + 14 LOOP
        v_day := (now() AT TIME ZONE v_tz)::date + i;
        SELECT a.slot_start INTO v_slot FROM private.available_slots(p_provider, p_duration, v_day, v_day) a
        ORDER BY a.slot_start LIMIT 1;
        IF v_slot IS NOT NULL THEN RETURN v_slot; END IF;
    END LOOP;
    RAISE EXCEPTION 'no free slot for the test provider';
END;
$$;

CREATE FUNCTION pg_temp.book(
    p_client uuid, p_provider uuid, p_service uuid, p_price integer, p_slot timestamptz, p_method text)
RETURNS public.bookings LANGUAGE plpgsql AS $$
DECLARE
    v_booking public.bookings;
BEGIN
    PERFORM pg_temp.act_as(p_client);
    v_booking := public.create_booking(
        gen_random_uuid(), p_provider, ARRAY[p_service], p_slot, 'studio', '0412345678', p_price, p_method);
    PERFORM pg_temp.as_owner();
    RETURN v_booking;
END;
$$;

DO $test$
DECLARE
    v_client     uuid;
    v_provider   uuid;
    v_other      uuid;
    v_service    uuid;
    v_price      integer;
    v_duration   integer;
    v_slot       timestamptz;
    v_b          public.bookings;
    v_b2         public.bookings;
    v_pay        public.booking_payments;
    v_checkout   jsonb;
    v_result     jsonb;
BEGIN
    -- Fixtures ------------------------------------------------------------------
    SELECT p.id INTO v_provider
    FROM public.profiles p
    JOIN public.provider_booking_settings s ON s.provider_id = p.id
    WHERE p.role = 'provider' AND s.accepts_bookings AND s.offers_studio AND p.address_text IS NOT NULL
      AND NOT EXISTS (SELECT 1 FROM private.provider_payout_accounts a WHERE a.provider_id = p.id)
      AND EXISTS (SELECT 1 FROM public.provider_working_hours h WHERE h.provider_id = p.id)
    ORDER BY (SELECT count(*) FROM public.provider_working_hours h WHERE h.provider_id = p.id) DESC, p.id
    LIMIT 1;
    SELECT p.id INTO v_other
    FROM public.profiles p
    JOIN public.provider_booking_settings s ON s.provider_id = p.id
    WHERE p.role = 'provider' AND p.id <> v_provider AND s.accepts_bookings AND s.offers_studio
      AND p.address_text IS NOT NULL
      AND NOT EXISTS (SELECT 1 FROM private.provider_payout_accounts a WHERE a.provider_id = p.id)
      AND EXISTS (SELECT 1 FROM public.provider_working_hours h WHERE h.provider_id = p.id)
      AND EXISTS (SELECT 1 FROM public.services sv WHERE sv.provider_id = p.id AND sv.price > 0)
    LIMIT 1;
    SELECT p.id INTO v_client FROM public.profiles p
    WHERE p.role = 'customer'
      AND NOT EXISTS (SELECT 1 FROM public.bookings b WHERE b.client_id = p.id AND b.status IN ('awaiting_payment', 'pending', 'confirmed'))
    ORDER BY p.created_at LIMIT 1;
    SELECT sv.id, round(sv.price * 100)::integer, sv.duration_minutes INTO v_service, v_price, v_duration
    FROM public.services sv
    WHERE sv.provider_id = v_provider AND sv.price > 0 AND sv.duration_minutes > 0
    ORDER BY sv.duration_minutes, sv.id LIMIT 1;
    IF v_client IS NULL OR v_provider IS NULL OR v_other IS NULL OR v_service IS NULL THEN
        RAISE EXCEPTION 'needs a free client and two bookable providers without payout accounts';
    END IF;

    UPDATE private.platform_settings
    SET platform_fee_percent = 5.5, fee_free_days = 0, card_max_advance_days = 60, checkout_hold_minutes = 15,
        card_request_response_hours = 144
    WHERE id;
    UPDATE public.provider_booking_settings
    SET requires_approval = false, accepts_cash = true, accepts_card = true, max_advance_days = 60
    WHERE provider_id IN (v_provider, v_other);

    -- Card is refused until the provider can take it -------------------------------
    PERFORM pg_temp.as_owner();
    v_slot := pg_temp.next_slot(v_provider, v_duration);
    PERFORM pg_temp.act_as(v_client);
    PERFORM pg_temp.expect_error(
        format('SELECT public.create_booking(gen_random_uuid(), %L, ARRAY[%L]::uuid[], %L, ''studio'', ''0412345678'', %s, ''card'')',
               v_provider, v_service, v_slot, v_price),
        'payment_method_unavailable', 'card before payouts work');
    PERFORM pg_temp.expect_error(
        format('SELECT public.create_booking(gen_random_uuid(), %L, ARRAY[%L]::uuid[], %L, ''studio'', ''0412345678'', %s, ''apple_pay'')',
               v_provider, v_service, v_slot, v_price),
        'payment_method_unavailable', 'wallets are paid as card');
    PERFORM pg_temp.as_owner();

    PERFORM public.save_connect_account(v_provider, 'acct_TestCheckout1');
    PERFORM public.apply_connect_account_state('acct_TestCheckout1', 'active', true, '{}', '{}', NULL, NULL);

    -- Instant card booking -----------------------------------------------------------
    v_b := pg_temp.book(v_client, v_provider, v_service, v_price, v_slot, 'card');
    IF v_b.status <> 'awaiting_payment' OR v_b.payment_status <> 'requires_payment' OR v_b.hold_expires_at IS NULL THEN
        RAISE EXCEPTION 'FAIL: new card booking is %/%', v_b.status, v_b.payment_status;
    END IF;
    IF v_b.platform_fee_percent <> 5.5 OR v_b.platform_fee_cents <> round(v_price * 5.5 / 100.0) THEN
        RAISE EXCEPTION 'FAIL: fee % (%%%) for a % cent booking', v_b.platform_fee_cents, v_b.platform_fee_percent, v_price;
    END IF;
    IF EXISTS (SELECT 1 FROM public.notifications WHERE booking_id = v_b.id) THEN
        RAISE EXCEPTION 'FAIL: an unpaid checkout notified someone';
    END IF;
    IF EXISTS (SELECT 1 FROM private.available_slots(v_provider, v_duration, (v_slot AT TIME ZONE 'Australia/Brisbane')::date,
                                                   (v_slot AT TIME ZONE 'Australia/Brisbane')::date) a
               WHERE a.slot_start = v_slot) THEN
        RAISE EXCEPTION 'FAIL: an unpaid checkout does not hold its slot';
    END IF;

    PERFORM pg_temp.act_as(v_provider);
    IF EXISTS (SELECT 1 FROM public.bookings WHERE id = v_b.id)
       OR EXISTS (SELECT 1 FROM public.booking_details WHERE id = v_b.id)
       OR EXISTS (SELECT 1 FROM public.booking_payments WHERE booking_id = v_b.id) THEN
        RAISE EXCEPTION 'FAIL: the provider can see an unpaid checkout';
    END IF;
    PERFORM pg_temp.expect_error(format('SELECT public.respond_to_booking_request(%L, true)', v_b.id),
        'booking_not_found', 'provider acts on an unpaid checkout');
    PERFORM pg_temp.act_as(v_other);
    PERFORM pg_temp.expect_error(format('SELECT public.begin_card_checkout(%L)', v_b.id),
        'booking_not_found', 'someone else starts the checkout');

    PERFORM pg_temp.act_as(v_client);
    v_checkout := public.begin_card_checkout(v_b.id);
    IF (v_checkout->>'amount_cents')::integer <> v_price OR v_checkout->>'capture_method' <> 'automatic'
       OR v_checkout->>'currency' <> 'aud' OR v_checkout->>'payment_intent_id' IS NOT NULL THEN
        RAISE EXCEPTION 'FAIL: checkout context %', v_checkout;
    END IF;
    PERFORM pg_temp.as_owner();

    PERFORM public.record_payment_intent(v_b.id, 'pi_TestInstant1');
    PERFORM public.record_payment_intent(v_b.id, 'pi_TestInstant1');
    PERFORM pg_temp.expect_error(format('SELECT public.record_payment_intent(%L, %L)', v_b.id, 'pi_Other'),
        'payment_intent_mismatch', 'second PaymentIntent');
    PERFORM pg_temp.expect_error(
        format('SELECT public.apply_payment_intent_state(%L, %L, %s)', 'pi_TestInstant1', 'succeeded', v_price + 1),
        'amount_mismatch', 'wrong amount');

    -- A declined card leaves the checkout open for another try.
    PERFORM public.apply_payment_intent_state('pi_TestInstant1', 'requires_payment_method', v_price,
        p_failure_code => 'card_declined');
    SELECT * INTO v_b FROM public.bookings WHERE id = v_b.id;
    IF v_b.status <> 'awaiting_payment' OR (private.booking_payment(v_b.id)).failure_code <> 'card_declined' THEN
        RAISE EXCEPTION 'FAIL: a declined card should keep the checkout open';
    END IF;

    v_result := public.apply_payment_intent_state('pi_TestInstant1', 'succeeded', v_price, v_price, 0,
        'ch_TestInstant1', NULL, 'apple_pay', 'visa', '4242');
    IF v_result->>'status' <> 'confirmed' OR v_result->>'payment_status' <> 'paid' THEN
        RAISE EXCEPTION 'FAIL: paid instant booking is %', v_result;
    END IF;
    PERFORM public.apply_payment_intent_state('pi_TestInstant1', 'succeeded', v_price, v_price, 0, 'ch_TestInstant1');
    IF (SELECT count(*) FROM public.notifications WHERE booking_id = v_b.id AND recipient_id = v_provider AND kind = 'booking_new') <> 1
       OR (SELECT count(*) FROM public.notifications WHERE booking_id = v_b.id AND recipient_id = v_client AND kind = 'booking_confirmed') <> 1 THEN
        RAISE EXCEPTION 'FAIL: a paid booking should be announced exactly once';
    END IF;
    v_pay := private.booking_payment(v_b.id);
    IF v_pay.status <> 'paid' OR v_pay.card_last4 <> '4242' OR v_pay.wallet <> 'apple_pay' OR v_pay.failure_code IS NOT NULL THEN
        RAISE EXCEPTION 'FAIL: payment row %', to_jsonb(v_pay);
    END IF;
    PERFORM pg_temp.act_as(v_provider);
    IF NOT EXISTS (SELECT 1 FROM public.booking_details WHERE id = v_b.id AND status = 'confirmed' AND card_last4 = '4242') THEN
        RAISE EXCEPTION 'FAIL: the provider should see the paid booking';
    END IF;
    PERFORM pg_temp.as_owner();

    -- Card request: held, then captured on accept ---------------------------------------
    UPDATE public.provider_booking_settings SET requires_approval = true WHERE provider_id = v_provider;
    v_b := pg_temp.book(v_client, v_provider, v_service, v_price, pg_temp.next_slot(v_provider, v_duration), 'card');
    IF (private.booking_payment(v_b.id)).capture_method <> 'manual' THEN
        RAISE EXCEPTION 'FAIL: a card request should be a hold';
    END IF;
    PERFORM public.record_payment_intent(v_b.id, 'pi_TestHold1');
    PERFORM public.apply_payment_intent_state('pi_TestHold1', 'requires_capture', v_price, 0, 0, 'ch_TestHold1',
        now() + interval '7 days', NULL, 'mastercard', '4444');
    SELECT * INTO v_b FROM public.bookings WHERE id = v_b.id;
    IF v_b.status <> 'pending' OR v_b.payment_status <> 'authorized' OR v_b.respond_by IS NULL
       OR v_b.respond_by > v_b.starts_at OR v_b.respond_by > now() + interval '144 hours' THEN
        RAISE EXCEPTION 'FAIL: held request %/% respond_by %', v_b.status, v_b.payment_status, v_b.respond_by;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM public.notifications WHERE booking_id = v_b.id AND recipient_id = v_provider AND kind = 'booking_request') THEN
        RAISE EXCEPTION 'FAIL: the provider was not told about the request';
    END IF;

    PERFORM pg_temp.act_as(v_provider);
    PERFORM public.respond_to_booking_request(v_b.id, true);
    PERFORM pg_temp.as_owner();
    IF NOT EXISTS (SELECT 1 FROM private.jobs WHERE idempotency_key = 'capture:' || v_b.id AND kind = 'capture_payment') THEN
        RAISE EXCEPTION 'FAIL: accepting a held request should capture it';
    END IF;
    PERFORM public.apply_payment_intent_state('pi_TestHold1', 'succeeded', v_price, v_price, 0, 'ch_TestHold1');
    SELECT * INTO v_b FROM public.bookings WHERE id = v_b.id;
    IF v_b.status <> 'confirmed' OR v_b.payment_status <> 'paid' THEN
        RAISE EXCEPTION 'FAIL: captured request is %/%', v_b.status, v_b.payment_status;
    END IF;

    -- Card request declined: the hold is released ----------------------------------------
    v_b := pg_temp.book(v_client, v_provider, v_service, v_price, pg_temp.next_slot(v_provider, v_duration), 'card');
    PERFORM public.record_payment_intent(v_b.id, 'pi_TestHold2');
    PERFORM public.apply_payment_intent_state('pi_TestHold2', 'requires_capture', v_price, 0, 0, NULL, now() + interval '7 days');
    PERFORM pg_temp.act_as(v_provider);
    PERFORM public.respond_to_booking_request(v_b.id, false, 'Fully booked');
    PERFORM pg_temp.as_owner();
    IF NOT EXISTS (SELECT 1 FROM private.jobs WHERE idempotency_key = 'hold-release:' || v_b.id) THEN
        RAISE EXCEPTION 'FAIL: declining a held request should release the hold';
    END IF;
    PERFORM public.apply_payment_intent_state('pi_TestHold2', 'canceled', v_price);
    IF (private.booking_payment(v_b.id)).status <> 'void' THEN
        RAISE EXCEPTION 'FAIL: released hold should be void';
    END IF;

    -- Card request nobody answers: it lapses at respond_by --------------------------------
    v_b := pg_temp.book(v_client, v_provider, v_service, v_price, pg_temp.next_slot(v_provider, v_duration), 'card');
    PERFORM public.record_payment_intent(v_b.id, 'pi_TestHold3');
    PERFORM public.apply_payment_intent_state('pi_TestHold3', 'requires_capture', v_price, 0, 0, NULL, now() + interval '7 days');
    UPDATE public.bookings SET respond_by = now() - interval '1 minute' WHERE id = v_b.id;
    PERFORM pg_temp.act_as(v_provider);
    PERFORM pg_temp.expect_error(format('SELECT public.respond_to_booking_request(%L, true)', v_b.id),
        'booking_request_expired', 'accept after respond_by');
    PERFORM pg_temp.as_owner();
    PERFORM private.expire_booking_requests();
    SELECT * INTO v_b FROM public.bookings WHERE id = v_b.id;
    IF v_b.status <> 'expired' OR NOT EXISTS (SELECT 1 FROM private.jobs WHERE idempotency_key = 'hold-release:' || v_b.id) THEN
        RAISE EXCEPTION 'FAIL: lapsed card request is % without a hold release', v_b.status;
    END IF;

    -- Checkouts that run out ------------------------------------------------------------------
    UPDATE public.provider_booking_settings SET requires_approval = false WHERE provider_id = v_provider;
    -- No PaymentIntent yet: closed straight away.
    v_b := pg_temp.book(v_client, v_provider, v_service, v_price, pg_temp.next_slot(v_provider, v_duration), 'card');
    UPDATE public.bookings SET hold_expires_at = now() - interval '1 minute' WHERE id = v_b.id;
    PERFORM pg_temp.act_as(v_client);
    PERFORM pg_temp.expect_error(format('SELECT public.begin_card_checkout(%L)', v_b.id),
        'checkout_expired', 'paying after the hold');
    PERFORM pg_temp.as_owner();
    PERFORM private.expire_checkouts();
    IF (SELECT status FROM public.bookings WHERE id = v_b.id) <> 'checkout_expired' THEN
        RAISE EXCEPTION 'FAIL: an expired checkout without a PaymentIntent stayed open';
    END IF;

    -- With a PaymentIntent: Stripe decides. Cancelled -> closed; a late payment
    -- on the closed checkout is refunded in full.
    v_b := pg_temp.book(v_client, v_provider, v_service, v_price, pg_temp.next_slot(v_provider, v_duration), 'card');
    PERFORM public.record_payment_intent(v_b.id, 'pi_TestLate1');
    UPDATE public.bookings SET hold_expires_at = now() - interval '1 minute' WHERE id = v_b.id;
    PERFORM private.expire_checkouts();
    IF (SELECT status FROM public.bookings WHERE id = v_b.id) <> 'awaiting_payment'
       OR NOT EXISTS (SELECT 1 FROM private.jobs WHERE idempotency_key = 'checkout-cancel:' || v_b.id) THEN
        RAISE EXCEPTION 'FAIL: an expired checkout with a PaymentIntent should wait for Stripe';
    END IF;
    PERFORM public.apply_payment_intent_state('pi_TestLate1', 'canceled', v_price);
    IF (SELECT status FROM public.bookings WHERE id = v_b.id) <> 'checkout_expired' THEN
        RAISE EXCEPTION 'FAIL: cancelled checkout should close';
    END IF;
    PERFORM public.apply_payment_intent_state('pi_TestLate1', 'succeeded', v_price, v_price, 0);
    IF NOT EXISTS (SELECT 1 FROM private.jobs WHERE idempotency_key = 'refund:orphan:pi_TestLate1'
                   AND (payload->>'amount_cents')::integer = v_price) THEN
        RAISE EXCEPTION 'FAIL: a payment on a closed checkout should be refunded';
    END IF;
    PERFORM public.apply_payment_intent_state('pi_TestLate1', 'succeeded', v_price, v_price, v_price);
    IF (SELECT payment_status FROM public.bookings WHERE id = v_b.id) <> 'refunded' THEN
        RAISE EXCEPTION 'FAIL: refunded payment not recorded';
    END IF;

    -- Abandoning, and starting again ----------------------------------------------------------
    v_b := pg_temp.book(v_client, v_provider, v_service, v_price, pg_temp.next_slot(v_provider, v_duration), 'card');
    PERFORM pg_temp.act_as(v_client);
    PERFORM public.abandon_checkout(v_b.id);
    PERFORM public.abandon_checkout(v_b.id);
    PERFORM pg_temp.as_owner();
    IF (SELECT status FROM public.bookings WHERE id = v_b.id) <> 'checkout_expired' THEN
        RAISE EXCEPTION 'FAIL: abandoned checkout still open';
    END IF;

    -- Switching to cash for the same time abandons the unfinished checkout.
    v_slot := pg_temp.next_slot(v_provider, v_duration);
    v_b := pg_temp.book(v_client, v_provider, v_service, v_price, v_slot, 'card');
    v_b2 := pg_temp.book(v_client, v_provider, v_service, v_price, v_slot, 'cash');
    IF v_b2.status <> 'pending' OR v_b2.platform_fee_cents <> 0
       OR (SELECT status FROM public.bookings WHERE id = v_b.id) <> 'checkout_expired' THEN
        RAISE EXCEPTION 'FAIL: a new booking should replace the unfinished checkout';
    END IF;

    -- Cash can be switched off only while cards work.
    UPDATE public.provider_booking_settings SET accepts_cash = false WHERE provider_id = v_provider;
    v_slot := pg_temp.next_slot(v_provider, v_duration);
    PERFORM pg_temp.act_as(v_client);
    PERFORM pg_temp.expect_error(
        format('SELECT public.create_booking(gen_random_uuid(), %L, ARRAY[%L]::uuid[], %L, ''studio'', ''0412345678'', %s, ''cash'')',
               v_provider, v_service, v_slot, v_price),
        'payment_method_unavailable', 'cash when the provider is card-only');
    PERFORM pg_temp.as_owner();
    UPDATE public.provider_booking_settings SET accepts_cash = true WHERE provider_id = v_provider;

    -- Card only for appointments Stripe can hold funds for.
    UPDATE private.platform_settings SET card_max_advance_days = 1 WHERE id;
    v_slot := pg_temp.next_slot(v_provider, v_duration, 3);
    PERFORM pg_temp.act_as(v_client);
    PERFORM pg_temp.expect_error(
        format('SELECT public.create_booking(gen_random_uuid(), %L, ARRAY[%L]::uuid[], %L, ''studio'', ''0412345678'', %s, ''card'')',
               v_provider, v_service, v_slot, v_price),
        'card_too_far_ahead', 'card beyond the hold window');
    PERFORM pg_temp.as_owner();

    -- Cash completions record cash; card completions don't touch the payment.
    IF (SELECT payment_status FROM public.bookings WHERE id = v_b2.id) <> 'pending' THEN
        RAISE EXCEPTION 'FAIL: cash request payment status';
    END IF;

    -- Privileges ----------------------------------------------------------------------------------
    IF has_function_privilege('authenticated', 'public.apply_payment_intent_state(text, text, integer, integer, integer, text, timestamptz, text, text, text, text)', 'EXECUTE')
       OR has_function_privilege('authenticated', 'public.record_payment_intent(uuid, text)', 'EXECUTE')
       OR has_function_privilege('anon', 'public.begin_card_checkout(uuid)', 'EXECUTE')
       OR has_function_privilege('anon', 'public.abandon_checkout(uuid)', 'EXECUTE')
       OR has_function_privilege('authenticated', 'private.expire_checkouts()', 'EXECUTE') THEN
        RAISE EXCEPTION 'FAIL: checkout internals reachable by an app role';
    END IF;

    RAISE NOTICE 'card_checkout.sql: all checks passed';
END;
$test$;
