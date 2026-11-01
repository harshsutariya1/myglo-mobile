-- Checks for the payment lifecycle (20261101130000_payment_lifecycle).
--
-- Run inside a transaction that is rolled back (see supabase/tests/jobs.sql).
-- Uses the same fixtures as card_checkout.sql. Stripe is simulated by calling
-- the service-role functions with the states Stripe would report.

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

-- A card booking the client has paid for (charge ch_<n>).
CREATE FUNCTION pg_temp.paid_booking(p_client uuid, p_provider uuid, p_service uuid, p_price integer, p_n integer)
RETURNS public.bookings LANGUAGE plpgsql AS $$
DECLARE
    v_booking public.bookings;
    v_slot    timestamptz := pg_temp.next_slot(p_provider, (SELECT duration_minutes FROM public.services WHERE id = p_service));
BEGIN
    PERFORM pg_temp.act_as(p_client);
    v_booking := public.create_booking(gen_random_uuid(), p_provider, ARRAY[p_service], v_slot, 'studio', '0412345678', p_price, 'card');
    PERFORM pg_temp.as_owner();
    PERFORM public.record_payment_intent(v_booking.id, 'pi_Life' || p_n);
    PERFORM public.apply_payment_intent_state('pi_Life' || p_n, 'succeeded', p_price, p_price, 0, 'ch_Life' || p_n);
    SELECT * INTO v_booking FROM public.bookings WHERE id = v_booking.id;
    RETURN v_booking;
END;
$$;

-- Moves a booking into the past so it can be completed or missed.
CREATE FUNCTION pg_temp.move_to_past(p_booking uuid, p_hours_ago integer)
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
    UPDATE public.bookings
    SET starts_at = now() - make_interval(hours => p_hours_ago),
        ends_at = now() - make_interval(hours => p_hours_ago) + interval '30 minutes',
        blocked_until = now() - make_interval(hours => p_hours_ago) + interval '30 minutes'
    WHERE id = p_booking;
END;
$$;

DO $test$
DECLARE
    v_client   uuid;
    v_provider uuid;
    v_service  uuid;
    v_price    integer;
    v_b        public.bookings;
    v_refund   public.booking_refunds;
    v_s        public.booking_settlements;
    v_fin      jsonb;
