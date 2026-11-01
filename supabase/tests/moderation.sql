-- Checks for moderation, reports and suspension
-- (20261101140000_moderation_and_suspension).
--
-- Run inside a transaction that is rolled back (see supabase/tests/jobs.sql).
-- Needs two free clients and a bookable provider without a payout account
-- (as payment_lifecycle.sql does); creates a throwaway admin account, posts,
-- a review and bookings, all removed by the rollback.

CREATE FUNCTION pg_temp.act_as(p_uid uuid, p_aal text DEFAULT 'aal1', p_totp_age interval DEFAULT NULL)
RETURNS void LANGUAGE plpgsql AS $$
DECLARE
    v_amr jsonb := jsonb_build_array(jsonb_build_object(
        'method', 'password', 'timestamp', extract(epoch FROM now() - interval '1 hour')::bigint));
BEGIN
    IF p_totp_age IS NOT NULL THEN
        v_amr := jsonb_build_array(jsonb_build_object(
            'method', 'totp', 'timestamp', extract(epoch FROM now() - p_totp_age)::bigint)) || v_amr;
    END IF;
    PERFORM set_config('request.jwt.claims', jsonb_build_object(
        'sub', p_uid, 'role', 'authenticated', 'aal', p_aal, 'amr', v_amr,
        'session_id', gen_random_uuid())::text, true);
    PERFORM set_config('role', 'authenticated', true);
END;
$$;

CREATE FUNCTION pg_temp.as_admin(p_admin uuid)
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
    PERFORM pg_temp.act_as(p_admin, 'aal2', interval '1 minute');
END;
$$;

CREATE FUNCTION pg_temp.as_anon()
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
    PERFORM set_config('request.jwt.claims', jsonb_build_object('role', 'anon')::text, true);
    PERFORM set_config('role', 'anon', true);
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

-- A booking made by p_client: card bookings come back paid (charge ch_Mod<n>).
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
        PERFORM public.record_payment_intent(v_booking.id, 'pi_Mod' || p_n);
        PERFORM public.apply_payment_intent_state('pi_Mod' || p_n, 'succeeded', p_price, p_price, 0, 'ch_Mod' || p_n);
    END IF;
    SELECT * INTO v_booking FROM public.bookings WHERE id = v_booking.id;
    RETURN v_booking;
END;
$$;

