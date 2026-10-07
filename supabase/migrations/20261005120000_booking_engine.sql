-- Booking engine: provider availability, atomic booking creation with
-- double-booking protection, the booking lifecycle and realtime signals.
--
-- Time handling
--   * Every instant is stored as timestamptz (UTC on the wire).
--   * Each provider has a time_zone (default Australia/Brisbane: AEST, UTC+10
--     all year round; Queensland has no daylight saving). Working hours are
--     wall-clock times in that zone and are converted with AT TIME ZONE, so a
--     zone that does observe DST is handled correctly too.
--   * Read models expose both the instant and the provider-local wall clock
--     (`*_local`), so the app never has to guess the provider's offset.
--
-- Money is stored in whole cents (AUD). Prices are always taken from
-- public.services at booking time, never from the client.
--
-- Writes to bookings only happen through the SECURITY DEFINER RPCs below;
-- clients and providers can only read the bookings they are a party to.

CREATE EXTENSION IF NOT EXISTS btree_gist WITH SCHEMA extensions;

-- Internal tables and helpers that must never be reachable through the API.
CREATE SCHEMA IF NOT EXISTS private;
REVOKE ALL ON SCHEMA private FROM PUBLIC, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 1. Platform configuration (admin-controlled once the admin panel exists).
-- ---------------------------------------------------------------------------

CREATE TABLE private.platform_settings (
    id                   boolean      PRIMARY KEY DEFAULT true,
    -- Commission owed by the provider on each booking. Never added to what the
    -- client pays.
    platform_fee_percent numeric(5,2) NOT NULL DEFAULT 0,
    -- New providers pay no commission for this many days after onboarding.
    fee_free_days        integer      NOT NULL DEFAULT 0,
    updated_at           timestamptz  NOT NULL DEFAULT now(),
    CONSTRAINT platform_settings_singleton CHECK (id),
    CONSTRAINT platform_settings_fee CHECK (platform_fee_percent BETWEEN 0 AND 100),
    CONSTRAINT platform_settings_fee_free_days CHECK (fee_free_days BETWEEN 0 AND 3650)
);

COMMENT ON TABLE private.platform_settings IS
    'Single-row platform configuration. Fees are computed server-side only and copied onto each booking.';

INSERT INTO private.platform_settings (id) VALUES (true) ON CONFLICT (id) DO NOTHING;

-- ---------------------------------------------------------------------------
-- 2. Provider booking settings, working hours and time off.
-- ---------------------------------------------------------------------------

CREATE TABLE public.provider_booking_settings (
    provider_id               uuid         PRIMARY KEY REFERENCES public.profiles (id) ON DELETE CASCADE,
    time_zone                 text         NOT NULL DEFAULT 'Australia/Brisbane',
    accepts_bookings          boolean      NOT NULL DEFAULT true,
    -- false: bookings are confirmed instantly; true: they wait for approval.
    requires_approval         boolean      NOT NULL DEFAULT false,
    slot_interval_minutes     smallint     NOT NULL DEFAULT 15,
    buffer_minutes            smallint     NOT NULL DEFAULT 0,
    min_notice_minutes        integer      NOT NULL DEFAULT 120,
    max_advance_days          smallint     NOT NULL DEFAULT 60,
    -- Clients may cancel for free until this many hours before the start.
    cancellation_window_hours smallint     NOT NULL DEFAULT 24,
    -- Share of the booking total recorded as owed for late cancellations and
    -- no-shows. Cash bookings track it; nothing is charged.
    cancellation_fee_percent  smallint     NOT NULL DEFAULT 0,
    offers_studio             boolean      NOT NULL DEFAULT true,
    offers_mobile             boolean      NOT NULL DEFAULT false,
    -- Furthest a mobile provider travels from their business location. NULL
    -- means no limit.
    travel_radius_km          numeric(5,1),
    -- Bumped whenever anything that affects availability changes (settings,
    -- working hours, time off, bookings). Clients subscribe to this row over
    -- realtime and refetch slots when it moves; it reveals nothing private.
    availability_version      bigint       NOT NULL DEFAULT 0,
    created_at                timestamptz  NOT NULL DEFAULT now(),
    updated_at                timestamptz  NOT NULL DEFAULT now(),
    CONSTRAINT pbs_slot_interval CHECK (slot_interval_minutes IN (5, 10, 15, 20, 30, 45, 60)),
    CONSTRAINT pbs_buffer CHECK (buffer_minutes BETWEEN 0 AND 120),
    CONSTRAINT pbs_min_notice CHECK (min_notice_minutes BETWEEN 0 AND 20160),
    CONSTRAINT pbs_max_advance CHECK (max_advance_days BETWEEN 1 AND 365),
    CONSTRAINT pbs_cancellation_window CHECK (cancellation_window_hours BETWEEN 0 AND 168),
    CONSTRAINT pbs_cancellation_fee CHECK (cancellation_fee_percent BETWEEN 0 AND 100),
    CONSTRAINT pbs_travel_radius CHECK (travel_radius_km IS NULL OR travel_radius_km BETWEEN 1 AND 100),
    CONSTRAINT pbs_some_location CHECK (offers_studio OR offers_mobile)
);

COMMENT ON TABLE public.provider_booking_settings IS
    'Public booking rules for each provider. Readable by signed-in users; providers edit their own row.';

-- Wall-clock opening hours per ISO weekday (1 = Monday), in the provider's
-- time zone. A day can have several ranges (e.g. a lunch break).
CREATE TABLE public.provider_working_hours (
    id          uuid     PRIMARY KEY DEFAULT gen_random_uuid(),
    provider_id uuid     NOT NULL REFERENCES public.profiles (id) ON DELETE CASCADE,
    weekday     smallint NOT NULL,
    opens_at    time     NOT NULL,
    closes_at   time     NOT NULL,
    CONSTRAINT pwh_weekday CHECK (weekday BETWEEN 1 AND 7),
    CONSTRAINT pwh_order CHECK (closes_at > opens_at),
    -- Ranges on the same day may touch but never overlap.
    CONSTRAINT pwh_no_overlap EXCLUDE USING gist (
        provider_id WITH =,
        weekday WITH =,
        tsrange(DATE '2000-01-03' + opens_at, DATE '2000-01-03' + closes_at, '[)') WITH &&
    )
);

