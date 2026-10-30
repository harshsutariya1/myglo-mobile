-- Provider payouts through Stripe Connect.
--
-- Each provider who wants card payments gets a Stripe connected account
-- (Accounts v2: Express Dashboard, recipient configuration with the
-- stripe_balance.stripe_transfers capability, Myglo responsible for fees and
-- losses). Myglo charges clients on its own account and transfers each
-- provider's share after the appointment ("separate charges and transfers").
--
-- The connect Edge Function creates the account and onboarding links; Stripe
-- webhooks (and a refresh when the provider returns to the app) report the
-- account's state, which apply_connect_account_state() stores here. A
-- provider can take card bookings once their account can receive transfers
-- (provider_booking_settings.card_ready).
--
-- Payment options: providers choose cash, card or both. Cash is always
-- accepted while card payments aren't ready, so turning cash off can never
-- leave a provider unbookable.

-- ---------------------------------------------------------------------------
-- 1. Connected accounts.
-- ---------------------------------------------------------------------------

CREATE TABLE private.provider_payout_accounts (
    provider_id          uuid        PRIMARY KEY REFERENCES public.profiles (id) ON DELETE CASCADE,
    stripe_account_id    text        NOT NULL UNIQUE,
    -- stripe_balance.stripe_transfers capability status.
    transfers_status     text        NOT NULL DEFAULT 'pending',
    payouts_enabled      boolean     NOT NULL DEFAULT false,
    -- Requirements the provider has to provide (currently or past due).
    requirements_due     text[]      NOT NULL DEFAULT '{}',
    -- Requirements Stripe is checking.
    requirements_pending text[]      NOT NULL DEFAULT '{}',
    requirements_deadline timestamptz,
    disabled_reason      text,
    -- First time the account could receive transfers: starts the fee-free period.
    first_enabled_at     timestamptz,
    closed_at            timestamptz,
    last_synced_at       timestamptz,
    created_at           timestamptz NOT NULL DEFAULT now(),
    updated_at           timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT provider_payout_accounts_status CHECK (
        transfers_status IN ('pending', 'active', 'restricted', 'rejected', 'unsupported')),
    CONSTRAINT provider_payout_accounts_stripe_id CHECK (stripe_account_id ~ '^acct_[A-Za-z0-9]+$')
);

COMMENT ON TABLE private.provider_payout_accounts IS
    'Each provider''s Stripe connected account and its state. Written by the connect function and Stripe webhooks only.';

-- ---------------------------------------------------------------------------
-- 2. Payment options on the provider's booking settings.
-- ---------------------------------------------------------------------------

ALTER TABLE public.provider_booking_settings
    ADD COLUMN accepts_cash boolean NOT NULL DEFAULT true,
    ADD COLUMN accepts_card boolean NOT NULL DEFAULT true,
    -- Maintained by the server: the provider's Stripe account can receive transfers.
    ADD COLUMN card_ready   boolean NOT NULL DEFAULT false,
    ADD CONSTRAINT pbs_accepts_a_payment CHECK (accepts_cash OR accepts_card);

COMMENT ON COLUMN public.provider_booking_settings.accepts_cash IS
    'Provider takes cash. Ignored (cash is accepted) while card payments are not ready.';
COMMENT ON COLUMN public.provider_booking_settings.accepts_card IS
    'Provider takes payment in the app. Only offered to clients when card_ready.';
COMMENT ON COLUMN public.provider_booking_settings.card_ready IS
    'Server-maintained: the provider''s Stripe account can receive transfers.';

GRANT UPDATE (accepts_cash, accepts_card) ON public.provider_booking_settings TO authenticated;

-- Which payment methods a provider takes right now.
CREATE FUNCTION private.provider_takes_cash(s public.provider_booking_settings)
RETURNS boolean LANGUAGE sql IMMUTABLE SET search_path TO ''
AS $function$ SELECT s.accepts_cash OR NOT (s.accepts_card AND s.card_ready) $function$;

CREATE FUNCTION private.provider_takes_card(s public.provider_booking_settings)
RETURNS boolean LANGUAGE sql IMMUTABLE SET search_path TO ''
AS $function$ SELECT s.accepts_card AND s.card_ready $function$;

-- ---------------------------------------------------------------------------
-- 3. Provider-facing status.
-- ---------------------------------------------------------------------------