-- Moves a booking so it started p_hours_ago and ended 30 minutes later.
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
    v_admin    uuid := gen_random_uuid();
    v_client   uuid;
    v_client2  uuid;
    v_provider uuid;
    v_service  uuid;
    v_price    integer;
    v_post     uuid;
    v_post2    uuid;
    v_comment  uuid;
    v_review   uuid;
    v_report   uuid;
    v_b        public.bookings;
    v_upcoming public.bookings;
    v_count    integer;
    v_before   integer;
    v_slot     timestamptz;
    v_json     jsonb;
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
    SELECT p.id INTO v_client2 FROM public.profiles p
    WHERE p.role = 'customer' AND p.id <> v_client
      AND NOT EXISTS (SELECT 1 FROM public.bookings b WHERE b.client_id = p.id AND b.status IN ('awaiting_payment', 'pending', 'confirmed'))
    ORDER BY p.created_at LIMIT 1;
    SELECT sv.id, round(sv.price * 100)::integer INTO v_service, v_price
    FROM public.services sv
    WHERE sv.provider_id = v_provider AND sv.price >= 20 AND sv.duration_minutes > 0
    ORDER BY sv.duration_minutes, sv.id LIMIT 1;
    IF v_client IS NULL OR v_client2 IS NULL OR v_provider IS NULL OR v_service IS NULL THEN
        RAISE EXCEPTION 'needs two free clients and a bookable provider without a payout account';
    END IF;

    INSERT INTO auth.users (id, instance_id, aud, role, email)
    VALUES (v_admin, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
            'admin-' || v_admin || '@example.test');
    INSERT INTO private.admins (user_id, display_name) VALUES (v_admin, 'Test Admin');

    UPDATE private.platform_settings SET card_max_advance_days = 60, report_window_hours = 24 WHERE id;
    UPDATE public.provider_booking_settings
    SET requires_approval = false, accepts_cash = true, accepts_card = true, max_advance_days = 60
    WHERE provider_id = v_provider;
    PERFORM public.save_connect_account(v_provider, 'acct_TestMod1');
    PERFORM public.apply_connect_account_state('acct_TestMod1', 'active', true, '{}', '{}', NULL, NULL);

    INSERT INTO public.posts (author_id, media_urls, caption)
    VALUES (v_provider, ARRAY['https://example.test/mod-1.jpg'], 'Moderation test post')
    RETURNING id INTO v_post;
    INSERT INTO public.posts (author_id, media_urls, caption)
    VALUES (v_provider, ARRAY['https://example.test/mod-2.jpg'], 'Another post')
    RETURNING id INTO v_post2;
    PERFORM pg_temp.act_as(v_client2);
    INSERT INTO public.comments (post_id, author_id, content) VALUES (v_post2, v_client2, 'Moderation test comment')
    RETURNING id INTO v_comment;
    PERFORM pg_temp.as_owner();

    -- Reports ---------------------------------------------------------------------------
    PERFORM pg_temp.act_as(v_client);
    v_report := public.submit_report('post', v_post, 'spam', '  Selling followers  ');
    IF public.submit_report('post', v_post, 'inappropriate') <> v_report THEN
        RAISE EXCEPTION 'FAIL: a repeat report should return the open one';
    END IF;
    IF (SELECT details FROM public.reports WHERE id = v_report) <> 'Selling followers' THEN
        RAISE EXCEPTION 'FAIL: the reporter should see their own report, trimmed';
    END IF;
    PERFORM public.submit_report('comment', v_comment, 'harassment');
    PERFORM public.submit_report('provider', v_provider, 'scam');
    PERFORM pg_temp.expect_error(format('SELECT public.submit_report(%L, %L, %L)', 'post', v_post, 'rude'),
        'invalid_request', 'unknown reason');
    PERFORM pg_temp.expect_error(format('SELECT public.submit_report(%L, %L, %L)', 'provider', v_client, 'scam'),
        'report_target_not_found', 'a client reported as a provider');
    PERFORM pg_temp.expect_error(format('INSERT INTO public.reports (reporter_id, target_type, target_id, reason) VALUES (%L, %L, %L, %L)',
        v_client, 'post', v_post, 'spam'), 'permission denied for table reports', 'direct insert');
    PERFORM pg_temp.act_as(v_provider);
    PERFORM pg_temp.expect_error(format('SELECT public.submit_report(%L, %L, %L)', 'post', v_post, 'spam'),
        'report_target_not_found', 'reporting your own post');
    IF EXISTS (SELECT 1 FROM public.reports) THEN
        RAISE EXCEPTION 'FAIL: reports are visible only to their reporter';
    END IF;
    PERFORM pg_temp.as_owner();
    IF NOT EXISTS (SELECT 1 FROM private.jobs WHERE kind = 'admin_alert' AND idempotency_key = 'alert:report:' || v_report) THEN
        RAISE EXCEPTION 'FAIL: a report should alert the admins';
    END IF;

    PERFORM pg_temp.as_admin(v_admin);
    v_json := public.admin_list_reports('open');
    IF jsonb_array_length(v_json) < 3
       OR NOT EXISTS (SELECT 1 FROM jsonb_array_elements(v_json) r
                      WHERE r->>'id' = v_report::text AND r->'target'->>'text' = 'Moderation test post') THEN
        RAISE EXCEPTION 'FAIL: the queue should show the report and what it points at %', v_json;
    END IF;
    PERFORM pg_temp.expect_error(format('SELECT public.admin_resolve_report(%L, %L, %L)', v_report, 'resolved', ''),
        'reason_required', 'resolving without a note');

    -- Hiding content ----------------------------------------------------------------------
    PERFORM pg_temp.act_as(v_admin, 'aal2', interval '10 minutes');
    PERFORM pg_temp.expect_error(format('SELECT public.admin_set_content_hidden(%L, %L, true, %L)', 'post', v_post, 'Spam'),
        'reauth_required', 'hiding with a 10-minute-old code');
    PERFORM pg_temp.as_admin(v_admin);
    PERFORM public.admin_set_content_hidden('post', v_post, true, 'Spam');
    PERFORM public.admin_set_content_hidden('comment', v_comment, true, 'Abusive');
    PERFORM pg_temp.expect_error(format('SELECT public.admin_set_content_hidden(%L, %L, true, %L)', 'post', gen_random_uuid(), 'Spam'),
        'not_found', 'hiding a missing post');
    PERFORM public.admin_resolve_report(v_report, 'resolved', 'Post hidden');
    PERFORM pg_temp.expect_error(format('SELECT public.admin_resolve_report(%L, %L, %L)', v_report, 'dismissed', 'Again'),
        'report_closed', 'closing a closed report');

    PERFORM pg_temp.act_as(v_client);
    IF EXISTS (SELECT 1 FROM public.posts WHERE id = v_post) OR EXISTS (SELECT 1 FROM public.comments WHERE id = v_comment) THEN
        RAISE EXCEPTION 'FAIL: hidden content should be invisible to others';
    END IF;
    IF (SELECT status FROM public.reports WHERE id = v_report) <> 'resolved' THEN
        RAISE EXCEPTION 'FAIL: the reporter should see the report resolved';
    END IF;
    PERFORM pg_temp.as_anon();
    IF EXISTS (SELECT 1 FROM public.posts WHERE id = v_post) THEN
        RAISE EXCEPTION 'FAIL: hidden posts should be invisible signed out';
    END IF;
    PERFORM pg_temp.act_as(v_provider);
    IF NOT EXISTS (SELECT 1 FROM public.posts WHERE id = v_post AND hidden_at IS NOT NULL) THEN
        RAISE EXCEPTION 'FAIL: the author should still see their hidden post';
    END IF;
    PERFORM pg_temp.expect_error(format('UPDATE public.posts SET hidden_at = NULL WHERE id = %L', v_post),
        'hidden_columns_are_protected', 'author unhiding their post');
    -- Comments can't be edited at all.
    PERFORM pg_temp.act_as(v_client2);
    PERFORM pg_temp.expect_error(format('UPDATE public.comments SET hidden_at = NULL, hidden_reason = NULL WHERE id = %L', v_comment),
        'permission denied for table comments', 'author unhiding their comment');
    PERFORM pg_temp.as_owner();

    -- Hidden reviews leave the rating, and the list, except for their author ---------------
    v_b := pg_temp.book(v_client2, v_provider, v_service, v_price, 'cash', 1);
    PERFORM pg_temp.move_to_past(v_b.id, 3);
    UPDATE public.bookings SET status = 'completed', completed_at = now(), payment_status = 'paid' WHERE id = v_b.id;
    v_before := coalesce((SELECT (to_jsonb(s)->>'review_count')::integer FROM public.provider_review_stats s WHERE s.provider_id = v_provider), 0);
    INSERT INTO public.reviews (booking_id, provider_id, client_id, rating, body, service_ids, service_names)
    VALUES (v_b.id, v_provider, v_client2, 1, 'Moderation test review', ARRAY[v_service], ARRAY['Test service'])
    RETURNING id INTO v_review;
    PERFORM pg_temp.act_as(v_client);
    PERFORM public.submit_report('review', v_review, 'fake');
    PERFORM pg_temp.as_admin(v_admin);
    PERFORM public.admin_set_content_hidden('review', v_review, true, 'Fake review');
    PERFORM pg_temp.as_owner();
    IF coalesce((SELECT (to_jsonb(s)->>'review_count')::integer FROM public.provider_review_stats s WHERE s.provider_id = v_provider), 0) <> v_before THEN
        RAISE EXCEPTION 'FAIL: a hidden review should leave the rating';
    END IF;
    PERFORM pg_temp.act_as(v_client);
    IF EXISTS (SELECT 1 FROM public.list_reviews(v_provider) WHERE id = v_review) THEN
        RAISE EXCEPTION 'FAIL: others should not see a hidden review';
    END IF;
    PERFORM pg_temp.act_as(v_client2);
    IF NOT coalesce((SELECT is_hidden FROM public.list_reviews(v_provider) WHERE id = v_review), false) THEN
        RAISE EXCEPTION 'FAIL: the author should see their review marked hidden';
    END IF;
    PERFORM pg_temp.as_admin(v_admin);
    PERFORM public.admin_set_content_hidden('review', v_review, false, 'Checked with the client');
    PERFORM pg_temp.as_owner();
    IF coalesce((SELECT (to_jsonb(s)->>'review_count')::integer FROM public.provider_review_stats s WHERE s.provider_id = v_provider), 0) <> v_before + 1 THEN
        RAISE EXCEPTION 'FAIL: showing a review again should count it again';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM private.admin_audit_log WHERE admin_id = v_admin AND action = 'show_content' AND target_id = v_review::text) THEN
        RAISE EXCEPTION 'FAIL: showing content should be audited';
    END IF;

    -- A booking report holds the provider's share until it's resolved ---------------------
    v_b := pg_temp.book(v_client, v_provider, v_service, v_price, 'card', 2);
    PERFORM pg_temp.act_as(v_client);
    PERFORM pg_temp.expect_error(format('SELECT public.submit_report(%L, %L, %L)', 'booking', v_b.id, 'no_show'),
        'report_window_closed', 'reporting before the appointment');
    PERFORM pg_temp.act_as(v_client2);
    PERFORM pg_temp.expect_error(format('SELECT public.submit_report(%L, %L, %L)', 'booking', v_b.id, 'no_show'),
        'report_target_not_found', 'reporting someone else''s booking');
    PERFORM pg_temp.as_owner();
    PERFORM pg_temp.move_to_past(v_b.id, 1);
    PERFORM pg_temp.act_as(v_client);
    v_report := public.submit_report('booking', v_b.id, 'service_not_as_described', 'Got a different service');
    PERFORM pg_temp.act_as(v_provider);
    PERFORM public.complete_booking(v_b.id);
    PERFORM pg_temp.as_owner();
    IF (SELECT status || '/' || hold_reason FROM public.booking_settlements WHERE booking_id = v_b.id) <> 'held/report' THEN
        RAISE EXCEPTION 'FAIL: an open booking report should hold the settlement %',
            (SELECT to_jsonb(s) FROM public.booking_settlements s WHERE booking_id = v_b.id);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM public.booking_events WHERE booking_id = v_b.id AND event = 'reported') THEN
        RAISE EXCEPTION 'FAIL: the report should be in the booking''s history';
    END IF;
    PERFORM private.process_due_settlements();
    IF (SELECT status FROM public.booking_settlements WHERE booking_id = v_b.id) <> 'held' THEN
        RAISE EXCEPTION 'FAIL: the sweep must not release a reported booking';
    END IF;
    PERFORM pg_temp.as_admin(v_admin);
    PERFORM public.admin_resolve_report(v_report, 'dismissed', 'Provider showed the booked service');
    PERFORM pg_temp.as_owner();
    IF (SELECT status FROM public.booking_settlements WHERE booking_id = v_b.id) <> 'processing'
       OR NOT EXISTS (SELECT 1 FROM private.jobs WHERE kind = 'transfer' AND booking_id = v_b.id) THEN
        RAISE EXCEPTION 'FAIL: dismissing the report should send the provider''s share';
    END IF;

    -- Blocking a provider's bookings ----------------------------------------------------------
    v_slot := pg_temp.next_slot(v_provider, (SELECT duration_minutes FROM public.services WHERE id = v_service));
    PERFORM pg_temp.as_admin(v_admin);
    PERFORM pg_temp.expect_error(format('SELECT public.admin_set_bookings_blocked(%L, true, %L)', v_client, 'Nope'),
        'not_found', 'blocking a client''s bookings');
    PERFORM public.admin_set_bookings_blocked(v_provider, true, 'Under review');
    PERFORM pg_temp.as_owner();
    PERFORM pg_temp.expect_error(format('SELECT pg_temp.next_slot(%L, 30)', v_provider),
        'no free slot for the test provider', 'free times while blocked');
    PERFORM pg_temp.act_as(v_client2);
    PERFORM pg_temp.expect_error(format(
        'SELECT public.create_booking(gen_random_uuid(), %L, ARRAY[%L]::uuid[], %L::timestamptz, %L, %L, %s, %L)',
        v_provider, v_service, v_slot, 'studio', '0412345678', v_price, 'cash'),
        'provider_not_accepting', 'booking a blocked provider');
    PERFORM pg_temp.as_admin(v_admin);
    PERFORM public.admin_set_bookings_blocked(v_provider, false, 'Review finished');
    PERFORM pg_temp.as_owner();
    PERFORM pg_temp.next_slot(v_provider, (SELECT duration_minutes FROM public.services WHERE id = v_service));

    -- Suspending a client -------------------------------------------------------------------
    v_upcoming := pg_temp.book(v_client2, v_provider, v_service, v_price, 'cash', 3);
    PERFORM pg_temp.as_admin(v_admin);
    v_json := public.admin_get_moderation_state(v_client2);
    -- Their hidden comment and their review are still reported.
    IF (v_json->>'upcoming_bookings')::integer <> 1 OR (v_json->>'open_reports_about')::integer <> 2
       OR v_json->>'suspended_at' IS NOT NULL THEN
        RAISE EXCEPTION 'FAIL: moderation state before suspending %', v_json;
    END IF;
    PERFORM pg_temp.act_as(v_admin, 'aal2', interval '10 minutes');
    PERFORM pg_temp.expect_error(format('SELECT public.admin_set_suspension(%L, true, %L, true)', v_client2, 'Abuse'),
        'reauth_required', 'suspending with a 10-minute-old code');
    PERFORM pg_temp.as_admin(v_admin);
    v_count := public.admin_set_suspension(v_client2, true, 'Abusive comments', true);
    PERFORM pg_temp.as_owner();
    IF v_count <> 1 OR (SELECT status || '/' || cancelled_by FROM public.bookings WHERE id = v_upcoming.id) <> 'cancelled/system' THEN
        RAISE EXCEPTION 'FAIL: suspending should cancel the upcoming booking (% cancelled)', v_count;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM private.jobs WHERE kind = 'auth_ban' AND idempotency_key = 'auth-ban:' || v_client2 || ':1')
       OR NOT public.account_should_be_banned(v_client2) THEN
        RAISE EXCEPTION 'FAIL: suspending should queue the Auth ban';
    END IF;

    v_slot := pg_temp.next_slot(v_provider, (SELECT duration_minutes FROM public.services WHERE id = v_service));
    PERFORM pg_temp.act_as(v_client2);
    PERFORM pg_temp.expect_error(format('INSERT INTO public.likes (post_id, user_id) VALUES (%L, %L)', v_post2, v_client2),
        'account_suspended', 'a suspended client liking');
    PERFORM pg_temp.expect_error(format('INSERT INTO public.comments (post_id, author_id, content) VALUES (%L, %L, %L)', v_post2, v_client2, 'Hi'),
        'account_suspended', 'a suspended client commenting');
    PERFORM pg_temp.expect_error(format('UPDATE public.profiles SET bio = %L WHERE id = %L', 'Hello', v_client2),
        'account_suspended', 'a suspended client editing their profile');
    PERFORM pg_temp.expect_error(format('SELECT public.submit_report(%L, %L, %L)', 'post', v_post2, 'spam'),
        'account_suspended', 'a suspended client reporting');
    PERFORM pg_temp.expect_error(format(
        'SELECT public.create_booking(gen_random_uuid(), %L, ARRAY[%L]::uuid[], %L::timestamptz, %L, %L, %s, %L)',
        v_provider, v_service, v_slot, 'studio', '0412345678', v_price, 'cash'),
        'account_suspended', 'a suspended client booking');

    PERFORM pg_temp.as_admin(v_admin);
    PERFORM public.admin_set_suspension(v_client2, false, 'Appeal accepted');
    PERFORM pg_temp.as_owner();
    IF public.account_should_be_banned(v_client2)
       OR NOT EXISTS (SELECT 1 FROM private.jobs WHERE kind = 'auth_ban' AND idempotency_key = 'auth-ban:' || v_client2 || ':2') THEN
        RAISE EXCEPTION 'FAIL: lifting a suspension should queue lifting the Auth ban';
    END IF;
    PERFORM pg_temp.act_as(v_client2);
    INSERT INTO public.likes (post_id, user_id) VALUES (v_post2, v_client2);
    PERFORM pg_temp.as_owner();

    -- Suspending a provider: off search and booking, upcoming card bookings refunded ---------
    v_upcoming := pg_temp.book(v_client, v_provider, v_service, v_price, 'card', 4);
    PERFORM pg_temp.as_admin(v_admin);
    v_count := public.admin_set_suspension(v_provider, true, 'Fraud investigation', true);
    PERFORM pg_temp.as_owner();
    IF v_count < 1 OR (SELECT status FROM public.bookings WHERE id = v_upcoming.id) <> 'cancelled'
       OR (SELECT amount_cents || '/' || reason FROM public.booking_refunds WHERE booking_id = v_upcoming.id)
          <> v_price || '/myglo_cancelled' THEN
        RAISE EXCEPTION 'FAIL: a suspended provider''s paid booking should be refunded in full';
    END IF;
    PERFORM pg_temp.expect_error(format('SELECT pg_temp.next_slot(%L, 30)', v_provider),
        'no free slot for the test provider', 'free times while suspended');
    PERFORM pg_temp.act_as(v_provider);
    PERFORM pg_temp.expect_error(format('UPDATE public.provider_booking_settings SET buffer_minutes = 5 WHERE provider_id = %L', v_provider),
        'account_suspended', 'a suspended provider changing settings');
    PERFORM pg_temp.expect_error(format('INSERT INTO public.posts (author_id, media_urls, caption) VALUES (%L, ARRAY[%L], %L)',
        v_provider, 'https://example.test/x.jpg', 'Still here'), 'account_suspended', 'a suspended provider posting');
    PERFORM pg_temp.as_admin(v_admin);
    v_json := public.admin_get_moderation_state(v_provider);
    IF v_json->>'suspended_reason' <> 'Fraud investigation' OR (v_json->>'open_reports_about')::integer < 1 THEN
        RAISE EXCEPTION 'FAIL: moderation state of a suspended provider %', v_json;
    END IF;
    PERFORM pg_temp.as_owner();
    IF NOT EXISTS (SELECT 1 FROM private.admin_audit_log WHERE admin_id = v_admin AND action = 'suspend_account'
                   AND target_id = v_provider::text AND (after->>'cancelled_bookings')::integer = v_count) THEN
        RAISE EXCEPTION 'FAIL: the suspension should be audited';
    END IF;

    -- App roles can't reach restrictions or the worker's check ----------------------------
    IF has_table_privilege('authenticated', 'private.user_restrictions', 'SELECT')
       OR has_table_privilege('authenticated', 'public.reports', 'INSERT')
       OR has_table_privilege('authenticated', 'public.reports', 'UPDATE')
       OR has_table_privilege('anon', 'public.reports', 'SELECT')
       OR has_function_privilege('authenticated', 'public.account_should_be_banned(uuid)', 'EXECUTE')
       OR has_function_privilege('authenticated', 'private.cancel_by_myglo(public.bookings, text)', 'EXECUTE')
       OR has_function_privilege('anon', 'public.submit_report(text, uuid, text, text)', 'EXECUTE') THEN
        RAISE EXCEPTION 'FAIL: moderation internals reachable by an app role';
    END IF;

    RAISE NOTICE 'moderation.sql: all checks passed';
END;
$test$;