CREATE INDEX provider_working_hours_provider_idx ON public.provider_working_hours (provider_id, weekday, opens_at);

-- Blocked-out time (holidays, appointments outside Myglo, breaks). Private to
-- the provider; clients only ever see its effect on availability.
CREATE TABLE public.provider_time_off (
    id          uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    provider_id uuid        NOT NULL REFERENCES public.profiles (id) ON DELETE CASCADE,
    starts_at   timestamptz NOT NULL,
    ends_at     timestamptz NOT NULL,
    reason      text,
    created_at  timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT pto_order CHECK (ends_at > starts_at),
    CONSTRAINT pto_max_length CHECK (ends_at - starts_at <= interval '366 days'),
    CONSTRAINT pto_reason_length CHECK (reason IS NULL OR char_length(reason) <= 120)
);

CREATE INDEX provider_time_off_range_idx
    ON public.provider_time_off USING gist (provider_id, tstzrange(starts_at, ends_at, '[)'));

-- ---------------------------------------------------------------------------
-- 3. Bookings.
-- ---------------------------------------------------------------------------

CREATE TABLE public.bookings (
    -- Generated by the client so a retried request can't create a duplicate.
    id                        uuid          PRIMARY KEY,
    -- Short human-friendly code shown to clients and providers, e.g. MG-7K3P9Q.
    reference                 text          NOT NULL UNIQUE,
    -- SET NULL keeps the other party's record if an account is deleted; the
    -- name/phone snapshots below remain for their history.
    client_id                 uuid          REFERENCES public.profiles (id) ON DELETE SET NULL,
    provider_id               uuid          REFERENCES public.profiles (id) ON DELETE SET NULL,
    status                    text          NOT NULL,
    starts_at                 timestamptz   NOT NULL,
    ends_at                   timestamptz   NOT NULL,
    -- ends_at plus the provider's buffer: the provider is unavailable until then.
    blocked_until             timestamptz   NOT NULL,
    time_zone                 text          NOT NULL,
    duration_minutes          integer       NOT NULL,
    buffer_minutes            smallint      NOT NULL DEFAULT 0,
    location_type             text          NOT NULL,
    -- Where the appointment happens: the studio address (snapshot) or the
    -- client's address.
    address_text              text          NOT NULL,
    -- Structured client address ({line1, unit, suburb, state, postcode}).
    address                   jsonb,
    access_notes              text,
    -- Client location for mobile bookings. Visible only to the two parties.
    location                  public.geography(Point, 4326),
    distance_km               numeric(6,2),
    provider_name             text          NOT NULL,
    client_name               text          NOT NULL,
    client_phone              text          NOT NULL,
    client_notes              text,
    subtotal_cents            integer       NOT NULL,
    -- Commission owed by the provider (see private.platform_settings). Not
    -- part of what the client pays.
    platform_fee_cents        integer       NOT NULL DEFAULT 0,
    -- What the client pays.
    total_cents               integer       NOT NULL,
    currency                  text          NOT NULL DEFAULT 'AUD',
    payment_method            text          NOT NULL,
    payment_status            text          NOT NULL DEFAULT 'pending',
    -- Policy snapshots taken at booking time.
    requires_approval         boolean       NOT NULL,
    cancellation_window_hours smallint      NOT NULL,
    cancellation_fee_percent  smallint      NOT NULL,
    decline_reason            text,
    responded_at              timestamptz,
    cancelled_by              text,
    cancellation_reason       text,
    cancelled_at              timestamptz,
    late_cancellation         boolean       NOT NULL DEFAULT false,
    -- Fee recorded as owed for a late cancellation or no-show.
    cancellation_fee_cents    integer       NOT NULL DEFAULT 0,
    completed_at              timestamptz,
    reminder_day_sent_at      timestamptz,
    reminder_hour_sent_at     timestamptz,
    created_at                timestamptz   NOT NULL DEFAULT now(),
    updated_at                timestamptz   NOT NULL DEFAULT now(),
    CONSTRAINT bookings_status CHECK (
        status IN ('pending', 'confirmed', 'declined', 'cancelled', 'completed', 'no_show', 'expired')),
    CONSTRAINT bookings_times CHECK (ends_at > starts_at AND blocked_until >= ends_at),
    CONSTRAINT bookings_duration CHECK (duration_minutes BETWEEN 1 AND 1440),
    CONSTRAINT bookings_buffer CHECK (buffer_minutes BETWEEN 0 AND 120),
    CONSTRAINT bookings_location_type CHECK (location_type IN ('studio', 'client')),
    CONSTRAINT bookings_client_location CHECK (location_type = 'studio' OR location IS NOT NULL),
    CONSTRAINT bookings_amounts CHECK (
        subtotal_cents >= 0 AND platform_fee_cents >= 0 AND total_cents >= 0 AND cancellation_fee_cents >= 0),
    CONSTRAINT bookings_currency CHECK (currency = 'AUD'),
    CONSTRAINT bookings_payment_method CHECK (
        payment_method IN ('cash', 'card', 'apple_pay', 'google_pay', 'afterpay')),
    CONSTRAINT bookings_payment_status CHECK (payment_status IN ('pending', 'paid', 'refunded', 'void')),
    CONSTRAINT bookings_cancelled_by CHECK (cancelled_by IS NULL OR cancelled_by IN ('client', 'provider', 'system')),
    CONSTRAINT bookings_text_lengths CHECK (
        char_length(client_notes) <= 500
        AND char_length(access_notes) <= 300
        AND char_length(decline_reason) <= 300
        AND char_length(cancellation_reason) <= 300
        AND char_length(address_text) <= 400),
    -- The hard guarantee against double booking: two active bookings of the
    -- same provider can never overlap (buffer included).
    CONSTRAINT bookings_no_overlap EXCLUDE USING gist (
        provider_id WITH =,
        tstzrange(starts_at, blocked_until, '[)') WITH &&
    ) WHERE (status IN ('pending', 'confirmed'))
);

COMMENT ON TABLE public.bookings IS
    'Client bookings. Written only through RPCs (create_booking, respond_to_booking_request, cancel_booking, complete_booking, mark_booking_no_show, record_cash_payment).';

