-- Checks for admin account closure (20261124130000_admin_account_closure).
--
-- Run inside a transaction that is rolled back (see supabase/tests/jobs.sql).
-- Creates a throwaway admin and two throwaway clients, which the rollback
-- removes. The Stripe balance check and the email live in the
-- delete-account function and aren't covered here.

CREATE FUNCTION pg_temp.act_as(p_uid uuid, p_aal text DEFAULT 'aal1', p_totp_age interval DEFAULT NULL)
RETURNS void LANGUAGE plpgsql AS $$
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
        'email', 'admin@example.test', 'session_id', gen_random_uuid())::text, true);
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
        IF SQLERRM <> p_expected THEN
            RAISE EXCEPTION 'FAIL %: expected "%" got "%"', p_label, p_expected, SQLERRM;
        END IF;
END;
$$;

CREATE FUNCTION pg_temp.new_client(p_label text)
RETURNS uuid LANGUAGE plpgsql AS $$
DECLARE
    v_id uuid := gen_random_uuid();
BEGIN
    INSERT INTO auth.users (id, instance_id, aud, role, email)
    VALUES (v_id, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
            'close-' || p_label || '-' || v_id || '@example.test');
    INSERT INTO public.profiles (id, role, email, first_name, last_name, phone_number)
    VALUES (v_id, 'customer', 'close-' || p_label || '-' || v_id || '@example.test', 'Test', p_label, '0412345678');
    RETURN v_id;
END;
$$;

DO $test$
DECLARE
    v_admin     uuid := gen_random_uuid();
    v_client    uuid := pg_temp.new_client('plain');
    v_suspended uuid := pg_temp.new_client('suspended');
    v_json      jsonb;
BEGIN
    IF has_function_privilege('authenticated', 'public.delete_account(uuid, boolean)', 'EXECUTE')
       OR NOT has_function_privilege('service_role', 'public.delete_account(uuid, boolean)', 'EXECUTE')
       OR EXISTS (SELECT 1 FROM pg_proc WHERE oid = to_regprocedure('public.delete_account(uuid)')) THEN
        RAISE EXCEPTION 'FAIL: delete_account privileges or leftover overload';
    END IF;

    INSERT INTO auth.users (id, instance_id, aud, role, email)
    VALUES (v_admin, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
            'admin-' || v_admin || '@example.test');
    INSERT INTO private.admins (user_id, display_name) VALUES (v_admin, 'Test Admin');
    INSERT INTO private.user_restrictions (user_id, suspended_at, suspended_reason) VALUES (v_suspended, now(), 'test');

    -- Clients can't, and admins need a fresh code and a reason.
    PERFORM pg_temp.act_as(v_client, 'aal1');
    PERFORM pg_temp.expect_error(format('SELECT public.admin_begin_account_closure(%L, %L)', v_suspended, 'asked'),
        'admin_required', 'client closes an account');
    PERFORM pg_temp.act_as(v_admin, 'aal2', interval '10 minutes');
    PERFORM pg_temp.expect_error(format('SELECT public.admin_begin_account_closure(%L, %L)', v_suspended, 'asked'),
        'reauth_required', 'stale code');
    PERFORM pg_temp.act_as(v_admin, 'aal2', interval '1 minute');
    PERFORM pg_temp.expect_error(format('SELECT public.admin_begin_account_closure(%L, %L)', v_suspended, ''),
        'reason_required', 'no reason');
    PERFORM pg_temp.expect_error(format('SELECT public.admin_begin_account_closure(%L, %L)', v_admin, 'asked by email'),
        'account_deletion_blocked', 'admin account');

    -- A suspended account can be closed by an admin (not by itself).
    v_json := public.admin_begin_account_closure(v_suspended, 'Asked by email from the account address');
    IF v_json->>'user_id' <> v_suspended::text THEN
        RAISE EXCEPTION 'FAIL begin: %', v_json;
    END IF;
    PERFORM pg_temp.expect_error(format('SELECT public.admin_record_account_closure(%L, %L)', v_suspended, 'asked by email'),
        'account_still_exists', 'audit before deletion');

    PERFORM pg_temp.as_owner();
    PERFORM pg_temp.expect_error(format('SELECT public.delete_account(%L)', v_suspended),
        'account_deletion_blocked', 'self path refuses a suspended account');
    v_json := public.delete_account(v_suspended, true);
    IF NOT (v_json->>'deleted')::boolean OR EXISTS (SELECT 1 FROM auth.users WHERE id = v_suspended) THEN
        RAISE EXCEPTION 'FAIL admin delete: %', v_json;
    END IF;

    PERFORM pg_temp.act_as(v_admin, 'aal2', interval '1 minute');
    PERFORM public.admin_record_account_closure(v_suspended, 'Asked by email from the account address', 'customer');
    PERFORM pg_temp.as_owner();
    IF NOT EXISTS (SELECT 1 FROM private.admin_audit_log
                   WHERE action = 'account.close' AND target_id = v_suspended::text AND admin_id = v_admin) THEN
        RAISE EXCEPTION 'FAIL: no audit entry';
    END IF;

    -- The deployed function's one-argument call still works.
    v_json := public.delete_account(v_client);
    IF NOT (v_json->>'deleted')::boolean THEN
        RAISE EXCEPTION 'FAIL one-argument delete: %', v_json;
    END IF;

    RAISE NOTICE 'admin account closure: all checks passed';
END;
$test$;
