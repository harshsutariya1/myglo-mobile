-- In-app account deletion (App Store guideline 5.1.1(v), Google Play's
-- account deletion policy).
--
-- Flow (delete-account Edge Function, see docs/account_deletion.md)
--   1. The app re-checks the password (signInWithPassword), so the session's
--      JWT carries a fresh `password` entry in its amr claim.
--   2. begin_account_deletion() runs as the user: requires that fresh
--      password and no blockers, and returns the user's payout account.
--   3. The function makes sure the provider's Stripe balance is empty.
--   4. delete_account() (service role) re-checks under lock, strips personal
--      details from the booking records that must be kept, queues the file
--      purge and the Stripe account closure, and deletes the Auth user. The
--      foreign keys do the rest: the profile and everything that only
--      belongs to it cascade; bookings, settlements, payouts and reports
--      keep their rows with the person's id set to null.
--
-- What is kept, and why
--   Bookings, payments, refunds, settlements, payouts and disputes stay as
--   Nexotec's financial records (tax law keeps them for five years). The
--   client's name, phone, notes and home address are removed from them. A
--   provider's business name stays on past bookings because it identifies
--   the supplier on the client's receipts; their studio address is removed.
--   private.account_deletions records that an account was deleted, with no
--   personal details.
--
-- Blockers (account_deletion_blockers): an admin account, a suspended
-- account, upcoming or unanswered bookings, and for providers, money still
-- on its way to them (settlements, uncompleted paid bookings, pending
-- refunds) or an open dispute. Each clears by itself or with support.

-- ---------------------------------------------------------------------------
-- 1. Deletion log.
-- ---------------------------------------------------------------------------