CREATE INDEX bookings_provider_starts_idx ON public.bookings (provider_id, starts_at);
CREATE INDEX bookings_client_starts_idx ON public.bookings (client_id, starts_at DESC);
CREATE INDEX bookings_pending_starts_idx ON public.bookings (starts_at) WHERE status = 'pending';
CREATE INDEX bookings_reminder_idx ON public.bookings (starts_at)
    WHERE status = 'confirmed' AND reminder_hour_sent_at IS NULL;

-- Services as they were when booked, so later edits never rewrite history.
CREATE TABLE public.booking_items (
    id               uuid     PRIMARY KEY DEFAULT gen_random_uuid(),
    booking_id       uuid     NOT NULL REFERENCES public.bookings (id) ON DELETE CASCADE,
    service_id       uuid     REFERENCES public.services (id) ON DELETE SET NULL,
    position         smallint NOT NULL,
    service_name     text     NOT NULL,
    category         text,
    duration_minutes integer  NOT NULL CHECK (duration_minutes > 0),
    price_cents      integer  NOT NULL CHECK (price_cents >= 0),
    CONSTRAINT booking_items_position UNIQUE (booking_id, position)
);

CREATE INDEX booking_items_service_idx ON public.booking_items (service_id);

-- Payment ledger. Cash bookings start with one pending row; card payments
-- (Stripe) will add their own rows later.
CREATE TABLE public.booking_payments (
    id                 uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    booking_id         uuid        NOT NULL REFERENCES public.bookings (id) ON DELETE CASCADE,
    method             text        NOT NULL,
    status             text        NOT NULL DEFAULT 'pending',
    amount_cents       integer     NOT NULL CHECK (amount_cents >= 0),
    platform_fee_cents integer     NOT NULL DEFAULT 0 CHECK (platform_fee_cents >= 0),
    currency           text        NOT NULL DEFAULT 'AUD' CHECK (currency = 'AUD'),
    paid_at            timestamptz,
    recorded_by        uuid        REFERENCES public.profiles (id) ON DELETE SET NULL,
    external_reference text,
    created_at         timestamptz NOT NULL DEFAULT now(),
    updated_at         timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT booking_payments_method CHECK (method IN ('cash', 'card', 'apple_pay', 'google_pay', 'afterpay')),
    CONSTRAINT booking_payments_status CHECK (status IN ('pending', 'paid', 'refunded', 'void', 'failed'))
);

CREATE INDEX booking_payments_booking_idx ON public.booking_payments (booking_id);
CREATE INDEX booking_payments_recorded_by_idx ON public.booking_payments (recorded_by);

-- Append-only audit trail of everything that happens to a booking.
CREATE TABLE public.booking_events (
    id          bigint      GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    booking_id  uuid        NOT NULL REFERENCES public.bookings (id) ON DELETE CASCADE,
    event       text        NOT NULL,
    actor_id    uuid        REFERENCES public.profiles (id) ON DELETE SET NULL,
    actor_role  text        NOT NULL,
    from_status text,
    to_status   text,
    details     jsonb       NOT NULL DEFAULT '{}'::jsonb,
    created_at  timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT booking_events_actor_role CHECK (actor_role IN ('client', 'provider', 'system'))
);

CREATE INDEX booking_events_booking_idx ON public.booking_events (booking_id, created_at);
CREATE INDEX booking_events_actor_idx ON public.booking_events (actor_id);

-- ---------------------------------------------------------------------------
-- 4. Row level security and grants.
-- ---------------------------------------------------------------------------

ALTER TABLE public.provider_booking_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.provider_working_hours ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.provider_time_off ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bookings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.booking_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.booking_payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.booking_events ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON public.provider_booking_settings, public.provider_working_hours, public.provider_time_off,
    public.bookings, public.booking_items, public.booking_payments, public.booking_events
    FROM anon, authenticated;

-- Booking settings: public rules, editable by the owning provider. Only the
-- listed columns can be written; the version counter and time zone can't.
GRANT SELECT ON public.provider_booking_settings TO authenticated;
GRANT UPDATE (
    accepts_bookings, requires_approval, slot_interval_minutes, buffer_minutes, min_notice_minutes,
    max_advance_days, cancellation_window_hours, cancellation_fee_percent, offers_studio, offers_mobile,
    travel_radius_km
) ON public.provider_booking_settings TO authenticated;

CREATE POLICY "Booking settings are visible to signed-in users" ON public.provider_booking_settings
    FOR SELECT TO authenticated
    USING (true);

CREATE POLICY "Providers can update own booking settings" ON public.provider_booking_settings
    FOR UPDATE TO authenticated
    USING ((SELECT auth.uid()) = provider_id)
    WITH CHECK ((SELECT auth.uid()) = provider_id);

-- Working hours: public opening hours. Written only via set_working_hours.
GRANT SELECT ON public.provider_working_hours TO authenticated;

CREATE POLICY "Working hours are visible to signed-in users" ON public.provider_working_hours
    FOR SELECT TO authenticated
    USING (true);

-- Time off: private to the provider.
GRANT SELECT, INSERT, UPDATE, DELETE ON public.provider_time_off TO authenticated;

CREATE POLICY "Providers can view own time off" ON public.provider_time_off
    FOR SELECT TO authenticated
    USING ((SELECT auth.uid()) = provider_id);

CREATE POLICY "Providers can add own time off" ON public.provider_time_off
    FOR INSERT TO authenticated
    WITH CHECK ((SELECT auth.uid()) = provider_id);

CREATE POLICY "Providers can update own time off" ON public.provider_time_off
    FOR UPDATE TO authenticated
    USING ((SELECT auth.uid()) = provider_id)
    WITH CHECK ((SELECT auth.uid()) = provider_id);

CREATE POLICY "Providers can delete own time off" ON public.provider_time_off
    FOR DELETE TO authenticated
    USING ((SELECT auth.uid()) = provider_id);

-- Bookings and their children: readable by the client and the provider only.
GRANT SELECT ON public.bookings, public.booking_items, public.booking_payments, public.booking_events TO authenticated;

CREATE POLICY "Parties can view their bookings" ON public.bookings
    FOR SELECT TO authenticated
    USING ((SELECT auth.uid()) IN (client_id, provider_id));

