-- Card checkout: clients pay in the app (card, Apple Pay, Google Pay)
-- through a Stripe PaymentIntent on Myglo's own account.
--
-- How a card booking moves
--   1. create_booking (payment method 'card') makes the booking
--      'awaiting_payment'. It holds the slot for checkout_hold_minutes and is
--      invisible to the provider. Nobody is notified yet.
--   2. The payments Edge Function creates the PaymentIntent (automatic
--      capture for instant bookings, manual capture, i.e. a hold, for
--      providers who approve requests) and the app shows Stripe's payment
--      sheet.
--   3. Stripe's answer (webhook, or the app's sync call) is applied by
--      apply_payment_intent_state():
--        succeeded        -> 'confirmed', paid        (booking + notifications)
--        requires_capture -> 'pending', card held     (request + notifications)
--                            with respond_by before the hold can lapse
--        canceled         -> 'checkout_expired'
--   4. A request the provider accepts is captured; one they decline, or that
--      lapses at respond_by, has its hold released. Both run as background
--      jobs (private.jobs) with idempotency keys.
--   5. A checkout nobody finishes is closed after the hold: its
--      PaymentIntent is cancelled first, so a payment made at the last moment
--      wins instead of being lost. A payment that still lands on a closed
--      checkout is refunded automatically.
--
-- Money is only ever calculated here. Edge Functions carry out the Stripe
-- calls with the amounts and keys these functions give them.
--
-- Not in this migration (payment lifecycle, next): refunds for cancelled or
-- missed card bookings, transfers to providers, disputes. Until then a
-- cancelled card booking that was paid keeps payment_status 'paid'.

-- ---------------------------------------------------------------------------
-- 1. Statuses and columns.
-- ---------------------------------------------------------------------------

ALTER TABLE public.bookings DROP CONSTRAINT bookings_status;
ALTER TABLE public.bookings ADD CONSTRAINT bookings_status CHECK (status IN (
    'awaiting_payment', 'checkout_expired',
    'pending', 'confirmed', 'declined', 'cancelled', 'completed', 'no_show', 'expired'));

ALTER TABLE public.bookings DROP CONSTRAINT bookings_payment_status;
ALTER TABLE public.bookings ADD CONSTRAINT bookings_payment_status CHECK (payment_status IN (
    'pending', 'requires_payment', 'authorized', 'paid', 'partially_refunded', 'refunded', 'void', 'failed'));

ALTER TABLE public.bookings
    -- Until when an unpaid checkout holds the slot.
    ADD COLUMN hold_expires_at      timestamptz,
    -- When a request lapses if the provider hasn't answered. NULL means its
    -- start time (cash requests); card requests lapse before the hold on the
    -- client's card can.
    ADD COLUMN respond_by           timestamptz,
    -- The Myglo commission rate this booking was made under (0 during the
    -- provider's fee-free period and for cash).
    ADD COLUMN platform_fee_percent numeric(5,2) NOT NULL DEFAULT 0,
    ADD CONSTRAINT bookings_checkout_hold CHECK (status <> 'awaiting_payment' OR hold_expires_at IS NOT NULL),
    ADD CONSTRAINT bookings_platform_fee_percent CHECK (platform_fee_percent BETWEEN 0 AND 100);

COMMENT ON COLUMN public.bookings.hold_expires_at IS
    'Card checkout: the slot is held for the client until then while they pay.';
COMMENT ON COLUMN public.bookings.respond_by IS
    'When an unanswered request lapses. NULL = at its start time.';
COMMENT ON COLUMN public.bookings.platform_fee_percent IS
    'Myglo commission rate snapshotted at booking time (0 for cash and during the fee-free period).';

-- An unpaid checkout holds the slot like a booking does.
ALTER TABLE public.bookings DROP CONSTRAINT bookings_no_overlap;
ALTER TABLE public.bookings ADD CONSTRAINT bookings_no_overlap EXCLUDE USING gist (
    provider_id WITH =,
    tstzrange(starts_at, blocked_until, '[)') WITH &&
) WHERE (status IN ('awaiting_payment', 'pending', 'confirmed'));

CREATE INDEX bookings_checkout_hold_idx ON public.bookings (hold_expires_at) WHERE status = 'awaiting_payment';
CREATE INDEX bookings_request_deadline_idx ON public.bookings ((coalesce(respond_by, starts_at))) WHERE status = 'pending';

ALTER TABLE public.booking_payments DROP CONSTRAINT booking_payments_status;
ALTER TABLE public.booking_payments ADD CONSTRAINT booking_payments_status CHECK (status IN (
    'pending', 'authorized', 'paid', 'partially_refunded', 'refunded', 'void', 'failed'));

ALTER TABLE public.booking_payments
    ADD COLUMN stripe_payment_intent_id text UNIQUE,
    ADD COLUMN stripe_charge_id         text,
    -- 'manual' places a hold that is captured when the provider accepts.
    ADD COLUMN capture_method           text,
    ADD COLUMN authorized_at            timestamptz,
    ADD COLUMN captured_at              timestamptz,
    -- When the hold on the client's card lapses (Stripe's capture_before).
    ADD COLUMN authorization_expires_at timestamptz,
    ADD COLUMN amount_refunded_cents    integer NOT NULL DEFAULT 0,
    ADD COLUMN wallet                   text,
    ADD COLUMN card_brand               text,
    ADD COLUMN card_last4               text,
    -- Last decline or error code Stripe reported for this payment.
    ADD COLUMN failure_code             text,
    ADD CONSTRAINT booking_payments_stripe_pi CHECK (stripe_payment_intent_id ~ '^pi_[A-Za-z0-9]+$'),
    ADD CONSTRAINT booking_payments_capture_method CHECK (capture_method IN ('automatic', 'manual')),
    ADD CONSTRAINT booking_payments_refunded CHECK (amount_refunded_cents BETWEEN 0 AND amount_cents),
    ADD CONSTRAINT booking_payments_card_last4 CHECK (card_last4 ~ '^[0-9]{4}$'),
    ADD CONSTRAINT booking_payments_card_text CHECK (
        char_length(wallet) <= 30 AND char_length(card_brand) <= 30 AND char_length(failure_code) <= 80);

ALTER TABLE private.jobs DROP CONSTRAINT jobs_kind;
ALTER TABLE private.jobs ADD CONSTRAINT jobs_kind CHECK (kind IN (
    'noop', 'admin_alert', 'cancel_payment_intent', 'capture_payment', 'refund_payment'));

-- ---------------------------------------------------------------------------
-- 2. Visibility: an unpaid or abandoned checkout is the client's business only.
-- ---------------------------------------------------------------------------

-- The child tables (items, payments, events), booking_details, the provider
-- contact and stats functions and Realtime all follow this policy.
DROP POLICY "Parties can view their bookings" ON public.bookings;
CREATE POLICY "Parties can view their bookings" ON public.bookings
    FOR SELECT TO authenticated
    USING ((SELECT auth.uid()) = client_id
           OR ((SELECT auth.uid()) = provider_id AND status NOT IN ('awaiting_payment', 'checkout_expired')));

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
    pay.authorization_expires_at
