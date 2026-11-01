-- Payment lifecycle for bookings paid in the app: refunds, the provider's
-- share (settlements and Stripe transfers), disputes, payouts, and the
-- admin and provider screens that follow the money.
--
-- Who gets what, decided here and only here:
--   cancelled by the client in time, by the provider, or by Myglo
--                       -> full refund, nothing for the provider
--   cancelled late by the client, or a no-show
--                       -> the provider keeps their late fee (the snapshot %),
--                          the rest is refunded
--   completed (by the provider, or automatically auto_complete_after_hours
--   after the end)      -> the provider keeps the payment
-- Myglo's commission is the booking's platform_fee_percent snapshot of
-- whatever the provider keeps. Myglo absorbs Stripe's own fees (and dispute
-- fees) at launch.
--
-- The provider's share is a settlement. It's transferred to their Stripe
-- account (from the client's charge: source_transaction) once due, unless
-- it's held: an open dispute, their payout account not working, or an admin.
-- Refunds after a transfer can take the provider's share back (a transfer
-- reversal). Every Stripe call is a background job with an idempotency key;
-- the webhook reports the result, applied by idempotent functions.

-- ---------------------------------------------------------------------------
-- 1. Refunds.
-- ---------------------------------------------------------------------------

CREATE TABLE public.booking_refunds (
    id               uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    booking_id       uuid        NOT NULL REFERENCES public.bookings (id) ON DELETE CASCADE,
    amount_cents     integer     NOT NULL,
    reason           text        NOT NULL,
    initiated_by     text        NOT NULL,
    admin_id         uuid,
    note             text,
    status           text        NOT NULL DEFAULT 'pending',
    stripe_refund_id text        UNIQUE,
    failure_reason   text,
    created_at       timestamptz NOT NULL DEFAULT now(),
    updated_at       timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT booking_refunds_amount CHECK (amount_cents > 0),
    CONSTRAINT booking_refunds_reason CHECK (reason IN (
        'client_cancelled', 'late_cancellation', 'provider_cancelled', 'no_show', 'myglo_cancelled', 'admin')),
    CONSTRAINT booking_refunds_initiated_by CHECK (initiated_by IN ('client', 'provider', 'system', 'admin')),
    CONSTRAINT booking_refunds_status CHECK (status IN ('pending', 'succeeded', 'failed', 'canceled')),
    CONSTRAINT booking_refunds_text CHECK (char_length(note) <= 500 AND char_length(failure_reason) <= 200)
);

CREATE INDEX booking_refunds_booking_idx ON public.booking_refunds (booking_id, created_at);

COMMENT ON TABLE public.booking_refunds IS
    'Refunds of in-app payments. Created by booking and admin functions; carried out by the jobs worker.';

ALTER TABLE public.booking_refunds ENABLE ROW LEVEL SECURITY;
GRANT SELECT ON public.booking_refunds TO authenticated;
-- Runs under the bookings policy: only bookings the caller can see.
CREATE POLICY "Parties can view booking refunds" ON public.booking_refunds
    FOR SELECT TO authenticated
    USING (EXISTS (SELECT 1 FROM public.bookings b WHERE b.id = booking_id));

-- ---------------------------------------------------------------------------
-- 2. Settlements: the provider's share of a payment.
-- ---------------------------------------------------------------------------

CREATE TABLE public.booking_settlements (
    booking_id         uuid        PRIMARY KEY REFERENCES public.bookings (id) ON DELETE CASCADE,
    provider_id        uuid        REFERENCES public.profiles (id) ON DELETE SET NULL,
    -- What the provider earns from the client's payment.
    kept_cents         integer     NOT NULL,
    -- Myglo's commission on it.
    platform_fee_cents integer     NOT NULL,
    -- What's transferred to the provider: kept - commission.
    transfer_cents     integer     NOT NULL,
    status             text        NOT NULL DEFAULT 'scheduled',
    hold_reason        text,
    hold_note          text,
    -- When the transfer is due.
    available_at       timestamptz NOT NULL DEFAULT now(),
    -- Bumped whenever a new transfer is needed (e.g. a won dispute after a
    -- reversal), so each one has its own idempotency key.
    transfer_attempt   smallint    NOT NULL DEFAULT 1,
    stripe_transfer_id text        UNIQUE,
    transferred_at     timestamptz,
    reversed_cents     integer     NOT NULL DEFAULT 0,
    failure_reason     text,
    created_at         timestamptz NOT NULL DEFAULT now(),
    updated_at         timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT booking_settlements_status CHECK (status IN (
        'scheduled', 'held', 'processing', 'transferred', 'reversed', 'failed', 'not_applicable')),
    CONSTRAINT booking_settlements_hold CHECK (
        (status = 'held') = (hold_reason IS NOT NULL)
        AND hold_reason IN ('payout_account', 'dispute', 'report', 'admin')),
    CONSTRAINT booking_settlements_amounts CHECK (
        kept_cents >= 0 AND platform_fee_cents >= 0 AND transfer_cents >= 0
        AND kept_cents = platform_fee_cents + transfer_cents
        AND reversed_cents BETWEEN 0 AND transfer_cents)
);

CREATE INDEX booking_settlements_due_idx ON public.booking_settlements (available_at) WHERE status = 'scheduled';
CREATE INDEX booking_settlements_provider_idx ON public.booking_settlements (provider_id, created_at DESC);

COMMENT ON TABLE public.booking_settlements IS
    'The provider''s share of each in-app payment and its transfer. Written by booking, payment and admin functions only.';

ALTER TABLE public.booking_settlements ENABLE ROW LEVEL SECURITY;
GRANT SELECT ON public.booking_settlements TO authenticated;
CREATE POLICY "Providers can view own settlements" ON public.booking_settlements
    FOR SELECT TO authenticated
    USING ((SELECT auth.uid()) = provider_id);

-- ---------------------------------------------------------------------------
-- 3. Disputes and payouts.
-- ---------------------------------------------------------------------------

CREATE TABLE public.payment_disputes (
    id              text        PRIMARY KEY,
    booking_id      uuid        REFERENCES public.bookings (id) ON DELETE SET NULL,
    amount_cents    integer     NOT NULL,
    reason          text,
    status          text        NOT NULL,
    evidence_due_by timestamptz,
    closed_at       timestamptz,
    created_at      timestamptz NOT NULL DEFAULT now(),
    updated_at      timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT payment_disputes_id CHECK (id ~ '^(dp|du)_[A-Za-z0-9]+$'),
    CONSTRAINT payment_disputes_status CHECK (char_length(status) <= 40 AND char_length(reason) <= 60)
);

CREATE INDEX payment_disputes_booking_idx ON public.payment_disputes (booking_id);

ALTER TABLE public.payment_disputes ENABLE ROW LEVEL SECURITY;
GRANT SELECT ON public.payment_disputes TO authenticated;
-- Providers see disputes on their bookings (clients raised them with their bank).
CREATE POLICY "Providers can view disputes on their bookings" ON public.payment_disputes
    FOR SELECT TO authenticated
    USING (EXISTS (SELECT 1 FROM public.bookings b WHERE b.id = booking_id AND b.provider_id = (SELECT auth.uid())));

CREATE TABLE public.provider_payouts (
    id              text        PRIMARY KEY,
    provider_id     uuid        REFERENCES public.profiles (id) ON DELETE SET NULL,
    amount_cents    integer     NOT NULL,
    currency        text        NOT NULL DEFAULT 'aud',
    status          text        NOT NULL,
    arrival_date    date,
    failure_code    text,
    failure_message text,
    created_at      timestamptz NOT NULL DEFAULT now(),
    updated_at      timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT provider_payouts_id CHECK (id ~ '^po_[A-Za-z0-9]+$'),
    CONSTRAINT provider_payouts_status CHECK (status IN ('pending', 'in_transit', 'paid', 'failed', 'canceled')),
    CONSTRAINT provider_payouts_text CHECK (char_length(failure_code) <= 80 AND char_length(failure_message) <= 300)
);

CREATE INDEX provider_payouts_provider_idx ON public.provider_payouts (provider_id, created_at DESC);

ALTER TABLE public.provider_payouts ENABLE ROW LEVEL SECURITY;
GRANT SELECT ON public.provider_payouts TO authenticated;
CREATE POLICY "Providers can view own payouts" ON public.provider_payouts
    FOR SELECT TO authenticated
    USING ((SELECT auth.uid()) = provider_id);

-- ---------------------------------------------------------------------------
-- 4. Constraints and kinds that grow.
-- ---------------------------------------------------------------------------

ALTER TABLE public.booking_events DROP CONSTRAINT booking_events_actor_role;
ALTER TABLE public.booking_events ADD CONSTRAINT booking_events_actor_role
    CHECK (actor_role IN ('client', 'provider', 'system', 'admin'));

ALTER TABLE private.jobs DROP CONSTRAINT jobs_kind;
ALTER TABLE private.jobs ADD CONSTRAINT jobs_kind CHECK (kind IN (
    'noop', 'admin_alert', 'cancel_payment_intent', 'capture_payment', 'refund_payment',
    'transfer', 'reverse_transfer'));

ALTER TABLE public.notifications DROP CONSTRAINT notifications_kind;
ALTER TABLE public.notifications ADD CONSTRAINT notifications_kind CHECK (kind = ANY (ARRAY[
    'booking_request', 'booking_new', 'booking_requested', 'booking_confirmed', 'booking_declined',
    'booking_cancelled', 'booking_expired', 'booking_completed', 'booking_no_show', 'booking_reminder',
    'booking_request_reminder',
    'review_received', 'review_updated', 'review_thanks', 'review_reply',
    'payments_ready', 'payments_action_needed',
    'payment_refunded', 'payout_paid', 'payout_failed', 'booking_disputed']));

-- ---------------------------------------------------------------------------
-- 5. Money helpers.
-- ---------------------------------------------------------------------------