-- The subqueries run under the bookings policy above, so they only match
-- bookings the caller is a party to.
CREATE POLICY "Parties can view booking items" ON public.booking_items
    FOR SELECT TO authenticated
    USING (EXISTS (SELECT 1 FROM public.bookings b WHERE b.id = booking_id));

CREATE POLICY "Parties can view booking payments" ON public.booking_payments
    FOR SELECT TO authenticated
    USING (EXISTS (SELECT 1 FROM public.bookings b WHERE b.id = booking_id));

CREATE POLICY "Parties can view booking events" ON public.booking_events
    FOR SELECT TO authenticated
    USING (EXISTS (SELECT 1 FROM public.bookings b WHERE b.id = booking_id));

-- ---------------------------------------------------------------------------
-- 5. Read model.
-- ---------------------------------------------------------------------------

-- Runs with the caller's privileges (security_invoker), so the RLS above
-- decides which rows come back. Names and avatars come from the masked
-- public_profiles view. A request still pending after its start time reads as
-- expired even before the expiry job has run.
CREATE VIEW public.booking_details WITH (security_invoker = true) AS
SELECT
    b.id,
    b.reference,
    b.client_id,
    b.provider_id,
    CASE WHEN b.status = 'pending' AND b.starts_at <= now() THEN 'expired' ELSE b.status END AS status,
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
    b.starts_at - make_interval(hours => b.cancellation_window_hours) AS free_cancellation_until,
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
    ), '[]'::jsonb) AS items
FROM public.bookings b
LEFT JOIN public.public_profiles pp ON pp.id = b.provider_id
LEFT JOIN public.public_profiles cp ON cp.id = b.client_id;

REVOKE ALL ON public.booking_details FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.booking_details TO authenticated;

COMMENT ON VIEW public.booking_details IS
    'Bookings shaped for the app (security_invoker: callers only see their own). starts_at_local/ends_at_local are wall-clock times in the provider''s time zone.';

-- ---------------------------------------------------------------------------
-- 6. Internal helpers.
-- ---------------------------------------------------------------------------

-- Validates the requested services and returns them priced from the database,
-- in the order the client chose them.
CREATE FUNCTION private.resolve_services(p_provider_id uuid, p_service_ids uuid[])
RETURNS TABLE (ord integer, service_id uuid, service_name text, category text, duration_minutes integer, price_cents integer)
LANGUAGE plpgsql
STABLE
SET search_path TO ''
AS $function$
#variable_conflict use_column
DECLARE
    v_requested integer := coalesce(cardinality(p_service_ids), 0);
    v_found     integer;
BEGIN
    IF v_requested = 0 OR v_requested > 10
       OR v_requested <> (SELECT count(DISTINCT x) FROM unnest(p_service_ids) AS x) THEN
        RAISE EXCEPTION 'invalid_services' USING ERRCODE = '22023',
            DETAIL = 'Choose between 1 and 10 different services.';
    END IF;

    RETURN QUERY
    SELECT u.ord::integer,
           s.id,
           s.name,
           nullif(btrim(s.category), ''),
           s.duration_minutes,
           round(s.price * 100)::integer
    FROM unnest(p_service_ids) WITH ORDINALITY AS u(id, ord)
    JOIN public.services s ON s.id = u.id AND s.provider_id = p_provider_id
    WHERE s.price IS NOT NULL AND s.price >= 0 AND s.duration_minutes > 0
    ORDER BY u.ord;

    GET DIAGNOSTICS v_found = ROW_COUNT;
    IF v_found <> v_requested THEN
        RAISE EXCEPTION 'invalid_services' USING ERRCODE = '22023',
            DETAIL = 'One or more services are no longer offered by this provider.';
    END IF;
END;
$function$;

