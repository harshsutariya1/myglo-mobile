-- Checks for phone verification and the contact rules
-- (20261113120000_phone_verification_and_contact_rules).
--
-- Run inside a transaction that is rolled back (see supabase/tests/jobs.sql).
-- Needs one provider and one client profile. Auth's side (texting and
-- checking the code) is simulated by writing auth.users.phone /
-- phone_confirmed_at, which is what Auth does when a code is accepted.

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

DO $test$
DECLARE
    v_provider uuid;
    v_client   uuid;
    v_new      uuid := gen_random_uuid();
    -- A number no real account has (Auth keeps phones unique).
    v_phone    constant text := '61400' || lpad((floor(random() * 1000000))::integer::text, 6, '0');
    v_json     jsonb;
    v_first    timestamptz;
    v_profile  public.profiles;
    v_seen     record;
BEGIN
    IF NOT has_function_privilege('authenticated', 'public.confirm_phone_verification()', 'EXECUTE')
       OR has_function_privilege('anon', 'public.confirm_phone_verification()', 'EXECUTE') THEN
        RAISE EXCEPTION 'FAIL: privileges';
    END IF;

    SELECT p.id INTO v_provider FROM public.profiles p WHERE p.role = 'provider' ORDER BY p.id LIMIT 1;
    SELECT p.id INTO v_client FROM public.profiles p WHERE p.role = 'customer' ORDER BY p.id LIMIT 1;
    IF v_provider IS NULL OR v_client IS NULL THEN
        RAISE EXCEPTION 'needs a provider and a client';
    END IF;
    UPDATE public.profiles SET phone_number = '0400 000 000', phone_verified_at = NULL WHERE id = v_provider;
    UPDATE public.profiles SET phone_number = '0400 000 001' WHERE id = v_client;
    UPDATE auth.users SET phone = NULL, phone_confirmed_at = NULL WHERE id = v_provider;

    -- ------------------------------------------------------- verification
    -- Nothing confirmed by Auth: nothing to copy.
    PERFORM pg_temp.act_as(v_provider);
    PERFORM pg_temp.expect_error('SELECT public.confirm_phone_verification()', 'phone_not_verified', 'no phone');
    PERFORM pg_temp.as_owner();
    UPDATE auth.users SET phone = v_phone WHERE id = v_provider;
    PERFORM pg_temp.act_as(v_provider);
    PERFORM pg_temp.expect_error('SELECT public.confirm_phone_verification()', 'phone_not_verified', 'unconfirmed phone');

    -- The provider can't mark themselves verified.
    PERFORM pg_temp.expect_error(
        format('UPDATE public.profiles SET phone_verified_at = now() WHERE id = %L', v_provider),
        'Protected profile column cannot be modified directly', 'self-verified');

    -- Auth accepted the code: the number lands on the profile, verified.
    PERFORM pg_temp.as_owner();
    UPDATE auth.users SET phone_confirmed_at = now() WHERE id = v_provider;
    PERFORM pg_temp.act_as(v_provider);
    v_json := public.confirm_phone_verification();
    PERFORM pg_temp.as_owner();
    SELECT * INTO v_profile FROM public.profiles WHERE id = v_provider;
    IF v_profile.phone_number <> '+' || v_phone OR v_profile.phone_verified_at IS NULL
       OR v_json->>'phone_number' <> '+' || v_phone THEN
        RAISE EXCEPTION 'FAIL confirm: % / % / %', v_profile.phone_number, v_profile.phone_verified_at, v_json;
    END IF;
    v_first := v_profile.phone_verified_at;

    -- Confirming again keeps the original time; other profile edits keep the mark.
    PERFORM pg_temp.act_as(v_provider);
    PERFORM public.confirm_phone_verification();
    UPDATE public.profiles SET bio = bio WHERE id = v_provider;
    PERFORM pg_temp.as_owner();
    IF (SELECT p.phone_verified_at FROM public.profiles p WHERE p.id = v_provider) IS DISTINCT FROM v_first THEN
        RAISE EXCEPTION 'FAIL: the verified time moved';
    END IF;

    -- Changing the number in the profile editor clears the mark; the
    -- provider stays listed (verification is asked for, not enforced).
    PERFORM pg_temp.act_as(v_provider);
    UPDATE public.profiles SET phone_number = '0411 111 111' WHERE id = v_provider;
    PERFORM pg_temp.as_owner();
    IF (SELECT p.phone_verified_at FROM public.profiles p WHERE p.id = v_provider) IS NOT NULL THEN
        RAISE EXCEPTION 'FAIL: a changed number stayed verified';
    END IF;
    IF private.is_unlisted(v_provider) IS DISTINCT FROM
       (private.is_unbookable(v_provider) OR private.is_hidden_provider(v_provider)) THEN
        RAISE EXCEPTION 'FAIL: an unverified phone changed whether the provider is listed';
    END IF;

    -- --------------------------------------------------- a number is required
    PERFORM pg_temp.act_as(v_provider);
    PERFORM pg_temp.expect_error(
        format('UPDATE public.profiles SET phone_number = %L WHERE id = %L', '  ', v_provider),
        'phone_required', 'provider removed their number');
    PERFORM pg_temp.act_as(v_client);
    PERFORM pg_temp.expect_error(
        format('UPDATE public.profiles SET phone_number = NULL WHERE id = %L', v_client),
        'phone_required', 'client removed their number');

    -- Onboarding won't finish without a usable number.
    PERFORM pg_temp.as_owner();
    INSERT INTO auth.users (id, instance_id, aud, role, email)
    VALUES (v_new, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
            'phone-' || v_new || '@example.test');
    INSERT INTO public.profiles (id, role, email) VALUES (v_new, 'customer', 'phone-' || v_new || '@example.test');
    PERFORM pg_temp.act_as(v_new);
    PERFORM pg_temp.expect_error(
        format('SELECT public.update_onboarding_details(%L, %L, %L, %L, %L, NULL)', v_new, 'customer', 'Test', 'Client', ''),
        'A phone number is required', 'onboarding without a phone');
    PERFORM pg_temp.expect_error(
        format('SELECT public.update_onboarding_details(%L, %L, %L, %L, %L, NULL)', v_new, 'customer', 'Test', 'Client', '12345'),
        'Enter a valid phone number', 'onboarding with a bad phone');
    PERFORM public.update_onboarding_details(v_new, 'customer', 'Test', 'Client', '0412 345 678', NULL);
    PERFORM pg_temp.as_owner();
    IF (SELECT p.phone_number FROM public.profiles p WHERE p.id = v_new) <> '0412 345 678' THEN
        RAISE EXCEPTION 'FAIL: onboarding did not save the phone number';
    END IF;

    -- ------------------------------------------- contact details by role
    -- Whatever the old switches say: a provider's are shown, a client's never.
    UPDATE public.profiles SET is_email_public = false, is_phone_public = false WHERE id = v_provider;
    UPDATE public.profiles SET is_email_public = true, is_phone_public = true WHERE id = v_client;
    PERFORM pg_temp.act_as(v_new);
    SELECT pp.email, pp.phone_number INTO v_seen FROM public.public_profiles pp WHERE pp.id = v_provider;
    IF v_seen.email IS NULL OR v_seen.phone_number IS NULL THEN
        RAISE EXCEPTION 'FAIL: a provider''s contact details were hidden';
    END IF;
    SELECT pp.email, pp.phone_number INTO v_seen FROM public.public_profiles pp WHERE pp.id = v_client;
    IF v_seen.email IS NOT NULL OR v_seen.phone_number IS NOT NULL THEN
        RAISE EXCEPTION 'FAIL: a client''s contact details were public';
    END IF;

    PERFORM pg_temp.as_owner();
    RAISE NOTICE 'phone verification and contact rules: all checks passed';
END;
$test$;
