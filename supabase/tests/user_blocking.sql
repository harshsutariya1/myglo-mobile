-- Checks for blocking (20261124120000_user_blocking).
--
-- Run inside a transaction that is rolled back (see supabase/tests/jobs.sql).
-- Needs a listed provider with a location and an approved post, and creates
-- a throwaway client, which the rollback removes.

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
    v_post     uuid;
    v_client   uuid := gen_random_uuid();
    v_lat      double precision;
    v_lng      double precision;
    v_count    integer;
BEGIN
    -- Privileges: writes only through the functions; no "who blocked me" RPC.
    IF has_table_privilege('authenticated', 'public.user_blocks', 'INSERT')
       OR has_table_privilege('authenticated', 'public.user_blocks', 'DELETE')
       OR has_table_privilege('anon', 'public.user_blocks', 'SELECT')
       OR has_function_privilege('anon', 'public.block_user(uuid)', 'EXECUTE')
       OR has_function_privilege('authenticated', 'private.is_blocked_between(uuid, uuid)', 'EXECUTE')
       OR NOT has_function_privilege('authenticated', 'rls.is_blocked_with(uuid)', 'EXECUTE')
       OR has_function_privilege('anon', 'rls.is_blocked_with(uuid)', 'EXECUTE') THEN
        RAISE EXCEPTION 'FAIL: privileges';
    END IF;

    SELECT p.id, public.st_y(p.coordinates::public.geometry), public.st_x(p.coordinates::public.geometry)
    INTO v_provider, v_lat, v_lng
    FROM public.profiles p
    WHERE p.role = 'provider' AND p.coordinates IS NOT NULL AND NOT private.is_unlisted(p.id)
      AND EXISTS (SELECT 1 FROM public.posts po WHERE po.author_id = p.id AND po.tag_status = 'approved' AND po.hidden_at IS NULL)
    ORDER BY p.id LIMIT 1;
    SELECT po.id INTO v_post FROM public.posts po
    WHERE po.author_id = v_provider AND po.tag_status = 'approved' AND po.hidden_at IS NULL LIMIT 1;
    IF v_provider IS NULL THEN
        RAISE EXCEPTION 'needs a listed provider with a location and an approved post';
    END IF;

    INSERT INTO auth.users (id, instance_id, aud, role, email)
    VALUES (v_client, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
            'block-' || v_client || '@example.test');
    INSERT INTO public.profiles (id, role, email, first_name, last_name, phone_number)
    VALUES (v_client, 'customer', 'block-' || v_client || '@example.test', 'Test', 'Client', '0412345678');

    -- Before: the client sees the provider, their post, and can follow them.
    PERFORM pg_temp.act_as(v_client);
    IF NOT EXISTS (SELECT 1 FROM public.map_providers(v_lat, v_lng, 2000, 300) m WHERE m.provider_id = v_provider)
       OR NOT EXISTS (SELECT 1 FROM public.posts WHERE id = v_post) THEN
        RAISE EXCEPTION 'FAIL: provider not visible before blocking';
    END IF;
    INSERT INTO public.follows (follower_id, following_id) VALUES (v_client, v_provider);

    -- Refusals.
    PERFORM pg_temp.expect_error(format('SELECT public.block_user(%L)', v_client), 'invalid_block', 'block self');
    PERFORM pg_temp.expect_error(format('SELECT public.block_user(%L)', gen_random_uuid()), 'user_not_found', 'block nobody');
    PERFORM pg_temp.expect_error(
        format('INSERT INTO public.user_blocks (blocker_id, blocked_id) VALUES (%L, %L)', v_client, v_provider),
        'permission denied for table user_blocks', 'direct insert');

    -- The client blocks the provider.
    PERFORM public.block_user(v_provider);
    PERFORM public.block_user(v_provider); -- idempotent
    IF (SELECT count(*) FROM public.list_blocked_users()) <> 1 THEN
        RAISE EXCEPTION 'FAIL: list_blocked_users';
    END IF;
    IF EXISTS (SELECT 1 FROM public.follows f WHERE f.follower_id = v_client AND f.following_id = v_provider) THEN
        RAISE EXCEPTION 'FAIL: the follow survived the block';
    END IF;

    -- The client no longer sees the provider or their post, and can't follow.
    IF EXISTS (SELECT 1 FROM public.map_providers(v_lat, v_lng, 2000, 300) m WHERE m.provider_id = v_provider)
       OR EXISTS (SELECT 1 FROM public.posts WHERE id = v_post) THEN
        RAISE EXCEPTION 'FAIL: blocked provider still visible to the client';
    END IF;
    PERFORM pg_temp.expect_error('SELECT * FROM public.set_post_like(' || quote_literal(v_post) || ', true)',
        'post_not_found', 'like a blocked author''s post');
    BEGIN
        INSERT INTO public.follows (follower_id, following_id) VALUES (v_client, v_provider);
        RAISE EXCEPTION 'FAIL: followed a blocked provider';
    EXCEPTION WHEN insufficient_privilege THEN
        NULL; -- refused by row level security
    END;

    -- Both ways: the provider doesn't see the client's block, and can't follow them.
    PERFORM pg_temp.act_as(v_provider);
    SELECT count(*) INTO v_count FROM public.user_blocks;
    IF v_count <> 0 THEN
        RAISE EXCEPTION 'FAIL: the blocked provider can see who blocked them';
    END IF;
    BEGIN
        INSERT INTO public.follows (follower_id, following_id) VALUES (v_provider, v_client);
        RAISE EXCEPTION 'FAIL: the blocked provider followed the client';
    EXCEPTION WHEN insufficient_privilege THEN
        NULL;
    END;

    -- Unblock: visible again.
    PERFORM pg_temp.act_as(v_client);
    PERFORM public.unblock_user(v_provider);
    IF NOT EXISTS (SELECT 1 FROM public.map_providers(v_lat, v_lng, 2000, 300) m WHERE m.provider_id = v_provider)
       OR NOT EXISTS (SELECT 1 FROM public.posts WHERE id = v_post) THEN
        RAISE EXCEPTION 'FAIL: provider not visible after unblocking';
    END IF;

    PERFORM pg_temp.as_owner();
    RAISE NOTICE 'user blocking: all checks passed';
END;
$test$;