-- Every bookable start time for a provider between two local dates, for an
-- appointment of p_duration_minutes. Applies working hours, time off, active
-- bookings (with buffers), minimum notice and the booking window.
CREATE FUNCTION private.available_slots(
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
            AND b.status IN ('pending', 'confirmed')
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

-- Short, unambiguous booking code: "MG-" plus 6 characters without 0/O/1/I/L/U.
CREATE FUNCTION private.new_booking_reference()
RETURNS text
LANGUAGE plpgsql
VOLATILE
SET search_path TO ''
AS $function$
DECLARE
    v_alphabet constant text := '23456789ABCDEFGHJKMNPQRSTVWXYZ';
    v_bytes     bytea;
    v_reference text;
BEGIN
    LOOP
        v_bytes := extensions.gen_random_bytes(6);
        v_reference := 'MG-';
        FOR i IN 0..5 LOOP
            v_reference := v_reference || substr(v_alphabet, (get_byte(v_bytes, i) % 30) + 1, 1);
        END LOOP;
        EXIT WHEN NOT EXISTS (SELECT 1 FROM public.bookings WHERE reference = v_reference);
    END LOOP;
    RETURN v_reference;
END;
$function$;

-- Phone numbers are kept as digits with an optional leading +.
CREATE FUNCTION private.normalize_phone(p_phone text)
RETURNS text
LANGUAGE plpgsql
IMMUTABLE
SET search_path TO ''
AS $function$
DECLARE
    v_phone text := regexp_replace(coalesce(p_phone, ''), '[\s().-]', '', 'g');
BEGIN
    IF v_phone !~ '^\+?[0-9]{8,15}$' THEN
        RAISE EXCEPTION 'phone_invalid' USING ERRCODE = '22023',
            DETAIL = 'Enter a contact number with 8 to 15 digits.';
    END IF;
    RETURN v_phone;
END;
$function$;

-- Validates a client address ({line1, unit, suburb, state, postcode}) and
-- returns it formatted Australian-style: "Unit 3, 12 Smith St, Southport QLD 4215".
CREATE FUNCTION private.format_client_address(p_address jsonb)
RETURNS text
LANGUAGE plpgsql
IMMUTABLE
SET search_path TO ''
AS $function$
DECLARE
    v_line1    text := btrim(coalesce(p_address ->> 'line1', ''));
    v_unit     text := btrim(coalesce(p_address ->> 'unit', ''));
    v_suburb   text := btrim(coalesce(p_address ->> 'suburb', ''));
    v_state    text := upper(btrim(coalesce(p_address ->> 'state', '')));
    v_postcode text := btrim(coalesce(p_address ->> 'postcode', ''));
BEGIN
    IF p_address IS NULL OR jsonb_typeof(p_address) <> 'object'
       OR char_length(v_line1) NOT BETWEEN 3 AND 120
       OR char_length(v_unit) > 30
       OR char_length(v_suburb) NOT BETWEEN 2 AND 60
       OR v_state NOT IN ('QLD', 'NSW', 'VIC', 'TAS', 'SA', 'WA', 'NT', 'ACT')
       OR v_postcode !~ '^[0-9]{4}$' THEN
        RAISE EXCEPTION 'address_invalid' USING ERRCODE = '22023',
            DETAIL = 'Enter a street address, suburb, state and 4-digit postcode.';
    END IF;
    RETURN concat_ws(', ', nullif(v_unit, ''), v_line1, v_suburb || ' ' || v_state || ' ' || v_postcode);
END;
$function$;

-- "$45", "$45.50", "$1,250" (matches Formatters.aud in the app).
CREATE FUNCTION private.format_aud(p_cents integer)
RETURNS text
LANGUAGE sql
IMMUTABLE
SET search_path TO ''
AS $function$
    SELECT CASE
        WHEN p_cents % 100 = 0 THEN '$' || to_char(p_cents / 100, 'FM999,999,990')
        ELSE '$' || to_char(p_cents / 100.0, 'FM999,999,990.00')
    END;
$function$;

-- Bumps the availability signal of the given providers (see
-- provider_booking_settings.availability_version).
CREATE FUNCTION private.bump_availability(p_provider_ids uuid[])
RETURNS void
LANGUAGE sql
SET search_path TO ''
AS $function$
    UPDATE public.provider_booking_settings
    SET availability_version = availability_version + 1
    WHERE provider_id = ANY (p_provider_ids);
$function$;

-- ---------------------------------------------------------------------------
-- 7. Triggers.
-- ---------------------------------------------------------------------------

-- Every provider gets a settings row (defaults) as soon as they have the role.
CREATE FUNCTION private.ensure_provider_booking_settings()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
BEGIN
    IF NEW.role = 'provider' THEN
        INSERT INTO public.provider_booking_settings (provider_id)
        VALUES (NEW.id)
        ON CONFLICT (provider_id) DO NOTHING;
    END IF;
    RETURN NULL;
END;
$function$;

CREATE TRIGGER profiles_ensure_booking_settings
    AFTER INSERT OR UPDATE OF role ON public.profiles
    FOR EACH ROW EXECUTE FUNCTION private.ensure_provider_booking_settings();

INSERT INTO public.provider_booking_settings (provider_id)
SELECT id FROM public.profiles WHERE role = 'provider'
ON CONFLICT (provider_id) DO NOTHING;

-- Validates provider edits and signals clients that availability may have
-- changed. System bumps (which only move the version) pass straight through.
CREATE FUNCTION private.before_booking_settings_update()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
BEGIN
    IF NEW.provider_id IS DISTINCT FROM OLD.provider_id OR NEW.created_at IS DISTINCT FROM OLD.created_at THEN
        RAISE EXCEPTION 'Protected booking settings column cannot be modified' USING ERRCODE = '42501';
    END IF;
    IF NEW.time_zone IS DISTINCT FROM OLD.time_zone
       AND NOT EXISTS (SELECT 1 FROM pg_catalog.pg_timezone_names WHERE name = NEW.time_zone) THEN
        RAISE EXCEPTION 'invalid_time_zone' USING ERRCODE = '22023';
    END IF;
    IF NEW.offers_mobile AND NEW.travel_radius_km IS NOT NULL
       AND (NEW.offers_mobile IS DISTINCT FROM OLD.offers_mobile
            OR NEW.travel_radius_km IS DISTINCT FROM OLD.travel_radius_km)
       AND NOT EXISTS (
           SELECT 1 FROM public.profiles p WHERE p.id = NEW.provider_id AND p.coordinates IS NOT NULL) THEN
        RAISE EXCEPTION 'service_area_needs_location' USING ERRCODE = '22023',
            DETAIL = 'Set your business location before limiting how far you travel.';
    END IF;
    IF NEW.availability_version = OLD.availability_version THEN
        NEW.availability_version := OLD.availability_version + 1;
        NEW.updated_at := now();
    END IF;
    RETURN NEW;
END;
$function$;

CREATE TRIGGER provider_booking_settings_before_update
    BEFORE UPDATE ON public.provider_booking_settings
    FOR EACH ROW EXECUTE FUNCTION private.before_booking_settings_update();

-- Only providers can block out time.
CREATE FUNCTION private.validate_time_off()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM public.profiles WHERE id = NEW.provider_id AND role = 'provider') THEN
        RAISE EXCEPTION 'providers_only' USING ERRCODE = '42501';
    END IF;
    NEW.reason := nullif(btrim(NEW.reason), '');
    RETURN NEW;
END;
$function$;

CREATE TRIGGER provider_time_off_validate
    BEFORE INSERT OR UPDATE ON public.provider_time_off
    FOR EACH ROW EXECUTE FUNCTION private.validate_time_off();

-- Availability signals. Statement-level so a schedule replaced in one call
-- bumps each provider once.
CREATE FUNCTION private.signal_availability_from_new_rows()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
BEGIN
    PERFORM private.bump_availability(ARRAY(SELECT DISTINCT provider_id FROM new_rows WHERE provider_id IS NOT NULL));
    RETURN NULL;
END;
$function$;

CREATE FUNCTION private.signal_availability_from_old_rows()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
BEGIN
    PERFORM private.bump_availability(ARRAY(SELECT DISTINCT provider_id FROM old_rows WHERE provider_id IS NOT NULL));
    RETURN NULL;
END;
$function$;

CREATE FUNCTION private.signal_availability_from_changed_rows()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
BEGIN
    PERFORM private.bump_availability(ARRAY(
        SELECT provider_id FROM old_rows WHERE provider_id IS NOT NULL
        UNION
        SELECT provider_id FROM new_rows WHERE provider_id IS NOT NULL));
    RETURN NULL;
END;
$function$;