CREATE TABLE private.account_deletions (
    id                uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    -- No foreign key: the user no longer exists.
    user_id           uuid        NOT NULL,
    role              text,
    stripe_account_id text,
    deleted_at        timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE private.account_deletions IS
    'One row per deleted account: who (id only), their role, the closed Stripe account and when. No personal details.';

CREATE INDEX account_deletions_user_idx ON private.account_deletions (user_id);

ALTER TABLE private.account_deletions ENABLE ROW LEVEL SECURITY;

-- ---------------------------------------------------------------------------
-- 2. Checks.
-- ---------------------------------------------------------------------------

-- When the caller's session last checked the password, from the JWT's amr
-- claim (signInWithPassword adds a fresh entry; refreshes keep it).
CREATE FUNCTION private.jwt_password_verified_at()
RETURNS timestamptz
LANGUAGE sql
STABLE
SET search_path TO ''
AS $function$
    SELECT to_timestamp(max((m->>'timestamp')::double precision))
    FROM jsonb_array_elements(
             CASE WHEN jsonb_typeof(auth.jwt()->'amr') = 'array' THEN auth.jwt()->'amr' ELSE '[]'::jsonb END) m
    WHERE m->>'method' = 'password';
$function$;

-- Deleting needs the password from the last 10 minutes. A constant, not a
-- setting.
CREATE FUNCTION private.account_deletion_reauth_seconds() RETURNS integer LANGUAGE sql IMMUTABLE SET search_path TO '' AS 'SELECT 600';

-- What stops this account being deleted right now, as
-- [{ "code": ..., "count": n }] in the order the app shows them. Empty when
-- it can go.
CREATE FUNCTION private.account_deletion_blockers(p_user_id uuid)
RETURNS jsonb
LANGUAGE sql
STABLE
SET search_path TO ''
AS $function$
    SELECT coalesce(jsonb_agg(jsonb_build_object('code', x.code, 'count', x.n) ORDER BY x.ord), '[]'::jsonb)
    FROM (
        SELECT 1 AS ord, 'admin_account' AS code, 1::bigint AS n
        WHERE private.is_admin(p_user_id)

        UNION ALL
        SELECT 2, 'account_suspended', 1
        WHERE private.is_suspended(p_user_id)

        -- Either side: checkouts in progress, unanswered requests, and
        -- confirmed appointments that haven't ended.
        UNION ALL
        SELECT 3, 'upcoming_bookings', count(*)
        FROM public.bookings b
        WHERE (b.client_id = p_user_id OR b.provider_id = p_user_id)
          AND (b.status IN ('awaiting_payment', 'pending')
               OR (b.status = 'confirmed' AND b.ends_at > now()))
        HAVING count(*) > 0

        -- Provider: money still moving to or from their payout account.
        UNION ALL
        SELECT 4, 'payouts_pending', count(*)
        FROM public.bookings b
        WHERE b.provider_id = p_user_id
          AND (EXISTS (SELECT 1 FROM public.booking_settlements s
                       WHERE s.booking_id = b.id
                         AND s.status IN ('scheduled', 'held', 'processing', 'failed'))
               -- Paid by card, ended, not completed yet (auto-completes).
               OR (b.status = 'confirmed' AND b.ends_at <= now()
                   AND b.payment_status IN ('authorized', 'paid', 'partially_refunded'))
               OR EXISTS (SELECT 1 FROM public.booking_refunds r
                          WHERE r.booking_id = b.id AND r.status = 'pending'))
        HAVING count(*) > 0

        UNION ALL
        SELECT 5, 'open_disputes', count(*)
        FROM public.payment_disputes d
        JOIN public.bookings b ON b.id = d.booking_id
        WHERE b.provider_id = p_user_id AND d.closed_at IS NULL
        HAVING count(*) > 0
    ) x;
$function$;

-- ---------------------------------------------------------------------------
-- 3. App API.
-- ---------------------------------------------------------------------------

-- What the delete-account screen shows: the caller's role, anything that
-- blocks deletion, and whether a Stripe payout account will be closed.
CREATE FUNCTION public.get_my_account_deletion_status()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
    v_uid uuid := auth.uid();
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'not_authenticated' USING ERRCODE = '42501';
    END IF;

    RETURN jsonb_build_object(
        'role', (SELECT p.role FROM public.profiles p WHERE p.id = v_uid),
        'blockers', private.account_deletion_blockers(v_uid),
        'has_payout_account', EXISTS (
            SELECT 1 FROM private.provider_payout_accounts a
            WHERE a.provider_id = v_uid AND a.closed_at IS NULL));
END;
$function$;

COMMENT ON FUNCTION public.get_my_account_deletion_status() IS
    'The signed-in user''s account deletion status: role, blockers ([{code, count}]) and has_payout_account.';

-- Step 2 of the flow, as the user (called by the delete-account function
-- with the user's own token). Raises reauth_required without a recent
-- password check, and account_deletion_blocked (DETAIL: the blockers as
-- JSON) if anything is in the way. Returns { user_id, email,
-- stripe_account_id }.
CREATE FUNCTION public.begin_account_deletion()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
    v_uid      uuid := auth.uid();
    v_checked  timestamptz;
    v_blockers jsonb;
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'not_authenticated' USING ERRCODE = '42501';
    END IF;

    v_checked := private.jwt_password_verified_at();
    IF v_checked IS NULL
       OR v_checked < now() - make_interval(secs => private.account_deletion_reauth_seconds()) THEN
        RAISE EXCEPTION 'reauth_required' USING ERRCODE = '42501';
    END IF;

    v_blockers := private.account_deletion_blockers(v_uid);
    IF jsonb_array_length(v_blockers) > 0 THEN
        RAISE EXCEPTION 'account_deletion_blocked' USING ERRCODE = 'P0001', DETAIL = v_blockers::text;
    END IF;

    RETURN jsonb_build_object(
        'user_id', v_uid,
        'email', (SELECT u.email FROM auth.users u WHERE u.id = v_uid),
        'stripe_account_id', (
            SELECT a.stripe_account_id FROM private.provider_payout_accounts a
            WHERE a.provider_id = v_uid AND a.closed_at IS NULL));
END;
$function$;

-- ---------------------------------------------------------------------------
-- 4. Deletion (service role only).
-- ---------------------------------------------------------------------------

-- Step 4 of the flow. One transaction: either the account is gone, with its
-- clean-up jobs queued, or nothing changed.
CREATE FUNCTION public.delete_account(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
    v_email    text;
    v_role     text;
    v_stripe   text;
    v_blockers jsonb;
BEGIN
    SELECT u.email INTO v_email FROM auth.users u WHERE u.id = p_user_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'account_not_found' USING ERRCODE = 'P0002';
    END IF;

    -- Locking the profile also holds back a booking being made with this
    -- user (its foreign key check waits on the lock, then fails once the
    -- profile is gone), so the check below can't miss one.
    SELECT p.role INTO v_role FROM public.profiles p WHERE p.id = p_user_id FOR UPDATE;

    v_blockers := private.account_deletion_blockers(p_user_id);
    IF jsonb_array_length(v_blockers) > 0 THEN
        RAISE EXCEPTION 'account_deletion_blocked' USING ERRCODE = 'P0001', DETAIL = v_blockers::text;
    END IF;

    SELECT a.stripe_account_id INTO v_stripe
    FROM private.provider_payout_accounts a
    WHERE a.provider_id = p_user_id AND a.closed_at IS NULL;

    -- Kept booking records lose the client's personal details...
    UPDATE public.bookings b
    SET client_name = 'Deleted account',
        client_phone = '',
        client_notes = NULL,
        access_notes = NULL,
        address_text = CASE WHEN b.location_type = 'client' THEN '' ELSE b.address_text END,
        address = CASE WHEN b.location_type = 'client' THEN NULL ELSE b.address END,
        location = CASE WHEN b.location_type = 'client' THEN NULL ELSE b.location END,
        distance_km = CASE WHEN b.location_type = 'client' THEN NULL ELSE b.distance_km END,
        updated_at = now()
    WHERE b.client_id = p_user_id;

    -- ...and the provider's studio address (the business name stays on the
    -- client's receipts).
    UPDATE public.bookings b
    SET address_text = '',
        address = NULL,
        location = NULL,
        updated_at = now()
    WHERE b.provider_id = p_user_id AND b.location_type = 'studio';

    -- Other people's notifications that name this user.
    DELETE FROM public.notifications n WHERE n.actor_id = p_user_id;

    -- Reviews go before the profile so the provider's rating totals are
    -- updated row by row (their photo posts cascade with them).
    DELETE FROM public.reviews r WHERE r.client_id = p_user_id OR r.provider_id = p_user_id;

    -- A pre-launch waitlist sign-up with the same email.
    IF v_email IS NOT NULL THEN
        DELETE FROM public.waitlist w WHERE lower(w.email) = lower(v_email);
    END IF;

    INSERT INTO private.account_deletions (user_id, role, stripe_account_id)
    VALUES (p_user_id, v_role, v_stripe);

    -- Files can only be removed through the Storage API, and the Stripe
    -- account through Stripe: both run (and retry) in the jobs worker.
    PERFORM private.enqueue_job(
        'purge_user_storage', 'purge-storage:' || p_user_id,
        jsonb_build_object('user_id', p_user_id));
    IF v_stripe IS NOT NULL THEN
        PERFORM private.enqueue_job(
            'close_connect_account', 'close-account:' || v_stripe,
            jsonb_build_object('stripe_account_id', v_stripe));
    END IF;

    -- Cascades to sessions, identities and the profile, and from the profile
    -- to everything that belongs only to it.
    DELETE FROM auth.users u WHERE u.id = p_user_id;

    RETURN jsonb_build_object('deleted', true, 'role', v_role, 'stripe_account_closing', v_stripe IS NOT NULL);
END;
$function$;

COMMENT ON FUNCTION public.delete_account(uuid) IS
    'Deletes an account after begin_account_deletion passed (service role only, from the delete-account function).';

-- The deleted user's files, for the purge_user_storage job. Refuses while
-- the account still exists, so a mistaken job can't empty a live account.
CREATE FUNCTION public.list_deleted_account_files(p_user_id uuid, p_limit integer DEFAULT 1000)
RETURNS TABLE (bucket_id text, name text)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO ''
AS $function$
BEGIN
    IF EXISTS (SELECT 1 FROM auth.users u WHERE u.id = p_user_id) THEN
        RAISE EXCEPTION 'account_still_exists' USING ERRCODE = 'P0001';
    END IF;

    RETURN QUERY
    SELECT o.bucket_id, o.name
    FROM storage.objects o
    WHERE (o.bucket_id IN ('post-media', 'service-images', 'cover-photos')
           AND o.name LIKE p_user_id::text || '/%')
       OR (o.bucket_id = 'profile-pics' AND o.name LIKE p_user_id::text || '.%')
       OR o.owner_id = p_user_id::text
    ORDER BY o.bucket_id, o.name
    LIMIT least(greatest(coalesce(p_limit, 1000), 1), 1000);
END;
$function$;

-- ---------------------------------------------------------------------------
-- 5. Job kinds.
-- ---------------------------------------------------------------------------

ALTER TABLE private.jobs DROP CONSTRAINT jobs_kind;
ALTER TABLE private.jobs ADD CONSTRAINT jobs_kind CHECK (kind IN (
    'noop', 'admin_alert', 'cancel_payment_intent', 'capture_payment', 'refund_payment',
    'transfer', 'reverse_transfer', 'auth_ban', 'purge_user_storage', 'close_connect_account'));

-- ---------------------------------------------------------------------------
-- 6. Privileges.
-- ---------------------------------------------------------------------------

REVOKE ALL ON private.account_deletions FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION private.jwt_password_verified_at() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION private.account_deletion_reauth_seconds() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION private.account_deletion_blockers(uuid) FROM PUBLIC, anon, authenticated;

REVOKE ALL ON FUNCTION public.get_my_account_deletion_status() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_my_account_deletion_status() TO authenticated;
REVOKE ALL ON FUNCTION public.begin_account_deletion() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.begin_account_deletion() TO authenticated;

REVOKE ALL ON FUNCTION public.delete_account(uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.delete_account(uuid) TO service_role;
REVOKE ALL ON FUNCTION public.list_deleted_account_files(uuid, integer) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.list_deleted_account_files(uuid, integer) TO service_role;
