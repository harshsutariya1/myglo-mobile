-- Checks for account deletion (20261102120000_account_deletion).
--
-- Run inside a transaction that is rolled back (see supabase/tests/jobs.sql).
-- Creates two throwaway clients and an admin, and deletes a seeded provider
-- that has nothing in progress (for real only until the rollback). Needs one
-- such bookable provider without a payout account.

CREATE FUNCTION pg_temp.act_as(p_uid uuid, p_password_age interval DEFAULT interval '1 hour')
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
    PERFORM set_config('request.jwt.claims', jsonb_build_object(
        'sub', p_uid, 'role', 'authenticated', 'aal', 'aal1',
        'amr', jsonb_build_array(jsonb_build_object(
            'method', 'password', 'timestamp', extract(epoch FROM now() - p_password_age)::bigint)),
        'session_id', gen_random_uuid())::text, true);
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

CREATE FUNCTION pg_temp.new_client(p_label text)
RETURNS uuid LANGUAGE plpgsql AS $$
DECLARE
    v_id uuid := gen_random_uuid();
BEGIN
    INSERT INTO auth.users (id, instance_id, aud, role, email)
    VALUES (v_id, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
            'delete-' || p_label || '-' || v_id || '@example.test');
    INSERT INTO public.profiles (id, role, email, first_name, last_name, phone_number)
    VALUES (v_id, 'customer', 'delete-' || p_label || '-' || v_id || '@example.test', 'Test', p_label, '0412345678');
    RETURN v_id;
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

-- A booking made by p_client: card bookings come back paid.
CREATE FUNCTION pg_temp.book(p_client uuid, p_provider uuid, p_service uuid, p_price integer, p_method text, p_n integer)
RETURNS public.bookings LANGUAGE plpgsql AS $$
DECLARE
    v_booking public.bookings;
    v_slot    timestamptz := pg_temp.next_slot(p_provider, (SELECT duration_minutes FROM public.services WHERE id = p_service));
BEGIN
    PERFORM pg_temp.act_as(p_client);
    v_booking := public.create_booking(gen_random_uuid(), p_provider, ARRAY[p_service], v_slot, 'studio', '0412345678', p_price, p_method);
    PERFORM pg_temp.as_owner();
    IF p_method = 'card' THEN
        PERFORM public.record_payment_intent(v_booking.id, 'pi_Del' || p_n);
        PERFORM public.apply_payment_intent_state('pi_Del' || p_n, 'succeeded', p_price, p_price, 0, 'ch_Del' || p_n);
    END IF;
    SELECT * INTO v_booking FROM public.bookings WHERE id = v_booking.id;
    RETURN v_booking;
END;
$$;

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

CREATE FUNCTION pg_temp.blocker_codes(p_user uuid)
RETURNS text[] LANGUAGE sql AS $$
    SELECT coalesce(array_agg(b->>'code' ORDER BY ord), '{}')
    FROM jsonb_array_elements(private.account_deletion_blockers(p_user)) WITH ORDINALITY AS t(b, ord);
$$;

DO $test$
DECLARE
    v_admin      uuid := gen_random_uuid();
    v_client     uuid;
    v_client2    uuid;
    v_provider   uuid;
    v_service    uuid;
    v_price      integer;
    v_email      text;
    v_reviews    integer;
    v_b          public.bookings;
    v_card       public.bookings;
    v_post       uuid;
    v_json       jsonb;
    v_count      integer;