-- Bookings only matter when their time or active status changes.
CREATE FUNCTION private.signal_availability_from_booking_changes()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
BEGIN
    PERFORM private.bump_availability(ARRAY(
        SELECT DISTINCT n.provider_id
        FROM new_rows n
        JOIN old_rows o ON o.id = n.id
        WHERE n.provider_id IS NOT NULL
          AND (n.status, n.starts_at, n.blocked_until) IS DISTINCT FROM (o.status, o.starts_at, o.blocked_until)));
    RETURN NULL;
END;
$function$;

CREATE TRIGGER provider_working_hours_signal_insert
    AFTER INSERT ON public.provider_working_hours
    REFERENCING NEW TABLE AS new_rows
    FOR EACH STATEMENT EXECUTE FUNCTION private.signal_availability_from_new_rows();

CREATE TRIGGER provider_working_hours_signal_update
    AFTER UPDATE ON public.provider_working_hours
    REFERENCING OLD TABLE AS old_rows NEW TABLE AS new_rows
    FOR EACH STATEMENT EXECUTE FUNCTION private.signal_availability_from_changed_rows();

CREATE TRIGGER provider_working_hours_signal_delete
    AFTER DELETE ON public.provider_working_hours
    REFERENCING OLD TABLE AS old_rows
    FOR EACH STATEMENT EXECUTE FUNCTION private.signal_availability_from_old_rows();

CREATE TRIGGER provider_time_off_signal_insert
    AFTER INSERT ON public.provider_time_off
    REFERENCING NEW TABLE AS new_rows
    FOR EACH STATEMENT EXECUTE FUNCTION private.signal_availability_from_new_rows();

CREATE TRIGGER provider_time_off_signal_update
    AFTER UPDATE ON public.provider_time_off
    REFERENCING OLD TABLE AS old_rows NEW TABLE AS new_rows
    FOR EACH STATEMENT EXECUTE FUNCTION private.signal_availability_from_changed_rows();

CREATE TRIGGER provider_time_off_signal_delete
    AFTER DELETE ON public.provider_time_off
    REFERENCING OLD TABLE AS old_rows
    FOR EACH STATEMENT EXECUTE FUNCTION private.signal_availability_from_old_rows();

CREATE TRIGGER bookings_signal_insert
    AFTER INSERT ON public.bookings
    REFERENCING NEW TABLE AS new_rows
    FOR EACH STATEMENT EXECUTE FUNCTION private.signal_availability_from_new_rows();

CREATE TRIGGER bookings_signal_update
    AFTER UPDATE ON public.bookings
    REFERENCING OLD TABLE AS old_rows NEW TABLE AS new_rows
    FOR EACH STATEMENT EXECUTE FUNCTION private.signal_availability_from_booking_changes();