-- The caller's payment set-up: where their Stripe account is, the Myglo fee
-- and when their fee-free period ends. Providers only.
CREATE FUNCTION public.get_my_payments_setup()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
    v_uid      uuid := auth.uid();
    v_account  private.provider_payout_accounts;
    v_settings private.platform_settings;
    v_status   text;
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'not_authenticated' USING ERRCODE = '42501';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = v_uid AND p.role = 'provider') THEN
        RAISE EXCEPTION 'providers_only' USING ERRCODE = '42501';
    END IF;

    SELECT * INTO v_account FROM private.provider_payout_accounts a WHERE a.provider_id = v_uid;
    SELECT * INTO v_settings FROM private.platform_settings s WHERE s.id;

    v_status := CASE
        WHEN v_account.provider_id IS NULL THEN 'not_started'
        WHEN v_account.closed_at IS NOT NULL THEN 'closed'
        WHEN v_account.transfers_status = 'active' AND cardinality(v_account.requirements_due) > 0 THEN 'action_needed'
        WHEN v_account.transfers_status = 'active' THEN 'active'
        WHEN v_account.transfers_status IN ('rejected', 'unsupported') THEN 'rejected'
        WHEN cardinality(v_account.requirements_due) > 0 THEN
            CASE WHEN v_account.first_enabled_at IS NULL THEN 'onboarding' ELSE 'restricted' END
        ELSE 'verifying'
    END;

    RETURN jsonb_build_object(
        'status', v_status,
        'payouts_enabled', coalesce(v_account.payouts_enabled, false),
        'requirements_due', coalesce(to_jsonb(v_account.requirements_due), '[]'::jsonb),
        'requirements_deadline', v_account.requirements_deadline,
        'first_enabled_at', v_account.first_enabled_at,
        'fee_percent', v_settings.platform_fee_percent,
        'fee_free_days', v_settings.fee_free_days,
        'fee_free_until', CASE WHEN v_account.first_enabled_at IS NOT NULL
                               THEN v_account.first_enabled_at + make_interval(days => v_settings.fee_free_days) END,
        'payout_schedule', 'weekly');
END;
$function$;

-- What the connect function needs to set up the caller's account: their
-- details for prefilling and any existing account. Providers only.
CREATE FUNCTION public.begin_payments_setup()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
    v_uid    uuid := auth.uid();
    v_result jsonb;
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'not_authenticated' USING ERRCODE = '42501';
    END IF;

    SELECT jsonb_build_object(
        'provider_id', p.id,
        'email', u.email,
        'business_name', coalesce(nullif(btrim(p.provider_name), ''),
                                  nullif(btrim(concat_ws(' ', p.first_name, p.last_name)), '')),
        'stripe_account_id', a.stripe_account_id,
        'details_ready', a.first_enabled_at IS NOT NULL OR a.transfers_status = 'active')
    INTO v_result
    FROM public.profiles p
    JOIN auth.users u ON u.id = p.id
    LEFT JOIN private.provider_payout_accounts a ON a.provider_id = p.id
    WHERE p.id = v_uid AND p.role = 'provider';

    IF v_result IS NULL THEN
        RAISE EXCEPTION 'providers_only' USING ERRCODE = '42501';
    END IF;
    RETURN v_result;
END;
$function$;

-- ---------------------------------------------------------------------------
-- 4. Service-role writers (connect function and webhooks).
-- ---------------------------------------------------------------------------