BEGIN
    SELECT p.id INTO v_provider
    FROM public.profiles p
    JOIN public.provider_booking_settings s ON s.provider_id = p.id
    WHERE p.role = 'provider' AND s.accepts_bookings AND s.offers_studio AND p.address_text IS NOT NULL
      AND NOT EXISTS (SELECT 1 FROM private.provider_payout_accounts a WHERE a.provider_id = p.id)
      AND EXISTS (SELECT 1 FROM public.provider_working_hours h WHERE h.provider_id = p.id)
    ORDER BY (SELECT count(*) FROM public.provider_working_hours h WHERE h.provider_id = p.id) DESC, p.id
    LIMIT 1;
    SELECT p.id INTO v_client FROM public.profiles p
    WHERE p.role = 'customer'
      AND NOT EXISTS (SELECT 1 FROM public.bookings b WHERE b.client_id = p.id AND b.status IN ('awaiting_payment', 'pending', 'confirmed'))
    ORDER BY p.created_at LIMIT 1;
    SELECT sv.id, round(sv.price * 100)::integer INTO v_service, v_price
    FROM public.services sv
    WHERE sv.provider_id = v_provider AND sv.price >= 20 AND sv.duration_minutes > 0
    ORDER BY sv.duration_minutes, sv.id LIMIT 1;
    IF v_client IS NULL OR v_provider IS NULL OR v_service IS NULL THEN
        RAISE EXCEPTION 'needs a free client and a bookable provider without a payout account';
    END IF;

    UPDATE private.platform_settings
    SET platform_fee_percent = 10, fee_free_days = 0, card_max_advance_days = 60, auto_complete_after_hours = 24
    WHERE id;
    UPDATE public.provider_booking_settings
    SET requires_approval = false, accepts_cash = true, accepts_card = true, max_advance_days = 60,
        cancellation_window_hours = 24, cancellation_fee_percent = 50
    WHERE provider_id = v_provider;
    PERFORM public.save_connect_account(v_provider, 'acct_TestLife1');
    PERFORM public.apply_connect_account_state('acct_TestLife1', 'active', true, '{}', '{}', NULL, NULL);

    -- Cancelled in time: full refund, nothing for the provider ------------------------
    v_b := pg_temp.paid_booking(v_client, v_provider, v_service, v_price, 1);
    PERFORM pg_temp.act_as(v_client);
    PERFORM public.cancel_booking(v_b.id);
    IF (SELECT refund_pending_cents FROM public.booking_details WHERE id = v_b.id) <> v_price THEN
        RAISE EXCEPTION 'FAIL: the client should see a pending full refund';
    END IF;
    PERFORM pg_temp.as_owner();
    SELECT * INTO v_refund FROM public.booking_refunds WHERE booking_id = v_b.id;
    IF v_refund.amount_cents <> v_price OR v_refund.reason <> 'client_cancelled'
       OR NOT EXISTS (SELECT 1 FROM private.jobs WHERE idempotency_key = 'refund:' || v_refund.id) THEN
        RAISE EXCEPTION 'FAIL: in-time cancellation refund %', to_jsonb(v_refund);
    END IF;
    IF EXISTS (SELECT 1 FROM public.booking_settlements WHERE booking_id = v_b.id) THEN
        RAISE EXCEPTION 'FAIL: nothing should be settled for an in-time cancellation';
    END IF;
    PERFORM public.apply_refund_state(v_refund.id, 're_Life1', 'succeeded');
    PERFORM public.apply_refund_state(v_refund.id, 're_Life1', 'pending');
    IF (SELECT status FROM public.booking_refunds WHERE id = v_refund.id) <> 'succeeded'
       OR (SELECT count(*) FROM public.notifications WHERE booking_id = v_b.id AND kind = 'payment_refunded') <> 1 THEN
        RAISE EXCEPTION 'FAIL: refund success should stick and be announced once';
    END IF;

    -- Cancelled late: the provider keeps the fee (less Myglo's 10%), the rest refunded
    UPDATE public.provider_booking_settings SET cancellation_window_hours = 168 WHERE provider_id = v_provider;
    v_b := pg_temp.paid_booking(v_client, v_provider, v_service, v_price, 2);
    PERFORM pg_temp.act_as(v_client);
    PERFORM public.cancel_booking(v_b.id, NULL, true);
    PERFORM pg_temp.as_owner();
    SELECT * INTO v_s FROM public.booking_settlements WHERE booking_id = v_b.id;
    IF (SELECT sum(amount_cents) FROM public.booking_refunds WHERE booking_id = v_b.id) <> v_price - round(v_price * 0.5)
       OR v_s.kept_cents <> round(v_price * 0.5) OR v_s.platform_fee_cents <> round(round(v_price * 0.5) * 0.1)
       OR v_s.status <> 'processing'
       OR NOT EXISTS (SELECT 1 FROM private.jobs WHERE idempotency_key = 'transfer:' || v_b.id || ':1'
                      AND (payload->>'amount_cents')::integer = v_s.transfer_cents
                      AND payload->>'source_transaction' = 'ch_Life2') THEN
        RAISE EXCEPTION 'FAIL: late cancellation split %', to_jsonb(v_s);
    END IF;
    UPDATE public.provider_booking_settings SET cancellation_window_hours = 24 WHERE provider_id = v_provider;

    -- Completed: the provider keeps it all; transfer, then a partial reversal --------
    v_b := pg_temp.paid_booking(v_client, v_provider, v_service, v_price, 3);
    PERFORM pg_temp.move_to_past(v_b.id, 3);
    PERFORM pg_temp.act_as(v_provider);
    PERFORM public.complete_booking(v_b.id, true);
    PERFORM pg_temp.as_owner();
    SELECT * INTO v_s FROM public.booking_settlements WHERE booking_id = v_b.id;
    IF v_s.kept_cents <> v_price OR v_s.status <> 'processing' OR (SELECT payment_status FROM public.bookings WHERE id = v_b.id) <> 'paid' THEN
        RAISE EXCEPTION 'FAIL: completion settlement %', to_jsonb(v_s);
    END IF;
    PERFORM public.apply_transfer_state(v_b.id, 'tr_Life3', 'succeeded');
    IF private.reverse_settlement(v_b.id, 500, 'test') <> 500 THEN
        RAISE EXCEPTION 'FAIL: reversal not queued';
    END IF;
    PERFORM public.apply_transfer_state(v_b.id, 'tr_Life3', 'succeeded', 500);
    SELECT * INTO v_s FROM public.booking_settlements WHERE booking_id = v_b.id;
    IF v_s.status <> 'transferred' OR v_s.reversed_cents <> 500 THEN
        RAISE EXCEPTION 'FAIL: partial reversal %', to_jsonb(v_s);
    END IF;

    -- A dispute takes the rest back; winning it pays the provider again ------------
    PERFORM public.apply_dispute_state('dp_Life3', 'pi_Life3', v_price, 'fraudulent', 'needs_response', now() + interval '7 days');
    IF NOT EXISTS (SELECT 1 FROM private.jobs WHERE kind = 'reverse_transfer' AND booking_id = v_b.id
                   AND (payload->>'amount_cents')::integer = v_s.transfer_cents - 500)
       OR NOT EXISTS (SELECT 1 FROM public.notifications WHERE booking_id = v_b.id AND kind = 'booking_disputed')
       OR NOT EXISTS (SELECT 1 FROM private.jobs WHERE idempotency_key = 'alert:dispute:dp_Life3') THEN
        RAISE EXCEPTION 'FAIL: a new dispute should take the share back and alert';
    END IF;
    PERFORM public.apply_transfer_state(v_b.id, 'tr_Life3', 'succeeded', v_s.transfer_cents);
    PERFORM public.apply_dispute_state('dp_Life3', 'pi_Life3', v_price, 'fraudulent', 'won');
    SELECT * INTO v_s FROM public.booking_settlements WHERE booking_id = v_b.id;
    IF v_s.status <> 'processing' OR v_s.transfer_attempt <> 2
       OR NOT EXISTS (SELECT 1 FROM private.jobs WHERE idempotency_key = 'transfer:' || v_b.id || ':2') THEN
        RAISE EXCEPTION 'FAIL: a won dispute should transfer again %', to_jsonb(v_s);
    END IF;

    -- Not marked complete: auto-completed after the end -------------------------------
    v_b := pg_temp.paid_booking(v_client, v_provider, v_service, v_price, 4);
    PERFORM pg_temp.move_to_past(v_b.id, 30);
    PERFORM private.auto_complete_card_bookings();
    IF (SELECT status FROM public.bookings WHERE id = v_b.id) <> 'completed'
       OR (SELECT status FROM public.booking_settlements WHERE booking_id = v_b.id) <> 'processing' THEN
        RAISE EXCEPTION 'FAIL: auto-complete';
    END IF;

    -- No-show: fee kept, rest refunded --------------------------------------------------
    v_b := pg_temp.paid_booking(v_client, v_provider, v_service, v_price, 5);
    PERFORM pg_temp.move_to_past(v_b.id, 6);
    PERFORM pg_temp.act_as(v_provider);
    PERFORM public.mark_booking_no_show(v_b.id);
    PERFORM pg_temp.as_owner();
    IF (SELECT reason FROM public.booking_refunds WHERE booking_id = v_b.id) <> 'no_show'
       OR (SELECT kept_cents FROM public.booking_settlements WHERE booking_id = v_b.id) <> round(v_price * 0.5) THEN
        RAISE EXCEPTION 'FAIL: no-show split';
    END IF;

    -- Payout account not working: the share waits, then goes when it's fixed ---------
    -- (Booked before the account broke: a restricted account takes no new card bookings.)
    v_b := pg_temp.paid_booking(v_client, v_provider, v_service, v_price, 6);
    PERFORM public.apply_connect_account_state('acct_TestLife1', 'restricted', false, ARRAY['bank account'], '{}', NULL, 'requirements_past_due');
    PERFORM pg_temp.move_to_past(v_b.id, 9);
    PERFORM pg_temp.act_as(v_provider);
    PERFORM public.complete_booking(v_b.id);
    PERFORM pg_temp.as_owner();
    SELECT * INTO v_s FROM public.booking_settlements WHERE booking_id = v_b.id;
    IF v_s.status <> 'held' OR v_s.hold_reason <> 'payout_account' THEN
        RAISE EXCEPTION 'FAIL: settlement should wait for the payout account %', to_jsonb(v_s);
    END IF;
    PERFORM public.apply_connect_account_state('acct_TestLife1', 'active', true, '{}', '{}', NULL, NULL);
    IF (SELECT status FROM public.booking_settlements WHERE booking_id = v_b.id) <> 'processing' THEN
        RAISE EXCEPTION 'FAIL: fixing the payout account should release the share';
    END IF;

    -- Payouts ------------------------------------------------------------------------------
    PERFORM public.apply_payout_state('acct_TestLife1', 'po_Life1', 1234, 'AUD', 'in_transit', current_date + 2);
    PERFORM public.apply_payout_state('acct_TestLife1', 'po_Life1', 1234, 'AUD', 'paid', current_date + 2);
    PERFORM public.apply_payout_state('acct_TestLife1', 'po_Life1', 1234, 'AUD', 'paid', current_date + 2);
    IF (SELECT count(*) FROM public.notifications WHERE recipient_id = v_provider AND kind = 'payout_paid') <> 1 THEN
        RAISE EXCEPTION 'FAIL: payout should be announced once';
    END IF;

    -- What each side can see ---------------------------------------------------------------
    PERFORM pg_temp.act_as(v_client);
    IF EXISTS (SELECT 1 FROM public.booking_settlements) OR EXISTS (SELECT 1 FROM public.provider_payouts) THEN
        RAISE EXCEPTION 'FAIL: clients must not see settlements or payouts';
    END IF;
    PERFORM pg_temp.act_as(v_provider);
    v_fin := public.get_provider_financials(current_date - 30, current_date + 30);
    IF (v_fin->>'card_earned_cents')::integer <= 0 OR jsonb_array_length(v_fin->'payouts') <> 1
       OR NOT EXISTS (SELECT 1 FROM public.booking_settlements WHERE provider_id = v_provider) THEN
        RAISE EXCEPTION 'FAIL: provider financials %', v_fin;
    END IF;
    PERFORM pg_temp.as_owner();

    IF has_function_privilege('authenticated', 'public.apply_refund_state(uuid, text, text, text)', 'EXECUTE')
       OR has_function_privilege('authenticated', 'public.apply_transfer_state(uuid, text, text, integer, text)', 'EXECUTE')
       OR has_function_privilege('authenticated', 'public.apply_dispute_state(text, text, integer, text, text, timestamptz)', 'EXECUTE')
       OR has_function_privilege('authenticated', 'public.apply_payout_state(text, text, integer, text, text, date, text, text)', 'EXECUTE')
       OR has_function_privilege('authenticated', 'private.queue_refund(public.bookings, integer, text, text, uuid, text)', 'EXECUTE') THEN
        RAISE EXCEPTION 'FAIL: payment internals reachable by an app role';
    END IF;

    RAISE NOTICE 'payment_lifecycle.sql: all checks passed';
END;
$test$;