FROM public.bookings b
LEFT JOIN public.public_profiles pp ON pp.id = b.provider_id
LEFT JOIN public.public_profiles cp ON cp.id = b.client_id
LEFT JOIN public.reviews rv ON rv.booking_id = b.id
LEFT JOIN LATERAL (
    SELECT p.card_brand, p.card_last4, p.wallet, p.amount_refunded_cents, p.authorization_expires_at
    FROM public.booking_payments p
    WHERE p.booking_id = b.id
    ORDER BY p.created_at DESC
    LIMIT 1
) pay ON true;

-- ---------------------------------------------------------------------------
-- 3. Availability: unpaid checkouts hold their slot.
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION private.available_slots(
    p_provider_id      uuid,
    p_duration_minutes integer,
    p_from             date,
    p_to               date)
RETURNS TABLE (slot_start timestamptz)
LANGUAGE sql
STABLE
SET search_path TO ''
AS $function$
    WITH settings AS (
        SELECT s.time_zone,
               s.slot_interval_minutes,
               s.buffer_minutes,
               now() + make_interval(mins => s.min_notice_minutes) AS earliest,
               -- Start of the first local day past the booking window.
               (((now() AT TIME ZONE s.time_zone)::date + s.max_advance_days + 1)::timestamp
                   AT TIME ZONE s.time_zone) AS latest
        FROM public.provider_booking_settings s
        WHERE s.provider_id = p_provider_id
          AND s.accepts_bookings
    ),
    windows AS (
        SELECT st.*,
               (d.local_day::date + h.opens_at) AT TIME ZONE st.time_zone AS window_start,
               (d.local_day::date + h.closes_at) AT TIME ZONE st.time_zone AS window_end
        FROM settings st
        CROSS JOIN generate_series(p_from::timestamp, p_to::timestamp, interval '1 day') AS d(local_day)
        JOIN public.provider_working_hours h
          ON h.provider_id = p_provider_id
         AND h.weekday = extract(isodow FROM d.local_day)::smallint
    ),
    candidates AS (
        SELECT w.earliest,
               w.latest,
               w.buffer_minutes,
               c.slot_start
        FROM windows w
        CROSS JOIN LATERAL generate_series(
            w.window_start,
            w.window_end - make_interval(mins => p_duration_minutes),
            make_interval(mins => w.slot_interval_minutes)
        ) AS c(slot_start)
    )
    SELECT c.slot_start
    FROM candidates c
    WHERE c.slot_start >= c.earliest
      AND c.slot_start < c.latest
      AND NOT EXISTS (
          SELECT 1
          FROM public.bookings b
          WHERE b.provider_id = p_provider_id
            AND b.status IN ('awaiting_payment', 'pending', 'confirmed')
            AND tstzrange(b.starts_at, b.blocked_until, '[)')
                && tstzrange(c.slot_start, c.slot_start + make_interval(mins => p_duration_minutes + c.buffer_minutes), '[)')
      )
      AND NOT EXISTS (
          SELECT 1
          FROM public.provider_time_off t
          WHERE t.provider_id = p_provider_id
            AND tstzrange(t.starts_at, t.ends_at, '[)')
                && tstzrange(c.slot_start, c.slot_start + make_interval(mins => p_duration_minutes), '[)')
      )
    ORDER BY c.slot_start;
$function$;

-- ---------------------------------------------------------------------------
-- 4. Internal helpers.
-- ---------------------------------------------------------------------------

-- The payment row of a booking (one per booking today; the latest wins).
CREATE FUNCTION private.booking_payment(p_booking_id uuid)
RETURNS public.booking_payments
LANGUAGE sql
STABLE
SET search_path TO ''
AS $function$
    SELECT p.* FROM public.booking_payments p
    WHERE p.booking_id = p_booking_id
    ORDER BY p.created_at DESC
    LIMIT 1;
$function$;

-- Ends an unpaid checkout and frees its slot. If a PaymentIntent exists it
-- is cancelled in the background; should the client have paid after all,
-- that payment is refunded (see apply_payment_intent_state).
CREATE FUNCTION private.close_checkout(p_booking public.bookings, p_actor_role text, p_reason text)
RETURNS public.bookings
LANGUAGE plpgsql
SET search_path TO ''
AS $function$
DECLARE
    v_booking public.bookings%ROWTYPE;
    v_payment public.booking_payments%ROWTYPE;
BEGIN
    UPDATE public.bookings
    SET status = 'checkout_expired', payment_status = 'void', updated_at = now()
    WHERE id = p_booking.id AND status = 'awaiting_payment'
    RETURNING * INTO v_booking;
    IF NOT FOUND THEN
        RETURN p_booking;
    END IF;

    v_payment := private.booking_payment(v_booking.id);
    UPDATE public.booking_payments SET status = 'void', updated_at = now()
    WHERE id = v_payment.id AND status = 'pending';

    IF v_payment.stripe_payment_intent_id IS NOT NULL THEN
        PERFORM private.enqueue_job(
            'cancel_payment_intent', 'checkout-cancel:' || v_booking.id,
            jsonb_build_object('booking_id', v_booking.id,
                               'payment_intent_id', v_payment.stripe_payment_intent_id,
                               'mode', 'checkout'),
            v_booking.id);
    END IF;

    PERFORM private.on_booking_event(v_booking, 'checkout_expired', p_actor_role, 'awaiting_payment',
        jsonb_build_object('reason', p_reason));
    RETURN v_booking;
END;
$function$;

-- Releases the hold on the client's card (declined, lapsed or withdrawn
-- request). Safe to call more than once.
CREATE FUNCTION private.release_card_hold(p_booking public.bookings)
RETURNS void
LANGUAGE plpgsql
SET search_path TO ''
AS $function$
DECLARE
    v_payment public.booking_payments%ROWTYPE := private.booking_payment(p_booking.id);
BEGIN
    IF v_payment.stripe_payment_intent_id IS NULL OR v_payment.status <> 'authorized' THEN
        RETURN;
    END IF;
    PERFORM private.enqueue_job(
        'cancel_payment_intent', 'hold-release:' || p_booking.id,
        jsonb_build_object('booking_id', p_booking.id,
                           'payment_intent_id', v_payment.stripe_payment_intent_id,
                           'mode', 'release'),
        p_booking.id);
END;
$function$;

-- ---------------------------------------------------------------------------
-- 5. Booking creation.
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.create_booking(
    p_booking_id           uuid,
    p_provider_id          uuid,
    p_service_ids          uuid[],
    p_starts_at            timestamptz,
    p_location_type        text,
    p_client_phone         text,
    p_expected_total_cents integer,
    p_payment_method       text             DEFAULT 'cash',
    p_address              jsonb            DEFAULT NULL,
    p_latitude             double precision DEFAULT NULL,
    p_longitude            double precision DEFAULT NULL,
    p_access_notes         text             DEFAULT NULL,
    p_client_notes         text             DEFAULT NULL)