-- How much of the booking's payment can still be refunded: received, less
-- what was refunded or is being refunded.
CREATE FUNCTION private.refundable_cents(p_booking_id uuid)
RETURNS integer
LANGUAGE sql
STABLE
SET search_path TO ''
AS $function$
    SELECT greatest(0,
        coalesce((SELECT CASE WHEN p.status IN ('paid', 'partially_refunded', 'refunded') THEN p.amount_cents ELSE 0 END
                  FROM public.booking_payments p WHERE p.booking_id = p_booking_id
                  ORDER BY p.created_at DESC LIMIT 1), 0)
        - coalesce((SELECT sum(r.amount_cents) FROM public.booking_refunds r
                    WHERE r.booking_id = p_booking_id AND r.status IN ('pending', 'succeeded')), 0))::integer;
$function$;

-- Queues a refund of p_amount_cents (capped at what's refundable). Returns
-- the refund id, or NULL when there's nothing to refund.
CREATE FUNCTION private.queue_refund(
    p_booking      public.bookings,
    p_amount_cents integer,
    p_reason       text,
    p_initiated_by text,
    p_admin_id     uuid DEFAULT NULL,
    p_note         text DEFAULT NULL)
RETURNS uuid
LANGUAGE plpgsql
SET search_path TO ''
AS $function$
DECLARE
    v_amount  integer := least(coalesce(p_amount_cents, 0), private.refundable_cents(p_booking.id));
    v_payment public.booking_payments%ROWTYPE := private.booking_payment(p_booking.id);
    v_id      uuid;
BEGIN
    IF v_amount <= 0 OR v_payment.stripe_payment_intent_id IS NULL THEN
        RETURN NULL;
    END IF;
    INSERT INTO public.booking_refunds (booking_id, amount_cents, reason, initiated_by, admin_id, note)
    VALUES (p_booking.id, v_amount, p_reason, p_initiated_by, p_admin_id, left(p_note, 500))
    RETURNING id INTO v_id;
    PERFORM private.enqueue_job('refund_payment', 'refund:' || v_id,
        jsonb_build_object('booking_id', p_booking.id, 'refund_id', v_id,
                           'payment_intent_id', v_payment.stripe_payment_intent_id,
                           'amount_cents', v_amount, 'reason', p_reason),
        p_booking.id);
    RETURN v_id;
END;
$function$;

-- Records (or updates, before it's transferred) what the provider keeps from
-- a booking, and moves it along if it's due.
CREATE FUNCTION private.schedule_settlement(p_booking public.bookings, p_kept_cents integer, p_available_at timestamptz DEFAULT now())
RETURNS void
LANGUAGE plpgsql
SET search_path TO ''
AS $function$
DECLARE
    v_kept integer := greatest(coalesce(p_kept_cents, 0), 0);
    v_fee  integer := round(greatest(coalesce(p_kept_cents, 0), 0) * p_booking.platform_fee_percent / 100.0)::integer;
BEGIN
    IF p_booking.payment_method = 'cash' THEN
        RETURN;
    END IF;

    -- Keep the booking's own commission figure in step with what's earned.
    UPDATE public.bookings SET platform_fee_cents = v_fee, updated_at = now()
    WHERE id = p_booking.id AND platform_fee_cents IS DISTINCT FROM v_fee;

    -- Nothing earned and nothing recorded yet: no settlement at all.
    IF v_kept = 0 AND NOT EXISTS (SELECT 1 FROM public.booking_settlements WHERE booking_id = p_booking.id) THEN
        RETURN;
    END IF;

    INSERT INTO public.booking_settlements AS s (
        booking_id, provider_id, kept_cents, platform_fee_cents, transfer_cents, status, available_at)
    VALUES (p_booking.id, p_booking.provider_id, v_kept, v_fee, v_kept - v_fee,
            CASE WHEN v_kept - v_fee > 0 THEN 'scheduled' ELSE 'not_applicable' END, coalesce(p_available_at, now()))
    ON CONFLICT (booking_id) DO UPDATE SET
        kept_cents = EXCLUDED.kept_cents,
        platform_fee_cents = EXCLUDED.platform_fee_cents,
        transfer_cents = EXCLUDED.transfer_cents,
        status = CASE WHEN s.status = 'held' AND EXCLUDED.transfer_cents > 0 THEN 'held' ELSE EXCLUDED.status END,
        hold_reason = CASE WHEN s.status = 'held' AND EXCLUDED.transfer_cents > 0 THEN s.hold_reason END,
        hold_note = CASE WHEN s.status = 'held' AND EXCLUDED.transfer_cents > 0 THEN s.hold_note END,
        available_at = EXCLUDED.available_at,
        updated_at = now()
    WHERE s.status IN ('scheduled', 'held', 'not_applicable', 'failed');

    PERFORM private.process_settlement(p_booking.id);
END;
$function$;

-- Moves a settlement on: holds it (open dispute, payout account not
-- working) or queues its transfer once due and the payment is captured.
CREATE FUNCTION private.process_settlement(p_booking_id uuid)
RETURNS void
LANGUAGE plpgsql
SET search_path TO ''
AS $function$
DECLARE
    v_settlement public.booking_settlements%ROWTYPE;
    v_payment    public.booking_payments%ROWTYPE;
    v_account    private.provider_payout_accounts%ROWTYPE;
    v_hold       text;
BEGIN
    SELECT * INTO v_settlement FROM public.booking_settlements WHERE booking_id = p_booking_id FOR UPDATE;
    IF NOT FOUND OR v_settlement.status NOT IN ('scheduled', 'held') THEN
        RETURN;
    END IF;
    -- Admin holds and report holds are lifted by a person.
    IF v_settlement.status = 'held' AND v_settlement.hold_reason IN ('admin', 'report') THEN
        RETURN;
    END IF;
    IF v_settlement.available_at > now() THEN
        RETURN;
    END IF;

    v_payment := private.booking_payment(p_booking_id);
    SELECT * INTO v_account FROM private.provider_payout_accounts WHERE provider_id = v_settlement.provider_id;

    v_hold := CASE
        WHEN EXISTS (SELECT 1 FROM public.payment_disputes d
                     WHERE d.booking_id = p_booking_id AND d.closed_at IS NULL) THEN 'dispute'
        WHEN v_account.provider_id IS NULL OR v_account.transfers_status <> 'active'
             OR v_account.closed_at IS NOT NULL THEN 'payout_account'
    END;

    IF v_hold IS NOT NULL THEN
        UPDATE public.booking_settlements
        SET status = 'held', hold_reason = v_hold, updated_at = now()
        WHERE booking_id = p_booking_id AND (status, hold_reason) IS DISTINCT FROM ('held', v_hold);
        RETURN;
    END IF;

    -- Captured money only (a hold being captured comes back here when it is).
    IF v_payment.status NOT IN ('paid', 'partially_refunded') OR v_payment.stripe_charge_id IS NULL THEN
        IF v_settlement.status = 'held' THEN
            UPDATE public.booking_settlements SET status = 'scheduled', hold_reason = NULL, updated_at = now()
            WHERE booking_id = p_booking_id;
        END IF;
        RETURN;
    END IF;

    UPDATE public.booking_settlements
    SET status = 'processing', hold_reason = NULL, hold_note = NULL, failure_reason = NULL, updated_at = now()
    WHERE booking_id = p_booking_id;
    PERFORM private.enqueue_job('transfer', 'transfer:' || p_booking_id || ':' || v_settlement.transfer_attempt,
        jsonb_build_object(
            'booking_id', p_booking_id,
            'amount_cents', v_settlement.transfer_cents,
            'destination', v_account.stripe_account_id,
            'source_transaction', v_payment.stripe_charge_id),
        p_booking_id);
END;
$function$;

-- Takes back up to p_amount_cents of a transferred settlement (a refund or
-- dispute after the provider was paid).
CREATE FUNCTION private.reverse_settlement(p_booking_id uuid, p_amount_cents integer, p_reason text)
RETURNS integer
LANGUAGE plpgsql
SET search_path TO ''
AS $function$
DECLARE
    v_settlement public.booking_settlements%ROWTYPE;
    v_amount     integer;
BEGIN
    SELECT * INTO v_settlement FROM public.booking_settlements WHERE booking_id = p_booking_id FOR UPDATE;
    IF NOT FOUND OR v_settlement.status <> 'transferred' OR v_settlement.stripe_transfer_id IS NULL THEN
        RETURN 0;
    END IF;
    v_amount := least(greatest(coalesce(p_amount_cents, 0), 0), v_settlement.transfer_cents - v_settlement.reversed_cents);
    IF v_amount <= 0 THEN
        RETURN 0;
    END IF;
    PERFORM private.enqueue_job('reverse_transfer',
        'reversal:' || p_booking_id || ':' || v_settlement.transfer_attempt || ':' || (v_settlement.reversed_cents + v_amount),
        jsonb_build_object('booking_id', p_booking_id, 'transfer_id', v_settlement.stripe_transfer_id,
                           'amount_cents', v_amount, 'reason', p_reason),
        p_booking_id);
    RETURN v_amount;
END;
$function$;

-- ---------------------------------------------------------------------------
-- 6. Booking lifecycle with money.
-- ---------------------------------------------------------------------------

-- Cancels an upcoming booking. Clients cancel for free until the provider's
-- window; later it's a late cancellation (with the provider's fee, if any),
-- which must be acknowledged with p_accept_late_cancellation. Providers must
-- give a reason. In-app payments: held cards are released; paid bookings
-- are refunded in full, less a late fee the provider keeps.
CREATE OR REPLACE FUNCTION public.cancel_booking(
    p_booking_id               uuid,
    p_reason                   text    DEFAULT NULL,
    p_accept_late_cancellation boolean DEFAULT false)
RETURNS public.bookings
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
    v_uid     uuid := auth.uid();
    v_booking public.bookings%ROWTYPE;
    v_role    text;
    v_from    text;
    v_reason  text := nullif(btrim(p_reason), '');
    v_late    boolean := false;
    v_fee     integer := 0;
    v_refund  integer := 0;
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'not_authenticated' USING ERRCODE = '42501';
    END IF;
    IF char_length(v_reason) > 300 THEN
        RAISE EXCEPTION 'invalid_request' USING ERRCODE = '22023';
    END IF;

    SELECT * INTO v_booking FROM public.bookings WHERE id = p_booking_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'booking_not_found' USING ERRCODE = 'P0002';
    END IF;
    v_role := CASE
        WHEN v_booking.client_id = v_uid THEN 'client'
        WHEN v_booking.provider_id = v_uid AND v_booking.status NOT IN ('awaiting_payment', 'checkout_expired') THEN 'provider'
    END;
    IF v_role IS NULL THEN
        RAISE EXCEPTION 'booking_not_found' USING ERRCODE = 'P0002';
    END IF;
    IF v_booking.status NOT IN ('pending', 'confirmed') OR v_booking.starts_at <= now() THEN
        RAISE EXCEPTION 'booking_not_cancellable' USING ERRCODE = 'P0001';
    END IF;
    IF v_role = 'provider' AND v_reason IS NULL THEN
        RAISE EXCEPTION 'reason_required' USING ERRCODE = '22023';
    END IF;

    IF v_role = 'client' AND v_booking.status = 'confirmed'
       AND now() >= v_booking.starts_at - make_interval(hours => v_booking.cancellation_window_hours) THEN
        v_late := true;
        v_fee := round(v_booking.total_cents * v_booking.cancellation_fee_percent / 100.0)::integer;
        IF NOT coalesce(p_accept_late_cancellation, false) THEN
            RAISE EXCEPTION 'late_cancellation_unconfirmed' USING ERRCODE = 'P0001',
                DETAIL = jsonb_build_object(
                    'fee_cents', v_fee,
                    'fee_percent', v_booking.cancellation_fee_percent,
                    'window_hours', v_booking.cancellation_window_hours,
                    'refund_cents', CASE WHEN v_booking.payment_status = 'paid'
                                         THEN greatest(private.refundable_cents(v_booking.id) - v_fee, 0) ELSE 0 END)::text;
        END IF;
    END IF;

    v_from := v_booking.status;
    UPDATE public.bookings
    SET status = 'cancelled',
        cancelled_by = v_role,
        cancelled_at = now(),
        cancellation_reason = v_reason,
        late_cancellation = v_late,
        cancellation_fee_cents = v_fee,
        payment_status = CASE WHEN payment_status IN ('pending', 'requires_payment', 'authorized') THEN 'void'
                              ELSE payment_status END,
        updated_at = now()
    WHERE id = p_booking_id
    RETURNING * INTO v_booking;

    UPDATE public.booking_payments SET status = 'void', updated_at = now()
    WHERE booking_id = p_booking_id AND status = 'pending';
    PERFORM private.release_card_hold(v_booking);

    -- Paid in the app: refund what the provider doesn't keep.
    IF v_booking.payment_method <> 'cash' AND v_booking.payment_status IN ('paid', 'partially_refunded') THEN
        v_refund := greatest(private.refundable_cents(v_booking.id) - v_fee, 0);
        PERFORM private.queue_refund(v_booking, v_refund,
            CASE WHEN v_role = 'provider' THEN 'provider_cancelled' WHEN v_late THEN 'late_cancellation' ELSE 'client_cancelled' END,
            v_role);
        PERFORM private.schedule_settlement(v_booking, CASE WHEN v_late THEN v_fee ELSE 0 END);
    END IF;

    PERFORM private.on_booking_event(v_booking, 'cancelled', v_role, v_from,
        jsonb_build_object('reason', v_reason, 'late', v_late, 'fee_cents', v_fee, 'refund_cents', v_refund));

    RETURN v_booking;
END;
$function$;

-- Provider marks an appointment that has started as done. Cash can be
-- recorded as collected; a booking paid in the app becomes the provider's.
CREATE OR REPLACE FUNCTION public.complete_booking(
    p_booking_id       uuid,
    p_payment_received boolean DEFAULT true)
RETURNS public.bookings
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
    v_uid     uuid := auth.uid();
    v_booking public.bookings%ROWTYPE;
    v_paid    boolean;
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'not_authenticated' USING ERRCODE = '42501';
    END IF;

    SELECT * INTO v_booking FROM public.bookings WHERE id = p_booking_id FOR UPDATE;
    IF NOT FOUND OR v_booking.provider_id IS DISTINCT FROM v_uid THEN
        RAISE EXCEPTION 'booking_not_found' USING ERRCODE = 'P0002';
    END IF;
    IF v_booking.status <> 'confirmed' THEN
        RAISE EXCEPTION 'booking_not_confirmed' USING ERRCODE = 'P0001';
    END IF;
    IF v_booking.starts_at > now() THEN
        RAISE EXCEPTION 'booking_not_started' USING ERRCODE = 'P0001';
    END IF;
    v_paid := v_booking.payment_method = 'cash' AND coalesce(p_payment_received, false);

    v_booking := private.finish_booking(v_booking, 'provider', v_paid);
    IF v_paid THEN
        UPDATE public.booking_payments
        SET status = 'paid', paid_at = now(), recorded_by = v_uid, updated_at = now()
        WHERE booking_id = p_booking_id AND status = 'pending';
    END IF;
    RETURN v_booking;
END;
$function$;

-- Completes a confirmed booking (provider or auto-complete) and, for an
-- in-app payment, schedules the provider's share.
CREATE FUNCTION private.finish_booking(p_booking public.bookings, p_actor_role text, p_cash_paid boolean DEFAULT false)
RETURNS public.bookings
LANGUAGE plpgsql
SET search_path TO ''
AS $function$
DECLARE
    v_booking public.bookings%ROWTYPE;
BEGIN
    UPDATE public.bookings
    SET status = 'completed',
        completed_at = now(),
        payment_status = CASE WHEN p_cash_paid THEN 'paid' ELSE payment_status END,
        updated_at = now()
    WHERE id = p_booking.id
    RETURNING * INTO v_booking;

    -- The whole payment, less any refunds, is the provider's. A hold still
    -- being captured is transferred once it is (on_payment_paid).
    IF v_booking.payment_method <> 'cash' AND v_booking.payment_status NOT IN ('void', 'failed', 'refunded') THEN
        PERFORM private.schedule_settlement(v_booking, greatest(v_booking.total_cents - coalesce((
            SELECT sum(r.amount_cents) FROM public.booking_refunds r
            WHERE r.booking_id = v_booking.id AND r.status IN ('pending', 'succeeded')), 0), 0)::integer);
    END IF;

    PERFORM private.on_booking_event(v_booking, 'completed', p_actor_role, 'confirmed',
        jsonb_build_object('payment_received', p_cash_paid, 'automatic', p_actor_role = 'system'));
    RETURN v_booking;
END;
$function$;

-- Provider records that the client didn't turn up. The provider keeps their
-- late fee; the rest of an in-app payment is refunded.
CREATE OR REPLACE FUNCTION public.mark_booking_no_show(p_booking_id uuid)
RETURNS public.bookings
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
    v_uid     uuid := auth.uid();
    v_booking public.bookings%ROWTYPE;
    v_fee     integer;
    v_refund  integer := 0;
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'not_authenticated' USING ERRCODE = '42501';
    END IF;

    SELECT * INTO v_booking FROM public.bookings WHERE id = p_booking_id FOR UPDATE;
    IF NOT FOUND OR v_booking.provider_id IS DISTINCT FROM v_uid THEN
        RAISE EXCEPTION 'booking_not_found' USING ERRCODE = 'P0002';
    END IF;
    IF v_booking.status <> 'confirmed' THEN
        RAISE EXCEPTION 'booking_not_confirmed' USING ERRCODE = 'P0001';
    END IF;
    IF v_booking.starts_at > now() THEN
        RAISE EXCEPTION 'booking_not_started' USING ERRCODE = 'P0001';
    END IF;

    v_fee := round(v_booking.total_cents * v_booking.cancellation_fee_percent / 100.0)::integer;
    UPDATE public.bookings
    SET status = 'no_show', cancellation_fee_cents = v_fee,
        payment_status = CASE WHEN payment_status = 'pending' THEN 'void' ELSE payment_status END,
        updated_at = now()
    WHERE id = p_booking_id
    RETURNING * INTO v_booking;

    UPDATE public.booking_payments SET status = 'void', updated_at = now()
    WHERE booking_id = p_booking_id AND status = 'pending';

    IF v_booking.payment_method <> 'cash' AND v_booking.payment_status IN ('paid', 'partially_refunded') THEN
        v_refund := greatest(private.refundable_cents(v_booking.id) - v_fee, 0);
        PERFORM private.queue_refund(v_booking, v_refund, 'no_show', 'provider');
        PERFORM private.schedule_settlement(v_booking, v_fee);
    END IF;

    PERFORM private.on_booking_event(v_booking, 'no_show', 'provider', 'confirmed',
        jsonb_build_object('fee_cents', v_fee, 'refund_cents', v_refund));

    RETURN v_booking;
END;
$function$;

-- Card bookings the provider didn't mark complete become theirs
-- auto_complete_after_hours after the appointment ends (cash bookings wait
-- for the provider, who records the cash).
CREATE FUNCTION private.auto_complete_card_bookings()
RETURNS integer
LANGUAGE plpgsql
SET search_path TO ''
AS $function$
DECLARE
    v_platform private.platform_settings%ROWTYPE;
    v_booking  public.bookings%ROWTYPE;
    v_count    integer := 0;
BEGIN
    SELECT * INTO v_platform FROM private.platform_settings WHERE id;
    FOR v_booking IN
        SELECT b.* FROM public.bookings b
        WHERE b.status = 'confirmed'
          AND b.payment_method <> 'cash'
          AND b.payment_status IN ('paid', 'partially_refunded')
          AND b.ends_at + make_interval(hours => v_platform.auto_complete_after_hours) <= now()
        ORDER BY b.ends_at
        LIMIT 200
        FOR UPDATE SKIP LOCKED
    LOOP
        PERFORM private.finish_booking(v_booking, 'system');
        v_count := v_count + 1;
    END LOOP;
    RETURN v_count;
END;
$function$;

-- Settlements that came due, or whose hold can lift (payout account fixed,
-- dispute closed).
CREATE FUNCTION private.process_due_settlements()
RETURNS integer
LANGUAGE plpgsql
SET search_path TO ''
AS $function$
DECLARE
    v_booking_id uuid;
    v_count      integer := 0;
BEGIN
    FOR v_booking_id IN
        SELECT s.booking_id FROM public.booking_settlements s
        WHERE (s.status = 'scheduled' AND s.available_at <= now())
           OR (s.status = 'held' AND s.hold_reason IN ('payout_account', 'dispute'))
        ORDER BY s.available_at
        LIMIT 200
    LOOP
        PERFORM private.process_settlement(v_booking_id);
        v_count := v_count + 1;
    END LOOP;
    RETURN v_count;
END;
$function$;

SELECT cron.schedule('myglo-auto-complete-card-bookings', '*/10 * * * *', 'SELECT private.auto_complete_card_bookings();');
SELECT cron.schedule('myglo-process-settlements', '*/5 * * * *', 'SELECT private.process_due_settlements();');

-- A capture that lands after the booking was completed lets its settlement
-- go: re-check when the payment becomes paid.
CREATE FUNCTION private.on_payment_paid()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO ''
AS $function$
BEGIN
    IF NEW.status IN ('paid', 'partially_refunded') AND OLD.status IS DISTINCT FROM NEW.status THEN
        PERFORM private.process_settlement(NEW.booking_id);
    END IF;
    RETURN NULL;
END;
$function$;

CREATE TRIGGER booking_payments_paid
    AFTER UPDATE OF status ON public.booking_payments
    FOR EACH ROW EXECUTE FUNCTION private.on_payment_paid();

-- ---------------------------------------------------------------------------
-- 7. Service-role state from Stripe.
-- ---------------------------------------------------------------------------

-- The jobs worker created (or Stripe updated) a refund. Idempotent.
CREATE FUNCTION public.apply_refund_state(
    p_refund_id        uuid,
    p_stripe_refund_id text,
    p_status           text,
    p_failure_reason   text DEFAULT NULL)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
    v_refund  public.booking_refunds%ROWTYPE;
    v_booking public.bookings%ROWTYPE;
    v_status  text := CASE WHEN p_status IN ('succeeded', 'failed', 'canceled') THEN p_status ELSE 'pending' END;
BEGIN
    SELECT * INTO v_refund FROM public.booking_refunds
    WHERE id = p_refund_id OR (p_refund_id IS NULL AND stripe_refund_id = p_stripe_refund_id)
    FOR UPDATE;
    IF NOT FOUND THEN
        RETURN;
    END IF;
    IF v_refund.stripe_refund_id IS NOT NULL AND v_refund.stripe_refund_id <> p_stripe_refund_id THEN
        RAISE EXCEPTION 'refund_mismatch' USING ERRCODE = 'P0001';
    END IF;
    -- A finished refund doesn't go back to pending.
    IF v_refund.status IN ('succeeded', 'failed', 'canceled') AND v_status = 'pending' THEN
        RETURN;
    END IF;

    UPDATE public.booking_refunds
    SET stripe_refund_id = p_stripe_refund_id, status = v_status,
        failure_reason = left(p_failure_reason, 200), updated_at = now()
    WHERE id = v_refund.id AND (stripe_refund_id, status) IS DISTINCT FROM (p_stripe_refund_id, v_status);

    IF v_status = 'succeeded' AND v_refund.status <> 'succeeded' THEN
        SELECT * INTO v_booking FROM public.bookings WHERE id = v_refund.booking_id;
        PERFORM private.notify(v_booking.client_id, NULL, 'payment_refunded', 'Refund on its way',
            format('%s for your %s booking with %s is on its way back to your card. Banks usually take 3 to 10 business days.',
                   private.format_aud(v_refund.amount_cents),
                   private.booking_when(v_booking.starts_at, v_booking.time_zone), v_booking.provider_name),
            v_booking.id, true, jsonb_build_object('reference', v_booking.reference, 'status', v_booking.status));
    ELSIF v_status = 'failed' AND v_refund.status <> 'failed' THEN
        PERFORM private.enqueue_job('admin_alert', 'alert:refund_failed:' || v_refund.id,
            jsonb_build_object('severity', 'high',
                'subject', 'Refund failed',
                'body', format('A refund of %s on booking %s failed: %s. Refund the client another way.',
                               private.format_aud(v_refund.amount_cents), v_refund.booking_id,
                               coalesce(p_failure_reason, 'no reason given')),
                'booking_id', v_refund.booking_id));
    END IF;
END;
$function$;

-- A transfer to the provider was made (or reversed). Idempotent.
CREATE FUNCTION public.apply_transfer_state(
    p_booking_id     uuid,
    p_transfer_id    text,
    p_status         text,
    p_reversed_cents integer DEFAULT 0,
    p_failure_reason text DEFAULT NULL)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
    v_settlement public.booking_settlements%ROWTYPE;
BEGIN
    SELECT * INTO v_settlement FROM public.booking_settlements
    WHERE booking_id = p_booking_id OR (p_booking_id IS NULL AND stripe_transfer_id = p_transfer_id)
    FOR UPDATE;
    IF NOT FOUND THEN
        RETURN;
    END IF;

    IF p_status = 'failed' THEN
        UPDATE public.booking_settlements
        SET status = 'failed', failure_reason = left(p_failure_reason, 200), updated_at = now()
        WHERE booking_id = v_settlement.booking_id AND status = 'processing';
        RETURN;
    END IF;

    UPDATE public.booking_settlements SET
        stripe_transfer_id = coalesce(p_transfer_id, stripe_transfer_id),
        transferred_at = coalesce(transferred_at, now()),
        reversed_cents = least(greatest(reversed_cents, coalesce(p_reversed_cents, 0)), transfer_cents),
        status = CASE WHEN least(greatest(reversed_cents, coalesce(p_reversed_cents, 0)), transfer_cents) >= transfer_cents
                      THEN 'reversed' ELSE 'transferred' END,
        failure_reason = NULL,
        updated_at = now()
    WHERE booking_id = v_settlement.booking_id
      AND (stripe_transfer_id IS NULL OR stripe_transfer_id = p_transfer_id OR p_transfer_id IS NULL);
END;
$function$;

-- A dispute (chargeback) on a booking's charge: holds or takes back the
-- provider's share while it's open, and lets it go if Myglo wins.
CREATE FUNCTION public.apply_dispute_state(
    p_dispute_id        text,
    p_payment_intent_id text,
    p_amount_cents      integer,
    p_reason            text,
    p_status            text,
    p_evidence_due_by   timestamptz DEFAULT NULL)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
    v_booking_id uuid;
    v_before     public.payment_disputes%ROWTYPE;
    v_booking    public.bookings%ROWTYPE;
    v_closed     boolean := p_status IN ('won', 'lost', 'prevented');
BEGIN
    SELECT p.booking_id INTO v_booking_id FROM public.booking_payments p WHERE p.stripe_payment_intent_id = p_payment_intent_id;
    SELECT * INTO v_before FROM public.payment_disputes WHERE id = p_dispute_id FOR UPDATE;

    INSERT INTO public.payment_disputes AS d (id, booking_id, amount_cents, reason, status, evidence_due_by, closed_at)
    VALUES (p_dispute_id, v_booking_id, p_amount_cents, left(p_reason, 60), left(p_status, 40), p_evidence_due_by,
            CASE WHEN v_closed THEN now() END)
    ON CONFLICT (id) DO UPDATE SET
        amount_cents = EXCLUDED.amount_cents, reason = EXCLUDED.reason, status = EXCLUDED.status,
        evidence_due_by = EXCLUDED.evidence_due_by,
        closed_at = CASE WHEN v_closed THEN coalesce(d.closed_at, now()) END,
        updated_at = now();

    IF v_booking_id IS NULL THEN
        RETURN;
    END IF;
    SELECT * INTO v_booking FROM public.bookings WHERE id = v_booking_id;

    IF v_before.id IS NULL THEN
        -- New dispute: freeze the provider's share, or take it back if paid.
        PERFORM private.reverse_settlement(v_booking_id, p_amount_cents, 'dispute');
        PERFORM private.process_settlement(v_booking_id);
        PERFORM private.notify(v_booking.provider_id, NULL, 'booking_disputed', 'Payment disputed',
            format('%s disputed the payment for %s with their bank. Myglo handles the dispute; '
                   || 'your share is on hold until it''s settled.',
                   v_booking.client_name, private.booking_when(v_booking.starts_at, v_booking.time_zone)),
            v_booking_id, true, jsonb_build_object('reference', v_booking.reference, 'status', v_booking.status));
        PERFORM private.enqueue_job('admin_alert', 'alert:dispute:' || p_dispute_id,
            jsonb_build_object('severity', 'high',
                'subject', 'New dispute on booking ' || v_booking.reference,
                'body', format('A %s dispute (%s) was opened on booking %s. Respond in the Stripe Dashboard before %s.',
                               private.format_aud(p_amount_cents), coalesce(p_reason, 'no reason'), v_booking.reference,
                               coalesce(to_char(p_evidence_due_by, 'DD Mon YYYY'), 'the deadline')),
                'booking_id', v_booking_id, 'dispute_id', p_dispute_id));
    ELSIF v_closed AND v_before.closed_at IS NULL THEN
        IF p_status IN ('won', 'prevented') THEN
            -- The money came back: pay the provider again if it was taken back.
            UPDATE public.booking_settlements
            SET status = 'scheduled', hold_reason = NULL, transfer_attempt = transfer_attempt + 1,
                stripe_transfer_id = NULL, transferred_at = NULL, reversed_cents = 0, updated_at = now()
            WHERE booking_id = v_booking_id AND status = 'reversed';
            PERFORM private.process_settlement(v_booking_id);
        ELSE
            UPDATE public.booking_settlements
            SET status = CASE WHEN status = 'held' THEN 'not_applicable' ELSE status END,
                hold_reason = CASE WHEN status = 'held' THEN NULL ELSE hold_reason END,
                updated_at = now()
            WHERE booking_id = v_booking_id;
        END IF;
    END IF;
END;
$function$;

-- A payout from a provider's Stripe balance to their bank. Idempotent.
CREATE FUNCTION public.apply_payout_state(
    p_stripe_account_id text,
    p_payout_id         text,
    p_amount_cents      integer,
    p_currency          text,
    p_status            text,
    p_arrival_date      date,
    p_failure_code      text DEFAULT NULL,
    p_failure_message   text DEFAULT NULL)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
    v_provider uuid;
    v_before   text;
    v_status   text := CASE WHEN p_status IN ('pending', 'in_transit', 'paid', 'failed', 'canceled') THEN p_status ELSE 'pending' END;
BEGIN
    SELECT a.provider_id INTO v_provider FROM private.provider_payout_accounts a WHERE a.stripe_account_id = p_stripe_account_id;
    IF v_provider IS NULL THEN
        RETURN;
    END IF;
    SELECT status INTO v_before FROM public.provider_payouts WHERE id = p_payout_id FOR UPDATE;

    INSERT INTO public.provider_payouts AS p (id, provider_id, amount_cents, currency, status, arrival_date, failure_code, failure_message)
    VALUES (p_payout_id, v_provider, p_amount_cents, lower(p_currency), v_status, p_arrival_date,
            left(p_failure_code, 80), left(p_failure_message, 300))
    ON CONFLICT (id) DO UPDATE SET
        amount_cents = EXCLUDED.amount_cents, status = EXCLUDED.status, arrival_date = EXCLUDED.arrival_date,
        failure_code = EXCLUDED.failure_code, failure_message = EXCLUDED.failure_message, updated_at = now();

    IF v_status IS DISTINCT FROM v_before THEN
        IF v_status = 'paid' THEN
            PERFORM private.notify(v_provider, NULL, 'payout_paid', 'Payout sent',
                format('%s is on its way to your bank account.', private.format_aud(p_amount_cents)),
                NULL, false, jsonb_build_object('payout', p_payout_id));
        ELSIF v_status = 'failed' THEN
            PERFORM private.notify(v_provider, NULL, 'payout_failed', 'Payout failed',
                format('Your %s payout couldn''t reach your bank. Check your bank details in Payments & payouts.',
                       private.format_aud(p_amount_cents)),
                NULL, true, jsonb_build_object('payout', p_payout_id));
        END IF;
    END IF;
END;
$function$;

-- Lift payout-account holds as soon as the account can receive transfers.
CREATE FUNCTION private.on_payout_account_changed()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO ''
AS $function$
DECLARE
    v_booking_id uuid;
BEGIN
    IF NEW.transfers_status = 'active' AND NEW.closed_at IS NULL
       AND (OLD.transfers_status IS DISTINCT FROM 'active' OR OLD.closed_at IS NOT NULL) THEN
        FOR v_booking_id IN
            SELECT s.booking_id FROM public.booking_settlements s
            WHERE s.provider_id = NEW.provider_id AND s.status = 'held' AND s.hold_reason = 'payout_account'
        LOOP
            PERFORM private.process_settlement(v_booking_id);
        END LOOP;
    END IF;
    RETURN NULL;
END;
$function$;

CREATE TRIGGER provider_payout_accounts_changed
    AFTER UPDATE ON private.provider_payout_accounts
    FOR EACH ROW EXECUTE FUNCTION private.on_payout_account_changed();

-- ---------------------------------------------------------------------------
-- 8. What clients and providers see.
-- ---------------------------------------------------------------------------

CREATE OR REPLACE VIEW public.booking_details WITH (security_invoker = true) AS
SELECT
    b.id,
    b.reference,
    b.client_id,
    b.provider_id,
    CASE WHEN b.status = 'pending' AND coalesce(b.respond_by, b.starts_at) <= now() THEN 'expired' ELSE b.status END AS status,
    b.starts_at,
    b.ends_at,
    b.time_zone,
    (b.starts_at AT TIME ZONE b.time_zone) AS starts_at_local,
    (b.ends_at AT TIME ZONE b.time_zone) AS ends_at_local,
    b.duration_minutes,
    b.location_type,
    b.address_text,
    b.address,
    b.access_notes,
    public.st_y(b.location::public.geometry) AS latitude,
    public.st_x(b.location::public.geometry) AS longitude,
    b.distance_km,
    b.provider_name,
    pp.profile_pic AS provider_avatar_url,
    b.client_name,
    cp.profile_pic AS client_avatar_url,
    b.client_phone,
    b.client_notes,
    b.subtotal_cents,
    b.total_cents,
    b.currency,
    b.payment_method,
    b.payment_status,
    b.requires_approval,
    b.cancellation_window_hours,
    b.cancellation_fee_percent,
    b.starts_at - make_interval(hours => b.cancellation_window_hours::integer) AS free_cancellation_until,
    b.decline_reason,
    b.responded_at,
    b.cancelled_by,
    b.cancellation_reason,
    b.cancelled_at,
    b.late_cancellation,
    b.cancellation_fee_cents,
    b.completed_at,
    b.created_at,
    b.updated_at,
    COALESCE((
        SELECT jsonb_agg(jsonb_build_object(
                   'service_id', i.service_id,
                   'name', i.service_name,
                   'category', i.category,
                   'duration_minutes', i.duration_minutes,
                   'price_cents', i.price_cents
               ) ORDER BY i.position)
        FROM public.booking_items i
        WHERE i.booking_id = b.id
    ), '[]'::jsonb) AS items,
    CASE WHEN b.provider_id = (SELECT auth.uid()) THEN b.platform_fee_cents END AS platform_fee_cents,
    rv.id AS review_id,
    rv.rating AS review_rating,
    b.hold_expires_at,
    coalesce(b.respond_by, CASE WHEN b.status = 'pending' THEN b.starts_at END) AS respond_by,
    pay.card_brand,
    pay.card_last4,
    pay.wallet,
    coalesce(pay.amount_refunded_cents, 0) AS amount_refunded_cents,
    pay.authorization_expires_at,
    coalesce((SELECT sum(r.amount_cents) FROM public.booking_refunds r
              WHERE r.booking_id = b.id AND r.status = 'pending'), 0)::integer AS refund_pending_cents,
    CASE WHEN b.provider_id = (SELECT auth.uid()) THEN st.status END AS settlement_status,
    CASE WHEN b.provider_id = (SELECT auth.uid()) THEN st.transfer_cents - st.reversed_cents END AS payout_cents
FROM public.bookings b
LEFT JOIN public.public_profiles pp ON pp.id = b.provider_id
LEFT JOIN public.public_profiles cp ON cp.id = b.client_id
LEFT JOIN public.reviews rv ON rv.booking_id = b.id
LEFT JOIN public.booking_settlements st ON st.booking_id = b.id
LEFT JOIN LATERAL (
    SELECT p.card_brand, p.card_last4, p.wallet, p.amount_refunded_cents, p.authorization_expires_at
    FROM public.booking_payments p
    WHERE p.booking_id = b.id
    ORDER BY p.created_at DESC
    LIMIT 1
) pay ON true;

-- A provider's money over a period (provider-local dates, inclusive): what
-- they earned in the app and in cash, Myglo's fees, what's on its way, and
-- their recent payouts.
CREATE FUNCTION public.get_provider_financials(p_from date, p_to date)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
    v_uid  uuid := auth.uid();
    v_tz   text;
    v_from timestamptz;
    v_to   timestamptz;
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'not_authenticated' USING ERRCODE = '42501';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = v_uid AND p.role = 'provider') THEN
        RAISE EXCEPTION 'providers_only' USING ERRCODE = '42501';
    END IF;
    IF p_from IS NULL OR p_to IS NULL OR p_to < p_from OR p_to - p_from > 400 THEN
        RAISE EXCEPTION 'invalid_request' USING ERRCODE = '22023';
    END IF;
    SELECT coalesce(s.time_zone, 'Australia/Brisbane') INTO v_tz FROM public.provider_booking_settings s WHERE s.provider_id = v_uid;
    v_tz := coalesce(v_tz, 'Australia/Brisbane');
    v_from := p_from::timestamp AT TIME ZONE v_tz;
    v_to := (p_to + 1)::timestamp AT TIME ZONE v_tz;

    RETURN jsonb_build_object(
        'time_zone', v_tz,
        'card_earned_cents', coalesce((
            SELECT sum(s.kept_cents) FROM public.booking_settlements s JOIN public.bookings b ON b.id = s.booking_id
            WHERE s.provider_id = v_uid AND b.starts_at >= v_from AND b.starts_at < v_to
              AND s.status NOT IN ('not_applicable', 'reversed')), 0),
        'myglo_fee_cents', coalesce((
            SELECT sum(s.platform_fee_cents) FROM public.booking_settlements s JOIN public.bookings b ON b.id = s.booking_id
            WHERE s.provider_id = v_uid AND b.starts_at >= v_from AND b.starts_at < v_to
              AND s.status NOT IN ('not_applicable', 'reversed')), 0),
        'cash_collected_cents', coalesce((
            SELECT sum(b.total_cents) FROM public.bookings b
            WHERE b.provider_id = v_uid AND b.payment_method = 'cash' AND b.payment_status = 'paid'
              AND b.starts_at >= v_from AND b.starts_at < v_to), 0),
        'completed_bookings', (
            SELECT count(*) FROM public.bookings b
            WHERE b.provider_id = v_uid AND b.status = 'completed' AND b.starts_at >= v_from AND b.starts_at < v_to),
        'on_its_way_cents', coalesce((
            SELECT sum(s.transfer_cents) FROM public.booking_settlements s
            WHERE s.provider_id = v_uid AND s.status IN ('scheduled', 'processing', 'held')), 0),
        'held_cents', coalesce((
            SELECT sum(s.transfer_cents) FROM public.booking_settlements s
            WHERE s.provider_id = v_uid AND s.status = 'held'), 0),
        'settlements', coalesce((
            SELECT jsonb_agg(row_to_json(x) ORDER BY x.starts_at DESC) FROM (
                SELECT s.booking_id, b.reference, b.client_name, b.starts_at, b.status AS booking_status,
                       s.kept_cents, s.platform_fee_cents, s.transfer_cents, s.reversed_cents, s.status,
                       s.hold_reason, s.transferred_at
                FROM public.booking_settlements s JOIN public.bookings b ON b.id = s.booking_id
                WHERE s.provider_id = v_uid AND b.starts_at >= v_from AND b.starts_at < v_to
                ORDER BY b.starts_at DESC LIMIT 100) x), '[]'::jsonb),
        'payouts', coalesce((
            SELECT jsonb_agg(row_to_json(x) ORDER BY x.created_at DESC) FROM (
                SELECT p.id, p.amount_cents, p.status, p.arrival_date, p.failure_message, p.created_at
                FROM public.provider_payouts p WHERE p.provider_id = v_uid
                ORDER BY p.created_at DESC LIMIT 20) x), '[]'::jsonb));
