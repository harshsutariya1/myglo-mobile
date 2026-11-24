-- Security checks for the admin foundation (20261031130000_admin_foundation)
-- and every admin RPC added after it.
--
-- Run inside a transaction that is rolled back (see supabase/tests/jobs.sql).
-- It needs at least one client and one provider profile in the database; it
-- creates a throwaway admin account, which the rollback removes.
--
-- The JWT is simulated with request.jwt.claims, exactly as PostgREST sets it,
-- so auth.uid(), auth.jwt() and the aal / amr claims behave as in the app.

CREATE FUNCTION pg_temp.act_as(p_uid uuid, p_aal text DEFAULT 'aal1', p_totp_age interval DEFAULT NULL)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    v_amr jsonb := jsonb_build_array(jsonb_build_object(
        'method', 'password', 'timestamp', extract(epoch FROM now() - interval '13 hours')::bigint));
BEGIN
    IF p_totp_age IS NOT NULL THEN
        v_amr := jsonb_build_array(jsonb_build_object(
            'method', 'totp', 'timestamp', extract(epoch FROM now() - p_totp_age)::bigint)) || v_amr;
    END IF;
    PERFORM set_config('request.jwt.claims', jsonb_build_object(
        'sub', p_uid, 'role', 'authenticated', 'aal', p_aal, 'amr', v_amr,
        'email', 'test@example.test', 'session_id', gen_random_uuid())::text, true);
    PERFORM set_config('role', 'authenticated', true);
END;
$$;

CREATE FUNCTION pg_temp.as_owner()
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    PERFORM set_config('role', 'postgres', true);
    PERFORM set_config('request.jwt.claims', '', true);
END;
$$;

-- Runs p_sql and checks it fails with p_expected as the message.
CREATE FUNCTION pg_temp.expect_error(p_sql text, p_expected text, p_label text)
RETURNS void
LANGUAGE plpgsql
AS $$
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

DO $test$
DECLARE
    v_admin    uuid := gen_random_uuid();
    v_client   uuid;
    v_provider uuid;
    v_fn       record;
    v_call     text;
    v_settings jsonb;