RETURNS public.bookings
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
    v_uid          uuid := auth.uid();
    v_existing     public.bookings%ROWTYPE;
    v_booking      public.bookings%ROWTYPE;
    v_client       public.profiles%ROWTYPE;
    v_provider     public.profiles%ROWTYPE;
    v_settings     public.provider_booking_settings%ROWTYPE;
    v_platform     private.platform_settings%ROWTYPE;
    v_fee_free_from timestamptz;
    v_duration     integer;
    v_subtotal     integer;
    v_fee          integer := 0;
    v_fee_percent  numeric(5,2) := 0;
    v_method       text := coalesce(p_payment_method, '');
    v_card         boolean;
    v_approval     boolean;
    v_late_fee_pct smallint;
    v_local_day    date;
    v_ends_at      timestamptz;
    v_address_text text;
    v_address      jsonb;
    v_point        public.geography;
    v_distance     numeric;
    v_phone        text;
    v_client_name  text;
    v_access_notes text := nullif(btrim(p_access_notes), '');
    v_client_notes text := nullif(btrim(p_client_notes), '');
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'not_authenticated' USING ERRCODE = '42501';
    END IF;
    IF p_booking_id IS NULL OR p_provider_id IS NULL OR p_starts_at IS NULL THEN
        RAISE EXCEPTION 'invalid_request' USING ERRCODE = '22023';
    END IF;

    -- Retried request: hand back what the first attempt created.
    SELECT * INTO v_existing FROM public.bookings WHERE id = p_booking_id;
    IF FOUND THEN
        IF v_existing.client_id = v_uid THEN
            RETURN v_existing;
        END IF;
        RAISE EXCEPTION 'invalid_request' USING ERRCODE = '22023';
    END IF;

    SELECT * INTO v_client FROM public.profiles WHERE id = v_uid;
    IF NOT FOUND OR v_client.role <> 'customer' THEN
        RAISE EXCEPTION 'clients_only' USING ERRCODE = '42501';
    END IF;

    SELECT * INTO v_provider FROM public.profiles WHERE id = p_provider_id AND role = 'provider';
    IF NOT FOUND THEN
        RAISE EXCEPTION 'provider_not_found' USING ERRCODE = 'P0002';
    END IF;

    -- One booking write at a time per provider, so the availability check
    -- below can't race another client booking the same time.
    PERFORM pg_advisory_xact_lock(hashtextextended('myglo.booking.provider:' || p_provider_id::text, 0));

    -- A retry that raced its own original (e.g. after a timeout) finds the
    -- booking here rather than seeing its own slot as taken.
    SELECT * INTO v_existing FROM public.bookings WHERE id = p_booking_id;
    IF FOUND THEN
        IF v_existing.client_id = v_uid THEN
            RETURN v_existing;
        END IF;
        RAISE EXCEPTION 'invalid_request' USING ERRCODE = '22023';
    END IF;

    -- Starting a new booking abandons any checkout the client didn't finish
    -- (they changed their mind, or went back to change something), so it
    -- never blocks their own new booking.
    FOR v_existing IN
        SELECT * FROM public.bookings b
        WHERE b.client_id = v_uid AND b.status = 'awaiting_payment'
        FOR UPDATE
    LOOP
        PERFORM private.close_checkout(v_existing, 'client', 'replaced');
    END LOOP;

    SELECT * INTO v_settings FROM public.provider_booking_settings WHERE provider_id = p_provider_id;
    IF NOT FOUND OR NOT v_settings.accepts_bookings THEN
        RAISE EXCEPTION 'provider_not_accepting' USING ERRCODE = 'P0001';
    END IF;
    SELECT * INTO v_platform FROM private.platform_settings WHERE id;

    -- Cash is taken unless the provider turned it off and can take cards;
    -- cards once their payout account works and they haven't turned cards off.
    v_card := v_method = 'card';
    IF v_method NOT IN ('cash', 'card')
       OR (v_card AND NOT private.provider_takes_card(v_settings))
       OR (NOT v_card AND NOT private.provider_takes_cash(v_settings)) THEN
        RAISE EXCEPTION 'payment_method_unavailable' USING ERRCODE = 'P0001';
    END IF;

    -- Cash bookings are always requests the provider accepts, and never carry
    -- a late-cancellation / no-show fee. The provider's approval and fee
    -- settings apply to bookings paid in the app.
    v_approval := NOT v_card OR v_settings.requires_approval;
    v_late_fee_pct := CASE WHEN v_card THEN v_settings.cancellation_fee_percent ELSE 0 END;

    -- Price and length come from the database, never from the client.
    SELECT sum(r.duration_minutes), sum(r.price_cents)
    INTO v_duration, v_subtotal
    FROM private.resolve_services(p_provider_id, p_service_ids) r;

    IF p_expected_total_cents IS DISTINCT FROM v_subtotal THEN
        RAISE EXCEPTION 'price_changed' USING ERRCODE = 'P0001',
            DETAIL = jsonb_build_object('expected_cents', p_expected_total_cents, 'actual_cents', v_subtotal)::text;
    END IF;

    -- Timing rules, then the slot itself, re-verified under the lock.
    IF p_starts_at < now() + make_interval(mins => v_settings.min_notice_minutes) THEN
        RAISE EXCEPTION 'too_soon' USING ERRCODE = 'P0001',
            DETAIL = jsonb_build_object('min_notice_minutes', v_settings.min_notice_minutes)::text;
    END IF;
    v_local_day := (p_starts_at AT TIME ZONE v_settings.time_zone)::date;
    IF v_local_day > (now() AT TIME ZONE v_settings.time_zone)::date + v_settings.max_advance_days THEN
        RAISE EXCEPTION 'too_far_ahead' USING ERRCODE = 'P0001',
            DETAIL = jsonb_build_object('max_advance_days', v_settings.max_advance_days)::text;
    END IF;
    -- Stripe can hold card funds for a limited time, so card payments are
    -- for appointments within card_max_advance_days.
    IF v_card AND p_starts_at > now() + make_interval(days => v_platform.card_max_advance_days) THEN
        RAISE EXCEPTION 'card_too_far_ahead' USING ERRCODE = 'P0001',
            DETAIL = jsonb_build_object('max_days', v_platform.card_max_advance_days)::text;
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM private.available_slots(p_provider_id, v_duration, v_local_day, v_local_day) a
        WHERE a.slot_start = p_starts_at) THEN
        RAISE EXCEPTION 'slot_unavailable' USING ERRCODE = 'P0001';
    END IF;
    v_ends_at := p_starts_at + make_interval(mins => v_duration);

    -- A client can't be in two places at once, and can't hoard a calendar.
    IF EXISTS (
        SELECT 1 FROM public.bookings b
        WHERE b.client_id = v_uid
          AND b.status IN ('awaiting_payment', 'pending', 'confirmed')
          AND tstzrange(b.starts_at, b.ends_at, '[)') && tstzrange(p_starts_at, v_ends_at, '[)')) THEN
        RAISE EXCEPTION 'client_overlap' USING ERRCODE = 'P0001';
    END IF;
    IF (SELECT count(*) FROM public.bookings b
        WHERE b.client_id = v_uid
          AND b.provider_id = p_provider_id
          AND b.status IN ('awaiting_payment', 'pending', 'confirmed')
          AND b.starts_at > now()) >= 5 THEN
        RAISE EXCEPTION 'too_many_bookings' USING ERRCODE = 'P0001';
    END IF;

    -- Where the appointment happens.
    IF p_location_type = 'studio' THEN
        v_address_text := nullif(btrim(v_provider.address_text), '');
        IF NOT v_settings.offers_studio OR v_address_text IS NULL THEN
            RAISE EXCEPTION 'studio_unavailable' USING ERRCODE = 'P0001';
        END IF;
    ELSIF p_location_type = 'client' THEN
        IF NOT v_settings.offers_mobile THEN
            RAISE EXCEPTION 'mobile_unavailable' USING ERRCODE = 'P0001';
        END IF;
        v_address_text := private.format_client_address(p_address);
        v_address := jsonb_build_object(
            'line1', btrim(p_address ->> 'line1'),
            'unit', nullif(btrim(coalesce(p_address ->> 'unit', '')), ''),
            'suburb', btrim(p_address ->> 'suburb'),
            'state', upper(btrim(p_address ->> 'state')),
            'postcode', btrim(p_address ->> 'postcode'));
        IF p_latitude IS NULL OR p_longitude IS NULL
           OR p_latitude NOT BETWEEN -90 AND 90 OR p_longitude NOT BETWEEN -180 AND 180 THEN
            RAISE EXCEPTION 'address_invalid' USING ERRCODE = '22023';
        END IF;
        v_point := public.st_setsrid(public.st_makepoint(p_longitude, p_latitude), 4326)::public.geography;
        IF v_provider.coordinates IS NOT NULL THEN
            v_distance := round((public.st_distance(v_provider.coordinates, v_point) / 1000.0)::numeric, 2);
        END IF;
        IF v_settings.travel_radius_km IS NOT NULL THEN
            IF v_distance IS NULL THEN
                RAISE EXCEPTION 'service_area_unavailable' USING ERRCODE = 'P0001';
            END IF;
            IF v_distance > v_settings.travel_radius_km THEN
                RAISE EXCEPTION 'outside_service_area' USING ERRCODE = 'P0001',
                    DETAIL = jsonb_build_object('distance_km', v_distance, 'radius_km', v_settings.travel_radius_km)::text;
            END IF;
        END IF;
    ELSE
        RAISE EXCEPTION 'invalid_request' USING ERRCODE = '22023';
    END IF;

    v_phone := private.normalize_phone(p_client_phone);
    IF char_length(v_client_notes) > 500 OR char_length(v_access_notes) > 300 THEN
        RAISE EXCEPTION 'notes_too_long' USING ERRCODE = '22023';
    END IF;
    v_client_name := nullif(btrim(concat_ws(' ', btrim(v_client.first_name), btrim(v_client.last_name))), '');

    -- Myglo's commission, charged to the provider (never the client) on
    -- bookings paid in the app only. Each provider's fee-free period starts
    -- when their card payments were first enabled.
    IF v_card AND v_platform.platform_fee_percent > 0 THEN
        SELECT a.first_enabled_at INTO v_fee_free_from
        FROM private.provider_payout_accounts a WHERE a.provider_id = p_provider_id;
        IF now() >= coalesce(v_fee_free_from, now()) + make_interval(days => v_platform.fee_free_days) THEN
            v_fee_percent := v_platform.platform_fee_percent;
            v_fee := round(v_subtotal * v_fee_percent / 100.0)::integer;
        END IF;
    END IF;

    INSERT INTO public.bookings (
        id, reference, client_id, provider_id, status, starts_at, ends_at, blocked_until, time_zone,
        duration_minutes, buffer_minutes, location_type, address_text, address, access_notes, location,
        distance_km, provider_name, client_name, client_phone, client_notes, subtotal_cents,
        platform_fee_cents, platform_fee_percent, total_cents, payment_method, payment_status,
        requires_approval, cancellation_window_hours, cancellation_fee_percent, hold_expires_at)
    VALUES (
        p_booking_id, private.new_booking_reference(), v_uid, p_provider_id,
        CASE WHEN v_card THEN 'awaiting_payment' WHEN v_approval THEN 'pending' ELSE 'confirmed' END,
        p_starts_at, v_ends_at, v_ends_at + make_interval(mins => v_settings.buffer_minutes), v_settings.time_zone,
        v_duration, v_settings.buffer_minutes, p_location_type, v_address_text, v_address,
        CASE WHEN p_location_type = 'client' THEN v_access_notes END, v_point, v_distance,
        coalesce(nullif(btrim(v_provider.provider_name), ''),
                 nullif(btrim(concat_ws(' ', btrim(v_provider.first_name), btrim(v_provider.last_name))), ''),
                 'Provider'),
        coalesce(v_client_name, 'Client'), v_phone, v_client_notes, v_subtotal,
        v_fee, v_fee_percent, v_subtotal, v_method,
        CASE WHEN v_card THEN 'requires_payment' ELSE 'pending' END,
        v_approval, v_settings.cancellation_window_hours, v_late_fee_pct,
        CASE WHEN v_card THEN now() + make_interval(mins => v_platform.checkout_hold_minutes) END)
    RETURNING * INTO v_booking;

    INSERT INTO public.booking_items (booking_id, service_id, position, service_name, category, duration_minutes, price_cents)
    SELECT v_booking.id, r.service_id, r.ord, r.service_name, r.category, r.duration_minutes, r.price_cents
    FROM private.resolve_services(p_provider_id, p_service_ids) r;

    INSERT INTO public.booking_payments (booking_id, method, status, amount_cents, platform_fee_cents, capture_method)
    VALUES (v_booking.id, v_method, 'pending', v_booking.total_cents, v_booking.platform_fee_cents,
            CASE WHEN v_card THEN CASE WHEN v_approval THEN 'manual' ELSE 'automatic' END END);

    -- A card booking only becomes a booking (and is announced) once it's
    -- paid; until then it's recorded as a checkout.
    PERFORM private.on_booking_event(
        v_booking,
        CASE WHEN v_card THEN 'checkout_started' WHEN v_booking.status = 'pending' THEN 'requested' ELSE 'booked' END,
        'client',
        NULL,
        jsonb_build_object('payment_method', v_method, 'payment_status', v_booking.payment_status,
                           'total_cents', v_booking.total_cents));

    RETURN v_booking;
