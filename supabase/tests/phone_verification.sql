-- Checks for provider phone verification
-- (20261113120000_provider_phone_verification).
--
-- Run inside a transaction that is rolled back (see supabase/tests/jobs.sql).
-- Needs a listed provider with a location. Auth's side (texting and checking
-- the code) is simulated by writing auth.users.phone / phone_confirmed_at,
-- which is what Auth does when a code is accepted.

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
    v_viewer   uuid;
    v_lat      double precision;
    v_lng      double precision;
    -- A number no real account has (Auth keeps phones unique).
    v_phone    constant text := '61400' || lpad((floor(random() * 1000000))::integer::text, 6, '0');
    v_json     jsonb;
    v_first    timestamptz;
    v_profile  public.profiles;
    v_on_map   boolean;
BEGIN
    IF NOT has_function_privilege('authenticated', 'public.confirm_phone_verification()', 'EXECUTE')
       OR has_function_privilege('anon', 'public.confirm_phone_verification()', 'EXECUTE')
       OR has_function_privilege('authenticated', 'private.lacks_required_phone(uuid)', 'EXECUTE') THEN
        RAISE EXCEPTION 'FAIL: privileges';
    END IF;

    SELECT p.id, public.st_y(p.coordinates::public.geometry), public.st_x(p.coordinates::public.geometry)
    INTO v_provider, v_lat, v_lng
    FROM public.profiles p
    JOIN public.provider_booking_settings s ON s.provider_id = p.id
    WHERE p.role = 'provider' AND p.coordinates IS NOT NULL AND NOT s.hidden_from_marketplace
      AND NOT private.is_unbookable(p.id)
      AND EXISTS (SELECT 1 FROM public.services sv WHERE sv.provider_id = p.id)
    ORDER BY p.id LIMIT 1;
    SELECT p.id INTO v_viewer FROM public.profiles p WHERE p.id <> v_provider ORDER BY p.id LIMIT 1;
    IF v_provider IS NULL OR v_viewer IS NULL THEN
        RAISE EXCEPTION 'needs a listed provider with a location and a service, and one other account';
    END IF;
    UPDATE public.profiles SET phone_number = '0400 000 000', phone_verified_at = NULL WHERE id = v_provider;
    UPDATE auth.users SET phone = NULL, phone_confirmed_at = NULL WHERE id = v_provider;
    UPDATE private.platform_settings SET require_provider_phone_verification = false WHERE id;

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

    -- The requirement: verified providers stay listed, unverified ones don't.
    UPDATE private.platform_settings SET require_provider_phone_verification = true WHERE id;
    IF private.is_unlisted(v_provider) THEN
        RAISE EXCEPTION 'FAIL: a verified provider was unlisted';
    END IF;
    PERFORM pg_temp.act_as(v_viewer);
    v_on_map := EXISTS (SELECT 1 FROM public.map_providers(v_lat, v_lng, 2000, 300) m WHERE m.provider_id = v_provider);
    IF NOT v_on_map OR NOT (SELECT pp.is_listed FROM public.public_profiles pp WHERE pp.id = v_provider)
       OR NOT (public.get_app_config()->>'require_provider_phone_verification')::boolean THEN
        RAISE EXCEPTION 'FAIL verified + required: on map %', v_on_map;
    END IF;

    -- Changing the number in the profile editor clears the mark...
    PERFORM pg_temp.act_as(v_provider);
    UPDATE public.profiles SET phone_number = '0411 111 111' WHERE id = v_provider;
    PERFORM pg_temp.as_owner();
    IF (SELECT p.phone_verified_at FROM public.profiles p WHERE p.id = v_provider) IS NOT NULL THEN
        RAISE EXCEPTION 'FAIL: a changed number stayed verified';
    END IF;
    -- ...and with the requirement on, that unlists the provider.
    IF NOT private.is_unlisted(v_provider) OR NOT private.lacks_required_phone(v_provider) THEN
        RAISE EXCEPTION 'FAIL: an unverified provider stayed listed';
    END IF;
    PERFORM pg_temp.act_as(v_viewer);
    v_on_map := EXISTS (SELECT 1 FROM public.map_providers(v_lat, v_lng, 2000, 300) m WHERE m.provider_id = v_provider);
    IF v_on_map OR (SELECT pp.is_listed FROM public.public_profiles pp WHERE pp.id = v_provider) THEN
        RAISE EXCEPTION 'FAIL unverified + required: on map %', v_on_map;
    END IF;

    -- Requirement off: listed again, verified or not.
    PERFORM pg_temp.as_owner();
    UPDATE private.platform_settings SET require_provider_phone_verification = false WHERE id;
    IF private.is_unlisted(v_provider) THEN
        RAISE EXCEPTION 'FAIL: unlisted with the requirement off';
    END IF;

    RAISE NOTICE 'phone verification: all checks passed';
END;
$test$;