END;
$function$;

-- ---------------------------------------------------------------------------
-- 9. Admin: payments.
-- ---------------------------------------------------------------------------

-- Bookings paid in the app, newest first, with where their money is.
CREATE FUNCTION public.admin_list_payments(
    p_filter text    DEFAULT NULL,
    p_query  text    DEFAULT NULL,
    p_limit  integer DEFAULT 30,
    p_offset integer DEFAULT 0)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
    v_query text := nullif(btrim(p_query), '');
BEGIN
    PERFORM private.require_admin();
    RETURN coalesce((
        SELECT jsonb_agg(row_to_json(x) ORDER BY x.created_at DESC) FROM (
            SELECT b.id AS booking_id, b.reference, b.status, b.payment_status, b.total_cents, b.starts_at,
                   b.created_at, b.client_name, b.provider_name, b.client_id, b.provider_id,
                   p.card_brand, p.card_last4, p.amount_refunded_cents,
                   s.status AS settlement_status, s.hold_reason,
                   EXISTS (SELECT 1 FROM public.payment_disputes d WHERE d.booking_id = b.id AND d.closed_at IS NULL) AS disputed
            FROM public.bookings b
            LEFT JOIN LATERAL (SELECT * FROM public.booking_payments bp WHERE bp.booking_id = b.id
                               ORDER BY bp.created_at DESC LIMIT 1) p ON true
            LEFT JOIN public.booking_settlements s ON s.booking_id = b.id
            WHERE b.payment_method <> 'cash'
              AND b.status <> 'checkout_expired'
              AND (v_query IS NULL OR b.reference ILIKE '%' || v_query || '%'
                   OR b.client_name ILIKE '%' || v_query || '%' OR b.provider_name ILIKE '%' || v_query || '%'
                   OR p.stripe_payment_intent_id = v_query)
              AND CASE coalesce(p_filter, 'all')
                      WHEN 'held' THEN s.status = 'held'
                      WHEN 'failed' THEN s.status = 'failed' OR b.payment_status = 'failed'
                      WHEN 'disputed' THEN EXISTS (SELECT 1 FROM public.payment_disputes d WHERE d.booking_id = b.id)
                      WHEN 'refunded' THEN b.payment_status IN ('refunded', 'partially_refunded')
                      ELSE true END
            ORDER BY b.created_at DESC
            LIMIT least(greatest(coalesce(p_limit, 30), 1), 100) OFFSET greatest(coalesce(p_offset, 0), 0)) x), '[]'::jsonb);
