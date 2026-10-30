-- Checks for provider payouts (20261031140000_provider_payouts).
--
-- Run inside a transaction that is rolled back (see supabase/tests/jobs.sql).
-- Needs at least one client and one provider profile.

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

DO $test$
DECLARE
    v_client   uuid;
    v_provider uuid;
    v_setup    jsonb;
    v_account  private.provider_payout_accounts;
BEGIN
    SELECT id INTO v_client FROM public.profiles WHERE role = 'customer' ORDER BY created_at LIMIT 1;
    SELECT p.id INTO v_provider
    FROM public.profiles p
    WHERE p.role = 'provider'
      AND NOT EXISTS (SELECT 1 FROM private.provider_payout_accounts a WHERE a.provider_id = p.id)
    ORDER BY p.created_at LIMIT 1;
    IF v_client IS NULL OR v_provider IS NULL THEN
        RAISE EXCEPTION 'needs a client and a provider without a payout account';
    END IF;
    UPDATE private.platform_settings SET fee_free_days = 14, platform_fee_percent = 5.5 WHERE id;

    -- Only providers ---------------------------------------------------------
    PERFORM pg_temp.act_as(v_client);
    PERFORM pg_temp.expect_error('SELECT public.get_my_payments_setup()', 'providers_only', 'client reads setup');
    PERFORM pg_temp.expect_error('SELECT public.begin_payments_setup()', 'providers_only', 'client starts setup');

    PERFORM pg_temp.act_as(v_provider);
    v_setup := public.get_my_payments_setup();
    IF v_setup->>'status' <> 'not_started' THEN
        RAISE EXCEPTION 'FAIL: new provider status %', v_setup->>'status';
    END IF;
    IF (public.begin_payments_setup()->>'provider_id')::uuid <> v_provider THEN
        RAISE EXCEPTION 'FAIL: begin_payments_setup returned another provider';
    END IF;

    -- Providers can choose cash/card but can't mark themselves card-ready.
    PERFORM pg_temp.expect_error(
        format('UPDATE public.provider_booking_settings SET card_ready = true WHERE provider_id = %L', v_provider),
        'permission denied%', 'provider sets card_ready');
    UPDATE public.provider_booking_settings SET accepts_cash = false WHERE provider_id = v_provider;
    PERFORM pg_temp.expect_error(
        format('UPDATE public.provider_booking_settings SET accepts_card = false WHERE provider_id = %L', v_provider),
        '%pbs_accepts_a_payment%', 'provider turns off both');
    PERFORM pg_temp.as_owner();

    -- Cash stays on while card isn't ready.
    IF NOT (SELECT private.provider_takes_cash(s) FROM public.provider_booking_settings s WHERE provider_id = v_provider) THEN
        RAISE EXCEPTION 'FAIL: cash refused while card payments are not ready';
    END IF;

    -- Account lifecycle --------------------------------------------------------
    PERFORM public.save_connect_account(v_provider, 'acct_TestPayouts1');
    PERFORM public.save_connect_account(v_provider, 'acct_TestPayouts1');
    PERFORM pg_temp.expect_error(
        format('SELECT public.save_connect_account(%L, %L)', v_provider, 'acct_Other'),
        'account_mismatch', 'second account for a provider');

    PERFORM public.apply_connect_account_state('acct_TestPayouts1', 'pending', false,
        ARRAY['individual.dob'], '{}', now() + interval '7 days', NULL);
    PERFORM pg_temp.act_as(v_provider);
    IF public.get_my_payments_setup()->>'status' <> 'onboarding' THEN
        RAISE EXCEPTION 'FAIL: expected onboarding, got %', public.get_my_payments_setup()->>'status';
    END IF;
    PERFORM pg_temp.as_owner();

    PERFORM public.apply_connect_account_state('acct_TestPayouts1', 'pending', false, '{}', ARRAY['individual.id_number'], NULL, NULL);
    PERFORM pg_temp.act_as(v_provider);
    IF public.get_my_payments_setup()->>'status' <> 'verifying' THEN
        RAISE EXCEPTION 'FAIL: expected verifying';
    END IF;
    PERFORM pg_temp.as_owner();

    -- Enabled: card-ready, fee-free period starts, provider told once.
    PERFORM public.apply_connect_account_state('acct_TestPayouts1', 'active', true, '{}', '{}', NULL, NULL);
    SELECT * INTO v_account FROM private.provider_payout_accounts WHERE provider_id = v_provider;
    IF v_account.first_enabled_at IS NULL THEN RAISE EXCEPTION 'FAIL: first_enabled_at not set'; END IF;
    IF NOT (SELECT card_ready FROM public.provider_booking_settings WHERE provider_id = v_provider) THEN
        RAISE EXCEPTION 'FAIL: card_ready not set';
    END IF;
    IF (SELECT private.provider_takes_cash(s) FROM public.provider_booking_settings s WHERE provider_id = v_provider) THEN
        RAISE EXCEPTION 'FAIL: cash still taken after the provider turned it off and card is ready';
    END IF;
    PERFORM public.apply_connect_account_state('acct_TestPayouts1', 'active', true, '{}', '{}', NULL, NULL);
    IF (SELECT count(*) FROM public.notifications WHERE recipient_id = v_provider AND kind = 'payments_ready') <> 1 THEN
        RAISE EXCEPTION 'FAIL: payments_ready should be sent exactly once';
    END IF;
    PERFORM pg_temp.act_as(v_provider);
    v_setup := public.get_my_payments_setup();
    IF v_setup->>'status' <> 'active'
       OR (v_setup->>'fee_free_until')::timestamptz <> v_account.first_enabled_at + interval '14 days' THEN
        RAISE EXCEPTION 'FAIL: active setup wrong: %', v_setup;
    END IF;
    PERFORM pg_temp.as_owner();

    -- More details needed while active, then restricted.
    PERFORM public.apply_connect_account_state('acct_TestPayouts1', 'active', true,
        ARRAY['individual.verification.document'], '{}', now() + interval '3 days', NULL);
    IF NOT EXISTS (SELECT 1 FROM public.notifications WHERE recipient_id = v_provider AND kind = 'payments_action_needed') THEN
        RAISE EXCEPTION 'FAIL: payments_action_needed not sent';
    END IF;
    PERFORM public.apply_connect_account_state('acct_TestPayouts1', 'restricted', false,
        ARRAY['individual.verification.document'], '{}', NULL, 'requirements_past_due');
    IF (SELECT card_ready FROM public.provider_booking_settings WHERE provider_id = v_provider) THEN
        RAISE EXCEPTION 'FAIL: card_ready still set on a restricted account';
    END IF;
    IF NOT (SELECT private.provider_takes_cash(s) FROM public.provider_booking_settings s WHERE provider_id = v_provider) THEN
        RAISE EXCEPTION 'FAIL: cash must come back while card payments are restricted';
    END IF;
    PERFORM pg_temp.act_as(v_provider);
    IF public.get_my_payments_setup()->>'status' <> 'restricted' THEN
        RAISE EXCEPTION 'FAIL: expected restricted';
    END IF;
    PERFORM pg_temp.as_owner();

    -- Unknown accounts are ignored.
    IF public.apply_connect_account_state('acct_Unknown', 'active', true, '{}', '{}', NULL, NULL) IS NOT NULL THEN
        RAISE EXCEPTION 'FAIL: unknown account applied';
    END IF;

    -- Service-role only.
    IF has_function_privilege('authenticated', 'public.apply_connect_account_state(text, text, boolean, text[], text[], timestamptz, text, boolean)', 'EXECUTE')
       OR has_function_privilege('authenticated', 'public.save_connect_account(uuid, text)', 'EXECUTE')
       OR has_function_privilege('authenticated', 'public.connect_account_id(uuid)', 'EXECUTE')
       OR has_table_privilege('authenticated', 'private.provider_payout_accounts', 'SELECT') THEN
        RAISE EXCEPTION 'FAIL: payout internals reachable by an app role';
    END IF;

    RAISE NOTICE 'provider_payouts.sql: all checks passed';
END;
$test$;