-- Each booking change is recorded in booking_events by the RPCs through this
-- helper. Notification fan-out hooks in here (see the notifications migration).
CREATE FUNCTION private.on_booking_event(
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
BEGIN
    INSERT INTO public.booking_events (booking_id, event, actor_id, actor_role, from_status, to_status, details)
    VALUES (p_booking.id, p_event, auth.uid(), p_actor_role, p_from_status, p_booking.status, coalesce(p_details, '{}'::jsonb));
END;
$function$;

-- ---------------------------------------------------------------------------
-- 8. Public RPCs: availability.
-- ---------------------------------------------------------------------------

-- Bookable start times for the given services between two provider-local
-- dates (at most 62 days apart). Reveals free times only; never who booked.
CREATE FUNCTION public.get_available_slots(
    p_provider_id uuid,
    p_service_ids uuid[],
    p_from        date,
    p_to          date)
RETURNS TABLE (starts_at timestamptz, local_date date, local_time time without time zone)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
    v_duration integer;
    v_tz       text;
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'not_authenticated' USING ERRCODE = '42501';
    END IF;
    IF p_provider_id IS NULL OR p_from IS NULL OR p_to IS NULL OR p_to < p_from OR p_to - p_from > 62 THEN
        RAISE EXCEPTION 'invalid_request' USING ERRCODE = '22023',
            DETAIL = 'Ask for at most 62 days of availability at a time.';
    END IF;

    SELECT sum(r.duration_minutes) INTO v_duration
    FROM private.resolve_services(p_provider_id, p_service_ids) r;

    SELECT s.time_zone INTO v_tz
    FROM public.provider_booking_settings s
    WHERE s.provider_id = p_provider_id;
    IF v_tz IS NULL THEN
        RETURN;
    END IF;

    RETURN QUERY
    SELECT a.slot_start,
           (a.slot_start AT TIME ZONE v_tz)::date,
           (a.slot_start AT TIME ZONE v_tz)::time
    FROM private.available_slots(p_provider_id, v_duration, p_from, p_to) a;
END;
$function$;

-- Whether a point is inside a mobile provider's travel area.
CREATE FUNCTION public.check_service_area(
    p_provider_id uuid,
    p_latitude    double precision,
    p_longitude   double precision)
RETURNS TABLE (within_area boolean, distance_km numeric, radius_km numeric)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
    v_settings public.provider_booking_settings%ROWTYPE;
    v_origin   public.geography;
    v_distance numeric;
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'not_authenticated' USING ERRCODE = '42501';
    END IF;
    IF p_latitude IS NULL OR p_longitude IS NULL
       OR p_latitude NOT BETWEEN -90 AND 90 OR p_longitude NOT BETWEEN -180 AND 180 THEN
        RAISE EXCEPTION 'address_invalid' USING ERRCODE = '22023';
    END IF;

    SELECT * INTO v_settings FROM public.provider_booking_settings WHERE provider_id = p_provider_id;
    IF NOT FOUND OR NOT v_settings.offers_mobile THEN
        RAISE EXCEPTION 'mobile_unavailable' USING ERRCODE = 'P0001';
    END IF;

    SELECT p.coordinates INTO v_origin FROM public.profiles p WHERE p.id = p_provider_id;
    IF v_origin IS NOT NULL THEN
        v_distance := round((public.st_distance(
            v_origin,
            public.st_setsrid(public.st_makepoint(p_longitude, p_latitude), 4326)::public.geography) / 1000.0)::numeric, 2);
    END IF;

    IF v_settings.travel_radius_km IS NULL THEN
        RETURN QUERY SELECT true, v_distance, NULL::numeric;
    ELSIF v_distance IS NULL THEN
        RAISE EXCEPTION 'service_area_unavailable' USING ERRCODE = 'P0001';
    ELSE
        RETURN QUERY SELECT v_distance <= v_settings.travel_radius_km, v_distance, v_settings.travel_radius_km;
    END IF;
END;
$function$;

-- ---------------------------------------------------------------------------
-- 9. Public RPCs: provider schedule.
-- ---------------------------------------------------------------------------

-- Replaces the caller's whole weekly schedule atomically.
-- p_hours: [{"weekday": 1, "opens_at": "09:00", "closes_at": "17:00"}, ...]
CREATE FUNCTION public.set_working_hours(p_hours jsonb)
RETURNS SETOF public.provider_working_hours
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
    v_uid uuid := auth.uid();
BEGIN
    IF v_uid IS NULL OR NOT EXISTS (SELECT 1 FROM public.profiles WHERE id = v_uid AND role = 'provider') THEN
        RAISE EXCEPTION 'providers_only' USING ERRCODE = '42501';
    END IF;
    IF p_hours IS NULL OR jsonb_typeof(p_hours) <> 'array' OR jsonb_array_length(p_hours) > 21 THEN
        RAISE EXCEPTION 'working_hours_invalid' USING ERRCODE = '22023';
    END IF;

    BEGIN
        DELETE FROM public.provider_working_hours WHERE provider_id = v_uid;
        INSERT INTO public.provider_working_hours (provider_id, weekday, opens_at, closes_at)
        SELECT v_uid, (e ->> 'weekday')::smallint, (e ->> 'opens_at')::time, (e ->> 'closes_at')::time
        FROM jsonb_array_elements(p_hours) AS e;
    EXCEPTION
        WHEN exclusion_violation THEN
            RAISE EXCEPTION 'working_hours_overlap' USING ERRCODE = '22023';
        WHEN check_violation OR not_null_violation OR data_exception THEN
            RAISE EXCEPTION 'working_hours_invalid' USING ERRCODE = '22023';
    END;

    RETURN QUERY
    SELECT * FROM public.provider_working_hours
    WHERE provider_id = v_uid
    ORDER BY weekday, opens_at;
END;
$function$;

-- ---------------------------------------------------------------------------
-- 10. Public RPCs: booking lifecycle.
-- ---------------------------------------------------------------------------

-- Creates a booking for the signed-in client. Everything happens in one
-- transaction: availability is re-verified under a per-provider lock, prices
-- come from the database, and the booking, its items, the initial payment
-- record and the audit event are written together (or not at all).
--
-- Idempotent on p_booking_id: retrying the same request returns the booking
-- created by the first attempt.
--
-- Errors are raised with a stable message key the app maps to copy:
--   slot_unavailable, too_soon, too_far_ahead, price_changed, invalid_services,
--   provider_not_found, provider_not_accepting, studio_unavailable,
--   mobile_unavailable, address_invalid, outside_service_area,
--   service_area_unavailable, phone_invalid, notes_too_long,
--   payment_method_unavailable, client_overlap, too_many_bookings,
--   clients_only, not_authenticated, invalid_request.
CREATE FUNCTION public.create_booking(
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
    v_duration     integer;
    v_subtotal     integer;
    v_fee          integer := 0;
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

    SELECT * INTO v_settings FROM public.provider_booking_settings WHERE provider_id = p_provider_id;
    IF NOT FOUND OR NOT v_settings.accepts_bookings THEN
        RAISE EXCEPTION 'provider_not_accepting' USING ERRCODE = 'P0001';
    END IF;

    IF coalesce(p_payment_method, '') <> 'cash' THEN
        RAISE EXCEPTION 'payment_method_unavailable' USING ERRCODE = 'P0001';
    END IF;

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
          AND b.status IN ('pending', 'confirmed')
          AND tstzrange(b.starts_at, b.ends_at, '[)') && tstzrange(p_starts_at, v_ends_at, '[)')) THEN
        RAISE EXCEPTION 'client_overlap' USING ERRCODE = 'P0001';
    END IF;
    IF (SELECT count(*) FROM public.bookings b
        WHERE b.client_id = v_uid
          AND b.provider_id = p_provider_id
          AND b.status IN ('pending', 'confirmed')
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

    -- Platform commission (provider-side), free during the provider's
    -- fee-free period.
    SELECT * INTO v_platform FROM private.platform_settings WHERE id;
    IF FOUND AND v_platform.platform_fee_percent > 0
       AND now() >= v_provider.created_at + make_interval(days => v_platform.fee_free_days) THEN
        v_fee := round(v_subtotal * v_platform.platform_fee_percent / 100.0)::integer;
    END IF;

    INSERT INTO public.bookings (
        id, reference, client_id, provider_id, status, starts_at, ends_at, blocked_until, time_zone,
        duration_minutes, buffer_minutes, location_type, address_text, address, access_notes, location,
        distance_km, provider_name, client_name, client_phone, client_notes, subtotal_cents,
        platform_fee_cents, total_cents, payment_method, payment_status, requires_approval,
        cancellation_window_hours, cancellation_fee_percent)
    VALUES (
        p_booking_id, private.new_booking_reference(), v_uid, p_provider_id,
        CASE WHEN v_settings.requires_approval THEN 'pending' ELSE 'confirmed' END,
        p_starts_at, v_ends_at, v_ends_at + make_interval(mins => v_settings.buffer_minutes), v_settings.time_zone,
        v_duration, v_settings.buffer_minutes, p_location_type, v_address_text, v_address,
        CASE WHEN p_location_type = 'client' THEN v_access_notes END, v_point, v_distance,
        coalesce(nullif(btrim(v_provider.provider_name), ''),
                 nullif(btrim(concat_ws(' ', btrim(v_provider.first_name), btrim(v_provider.last_name))), ''),
                 'Provider'),
        coalesce(v_client_name, 'Client'), v_phone, v_client_notes, v_subtotal,
        v_fee, v_subtotal, 'cash', 'pending', v_settings.requires_approval,
        v_settings.cancellation_window_hours, v_settings.cancellation_fee_percent)
    RETURNING * INTO v_booking;

    INSERT INTO public.booking_items (booking_id, service_id, position, service_name, category, duration_minutes, price_cents)
    SELECT v_booking.id, r.service_id, r.ord, r.service_name, r.category, r.duration_minutes, r.price_cents
    FROM private.resolve_services(p_provider_id, p_service_ids) r;

    INSERT INTO public.booking_payments (booking_id, method, status, amount_cents, platform_fee_cents)
    VALUES (v_booking.id, 'cash', 'pending', v_booking.total_cents, v_booking.platform_fee_cents);

    PERFORM private.on_booking_event(
        v_booking,
        CASE WHEN v_booking.status = 'pending' THEN 'requested' ELSE 'booked' END,
        'client',
        NULL,
        jsonb_build_object('payment_method', 'cash', 'payment_status', 'pending', 'total_cents', v_booking.total_cents));

    RETURN v_booking;
EXCEPTION
    -- Belt and braces: the exclusion constraint caught an overlap the check
    -- above should already have rejected.
    WHEN exclusion_violation THEN
        RAISE EXCEPTION 'slot_unavailable' USING ERRCODE = 'P0001';
END;
$function$;

-- Provider accepts or declines a pending request.
CREATE FUNCTION public.respond_to_booking_request(
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
    v_reason  text := nullif(btrim(p_reason), '');
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'not_authenticated' USING ERRCODE = '42501';
    END IF;
    IF p_accept IS NULL OR char_length(v_reason) > 300 THEN
        RAISE EXCEPTION 'invalid_request' USING ERRCODE = '22023';
    END IF;

    SELECT * INTO v_booking FROM public.bookings WHERE id = p_booking_id FOR UPDATE;
    IF NOT FOUND OR v_booking.provider_id IS DISTINCT FROM v_uid THEN
        RAISE EXCEPTION 'booking_not_found' USING ERRCODE = 'P0002';
    END IF;
    IF v_booking.status <> 'pending' THEN
        RAISE EXCEPTION 'booking_not_pending' USING ERRCODE = 'P0001';
    END IF;
    IF v_booking.starts_at <= now() THEN
        RAISE EXCEPTION 'booking_request_expired' USING ERRCODE = 'P0001';
    END IF;

    IF p_accept THEN
        UPDATE public.bookings
        SET status = 'confirmed', responded_at = now(), updated_at = now()
        WHERE id = p_booking_id
        RETURNING * INTO v_booking;
        PERFORM private.on_booking_event(v_booking, 'confirmed', 'provider', 'pending');
    ELSE
        UPDATE public.bookings
        SET status = 'declined', decline_reason = v_reason, responded_at = now(),
            payment_status = 'void', updated_at = now()
        WHERE id = p_booking_id
        RETURNING * INTO v_booking;
        UPDATE public.booking_payments SET status = 'void', updated_at = now()
        WHERE booking_id = p_booking_id AND status = 'pending';
        PERFORM private.on_booking_event(v_booking, 'declined', 'provider', 'pending',
            jsonb_build_object('reason', v_reason));
    END IF;

    RETURN v_booking;
END;
$function$;

-- Cancels an upcoming booking. Clients cancel for free until the provider's
-- cancellation window; after that the cancellation is recorded as late (with
-- the provider's fee, if any) and must be explicitly acknowledged with
-- p_accept_late_cancellation, otherwise late_cancellation_unconfirmed is
-- raised with the fee in DETAIL. Providers must give a reason.
CREATE FUNCTION public.cancel_booking(
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
        WHEN v_booking.provider_id = v_uid THEN 'provider'
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
        payment_status = 'void',
        updated_at = now()
    WHERE id = p_booking_id
    RETURNING * INTO v_booking;

    UPDATE public.booking_payments SET status = 'void', updated_at = now()
    WHERE booking_id = p_booking_id AND status = 'pending';

    PERFORM private.on_booking_event(v_booking, 'cancelled', v_role, v_from,
        jsonb_build_object('reason', v_reason, 'late', v_late, 'fee_cents', v_fee));

    RETURN v_booking;
END;
$function$;

-- Provider marks an appointment that has started as done, optionally
-- recording that the cash was collected.
CREATE FUNCTION public.complete_booking(
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
-- recorded as owed.
CREATE FUNCTION public.mark_booking_no_show(p_booking_id uuid)
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
    SET status = 'no_show', cancellation_fee_cents = v_fee, payment_status = 'void', updated_at = now()
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
CREATE FUNCTION public.record_cash_payment(p_booking_id uuid)
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
    IF v_booking.status <> 'completed' OR v_booking.payment_status <> 'pending' THEN
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
-- 11. Function privileges. PUBLIC has EXECUTE by default, so revoke it.
-- ---------------------------------------------------------------------------

REVOKE ALL ON ALL FUNCTIONS IN SCHEMA private FROM PUBLIC, anon, authenticated;

REVOKE ALL ON FUNCTION public.get_available_slots(uuid, uuid[], date, date) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.check_service_area(uuid, double precision, double precision) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.set_working_hours(jsonb) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.create_booking(uuid, uuid, uuid[], timestamptz, text, text, integer, text, jsonb, double precision, double precision, text, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.respond_to_booking_request(uuid, boolean, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.cancel_booking(uuid, text, boolean) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.complete_booking(uuid, boolean) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.mark_booking_no_show(uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.record_cash_payment(uuid) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.get_available_slots(uuid, uuid[], date, date) TO authenticated;
GRANT EXECUTE ON FUNCTION public.check_service_area(uuid, double precision, double precision) TO authenticated;
GRANT EXECUTE ON FUNCTION public.set_working_hours(jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.create_booking(uuid, uuid, uuid[], timestamptz, text, text, integer, text, jsonb, double precision, double precision, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.respond_to_booking_request(uuid, boolean, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.cancel_booking(uuid, text, boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.complete_booking(uuid, boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_booking_no_show(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.record_cash_payment(uuid) TO authenticated;

-- ---------------------------------------------------------------------------
-- 12. Realtime: booking changes for both parties, and the per-provider
--     availability signal for clients picking a time.
-- ---------------------------------------------------------------------------

ALTER PUBLICATION supabase_realtime ADD TABLE public.bookings, public.provider_booking_settings;