BEGIN
    SELECT id INTO v_client FROM public.profiles WHERE role = 'customer' ORDER BY created_at LIMIT 1;
    SELECT id INTO v_provider FROM public.profiles WHERE role = 'provider' ORDER BY created_at LIMIT 1;
    IF v_client IS NULL OR v_provider IS NULL THEN
        RAISE EXCEPTION 'needs a client and a provider profile';
    END IF;

    -- Admin accounts --------------------------------------------------------
    INSERT INTO auth.users (id, instance_id, aud, role, email)
    VALUES (v_admin, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
            'admin-' || v_admin || '@example.test');
    INSERT INTO private.admins (user_id, display_name) VALUES (v_admin, 'Test Admin');

    IF NOT coalesce((SELECT (raw_app_meta_data->>'myglo_admin')::boolean FROM auth.users WHERE id = v_admin), false) THEN
        RAISE EXCEPTION 'FAIL: app_metadata.myglo_admin not set on the admin';
    END IF;
    PERFORM pg_temp.expect_error(
        format('INSERT INTO private.admins (user_id, display_name) VALUES (%L, %L)', v_client, 'Nope'),
        'admin_account_has_profile', 'client account made admin');

    -- An admin can't become a client or provider.
    PERFORM pg_temp.act_as(v_admin, 'aal2', interval '1 minute');
    PERFORM pg_temp.expect_error(
        format('INSERT INTO public.profiles (id, role, email) VALUES (%L, %L, %L)', v_admin, 'customer', 'x@example.test'),
        'permission denied for table profiles', 'admin inserted own profile');
    PERFORM pg_temp.expect_error(
        format('SELECT public.register_user_role(%L, %L, %L)', v_admin, 'x@example.test', 'provider'),
        'admin_accounts_cannot_have_profiles', 'admin registered a role');
    PERFORM pg_temp.as_owner();

    -- Every admin RPC refuses non-admins and weak sessions ------------------
    FOR v_fn IN
        SELECT p.proname, p.pronargs
        FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname = 'public' AND p.proname LIKE 'admin\_%'
    LOOP
        v_call := format('SELECT public.%I(%s)', v_fn.proname,
                         (SELECT string_agg('NULL', ', ') FROM generate_series(1, v_fn.pronargs)));
        IF v_fn.pronargs = 0 THEN v_call := format('SELECT public.%I()', v_fn.proname); END IF;

        PERFORM pg_temp.act_as(v_client, 'aal1');
        PERFORM pg_temp.expect_error(v_call, 'admin_required', v_fn.proname || ' as client');
        PERFORM pg_temp.act_as(v_provider, 'aal2', interval '1 minute');
        PERFORM pg_temp.expect_error(v_call, 'admin_required', v_fn.proname || ' as provider with MFA');
        PERFORM pg_temp.act_as(v_admin, 'aal1');
        PERFORM pg_temp.expect_error(v_call, 'mfa_required', v_fn.proname || ' as admin without MFA');
        PERFORM pg_temp.act_as(v_admin, 'aal2', interval '13 hours');
        PERFORM pg_temp.expect_error(v_call, 'admin_session_expired', v_fn.proname || ' with a stale TOTP');
        PERFORM pg_temp.as_owner();
    END LOOP;

    -- Status for non-admins says nothing.
    PERFORM pg_temp.act_as(v_client, 'aal1');
    IF (public.get_admin_status()->>'is_admin')::boolean THEN
        RAISE EXCEPTION 'FAIL: client reported as admin';
    END IF;

    -- Admin with a valid session --------------------------------------------
    PERFORM pg_temp.act_as(v_admin, 'aal2', interval '10 minutes');
    IF NOT (public.get_admin_status()->>'is_admin')::boolean THEN
        RAISE EXCEPTION 'FAIL: admin not reported as admin';
    END IF;
    PERFORM public.admin_get_dashboard();
    PERFORM public.admin_get_platform_settings();
    PERFORM * FROM public.admin_search_users(NULL, NULL, 5, 0);
    PERFORM public.admin_get_user(v_client);
    PERFORM * FROM public.admin_list_service_cities();

    -- Sensitive changes need a fresh TOTP.
    PERFORM pg_temp.expect_error(
        $$SELECT public.admin_update_platform_settings('{"checkout_hold_minutes": 20}', 'Testing the hold')$$,
        'reauth_required', 'settings with a 10-minute-old TOTP');

    PERFORM pg_temp.act_as(v_admin, 'aal2', interval '1 minute');
    PERFORM pg_temp.expect_error(
        $$SELECT public.admin_update_platform_settings('{"checkout_hold_minutes": 20}', '')$$,
        'reason_required', 'settings without a reason');
    PERFORM pg_temp.expect_error(
        $$SELECT public.admin_update_platform_settings('{"owner": "me"}', 'Testing')$$,
        'invalid_setting', 'unknown setting');
    PERFORM pg_temp.expect_error(
        $$SELECT public.admin_update_platform_settings('{"platform_fee_percent": 140}', 'Testing')$$,
        'invalid_setting', 'fee out of range');
    PERFORM pg_temp.expect_error(
        $$SELECT public.admin_update_platform_settings('{"map_provider": "mapbox"}', 'Testing')$$,
        'invalid_setting', 'unsupported map provider');

    v_settings := public.admin_update_platform_settings('{"checkout_hold_minutes": 20}', 'Testing the hold');
    IF (v_settings->>'checkout_hold_minutes')::integer <> 20 THEN
        RAISE EXCEPTION 'FAIL: setting not changed';
    END IF;
    PERFORM pg_temp.as_owner();

    IF NOT EXISTS (
        SELECT 1 FROM private.admin_audit_log
        WHERE admin_id = v_admin AND action = 'platform_settings.update'
          AND (before->>'checkout_hold_minutes')::integer = 15
          AND (after->>'checkout_hold_minutes')::integer = 20
          AND reason = 'Testing the hold' AND aal = 'aal2') THEN
        RAISE EXCEPTION 'FAIL: settings change not audited with before/after';
    END IF;

    -- The audit log is append-only, even for the owner -----------------------
    PERFORM pg_temp.expect_error('UPDATE private.admin_audit_log SET reason = ''edited''',
        'admin_audit_log_is_append_only', 'audit update');
    PERFORM pg_temp.expect_error('DELETE FROM private.admin_audit_log',
        'admin_audit_log_is_append_only', 'audit delete');
    PERFORM pg_temp.expect_error('TRUNCATE private.admin_audit_log',
        'admin_audit_log_is_append_only', 'audit truncate');

    -- App roles can't reach admin data directly ------------------------------
    IF has_table_privilege('authenticated', 'private.admins', 'SELECT')
       OR has_table_privilege('authenticated', 'private.admin_audit_log', 'SELECT')
       OR has_table_privilege('authenticated', 'private.admin_audit_log', 'INSERT')
       OR has_function_privilege('authenticated', 'private.require_admin(boolean)', 'EXECUTE')
       OR has_function_privilege('authenticated', 'private.audit(text, text, text, text, jsonb, jsonb)', 'EXECUTE')
       OR has_function_privilege('authenticated', 'public.list_admin_alert_recipients()', 'EXECUTE')
       OR has_function_privilege('anon', 'public.admin_get_dashboard()', 'EXECUTE') THEN
        RAISE EXCEPTION 'FAIL: admin internals reachable by an app role';
    END IF;

    RAISE NOTICE 'admin_security.sql: all checks passed';
END;
$test$;