END;
$function$;

-- Everything about one booking's money: payment, refunds, settlement,
-- disputes, background jobs and its timeline.
CREATE FUNCTION public.admin_get_booking_payment(p_booking_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
    v_booking public.bookings%ROWTYPE;
BEGIN
    PERFORM private.require_admin();
    SELECT * INTO v_booking FROM public.bookings WHERE id = p_booking_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'not_found' USING ERRCODE = 'P0002';
    END IF;
    RETURN jsonb_build_object(
        'booking', jsonb_build_object(
            'id', v_booking.id, 'reference', v_booking.reference, 'status', v_booking.status,
            'payment_method', v_booking.payment_method, 'payment_status', v_booking.payment_status,
            'total_cents', v_booking.total_cents, 'platform_fee_cents', v_booking.platform_fee_cents,
            'platform_fee_percent', v_booking.platform_fee_percent,
            'cancellation_fee_cents', v_booking.cancellation_fee_cents,
            'starts_at', v_booking.starts_at, 'ends_at', v_booking.ends_at,
            'client_id', v_booking.client_id, 'client_name', v_booking.client_name,
            'provider_id', v_booking.provider_id, 'provider_name', v_booking.provider_name,
            'refundable_cents', private.refundable_cents(v_booking.id)),
        'payment', (SELECT to_jsonb(p) - 'recorded_by' FROM public.booking_payments p
                    WHERE p.booking_id = p_booking_id ORDER BY p.created_at DESC LIMIT 1),
        'refunds', coalesce((SELECT jsonb_agg(to_jsonb(r) ORDER BY r.created_at) FROM public.booking_refunds r
                             WHERE r.booking_id = p_booking_id), '[]'::jsonb),
        'settlement', (SELECT to_jsonb(s) FROM public.booking_settlements s WHERE s.booking_id = p_booking_id),
        'disputes', coalesce((SELECT jsonb_agg(to_jsonb(d) ORDER BY d.created_at) FROM public.payment_disputes d
                              WHERE d.booking_id = p_booking_id), '[]'::jsonb),
        'jobs', coalesce((SELECT jsonb_agg(jsonb_build_object(
                                'id', j.id, 'kind', j.kind, 'status', j.status, 'attempts', j.attempts,
                                'last_error', j.last_error, 'created_at', j.created_at, 'updated_at', j.updated_at)
                              ORDER BY j.created_at)
                          FROM private.jobs j WHERE j.booking_id = p_booking_id), '[]'::jsonb),
        'events', coalesce((SELECT jsonb_agg(jsonb_build_object(
                                  'event', e.event, 'actor_role', e.actor_role, 'from_status', e.from_status,
                                  'to_status', e.to_status, 'details', e.details, 'created_at', e.created_at)
                                ORDER BY e.created_at)
                            FROM public.booking_events e WHERE e.booking_id = p_booking_id), '[]'::jsonb));
END;
$function$;

-- Refunds part or all of a booking's payment. With p_recover, takes the
-- same share back from the provider if they were already paid. Needs a
-- fresh authenticator code; audited.
CREATE FUNCTION public.admin_refund_booking(
    p_booking_id   uuid,
    p_amount_cents integer,
    p_reason       text,
    p_recover      boolean DEFAULT true)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
    v_admin      uuid := auth.uid();
    v_reason     text;
    v_booking    public.bookings%ROWTYPE;
    v_settlement public.booking_settlements%ROWTYPE;
    v_refundable integer;
    v_refund_id  uuid;
    v_recovered  integer := 0;
BEGIN
    PERFORM private.require_admin(true);
    v_reason := private.require_reason(p_reason);
    SELECT * INTO v_booking FROM public.bookings WHERE id = p_booking_id FOR UPDATE;
    IF NOT FOUND OR v_booking.payment_method = 'cash' THEN
        RAISE EXCEPTION 'not_found' USING ERRCODE = 'P0002';
    END IF;
    v_refundable := private.refundable_cents(p_booking_id);
    IF p_amount_cents IS NULL OR p_amount_cents <= 0 OR p_amount_cents > v_refundable THEN
        RAISE EXCEPTION 'invalid_amount' USING ERRCODE = '22023',
            DETAIL = jsonb_build_object('refundable_cents', v_refundable)::text;
    END IF;

    v_refund_id := private.queue_refund(v_booking, p_amount_cents, 'admin', 'admin', v_admin, v_reason);

    SELECT * INTO v_settlement FROM public.booking_settlements WHERE booking_id = p_booking_id FOR UPDATE;
    IF FOUND THEN
        IF v_settlement.status = 'transferred' AND coalesce(p_recover, true) THEN
            -- The provider's part of the refund, in proportion to what they got.
            v_recovered := private.reverse_settlement(p_booking_id,
                round(p_amount_cents::numeric * v_settlement.transfer_cents / greatest(v_settlement.kept_cents, 1))::integer,
                'admin_refund');
        ELSIF v_settlement.status IN ('scheduled', 'held', 'failed') THEN
            PERFORM private.schedule_settlement(v_booking, greatest(v_settlement.kept_cents - p_amount_cents, 0),
                                                v_settlement.available_at);
        END IF;
    END IF;

    PERFORM private.on_booking_event(v_booking, 'admin_refund', 'admin', v_booking.status,
        jsonb_build_object('amount_cents', p_amount_cents, 'reason', v_reason, 'recovered_cents', v_recovered));
    PERFORM private.audit('refund_booking', 'booking', p_booking_id::text, v_reason,
        jsonb_build_object('refundable_cents', v_refundable, 'settlement', to_jsonb(v_settlement)),
        jsonb_build_object('refund_id', v_refund_id, 'amount_cents', p_amount_cents, 'recovered_cents', v_recovered));
    RETURN jsonb_build_object('refund_id', v_refund_id, 'recovered_cents', v_recovered);
END;
$function$;

-- Cancels an upcoming booking on Myglo's behalf, refunding an in-app
-- payment in full (or releasing a hold). Needs a fresh authenticator code;
-- audited. Both parties are told.
CREATE FUNCTION public.admin_cancel_booking(p_booking_id uuid, p_reason text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
    v_reason  text;
    v_booking public.bookings%ROWTYPE;
    v_from    text;
BEGIN
    PERFORM private.require_admin(true);
    v_reason := private.require_reason(p_reason);
    SELECT * INTO v_booking FROM public.bookings WHERE id = p_booking_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'not_found' USING ERRCODE = 'P0002';
    END IF;
    IF v_booking.status NOT IN ('pending', 'confirmed') THEN
        RAISE EXCEPTION 'booking_not_cancellable' USING ERRCODE = 'P0001';
    END IF;
    v_from := v_booking.status;

    UPDATE public.bookings
    SET status = 'cancelled', cancelled_by = 'system', cancelled_at = now(),
        cancellation_reason = 'Cancelled by Myglo support',
        payment_status = CASE WHEN payment_status IN ('pending', 'requires_payment', 'authorized') THEN 'void'
                              ELSE payment_status END,
        updated_at = now()
    WHERE id = p_booking_id
    RETURNING * INTO v_booking;
    UPDATE public.booking_payments SET status = 'void', updated_at = now()
    WHERE booking_id = p_booking_id AND status = 'pending';
    PERFORM private.release_card_hold(v_booking);
    IF v_booking.payment_method <> 'cash' AND v_booking.payment_status IN ('paid', 'partially_refunded') THEN
        PERFORM private.queue_refund(v_booking, private.refundable_cents(v_booking.id), 'myglo_cancelled', 'admin',
                                     auth.uid(), v_reason);
        PERFORM private.schedule_settlement(v_booking, 0);
    END IF;

    PERFORM private.on_booking_event(v_booking, 'cancelled', 'admin', v_from, jsonb_build_object('reason', v_reason));
    PERFORM private.audit('cancel_booking', 'booking', p_booking_id::text, v_reason,
        jsonb_build_object('status', v_from), jsonb_build_object('status', 'cancelled'));
END;
$function$;

-- Holds a provider's share (e.g. while a complaint is looked at), or lets it
-- go. Needs a fresh authenticator code; audited.
CREATE FUNCTION public.admin_set_settlement_hold(p_booking_id uuid, p_hold boolean, p_reason text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
    v_reason text;
    v_before public.booking_settlements%ROWTYPE;
BEGIN
    PERFORM private.require_admin(true);
    v_reason := private.require_reason(p_reason);
    SELECT * INTO v_before FROM public.booking_settlements WHERE booking_id = p_booking_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'not_found' USING ERRCODE = 'P0002';
    END IF;

    IF p_hold THEN
        IF v_before.status NOT IN ('scheduled', 'held', 'failed') THEN
            RAISE EXCEPTION 'settlement_not_holdable' USING ERRCODE = 'P0001';
        END IF;
        UPDATE public.booking_settlements
        SET status = 'held', hold_reason = 'admin', hold_note = v_reason, updated_at = now()
        WHERE booking_id = p_booking_id;
    ELSE
        IF v_before.status NOT IN ('held', 'failed') THEN
            RAISE EXCEPTION 'settlement_not_held' USING ERRCODE = 'P0001';
        END IF;
        UPDATE public.booking_settlements
        SET status = 'scheduled', hold_reason = NULL, hold_note = NULL,
            transfer_attempt = transfer_attempt + CASE WHEN status = 'failed' THEN 1 ELSE 0 END,
            updated_at = now()
        WHERE booking_id = p_booking_id;
        PERFORM private.process_settlement(p_booking_id);
    END IF;

    PERFORM private.audit(CASE WHEN p_hold THEN 'hold_settlement' ELSE 'release_settlement' END,
        'booking', p_booking_id::text, v_reason, to_jsonb(v_before),
        (SELECT to_jsonb(s) FROM public.booking_settlements s WHERE s.booking_id = p_booking_id));
END;
$function$;

-- Runs a failed background job again. Audited.
CREATE FUNCTION public.admin_retry_job(p_job_id uuid, p_reason text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
    v_reason text;
    v_job    private.jobs%ROWTYPE;
BEGIN
    PERFORM private.require_admin(true);
    v_reason := private.require_reason(p_reason);
    SELECT * INTO v_job FROM private.jobs WHERE id = p_job_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'not_found' USING ERRCODE = 'P0002';
    END IF;
    IF v_job.status <> 'failed' THEN
        RAISE EXCEPTION 'job_not_failed' USING ERRCODE = 'P0001';
    END IF;
    UPDATE private.jobs
    SET status = 'pending', attempts = 0, next_attempt_at = now(), last_error = NULL, updated_at = now()
    WHERE id = p_job_id;
    IF v_job.kind = 'transfer' THEN
        UPDATE public.booking_settlements SET status = 'processing', failure_reason = NULL, updated_at = now()
        WHERE booking_id = v_job.booking_id AND status = 'failed';
    END IF;
    PERFORM private.audit('retry_job', 'job', p_job_id::text, v_reason,
        jsonb_build_object('kind', v_job.kind, 'last_error', v_job.last_error, 'attempts', v_job.attempts),
        jsonb_build_object('status', 'pending'));
END;
$function$;

-- What needs a person: failed jobs, open disputes, held settlements.
CREATE FUNCTION public.admin_payments_overview()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO ''
AS $function$
BEGIN
    PERFORM private.require_admin();
    RETURN jsonb_build_object(
        'paid_7d_cents', coalesce((SELECT sum(p.amount_cents - p.amount_refunded_cents) FROM public.booking_payments p
                                   WHERE p.method <> 'cash' AND p.status IN ('paid', 'partially_refunded')
                                     AND p.paid_at >= now() - interval '7 days'), 0),
        'fees_7d_cents', coalesce((SELECT sum(s.platform_fee_cents) FROM public.booking_settlements s
                                   WHERE s.created_at >= now() - interval '7 days'
                                     AND s.status NOT IN ('not_applicable', 'reversed')), 0),
        'held_settlements', (SELECT count(*) FROM public.booking_settlements WHERE status = 'held'),
        'failed_settlements', (SELECT count(*) FROM public.booking_settlements WHERE status = 'failed'),
        'open_disputes', (SELECT count(*) FROM public.payment_disputes WHERE closed_at IS NULL),
        'pending_refunds', (SELECT count(*) FROM public.booking_refunds WHERE status = 'pending'),
        'failed_jobs', coalesce((SELECT jsonb_agg(jsonb_build_object(
                                     'id', j.id, 'kind', j.kind, 'booking_id', j.booking_id, 'attempts', j.attempts,
                                     'last_error', j.last_error, 'updated_at', j.updated_at) ORDER BY j.updated_at DESC)
                                 FROM (SELECT * FROM private.jobs WHERE status = 'failed'
                                       ORDER BY updated_at DESC LIMIT 50) j), '[]'::jsonb),
        'disputes', coalesce((SELECT jsonb_agg(jsonb_build_object(
                                  'id', d.id, 'booking_id', d.booking_id, 'reference', b.reference,
                                  'amount_cents', d.amount_cents, 'reason', d.reason, 'status', d.status,
                                  'evidence_due_by', d.evidence_due_by, 'created_at', d.created_at)
                                ORDER BY d.created_at DESC)
                              FROM public.payment_disputes d LEFT JOIN public.bookings b ON b.id = d.booking_id
                              WHERE d.closed_at IS NULL), '[]'::jsonb));
END;
$function$;

-- ---------------------------------------------------------------------------
-- 9b. Notification copy: refunds, kept fees and Myglo cancellations.
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION private.on_booking_event(
    p_booking     public.bookings,
    p_event       text,
    p_actor_role  text,
    p_from_status text,
    p_details     jsonb DEFAULT '{}'::jsonb)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
    v_actor    uuid := auth.uid();
    v_when     text := private.booking_when(p_booking.starts_at, p_booking.time_zone);
    v_total    text := private.format_aud(p_booking.total_cents);
    v_reason   text := nullif(btrim(coalesce(p_details ->> 'reason', '')), '');
    v_fee      integer := coalesce((p_details ->> 'fee_cents')::integer, 0);
    v_late     boolean := coalesce((p_details ->> 'late')::boolean, false);
    v_refund   integer := coalesce((p_details ->> 'refund_cents')::integer, 0);
    v_card     boolean := p_booking.payment_method <> 'cash';
    v_deadline timestamptz := coalesce(p_booking.respond_by, p_booking.starts_at);
    v_by       text;
    v_services text;
    v_data     jsonb := jsonb_build_object('reference', p_booking.reference, 'status', p_booking.status);
BEGIN
    INSERT INTO public.booking_events (booking_id, event, actor_id, actor_role, from_status, to_status, details)
    VALUES (p_booking.id, p_event, v_actor, p_actor_role, p_from_status, p_booking.status, coalesce(p_details, '{}'::jsonb));

    SELECT string_agg(i.service_name, ', ' ORDER BY i.position) INTO v_services
    FROM public.booking_items i
    WHERE i.booking_id = p_booking.id;
    v_services := coalesce(v_services, 'your appointment');

    -- "by Tue 4 Nov, 2:30 pm" when a request lapses before its start time.
    v_by := CASE WHEN v_deadline < p_booking.starts_at
                 THEN private.booking_when(v_deadline, p_booking.time_zone)
                 ELSE private.booking_time(p_booking.starts_at, p_booking.time_zone) END;

    CASE p_event
        WHEN 'requested' THEN
            PERFORM private.notify(p_booking.provider_id, v_actor, 'booking_request', 'New booking request',
                format('%s requested %s on %s. ', p_booking.client_name, v_services, v_when)
                    || CASE WHEN v_deadline < p_booking.starts_at
                            THEN format('Accept or decline by %s. %s is held on their card until then.', v_by, v_total)
                            ELSE 'Accept or decline before it starts.' END,
                p_booking.id, true, v_data);
            PERFORM private.notify(p_booking.client_id, v_actor, 'booking_requested', 'Request sent',
                format('%s will confirm your %s appointment soon. We''ll let you know as soon as they reply.',
                       p_booking.provider_name, v_when)
                    || CASE WHEN v_card
                            THEN format(' %s is held on your card, not charged, until they accept.', v_total)
                            ELSE '' END,
                p_booking.id, true, v_data);

        WHEN 'booked' THEN
            PERFORM private.notify(p_booking.provider_id, v_actor, 'booking_new', 'New booking',
                format('%s booked %s on %s.', p_booking.client_name, v_services, v_when)
                    || CASE WHEN v_card THEN ' Paid in the app.' ELSE '' END,
                p_booking.id, true, v_data);
            PERFORM private.notify(p_booking.client_id, v_actor, 'booking_confirmed', 'Booking confirmed',
                format('%s with %s on %s. ', v_services, p_booking.provider_name, v_when)
                    || CASE WHEN v_card THEN format('You paid %s.', v_total)
                            ELSE format('Pay %s in cash at your appointment.', v_total) END,
                p_booking.id, true, v_data);

        WHEN 'confirmed' THEN
            PERFORM private.notify(p_booking.client_id, v_actor, 'booking_confirmed', 'Booking confirmed',
                format('%s accepted your request for %s. ', p_booking.provider_name, v_when)
                    || CASE WHEN v_card THEN format('The %s held on your card is now charged.', v_total)
                            ELSE format('Pay %s in cash at your appointment.', v_total) END,
                p_booking.id, true, v_data);

        WHEN 'declined' THEN
            PERFORM private.notify(p_booking.client_id, v_actor, 'booking_declined', 'Request declined',
                format('%s can''t take your booking on %s.', p_booking.provider_name, v_when)
                    || CASE WHEN v_reason IS NOT NULL THEN format(' Their note: "%s"', v_reason) ELSE '' END
                    || CASE WHEN v_card THEN ' The hold on your card is being released.' ELSE '' END
                    || ' Try another time or provider.',
                p_booking.id, true, v_data);

        WHEN 'cancelled' THEN
            IF p_actor_role = 'client' THEN
                PERFORM private.notify(p_booking.provider_id, v_actor, 'booking_cancelled', 'Booking cancelled',
                    format('%s cancelled %s on %s.', p_booking.client_name, v_services, v_when)
                        || CASE
                               WHEN v_late AND v_fee > 0 AND v_card THEN
                                   format(' This was a late cancellation: you keep %s under your policy.', private.format_aud(v_fee))
                               WHEN v_late AND v_fee > 0 THEN
                                   format(' This was a late cancellation: %s is owed under your policy.', private.format_aud(v_fee))
                               WHEN v_late THEN ' This was a late cancellation.'
                               ELSE ''
                           END,
                    p_booking.id, true, v_data);
                PERFORM private.notify(p_booking.client_id, v_actor, 'booking_cancelled', 'Booking cancelled',
                    format('You cancelled your %s booking with %s.', v_when, p_booking.provider_name)
                        || CASE
                               WHEN v_late AND v_fee > 0 AND v_card THEN
                                   format(' It was within %s hours of the start, so %s goes to %s under their policy%s.',
                                          p_booking.cancellation_window_hours, private.format_aud(v_fee), p_booking.provider_name,
                                          CASE WHEN v_refund > 0 THEN format(' and %s is refunded to your card', private.format_aud(v_refund))
                                               ELSE '' END)
                               WHEN v_late AND v_fee > 0 THEN
                                   format(' It was within %s hours of the start, so a late-cancellation fee of %s is owed to %s.',
                                          p_booking.cancellation_window_hours, private.format_aud(v_fee), p_booking.provider_name)
                               WHEN v_late THEN
                                   format(' It was within %s hours of the start, so it''s recorded as a late cancellation.',
                                          p_booking.cancellation_window_hours)
                                   || CASE WHEN v_refund > 0 THEN format(' %s is refunded to your card.', private.format_aud(v_refund))
                                           ELSE '' END
                               WHEN v_refund > 0 THEN format(' %s is refunded to your card.', private.format_aud(v_refund))
                               WHEN p_from_status = 'pending' AND v_card THEN ' The hold on your card is being released.'
                               ELSE ''
                           END,
                    p_booking.id, true, v_data);
            ELSIF p_actor_role = 'admin' THEN
                PERFORM private.notify(p_booking.client_id, NULL, 'booking_cancelled', 'Booking cancelled',
                    format('Myglo cancelled your %s booking with %s.', v_when, p_booking.provider_name)
                        || CASE WHEN v_card AND p_booking.payment_status IN ('paid', 'partially_refunded')
                                THEN format(' You''ll get a full refund of %s.', v_total)
                                ELSE ' You won''t be charged.' END
                        || ' Contact us if you have questions.',
                    p_booking.id, true, v_data);
                PERFORM private.notify(p_booking.provider_id, NULL, 'booking_cancelled', 'Booking cancelled',
                    format('Myglo cancelled %s''s booking for %s on %s. Contact us if you have questions.',
                           p_booking.client_name, v_services, v_when),
                    p_booking.id, true, v_data);
            ELSE
                PERFORM private.notify(p_booking.client_id, v_actor, 'booking_cancelled', 'Booking cancelled',
                    format('%s cancelled your %s booking.', p_booking.provider_name, v_when)
                        || CASE WHEN v_reason IS NOT NULL THEN format(' Their note: "%s"', v_reason) ELSE '' END
                        || CASE WHEN v_refund > 0 THEN format(' You''ll get a full refund of %s.', private.format_aud(v_refund))
                                ELSE ' You won''t be charged.' END,
                    p_booking.id, true, v_data);
            END IF;

        WHEN 'expired' THEN
            PERFORM private.notify(p_booking.client_id, v_actor, 'booking_expired', 'Request expired',
                format('%s didn''t respond to your request for %s.', p_booking.provider_name, v_when)
                    || CASE WHEN v_card THEN ' The hold on your card is being released.' ELSE '' END
                    || ' Try booking another time.',
                p_booking.id, true, v_data);
            PERFORM private.notify(p_booking.provider_id, v_actor, 'booking_expired', 'Request expired',
                format('%s''s request for %s expired before you responded.', p_booking.client_name, v_when),
                p_booking.id, false, v_data);

        WHEN 'completed' THEN
            PERFORM private.notify(p_booking.client_id, v_actor, 'booking_completed',
                format('Thanks for visiting %s', p_booking.provider_name),
                format('We hope you loved your %s.', v_services),
                p_booking.id, false, v_data);

        WHEN 'no_show' THEN
            PERFORM private.notify(p_booking.client_id, v_actor, 'booking_no_show', 'Missed appointment',
                format('%s marked your %s appointment as missed.', p_booking.provider_name, v_when)
                    || CASE WHEN v_fee > 0 AND v_card
                            THEN format(' Under their policy, %s goes to them%s.', private.format_aud(v_fee),
                                        CASE WHEN v_refund > 0 THEN format(' and %s is refunded to your card', private.format_aud(v_refund))
                                             ELSE '' END)
                            WHEN v_fee > 0 THEN format(' Under their policy, %s is owed.', private.format_aud(v_fee))
                            WHEN v_refund > 0 THEN format(' %s is refunded to your card.', private.format_aud(v_refund))
                            ELSE '' END,
                p_booking.id, true, v_data);

        WHEN 'reminder_day' THEN
            PERFORM private.notify(p_booking.client_id, NULL, 'booking_reminder', 'Upcoming appointment',
                format('%s with %s on %s.', v_services, p_booking.provider_name, v_when),
                p_booking.id, true, v_data);

        WHEN 'reminder_hour' THEN
            PERFORM private.notify(p_booking.client_id, NULL, 'booking_reminder', 'Starting soon',
                format('%s with %s at %s.', v_services, p_booking.provider_name,
                       private.booking_time(p_booking.starts_at, p_booking.time_zone)),
                p_booking.id, false, v_data);

        WHEN 'request_reminder' THEN
            PERFORM private.notify(p_booking.provider_id, NULL, 'booking_request_reminder', 'Request waiting for you',
                format('%s is waiting to hear about %s on %s. Accept or decline so they can plan.',
                       p_booking.client_name, v_services, v_when),
                p_booking.id, true, v_data);

        WHEN 'request_final_reminder' THEN
            PERFORM private.notify(p_booking.provider_id, NULL, 'booking_request_reminder', 'Respond before it expires',
                format('%s''s request for %s on %s still needs an answer. If you don''t accept or decline, '
                       || 'it expires %s and the time opens up for other clients.',
                       p_booking.client_name, v_services, v_when,
                       CASE WHEN v_deadline < p_booking.starts_at THEN 'on ' ELSE 'at ' END || v_by),
                p_booking.id, true, v_data);

        ELSE
            -- Audit-only events (checkout and payment steps, payment_recorded)
            -- notify nobody.
            NULL;
    END CASE;
END;
$function$;

-- ---------------------------------------------------------------------------
-- 10. Privileges.
-- ---------------------------------------------------------------------------

REVOKE ALL ON FUNCTION private.refundable_cents(uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION private.queue_refund(public.bookings, integer, text, text, uuid, text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION private.schedule_settlement(public.bookings, integer, timestamptz) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION private.process_settlement(uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION private.reverse_settlement(uuid, integer, text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION private.finish_booking(public.bookings, text, boolean) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION private.auto_complete_card_bookings() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION private.process_due_settlements() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION private.on_payment_paid() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION private.on_payout_account_changed() FROM PUBLIC, anon, authenticated;

REVOKE ALL ON FUNCTION public.apply_refund_state(uuid, text, text, text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.apply_transfer_state(uuid, text, text, integer, text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.apply_dispute_state(text, text, integer, text, text, timestamptz) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.apply_payout_state(text, text, integer, text, text, date, text, text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.apply_refund_state(uuid, text, text, text) TO service_role;
GRANT EXECUTE ON FUNCTION public.apply_transfer_state(uuid, text, text, integer, text) TO service_role;
GRANT EXECUTE ON FUNCTION public.apply_dispute_state(text, text, integer, text, text, timestamptz) TO service_role;
GRANT EXECUTE ON FUNCTION public.apply_payout_state(text, text, integer, text, text, date, text, text) TO service_role;

REVOKE ALL ON FUNCTION public.get_provider_financials(date, date) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_provider_financials(date, date) TO authenticated;

REVOKE ALL ON FUNCTION public.admin_list_payments(text, text, integer, integer) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.admin_get_booking_payment(uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.admin_refund_booking(uuid, integer, text, boolean) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.admin_cancel_booking(uuid, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.admin_set_settlement_hold(uuid, boolean, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.admin_retry_job(uuid, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.admin_payments_overview() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_list_payments(text, text, integer, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_get_booking_payment(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_refund_booking(uuid, integer, text, boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_cancel_booking(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_set_settlement_hold(uuid, boolean, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_retry_job(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_payments_overview() TO authenticated;