-- Records a newly created connected account for a provider. Idempotent.
CREATE FUNCTION public.save_connect_account(p_provider_id uuid, p_stripe_account_id text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
BEGIN
    INSERT INTO private.provider_payout_accounts (provider_id, stripe_account_id)
    VALUES (p_provider_id, p_stripe_account_id)
    ON CONFLICT (provider_id) DO NOTHING;

    IF NOT EXISTS (
        SELECT 1 FROM private.provider_payout_accounts
        WHERE provider_id = p_provider_id AND stripe_account_id = p_stripe_account_id) THEN
        RAISE EXCEPTION 'account_mismatch' USING ERRCODE = 'P0001';
    END IF;
END;
$function$;

-- Stores a connected account's latest state (from Stripe), keeps card_ready
-- in step and tells the provider when something changes for them. Returns
-- the provider id, or NULL for an account Myglo doesn't know.
CREATE FUNCTION public.apply_connect_account_state(
    p_stripe_account_id     text,
    p_transfers_status      text,
    p_payouts_enabled       boolean,
    p_requirements_due      text[],
    p_requirements_pending  text[],
    p_requirements_deadline timestamptz,
    p_disabled_reason       text,
    p_closed                boolean DEFAULT false)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
    v_before private.provider_payout_accounts;
    v_after  private.provider_payout_accounts;
    v_ready  boolean;
BEGIN
    SELECT * INTO v_before
    FROM private.provider_payout_accounts a
    WHERE a.stripe_account_id = p_stripe_account_id
    FOR UPDATE;
    IF NOT FOUND THEN
        RETURN NULL;
    END IF;

    UPDATE private.provider_payout_accounts a SET
        transfers_status = CASE WHEN p_transfers_status IN ('pending', 'active', 'restricted', 'rejected', 'unsupported')
                                THEN p_transfers_status ELSE 'pending' END,
        payouts_enabled = coalesce(p_payouts_enabled, false),
        requirements_due = coalesce(p_requirements_due, '{}'),
        requirements_pending = coalesce(p_requirements_pending, '{}'),
        requirements_deadline = p_requirements_deadline,
        disabled_reason = left(p_disabled_reason, 200),
        first_enabled_at = CASE WHEN a.first_enabled_at IS NULL AND p_transfers_status = 'active'
                                THEN now() ELSE a.first_enabled_at END,
        closed_at = CASE WHEN p_closed THEN coalesce(a.closed_at, now()) END,
        last_synced_at = now(),
        updated_at = now()
    WHERE a.provider_id = v_before.provider_id
    RETURNING * INTO v_after;

    v_ready := v_after.transfers_status = 'active' AND v_after.closed_at IS NULL;
    UPDATE public.provider_booking_settings s
    SET card_ready = v_ready
    WHERE s.provider_id = v_after.provider_id AND s.card_ready IS DISTINCT FROM v_ready;

    -- Tell the provider about changes that need them or that they've waited for.
    IF v_after.first_enabled_at IS NOT NULL AND v_before.first_enabled_at IS NULL THEN
        PERFORM private.notify(
            v_after.provider_id, NULL, 'payments_ready',
            'You can take card payments',
            'Clients can now pay you in the app. Payouts reach your bank weekly.',
            NULL, true, '{}'::jsonb);
    ELSIF cardinality(v_after.requirements_due) > 0
          AND (cardinality(v_before.requirements_due) = 0
               OR v_before.transfers_status IS DISTINCT FROM v_after.transfers_status)
          AND v_after.first_enabled_at IS NOT NULL THEN
        PERFORM private.notify(
            v_after.provider_id, NULL, 'payments_action_needed',
            'Stripe needs a few details',
            'Update your payout details to keep taking card payments and receiving payouts.',
            NULL, true, '{}'::jsonb);
    END IF;

    RETURN v_after.provider_id;
END;
$function$;

-- The connected account for a provider (service role).
CREATE FUNCTION public.connect_account_id(p_provider_id uuid)
RETURNS text
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO ''
AS $function$
    SELECT a.stripe_account_id FROM private.provider_payout_accounts a WHERE a.provider_id = p_provider_id;
$function$;

-- ---------------------------------------------------------------------------
-- 5. Notification kinds.
-- ---------------------------------------------------------------------------

ALTER TABLE public.notifications DROP CONSTRAINT notifications_kind;
ALTER TABLE public.notifications ADD CONSTRAINT notifications_kind CHECK (kind = ANY (ARRAY[
    'booking_request', 'booking_new', 'booking_requested', 'booking_confirmed', 'booking_declined',
    'booking_cancelled', 'booking_expired', 'booking_completed', 'booking_no_show', 'booking_reminder',
    'booking_request_reminder',
    'review_received', 'review_updated', 'review_thanks', 'review_reply',
    'payments_ready', 'payments_action_needed']));

-- ---------------------------------------------------------------------------
-- 6. Admin: payout state on the user detail.
-- ---------------------------------------------------------------------------

CREATE FUNCTION public.admin_get_payout_account(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO ''
AS $function$
BEGIN
    PERFORM private.require_admin();
    RETURN (
        SELECT jsonb_build_object(
            'stripe_account_id', a.stripe_account_id,
            'transfers_status', a.transfers_status,
            'payouts_enabled', a.payouts_enabled,
            'requirements_due', to_jsonb(a.requirements_due),
            'requirements_pending', to_jsonb(a.requirements_pending),
            'requirements_deadline', a.requirements_deadline,
            'disabled_reason', a.disabled_reason,
            'first_enabled_at', a.first_enabled_at,
            'closed_at', a.closed_at,
            'last_synced_at', a.last_synced_at,
            'accepts_cash', s.accepts_cash,
            'accepts_card', s.accepts_card,
            'card_ready', s.card_ready)
        FROM private.provider_payout_accounts a
        LEFT JOIN public.provider_booking_settings s ON s.provider_id = a.provider_id
        WHERE a.provider_id = p_user_id);
END;
$function$;

-- ---------------------------------------------------------------------------
-- 7. Privileges.
-- ---------------------------------------------------------------------------

REVOKE ALL ON private.provider_payout_accounts FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION private.provider_takes_cash(public.provider_booking_settings) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION private.provider_takes_card(public.provider_booking_settings) FROM PUBLIC, anon, authenticated;

REVOKE ALL ON FUNCTION public.get_my_payments_setup() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.begin_payments_setup() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.admin_get_payout_account(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_my_payments_setup() TO authenticated;
GRANT EXECUTE ON FUNCTION public.begin_payments_setup() TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_get_payout_account(uuid) TO authenticated;

REVOKE ALL ON FUNCTION public.save_connect_account(uuid, text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.apply_connect_account_state(text, text, boolean, text[], text[], timestamptz, text, boolean) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.connect_account_id(uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.save_connect_account(uuid, text) TO service_role;
GRANT EXECUTE ON FUNCTION public.apply_connect_account_state(text, text, boolean, text[], text[], timestamptz, text, boolean) TO service_role;
GRANT EXECUTE ON FUNCTION public.connect_account_id(uuid) TO service_role;