BEGIN
    -- Privileges.
    IF has_function_privilege('authenticated', 'public.delete_account(uuid)', 'EXECUTE')
       OR has_function_privilege('anon', 'public.delete_account(uuid)', 'EXECUTE')
       OR has_function_privilege('authenticated', 'public.list_deleted_account_files(uuid, integer)', 'EXECUTE')
       OR has_function_privilege('anon', 'public.begin_account_deletion()', 'EXECUTE')
       OR has_function_privilege('anon', 'public.get_my_account_deletion_status()', 'EXECUTE')
       OR has_table_privilege('authenticated', 'private.account_deletions', 'SELECT') THEN
        RAISE EXCEPTION 'FAIL privileges: deletion functions or log reachable by the wrong role';
    END IF;
    IF NOT has_function_privilege('authenticated', 'public.begin_account_deletion()', 'EXECUTE')
       OR NOT has_function_privilege('service_role', 'public.delete_account(uuid)', 'EXECUTE') THEN
        RAISE EXCEPTION 'FAIL privileges: callers lost access';
    END IF;

    SELECT p.id INTO v_provider
    FROM public.profiles p
    JOIN public.provider_booking_settings s ON s.provider_id = p.id
    WHERE p.role = 'provider' AND s.accepts_bookings AND s.offers_studio AND p.address_text IS NOT NULL
      AND NOT EXISTS (SELECT 1 FROM private.provider_payout_accounts a WHERE a.provider_id = p.id)
      AND EXISTS (SELECT 1 FROM public.provider_working_hours h WHERE h.provider_id = p.id)
      AND private.account_deletion_blockers(p.id) = '[]'::jsonb
    ORDER BY (SELECT count(*) FROM public.provider_working_hours h WHERE h.provider_id = p.id) DESC, p.id
    LIMIT 1;
    SELECT sv.id, round(sv.price * 100)::integer INTO v_service, v_price
    FROM public.services sv
    WHERE sv.provider_id = v_provider AND sv.price >= 20 AND sv.duration_minutes > 0
    ORDER BY sv.duration_minutes, sv.id LIMIT 1;
    IF v_provider IS NULL OR v_service IS NULL THEN
        RAISE EXCEPTION 'needs a bookable provider with nothing in progress and no payout account';
    END IF;
    UPDATE public.provider_booking_settings
    SET requires_approval = false, accepts_cash = true, accepts_card = true, max_advance_days = 60
    WHERE provider_id = v_provider;

    v_client := pg_temp.new_client('client');
    v_client2 := pg_temp.new_client('client2');
    SELECT email INTO v_email FROM auth.users WHERE id = v_client;
    INSERT INTO public.waitlist (email, name) VALUES (upper(v_email), 'Test client');

    -- Admins and suspended accounts can't delete themselves here.
    INSERT INTO auth.users (id, instance_id, aud, role, email)
    VALUES (v_admin, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
            'admin-' || v_admin || '@example.test');
    INSERT INTO private.admins (user_id, display_name) VALUES (v_admin, 'Test Admin');
    IF NOT 'admin_account' = ANY (pg_temp.blocker_codes(v_admin)) THEN
        RAISE EXCEPTION 'FAIL admin: admin accounts must be blocked';
    END IF;
    INSERT INTO private.user_restrictions (user_id, suspended_at, suspended_reason)
    VALUES (v_client2, now(), 'test');
    IF pg_temp.blocker_codes(v_client2) <> ARRAY['account_suspended'] THEN
        RAISE EXCEPTION 'FAIL suspended: got %', pg_temp.blocker_codes(v_client2);
    END IF;
    DELETE FROM private.user_restrictions WHERE user_id = v_client2;

    -- ---------------------------------------------------------------- client
    -- A cash booking is always a request: it blocks both sides.
    v_b := pg_temp.book(v_client, v_provider, v_service, v_price, 'cash', 1);
    IF pg_temp.blocker_codes(v_client) <> ARRAY['upcoming_bookings']
       OR pg_temp.blocker_codes(v_provider) <> ARRAY['upcoming_bookings'] THEN
        RAISE EXCEPTION 'FAIL request: client % provider %', pg_temp.blocker_codes(v_client), pg_temp.blocker_codes(v_provider);
    END IF;

    PERFORM pg_temp.act_as(v_client);
    v_json := public.get_my_account_deletion_status();
    IF v_json->>'role' <> 'customer' OR (v_json->>'has_payout_account')::boolean
       OR v_json->'blockers'->0->>'code' <> 'upcoming_bookings' OR (v_json->'blockers'->0->>'count')::integer <> 1 THEN
        RAISE EXCEPTION 'FAIL status: %', v_json;
    END IF;
    -- An old password check isn't enough...
    PERFORM pg_temp.expect_error('SELECT public.begin_account_deletion()', 'reauth_required', 'stale password');
    -- ...and a fresh one still hits the blocker.
    PERFORM pg_temp.act_as(v_client, interval '30 seconds');
    PERFORM pg_temp.expect_error('SELECT public.begin_account_deletion()', 'account_deletion_blocked', 'begin blocked');
    PERFORM pg_temp.expect_error(format('SELECT public.delete_account(%L)', v_client), 'permission denied for function delete_account', 'user calls delete');
    PERFORM pg_temp.as_owner();
    PERFORM pg_temp.expect_error(format('SELECT public.delete_account(%L)', v_client), 'account_deletion_blocked', 'delete blocked');

    -- Past and done: nothing blocks. A review, a like, a comment, a
    -- favourite and a tagged post to clean up.
    PERFORM pg_temp.move_to_past(v_b.id, 48);
    UPDATE public.bookings SET status = 'completed', completed_at = now() WHERE id = v_b.id;
    IF pg_temp.blocker_codes(v_client) <> '{}' THEN
        RAISE EXCEPTION 'FAIL past: %', pg_temp.blocker_codes(v_client);
    END IF;
    SELECT coalesce((SELECT review_count FROM public.provider_review_stats WHERE provider_id = v_provider), 0) INTO v_reviews;
    INSERT INTO public.reviews (booking_id, provider_id, client_id, rating, body)
    VALUES (v_b.id, v_provider, v_client, 5, 'Lovely');
    INSERT INTO public.favourites (client_id, provider_id) VALUES (v_client, v_provider);
    INSERT INTO public.posts (author_id, media_urls, caption, tagged_provider_id)
    VALUES (v_client, ARRAY['https://example.test/a.jpg'], 'Fresh cut', v_provider)
    RETURNING id INTO v_post;
    INSERT INTO public.likes (post_id, user_id)
    SELECT p.id, v_client FROM public.posts p WHERE p.author_id <> v_client LIMIT 1;
    INSERT INTO public.comments (post_id, author_id, content)
    SELECT p.id, v_client, 'Nice' FROM public.posts p WHERE p.author_id <> v_client LIMIT 1;
    IF NOT EXISTS (SELECT 1 FROM public.notifications WHERE actor_id = v_client) THEN
        RAISE EXCEPTION 'setup: the booking request should have notified the provider';
    END IF;

    PERFORM pg_temp.act_as(v_client, interval '30 seconds');
    v_json := public.begin_account_deletion();
    IF (v_json->>'user_id')::uuid <> v_client OR v_json->>'email' <> v_email OR v_json->'stripe_account_id' <> 'null'::jsonb THEN
        RAISE EXCEPTION 'FAIL begin: %', v_json;
    END IF;

    PERFORM pg_temp.as_owner();
    v_json := public.delete_account(v_client);
    IF NOT (v_json->>'deleted')::boolean OR v_json->>'role' <> 'customer' OR (v_json->>'stripe_account_closing')::boolean THEN
        RAISE EXCEPTION 'FAIL delete: %', v_json;
    END IF;

    IF EXISTS (SELECT 1 FROM auth.users WHERE id = v_client)
       OR EXISTS (SELECT 1 FROM public.profiles WHERE id = v_client)
       OR EXISTS (SELECT 1 FROM public.reviews WHERE client_id = v_client)
       OR EXISTS (SELECT 1 FROM public.favourites WHERE client_id = v_client)
       OR EXISTS (SELECT 1 FROM public.posts WHERE id = v_post)
       OR EXISTS (SELECT 1 FROM public.likes WHERE user_id = v_client)
       OR EXISTS (SELECT 1 FROM public.comments WHERE author_id = v_client)
       OR EXISTS (SELECT 1 FROM public.notifications WHERE actor_id = v_client OR recipient_id = v_client)
       OR EXISTS (SELECT 1 FROM public.waitlist WHERE lower(email) = lower(v_email)) THEN
        RAISE EXCEPTION 'FAIL cascade: the client left data behind';
    END IF;
    SELECT * INTO v_b FROM public.bookings WHERE id = v_b.id;
    IF v_b.client_id IS NOT NULL OR v_b.client_name <> 'Deleted account' OR v_b.client_phone <> ''
       OR v_b.client_notes IS NOT NULL OR v_b.provider_id IS DISTINCT FROM v_provider THEN
        RAISE EXCEPTION 'FAIL scrub: booking kept the client''s details';
    END IF;
    IF coalesce((SELECT review_count FROM public.provider_review_stats WHERE provider_id = v_provider), 0) <> v_reviews THEN
        RAISE EXCEPTION 'FAIL stats: review totals not updated';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM private.account_deletions WHERE user_id = v_client AND role = 'customer' AND stripe_account_id IS NULL)
       OR NOT EXISTS (SELECT 1 FROM private.jobs WHERE idempotency_key = 'purge-storage:' || v_client AND kind = 'purge_user_storage')
       OR EXISTS (SELECT 1 FROM private.jobs WHERE kind = 'close_connect_account' AND payload->>'stripe_account_id' IS NULL) THEN
        RAISE EXCEPTION 'FAIL record: deletion log or purge job missing';
    END IF;
    -- Deleting twice finds nothing.
    PERFORM pg_temp.expect_error(format('SELECT public.delete_account(%L)', v_client), 'account_not_found', 'delete twice');

    -- Files: only once the account is gone.
    PERFORM count(*) FROM public.list_deleted_account_files(v_client);
    PERFORM pg_temp.expect_error(format('SELECT * FROM public.list_deleted_account_files(%L)', v_provider),
        'account_still_exists', 'purge live account');

    -- -------------------------------------------------------------- provider
    PERFORM public.save_connect_account(v_provider, 'acct_TestDel1');
    PERFORM public.apply_connect_account_state('acct_TestDel1', 'active', true, '{}', '{}', NULL, NULL);
    INSERT INTO public.favourites (client_id, provider_id) VALUES (v_client2, v_provider);

    -- Paid by card and upcoming.
    v_card := pg_temp.book(v_client2, v_provider, v_service, v_price, 'card', 2);
    IF v_card.status <> 'confirmed' OR pg_temp.blocker_codes(v_provider) <> ARRAY['upcoming_bookings'] THEN
        RAISE EXCEPTION 'FAIL card upcoming: % %', v_card.status, pg_temp.blocker_codes(v_provider);
    END IF;
    -- Ended but not completed: the provider is still owed.
    PERFORM pg_temp.move_to_past(v_card.id, 2);
    IF pg_temp.blocker_codes(v_provider) <> ARRAY['payouts_pending'] OR pg_temp.blocker_codes(v_client2) <> '{}' THEN
        RAISE EXCEPTION 'FAIL ended: provider % client %', pg_temp.blocker_codes(v_provider), pg_temp.blocker_codes(v_client2);
    END IF;
    -- Completed: the settlement waits for, or is making, its transfer.
    PERFORM pg_temp.move_to_past(v_card.id, 30);
    PERFORM private.auto_complete_card_bookings();
    IF NOT EXISTS (SELECT 1 FROM public.booking_settlements
                   WHERE booking_id = v_card.id AND status IN ('scheduled', 'held', 'processing'))
       OR pg_temp.blocker_codes(v_provider) <> ARRAY['payouts_pending'] THEN
        RAISE EXCEPTION 'FAIL settlement: %', pg_temp.blocker_codes(v_provider);
    END IF;
    UPDATE public.booking_settlements
    SET status = 'transferred', hold_reason = NULL, stripe_transfer_id = 'tr_TestDel1', transferred_at = now()
    WHERE booking_id = v_card.id;
    -- An open dispute blocks until it closes.
    INSERT INTO public.payment_disputes (id, booking_id, amount_cents, reason, status)
    VALUES ('dp_TestDel1', v_card.id, v_price, 'fraudulent', 'needs_response');
    IF pg_temp.blocker_codes(v_provider) <> ARRAY['open_disputes'] THEN
        RAISE EXCEPTION 'FAIL dispute: %', pg_temp.blocker_codes(v_provider);
    END IF;
    UPDATE public.payment_disputes SET status = 'won', closed_at = now() WHERE id = 'dp_TestDel1';
    IF pg_temp.blocker_codes(v_provider) <> '{}' THEN
        RAISE EXCEPTION 'FAIL provider clear: %', pg_temp.blocker_codes(v_provider);
    END IF;

    -- Providers hide their business instead of deleting their own account
    -- (20261112120000), unless the platform setting allows it. Support can
    -- still close the account: delete_account() doesn't apply the rule.
    UPDATE private.platform_settings SET provider_self_deletion = false WHERE id;
    PERFORM pg_temp.act_as(v_provider, interval '30 seconds');
    v_json := public.get_my_account_deletion_status();
    IF v_json->'blockers' <> '[{"code": "provider_deletion_disabled", "count": 1}]'::jsonb THEN
        RAISE EXCEPTION 'FAIL provider self-deletion off: %', v_json;
    END IF;
    PERFORM pg_temp.expect_error('SELECT public.begin_account_deletion()', 'account_deletion_blocked',
        'provider self-deletion off');
    PERFORM pg_temp.as_owner();
    IF pg_temp.blocker_codes(v_provider) <> '{}' THEN
        RAISE EXCEPTION 'FAIL support deletion blocked: %', pg_temp.blocker_codes(v_provider);
    END IF;
    UPDATE private.platform_settings SET provider_self_deletion = true WHERE id;

    PERFORM pg_temp.act_as(v_provider, interval '30 seconds');
    v_json := public.get_my_account_deletion_status();
    IF v_json->>'role' <> 'provider' OR NOT (v_json->>'has_payout_account')::boolean
       OR jsonb_array_length(v_json->'blockers') <> 0 THEN
        RAISE EXCEPTION 'FAIL provider status: %', v_json;
    END IF;
    v_json := public.begin_account_deletion();
    IF v_json->>'stripe_account_id' <> 'acct_TestDel1' THEN
        RAISE EXCEPTION 'FAIL provider begin: %', v_json;
    END IF;

    PERFORM pg_temp.as_owner();
    v_json := public.delete_account(v_provider);
    IF NOT (v_json->>'stripe_account_closing')::boolean THEN
        RAISE EXCEPTION 'FAIL provider delete: %', v_json;
    END IF;

    SELECT * INTO v_card FROM public.bookings WHERE id = v_card.id;
    IF v_card.provider_id IS NOT NULL OR v_card.client_id IS DISTINCT FROM v_client2
       OR v_card.provider_name = '' OR v_card.address_text <> '' OR v_card.location IS NOT NULL
       OR v_card.client_name = 'Deleted account' THEN
        RAISE EXCEPTION 'FAIL provider scrub: % / % / %', v_card.provider_name, v_card.address_text, v_card.client_name;
    END IF;
    IF EXISTS (SELECT 1 FROM public.services WHERE provider_id = v_provider)
       OR EXISTS (SELECT 1 FROM public.favourites WHERE provider_id = v_provider)
       OR EXISTS (SELECT 1 FROM private.provider_payout_accounts WHERE provider_id = v_provider)
       OR EXISTS (SELECT 1 FROM public.provider_booking_settings WHERE provider_id = v_provider)
       OR EXISTS (SELECT 1 FROM public.posts WHERE tagged_provider_id = v_provider) THEN
        RAISE EXCEPTION 'FAIL provider cascade: data left behind';
    END IF;
    SELECT count(*) INTO v_count FROM public.booking_settlements WHERE booking_id = v_card.id AND provider_id IS NULL;
    IF v_count <> 1 OR NOT EXISTS (SELECT 1 FROM public.payment_disputes WHERE id = 'dp_TestDel1') THEN
        RAISE EXCEPTION 'FAIL provider records: settlement or dispute not kept';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM private.account_deletions WHERE user_id = v_provider AND stripe_account_id = 'acct_TestDel1')
       OR NOT EXISTS (SELECT 1 FROM private.jobs WHERE idempotency_key = 'close-account:acct_TestDel1'
                      AND kind = 'close_connect_account' AND payload->>'stripe_account_id' = 'acct_TestDel1') THEN
        RAISE EXCEPTION 'FAIL provider jobs: close-account job missing';
    END IF;
    -- A late Stripe event for the closed account is ignored.
    IF public.apply_connect_account_state('acct_TestDel1', 'inactive', false, '{}', '{}', NULL, NULL, true) IS NOT NULL THEN
        RAISE EXCEPTION 'FAIL webhook: event for a deleted provider should be ignored';
    END IF;

    RAISE NOTICE 'account_deletion: all checks passed';
END;
$test$;