EXCEPTION
    -- Belt and braces: the exclusion constraint caught an overlap the check
    -- above should already have rejected.
    WHEN exclusion_violation THEN
        RAISE EXCEPTION 'slot_unavailable' USING ERRCODE = 'P0001';
END;
$function$;

-- ---------------------------------------------------------------------------
-- 6. Client checkout RPCs.
-- ---------------------------------------------------------------------------

-- What the payments function needs to take payment for the caller's
-- unpaid checkout. Runs as the client: anyone else gets booking_not_found.
CREATE FUNCTION public.begin_card_checkout(p_booking_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
    v_uid     uuid := auth.uid();
    v_booking public.bookings%ROWTYPE;
    v_payment public.booking_payments%ROWTYPE;
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'not_authenticated' USING ERRCODE = '42501';
    END IF;
    SELECT * INTO v_booking FROM public.bookings WHERE id = p_booking_id;
    IF NOT FOUND OR v_booking.client_id IS DISTINCT FROM v_uid THEN
        RAISE EXCEPTION 'booking_not_found' USING ERRCODE = 'P0002';
    END IF;
    v_payment := private.booking_payment(v_booking.id);

    IF v_booking.status = 'checkout_expired'
       OR (v_booking.status = 'awaiting_payment' AND v_booking.hold_expires_at <= now()) THEN
        RAISE EXCEPTION 'checkout_expired' USING ERRCODE = 'P0001';
    END IF;
    -- Already paid (e.g. the app missed Stripe's answer): the function syncs.
    IF v_booking.status <> 'awaiting_payment' AND v_payment.stripe_payment_intent_id IS NULL THEN
        RAISE EXCEPTION 'checkout_not_open' USING ERRCODE = 'P0001';
    END IF;

    RETURN jsonb_build_object(
        'booking_id', v_booking.id,
        'reference', v_booking.reference,
        'status', v_booking.status,
        'amount_cents', v_payment.amount_cents,
        'currency', lower(v_booking.currency),
        'capture_method', v_payment.capture_method,
        'payment_intent_id', v_payment.stripe_payment_intent_id,
        'provider_id', v_booking.provider_id,
        'provider_name', v_booking.provider_name,
        'client_id', v_booking.client_id,
        'hold_expires_at', v_booking.hold_expires_at);
END;
$function$;

-- The caller's PaymentIntent for a booking, so the payments function can
-- check Stripe when the app is waiting for the outcome.
CREATE FUNCTION public.get_checkout_payment_intent(p_booking_id uuid)
RETURNS text
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
    v_uid     uuid := auth.uid();
    v_booking public.bookings%ROWTYPE;
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'not_authenticated' USING ERRCODE = '42501';
    END IF;
    SELECT * INTO v_booking FROM public.bookings WHERE id = p_booking_id;
    IF NOT FOUND OR v_booking.client_id IS DISTINCT FROM v_uid THEN
        RAISE EXCEPTION 'booking_not_found' USING ERRCODE = 'P0002';
    END IF;
    RETURN (private.booking_payment(v_booking.id)).stripe_payment_intent_id;
END;
$function$;

-- The client gives up on an unpaid checkout (e.g. to pay in cash instead):
-- the slot is freed at once. Idempotent.
CREATE FUNCTION public.abandon_checkout(p_booking_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
    v_uid     uuid := auth.uid();
    v_booking public.bookings%ROWTYPE;
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'not_authenticated' USING ERRCODE = '42501';
    END IF;
    SELECT * INTO v_booking FROM public.bookings WHERE id = p_booking_id FOR UPDATE;
    IF NOT FOUND OR v_booking.client_id IS DISTINCT FROM v_uid THEN
        RAISE EXCEPTION 'booking_not_found' USING ERRCODE = 'P0002';
    END IF;
    IF v_booking.status = 'checkout_expired' THEN
        RETURN;
    END IF;
    IF v_booking.status <> 'awaiting_payment' THEN
        RAISE EXCEPTION 'checkout_not_open' USING ERRCODE = 'P0001';
    END IF;
    PERFORM private.close_checkout(v_booking, 'client', 'abandoned');
END;
$function$;

-- ---------------------------------------------------------------------------
-- 7. Service-role RPCs (payments function, webhook, jobs worker).
-- ---------------------------------------------------------------------------

-- Links the PaymentIntent created for a checkout. Idempotent; a different
-- PaymentIntent for the same booking is refused.
CREATE FUNCTION public.record_payment_intent(p_booking_id uuid, p_payment_intent_id text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
    v_payment public.booking_payments%ROWTYPE;
BEGIN
    SELECT * INTO v_payment FROM public.booking_payments p
    WHERE p.booking_id = p_booking_id
    ORDER BY p.created_at DESC
    LIMIT 1
    FOR UPDATE;
    IF NOT FOUND OR v_payment.method <> 'card' THEN
        RAISE EXCEPTION 'booking_not_found' USING ERRCODE = 'P0002';
    END IF;
    IF v_payment.stripe_payment_intent_id IS NULL THEN
        UPDATE public.booking_payments
        SET stripe_payment_intent_id = p_payment_intent_id, updated_at = now()
        WHERE id = v_payment.id;
    ELSIF v_payment.stripe_payment_intent_id <> p_payment_intent_id THEN
        RAISE EXCEPTION 'payment_intent_mismatch' USING ERRCODE = 'P0001';
    END IF;
END;
$function$;

-- Applies a PaymentIntent's current state (fetched from Stripe, never taken
-- from an event payload) to its booking. Idempotent and safe in any order:
-- every branch checks where the booking is now. Returns the booking's
-- status, or NULL for a PaymentIntent Myglo doesn't know.
CREATE FUNCTION public.apply_payment_intent_state(
    p_payment_intent_id     text,
    p_status                text,
    p_amount_cents          integer,
    p_amount_received_cents integer DEFAULT 0,
    p_amount_refunded_cents integer DEFAULT 0,
    p_charge_id             text DEFAULT NULL,
    p_capture_before        timestamptz DEFAULT NULL,
    p_wallet                text DEFAULT NULL,
    p_card_brand            text DEFAULT NULL,
    p_card_last4            text DEFAULT NULL,
    p_failure_code          text DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
    v_payment   public.booking_payments%ROWTYPE;
    v_booking   public.bookings%ROWTYPE;
    v_platform  private.platform_settings%ROWTYPE;
    v_from      text;
    v_paid      boolean := p_status = 'succeeded';
    v_held      boolean := p_status = 'requires_capture';
    v_refunded  integer := greatest(coalesce(p_amount_refunded_cents, 0), 0);
    v_received  integer := greatest(coalesce(p_amount_received_cents, 0), 0);
BEGIN
    SELECT * INTO v_payment FROM public.booking_payments WHERE stripe_payment_intent_id = p_payment_intent_id;
    IF NOT FOUND THEN
        RETURN NULL;
    END IF;
    SELECT * INTO v_booking FROM public.bookings WHERE id = v_payment.booking_id FOR UPDATE;
    SELECT * INTO v_payment FROM public.booking_payments WHERE id = v_payment.id FOR UPDATE;
    SELECT * INTO v_platform FROM private.platform_settings WHERE id;

    IF p_amount_cents IS DISTINCT FROM v_payment.amount_cents THEN
        RAISE EXCEPTION 'amount_mismatch' USING ERRCODE = 'P0001',
            DETAIL = jsonb_build_object('expected_cents', v_payment.amount_cents, 'actual_cents', p_amount_cents)::text;
    END IF;

    -- What Stripe knows about the card, whatever happens to the booking.
    UPDATE public.booking_payments SET
        stripe_charge_id = coalesce(p_charge_id, stripe_charge_id),
        wallet = coalesce(left(p_wallet, 30), wallet),
        card_brand = coalesce(left(p_card_brand, 30), card_brand),
        card_last4 = coalesce(CASE WHEN p_card_last4 ~ '^[0-9]{4}$' THEN p_card_last4 END, card_last4),
        authorization_expires_at = coalesce(p_capture_before, authorization_expires_at),
        failure_code = CASE WHEN p_status = 'requires_payment_method' AND p_failure_code IS NOT NULL
                            THEN left(p_failure_code, 80) ELSE failure_code END,
        amount_refunded_cents = greatest(amount_refunded_cents, least(v_refunded, amount_cents)),
        updated_at = now()
    WHERE id = v_payment.id
    RETURNING * INTO v_payment;

    v_from := v_booking.status;

    IF v_booking.status = 'awaiting_payment' AND (v_paid OR v_held) THEN
        -- The checkout is paid (or the card held): it becomes a real booking.
        UPDATE public.booking_payments SET
            status = CASE WHEN v_paid THEN 'paid' ELSE 'authorized' END,
            authorized_at = coalesce(authorized_at, now()),
            captured_at = CASE WHEN v_paid THEN coalesce(captured_at, now()) ELSE captured_at END,
            paid_at = CASE WHEN v_paid THEN coalesce(paid_at, now()) ELSE paid_at END,
            failure_code = NULL,
            updated_at = now()
        WHERE id = v_payment.id;

        UPDATE public.bookings SET
            status = CASE WHEN v_booking.requires_approval THEN 'pending' ELSE 'confirmed' END,
            payment_status = CASE WHEN v_paid THEN 'paid' ELSE 'authorized' END,
            -- A request must be answered before the hold on the card can
            -- lapse, and before the appointment.
            respond_by = CASE WHEN v_booking.requires_approval THEN least(
                v_booking.starts_at,
                now() + make_interval(hours => v_platform.card_request_response_hours),
                coalesce(p_capture_before, now() + interval '7 days') - interval '2 hours') END,
            responded_at = CASE WHEN v_booking.requires_approval THEN NULL ELSE responded_at END,
            updated_at = now()
        WHERE id = v_booking.id
        RETURNING * INTO v_booking;

        PERFORM private.on_booking_event(
            v_booking, CASE WHEN v_booking.status = 'pending' THEN 'requested' ELSE 'booked' END, 'client', v_from,
            jsonb_build_object('payment_method', 'card', 'payment_status', v_booking.payment_status,
                               'total_cents', v_booking.total_cents, 'payment_intent', p_payment_intent_id));

        -- An instant booking paid by a hold (shouldn't happen: its capture
        -- method is automatic) is captured straight away.
        IF v_held AND v_booking.status = 'confirmed' THEN
            PERFORM private.enqueue_job('capture_payment', 'capture:' || v_booking.id,
                jsonb_build_object('booking_id', v_booking.id, 'payment_intent_id', p_payment_intent_id),
                v_booking.id);
        END IF;

    ELSIF v_paid AND v_payment.status = 'authorized' AND v_booking.status IN ('pending', 'confirmed', 'completed') THEN
        -- The hold was captured.
        UPDATE public.booking_payments SET
            status = 'paid', captured_at = coalesce(captured_at, now()), paid_at = coalesce(paid_at, now()),
            updated_at = now()
        WHERE id = v_payment.id;
        UPDATE public.bookings SET payment_status = 'paid', updated_at = now()
        WHERE id = v_booking.id
        RETURNING * INTO v_booking;
        PERFORM private.on_booking_event(v_booking, 'payment_captured', 'system', v_from,
            jsonb_build_object('payment_intent', p_payment_intent_id));

    ELSIF (v_paid OR v_held) AND v_booking.status IN ('checkout_expired', 'declined', 'expired', 'cancelled')
          AND v_payment.status IN ('pending', 'void', 'authorized') THEN
        -- Money arrived for a booking that no longer exists (a checkout
        -- closed while the client was paying, or a request withdrawn as it
        -- was authorised): release the hold, or refund in full. Both jobs
        -- are idempotent, so repeated events change nothing.
        IF v_payment.status <> 'authorized' THEN
            PERFORM private.on_booking_event(v_booking, 'payment_after_close', 'system', v_from,
                jsonb_build_object('payment_intent', p_payment_intent_id, 'stripe_status', p_status));
        END IF;
        IF v_held THEN
            PERFORM private.enqueue_job(
                'cancel_payment_intent', 'hold-release:' || v_booking.id,
                jsonb_build_object('booking_id', v_booking.id, 'payment_intent_id', p_payment_intent_id,
                                   'mode', 'release'),
                v_booking.id);
            UPDATE public.booking_payments SET status = 'authorized', updated_at = now() WHERE id = v_payment.id;
        ELSIF v_received > v_refunded THEN
            PERFORM private.enqueue_job(
                'refund_payment', 'refund:orphan:' || p_payment_intent_id,
                jsonb_build_object('booking_id', v_booking.id, 'payment_intent_id', p_payment_intent_id,
                                   'amount_cents', v_received - v_refunded, 'reason', 'booking_closed'),
                v_booking.id);
            UPDATE public.booking_payments SET status = 'paid', paid_at = coalesce(paid_at, now()), updated_at = now()
            WHERE id = v_payment.id;
            UPDATE public.bookings SET payment_status = 'paid', updated_at = now()
            WHERE id = v_booking.id
            RETURNING * INTO v_booking;
        END IF;

    ELSIF p_status = 'canceled' THEN
        IF v_booking.status = 'awaiting_payment' THEN
            v_booking := private.close_checkout(v_booking, 'system', 'hold_expired');
        ELSIF v_payment.status = 'authorized' AND v_booking.status = 'pending' THEN
            -- The hold lapsed before the provider answered: the request lapses too.
            UPDATE public.bookings SET status = 'expired', payment_status = 'void', updated_at = now()
            WHERE id = v_booking.id
            RETURNING * INTO v_booking;
            PERFORM private.on_booking_event(v_booking, 'expired', 'system', v_from);
        ELSIF v_payment.status = 'authorized' AND v_booking.status IN ('confirmed', 'completed') THEN
            -- Accepted, but the hold lapsed before it was captured. Rare (the
            -- capture runs as soon as the provider accepts); admins resolve it.
            UPDATE public.bookings SET payment_status = 'failed', updated_at = now()
            WHERE id = v_booking.id
            RETURNING * INTO v_booking;
            PERFORM private.on_booking_event(v_booking, 'payment_failed', 'system', v_from,
                jsonb_build_object('payment_intent', p_payment_intent_id));
            PERFORM private.enqueue_job('admin_alert', 'alert:capture_lapsed:' || v_booking.id,
                jsonb_build_object(
                    'severity', 'high',
                    'subject', 'Card hold lapsed on a confirmed booking ' || v_booking.reference,
                    'body', 'The provider accepted booking ' || v_booking.reference
                            || ' but the hold on the client''s card was released before it was captured ('
                            || p_payment_intent_id || '). The client has not paid.',
                    'booking_id', v_booking.id),
                v_booking.id);
        END IF;
        UPDATE public.booking_payments
        SET status = CASE WHEN v_booking.payment_status = 'failed' THEN 'failed' ELSE 'void' END, updated_at = now()
        WHERE id = v_payment.id AND status IN ('pending', 'authorized');

    ELSIF v_received > 0 AND v_refunded > 0 AND v_payment.status IN ('paid', 'partially_refunded') THEN
        -- Refunds (from Myglo's refund jobs or the Stripe Dashboard).
        UPDATE public.booking_payments
        SET status = CASE WHEN v_refunded >= v_received THEN 'refunded' ELSE 'partially_refunded' END,
            updated_at = now()
        WHERE id = v_payment.id
        RETURNING * INTO v_payment;
        UPDATE public.bookings SET payment_status = v_payment.status, updated_at = now()
        WHERE id = v_booking.id AND payment_status IS DISTINCT FROM v_payment.status
        RETURNING * INTO v_booking;
        IF FOUND THEN
            PERFORM private.on_booking_event(v_booking, 'payment_refunded', 'system', v_booking.status,
                jsonb_build_object('payment_intent', p_payment_intent_id, 'amount_refunded_cents', v_refunded));
        END IF;
    END IF;

    SELECT * INTO v_booking FROM public.bookings WHERE id = v_booking.id;
    RETURN jsonb_build_object(
        'booking_id', v_booking.id,
        'status', v_booking.status,
        'payment_status', v_booking.payment_status);
END;
$function$;

-- ---------------------------------------------------------------------------
-- 8. Lifecycle changes for card bookings.
-- ---------------------------------------------------------------------------

-- Provider accepts or declines a pending request. Accepting a card request
-- captures the hold; declining releases it.
CREATE OR REPLACE FUNCTION public.respond_to_booking_request(
    p_booking_id uuid,
    p_accept     boolean,
    p_reason     text DEFAULT NULL)
RETURNS public.bookings
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
    v_uid     uuid := auth.uid();
    v_booking public.bookings%ROWTYPE;
    v_payment public.booking_payments%ROWTYPE;
    v_reason  text := nullif(btrim(p_reason), '');
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'not_authenticated' USING ERRCODE = '42501';
    END IF;
    IF p_accept IS NULL OR char_length(v_reason) > 300 THEN
        RAISE EXCEPTION 'invalid_request' USING ERRCODE = '22023';
    END IF;

    SELECT * INTO v_booking FROM public.bookings WHERE id = p_booking_id FOR UPDATE;
    IF NOT FOUND OR v_booking.provider_id IS DISTINCT FROM v_uid
       OR v_booking.status IN ('awaiting_payment', 'checkout_expired') THEN
        RAISE EXCEPTION 'booking_not_found' USING ERRCODE = 'P0002';
    END IF;
    IF v_booking.status <> 'pending' THEN
        RAISE EXCEPTION 'booking_not_pending' USING ERRCODE = 'P0001';
    END IF;
    IF coalesce(v_booking.respond_by, v_booking.starts_at) <= now() THEN
        RAISE EXCEPTION 'booking_request_expired' USING ERRCODE = 'P0001';
    END IF;
    v_payment := private.booking_payment(v_booking.id);

    IF p_accept THEN
        UPDATE public.bookings
        SET status = 'confirmed', responded_at = now(), updated_at = now()
        WHERE id = p_booking_id
        RETURNING * INTO v_booking;
        IF v_payment.status = 'authorized' AND v_payment.stripe_payment_intent_id IS NOT NULL THEN
            PERFORM private.enqueue_job('capture_payment', 'capture:' || v_booking.id,
                jsonb_build_object('booking_id', v_booking.id,
                                   'payment_intent_id', v_payment.stripe_payment_intent_id),
                v_booking.id);
        END IF;
        PERFORM private.on_booking_event(v_booking, 'confirmed', 'provider', 'pending');
    ELSE
        UPDATE public.bookings
        SET status = 'declined', decline_reason = v_reason, responded_at = now(),
            payment_status = 'void', updated_at = now()
        WHERE id = p_booking_id
        RETURNING * INTO v_booking;
        UPDATE public.booking_payments SET status = 'void', updated_at = now()
        WHERE id = v_payment.id AND status = 'pending';
        PERFORM private.release_card_hold(v_booking);
        PERFORM private.on_booking_event(v_booking, 'declined', 'provider', 'pending',
            jsonb_build_object('reason', v_reason));
    END IF;

    RETURN v_booking;
END;
$function$;

-- Cancels an upcoming booking (see the booking engine for the rules). For
-- card bookings: a held request has its hold released; a paid booking keeps
-- payment_status 'paid' until refunds are processed (payment lifecycle).
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
                    'window_hours', v_booking.cancellation_window_hours)::text;
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

    PERFORM private.on_booking_event(v_booking, 'cancelled', v_role, v_from,
        jsonb_build_object('reason', v_reason, 'late', v_late, 'fee_cents', v_fee));

    RETURN v_booking;
END;
$function$;

-- Provider marks an appointment that has started as done. Only cash is
-- collected in person; card bookings are already paid.
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
    v_cash    boolean;
    v_paid    boolean := coalesce(p_payment_received, false);
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
    v_cash := v_booking.payment_method = 'cash';
    v_paid := v_cash AND v_paid;

    UPDATE public.bookings
    SET status = 'completed',
        completed_at = now(),
        payment_status = CASE WHEN v_paid THEN 'paid' ELSE payment_status END,
        updated_at = now()
    WHERE id = p_booking_id
    RETURNING * INTO v_booking;

    IF v_paid THEN
        UPDATE public.booking_payments
        SET status = 'paid', paid_at = now(), recorded_by = v_uid, updated_at = now()
        WHERE booking_id = p_booking_id AND status = 'pending';
    END IF;

    PERFORM private.on_booking_event(v_booking, 'completed', 'provider', 'confirmed',
        jsonb_build_object('payment_received', v_paid));

    RETURN v_booking;
END;
$function$;

-- Provider records that the client didn't turn up. The provider's late fee is
-- recorded as owed; a card payment stays as it is until refunds are processed.
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

    PERFORM private.on_booking_event(v_booking, 'no_show', 'provider', 'confirmed',
        jsonb_build_object('fee_cents', v_fee));

    RETURN v_booking;
END;
$function$;

-- Provider records cash collected after the appointment was completed.
CREATE OR REPLACE FUNCTION public.record_cash_payment(p_booking_id uuid)
RETURNS public.bookings
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
    v_uid     uuid := auth.uid();
    v_booking public.bookings%ROWTYPE;
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'not_authenticated' USING ERRCODE = '42501';
    END IF;

    SELECT * INTO v_booking FROM public.bookings WHERE id = p_booking_id FOR UPDATE;
    IF NOT FOUND OR v_booking.provider_id IS DISTINCT FROM v_uid THEN
        RAISE EXCEPTION 'booking_not_found' USING ERRCODE = 'P0002';
    END IF;
    IF v_booking.payment_method <> 'cash' OR v_booking.status <> 'completed' OR v_booking.payment_status <> 'pending' THEN
        RAISE EXCEPTION 'payment_not_pending' USING ERRCODE = 'P0001';
    END IF;

    UPDATE public.bookings SET payment_status = 'paid', updated_at = now()
    WHERE id = p_booking_id
    RETURNING * INTO v_booking;

    UPDATE public.booking_payments
    SET status = 'paid', paid_at = now(), recorded_by = v_uid, updated_at = now()
    WHERE booking_id = p_booking_id AND status = 'pending';

    PERFORM private.on_booking_event(v_booking, 'payment_recorded', 'provider', v_booking.status,
        jsonb_build_object('method', v_booking.payment_method));

    RETURN v_booking;
END;
$function$;

-- ---------------------------------------------------------------------------
-- 9. Scheduled jobs.
-- ---------------------------------------------------------------------------

-- Requests nobody answered in time lapse (at respond_by, or the start time).
CREATE OR REPLACE FUNCTION private.expire_booking_requests()
RETURNS integer
LANGUAGE plpgsql
SET search_path TO ''
AS $function$
DECLARE
    v_booking public.bookings%ROWTYPE;
    v_count   integer := 0;
BEGIN
    FOR v_booking IN
        UPDATE public.bookings b
        SET status = 'expired', payment_status = 'void', updated_at = now()
        WHERE b.id IN (
            SELECT p.id FROM public.bookings p
            WHERE p.status = 'pending' AND coalesce(p.respond_by, p.starts_at) <= now()
            ORDER BY coalesce(p.respond_by, p.starts_at)
            LIMIT 200
            FOR UPDATE SKIP LOCKED)
        RETURNING b.*
    LOOP
        UPDATE public.booking_payments SET status = 'void', updated_at = now()
        WHERE booking_id = v_booking.id AND status = 'pending';
        PERFORM private.release_card_hold(v_booking);
        PERFORM private.on_booking_event(v_booking, 'expired', 'system', 'pending');
        v_count := v_count + 1;
    END LOOP;
    RETURN v_count;
END;
$function$;

-- Closes checkouts whose hold ran out. With a PaymentIntent, Stripe decides:
-- the cancel job applies a last-moment payment instead of cancelling it.
CREATE FUNCTION private.expire_checkouts()
RETURNS integer
LANGUAGE plpgsql
SET search_path TO ''
AS $function$
DECLARE
    v_booking public.bookings%ROWTYPE;
    v_pi      text;
    v_count   integer := 0;
BEGIN
    FOR v_booking IN
        SELECT b.* FROM public.bookings b
        WHERE b.status = 'awaiting_payment' AND b.hold_expires_at <= now()
        ORDER BY b.hold_expires_at
        LIMIT 200
        FOR UPDATE SKIP LOCKED
    LOOP
        v_pi := (private.booking_payment(v_booking.id)).stripe_payment_intent_id;
        IF v_pi IS NULL THEN
            PERFORM private.close_checkout(v_booking, 'system', 'hold_expired');
        ELSE
            PERFORM private.enqueue_job(
                'cancel_payment_intent', 'checkout-cancel:' || v_booking.id,
                jsonb_build_object('booking_id', v_booking.id, 'payment_intent_id', v_pi, 'mode', 'checkout'),
                v_booking.id);
        END IF;
        v_count := v_count + 1;
    END LOOP;
    RETURN v_count;
END;
$function$;

COMMENT ON FUNCTION private.expire_checkouts() IS
    'Closes card checkouts whose slot hold ran out (run by pg_cron every minute).';

SELECT cron.schedule('myglo-expire-checkouts', '* * * * *', 'SELECT private.expire_checkouts();');

-- Reminds providers about requests they haven't answered, timed against
-- when the request lapses (respond_by for card requests).
CREATE OR REPLACE FUNCTION private.queue_booking_request_reminders()
RETURNS integer
LANGUAGE plpgsql
SET search_path TO ''
AS $function$
DECLARE
    v_booking public.bookings%ROWTYPE;
    v_count   integer := 0;
BEGIN
    FOR v_booking IN
        UPDATE public.bookings b
        SET request_reminder_sent_at = now()
        WHERE b.id IN (
            SELECT p.id FROM public.bookings p
            WHERE p.status = 'pending'
              AND p.request_reminder_sent_at IS NULL
              AND coalesce(p.respond_by, p.starts_at) > now() + interval '15 minutes'
              AND now() >= p.created_at + least(interval '2 hours', (coalesce(p.respond_by, p.starts_at) - p.created_at) / 2)
            ORDER BY coalesce(p.respond_by, p.starts_at)
            LIMIT 500
            FOR UPDATE SKIP LOCKED)
        RETURNING b.*
    LOOP
        PERFORM private.on_booking_event(v_booking, 'request_reminder', 'system', 'pending');
        v_count := v_count + 1;
    END LOOP;

    -- request_reminder_sent_at < now() keeps the final reminder out of the
    -- run that sent the first (now() is fixed for the transaction).
    FOR v_booking IN
        UPDATE public.bookings b
        SET request_final_reminder_sent_at = now()
        WHERE b.id IN (
            SELECT p.id FROM public.bookings p
            WHERE p.status = 'pending'
              AND p.request_final_reminder_sent_at IS NULL
              AND p.request_reminder_sent_at < now()
              AND coalesce(p.respond_by, p.starts_at) > now() + interval '15 minutes'
              AND now() >= coalesce(p.respond_by, p.starts_at)
                           - least(interval '24 hours', (coalesce(p.respond_by, p.starts_at) - p.created_at) / 4)
            ORDER BY coalesce(p.respond_by, p.starts_at)
            LIMIT 500
            FOR UPDATE SKIP LOCKED)
        RETURNING b.*
    LOOP
        PERFORM private.on_booking_event(v_booking, 'request_final_reminder', 'system', 'pending');
        v_count := v_count + 1;
    END LOOP;

    RETURN v_count;
END;
$function$;

-- ---------------------------------------------------------------------------
-- 10. Notification copy for card bookings.
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
                               WHEN v_late AND v_fee > 0 THEN
                                   format(' This was a late cancellation: %s is owed under your policy.', private.format_aud(v_fee))
                               WHEN v_late THEN ' This was a late cancellation.'
                               ELSE ''
                           END,
                    p_booking.id, true, v_data);
                PERFORM private.notify(p_booking.client_id, v_actor, 'booking_cancelled', 'Booking cancelled',
                    format('You cancelled your %s booking with %s.', v_when, p_booking.provider_name)
                        || CASE
                               WHEN v_late AND v_fee > 0 THEN
                                   format(' It was within %s hours of the start, so a late-cancellation fee of %s is owed to %s.',
                                          p_booking.cancellation_window_hours, private.format_aud(v_fee), p_booking.provider_name)
                               WHEN v_late THEN
                                   format(' It was within %s hours of the start, so it''s recorded as a late cancellation.',
                                          p_booking.cancellation_window_hours)
                               WHEN p_from_status = 'pending' AND v_card THEN ' The hold on your card is being released.'
                               ELSE ''
                           END,
                    p_booking.id, true, v_data);
            ELSE
                PERFORM private.notify(p_booking.client_id, v_actor, 'booking_cancelled', 'Booking cancelled',
                    format('%s cancelled your %s booking.', p_booking.provider_name, v_when)
                        || CASE WHEN v_reason IS NOT NULL THEN format(' Their note: "%s"', v_reason) ELSE '' END
                        || ' You won''t be charged.',
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
                    || CASE WHEN v_fee > 0
                            THEN format(' Under their policy, %s is owed.', private.format_aud(v_fee))
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
-- 11. App configuration: what the booking screens need to know up front.
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.get_app_config()
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO ''
AS $function$
    SELECT jsonb_build_object(
        'map_provider', s.map_provider,
        'card_max_advance_days', s.card_max_advance_days,
        'checkout_hold_minutes', s.checkout_hold_minutes)
    FROM private.platform_settings s WHERE s.id;
$function$;

-- ---------------------------------------------------------------------------
-- 12. Privileges.
-- ---------------------------------------------------------------------------

REVOKE ALL ON FUNCTION private.booking_payment(uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION private.close_checkout(public.bookings, text, text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION private.release_card_hold(public.bookings) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION private.expire_checkouts() FROM PUBLIC, anon, authenticated;

REVOKE ALL ON FUNCTION public.begin_card_checkout(uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.get_checkout_payment_intent(uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.abandon_checkout(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.begin_card_checkout(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_checkout_payment_intent(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.abandon_checkout(uuid) TO authenticated;

REVOKE ALL ON FUNCTION public.record_payment_intent(uuid, text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.apply_payment_intent_state(text, text, integer, integer, integer, text, timestamptz, text, text, text, text)
    FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.record_payment_intent(uuid, text) TO service_role;
GRANT EXECUTE ON FUNCTION public.apply_payment_intent_state(text, text, integer, integer, integer, text, timestamptz, text, text, text, text)
    TO service_role;
