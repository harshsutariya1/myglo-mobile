-- Booking notifications: an in-app inbox (realtime), transactional email
-- through the send-notifications Edge Function (Resend), and scheduled jobs
-- for reminders, expiring unanswered requests and retrying deliveries.
--
-- Delivery pipeline
--   booking RPC -> private.on_booking_event -> public.notifications (in-app)
--     -> private.notification_deliveries (email outbox, same transaction)
--     -> pg_net POST /functions/v1/send-notifications (sent after commit)
--     -> Edge Function claims the delivery, sends it, records the outcome.
--   A pg_cron sweeper re-dispatches anything due (retries with backoff) and
--   gives up on deliveries older than 12 hours.
--
-- Environment setup (not part of this migration because the values are
-- project-specific; see docs/booking_notifications.md):
--   select vault.create_secret('https://<ref>.supabase.co', 'project_url');
--   select vault.create_secret('<anon (legacy JWT) key>', 'notifications_function_key');
--   Edge Function secret RESEND_API_KEY (and optionally NOTIFICATIONS_EMAIL_FROM).
-- Until the Vault secrets exist, in-app notifications work and emails stay
-- queued (then expire); nothing in the booking flow fails.

CREATE EXTENSION IF NOT EXISTS pg_net WITH SCHEMA extensions;
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- ---------------------------------------------------------------------------
-- 1. In-app notifications.
-- ---------------------------------------------------------------------------

CREATE TABLE public.notifications (
    id           uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    recipient_id uuid        NOT NULL REFERENCES public.profiles (id) ON DELETE CASCADE,
    -- Who caused it (NULL for the system). Notifications about the
    -- recipient's own action are created already read.
    actor_id     uuid        REFERENCES public.profiles (id) ON DELETE SET NULL,
    kind         text        NOT NULL,
    title        text        NOT NULL,
    body         text        NOT NULL,
    booking_id   uuid        REFERENCES public.bookings (id) ON DELETE CASCADE,
    data         jsonb       NOT NULL DEFAULT '{}'::jsonb,
    read_at      timestamptz,
    created_at   timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT notifications_kind CHECK (kind IN (
        'booking_request', 'booking_new', 'booking_requested', 'booking_confirmed', 'booking_declined',
        'booking_cancelled', 'booking_expired', 'booking_completed', 'booking_no_show', 'booking_reminder')),
    CONSTRAINT notifications_text_lengths CHECK (char_length(title) <= 120 AND char_length(body) <= 600)
);

COMMENT ON TABLE public.notifications IS
    'In-app notifications. Created by booking RPCs and scheduled jobs; recipients can read, mark read and delete their own.';

CREATE INDEX notifications_recipient_created_idx ON public.notifications (recipient_id, created_at DESC);
CREATE INDEX notifications_unread_idx ON public.notifications (recipient_id) WHERE read_at IS NULL;
CREATE INDEX notifications_booking_idx ON public.notifications (booking_id);
CREATE INDEX notifications_actor_idx ON public.notifications (actor_id);

ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON public.notifications FROM anon, authenticated;
GRANT SELECT, DELETE ON public.notifications TO authenticated;
-- Recipients may only flip read_at.
GRANT UPDATE (read_at) ON public.notifications TO authenticated;

CREATE POLICY "Recipients can view own notifications" ON public.notifications
    FOR SELECT TO authenticated
    USING ((SELECT auth.uid()) = recipient_id);

CREATE POLICY "Recipients can mark own notifications read" ON public.notifications
    FOR UPDATE TO authenticated
    USING ((SELECT auth.uid()) = recipient_id)
    WITH CHECK ((SELECT auth.uid()) = recipient_id);

CREATE POLICY "Recipients can delete own notifications" ON public.notifications
    FOR DELETE TO authenticated
    USING ((SELECT auth.uid()) = recipient_id);

-- ---------------------------------------------------------------------------
-- 2. Delivery outbox (private; only the Edge Function touches it, via the
--    service-role RPCs below).
-- ---------------------------------------------------------------------------

CREATE TABLE private.notification_deliveries (
    id                  uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    notification_id     uuid        NOT NULL REFERENCES public.notifications (id) ON DELETE CASCADE,
    channel             text        NOT NULL,
    status              text        NOT NULL DEFAULT 'pending',
    attempts            smallint    NOT NULL DEFAULT 0,
    next_attempt_at     timestamptz NOT NULL DEFAULT now(),
    last_error          text,
    provider_message_id text,
    sent_at             timestamptz,
    created_at          timestamptz NOT NULL DEFAULT now(),
    updated_at          timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT notification_deliveries_channel CHECK (channel IN ('email', 'push')),
    CONSTRAINT notification_deliveries_status CHECK (
        status IN ('pending', 'processing', 'sent', 'retry', 'failed', 'skipped')),
    CONSTRAINT notification_deliveries_once UNIQUE (notification_id, channel)
);

CREATE INDEX notification_deliveries_due_idx ON private.notification_deliveries (next_attempt_at)
    WHERE status IN ('pending', 'retry', 'processing');

-- ---------------------------------------------------------------------------
-- 3. Formatting helpers (provider-local time, matching the app).
-- ---------------------------------------------------------------------------

-- "Tue 7 Oct, 9:30 am"
CREATE FUNCTION private.booking_when(p_starts_at timestamptz, p_time_zone text)
RETURNS text
LANGUAGE sql
STABLE
SET search_path TO ''
AS $function$
    SELECT to_char(p_starts_at AT TIME ZONE p_time_zone, 'FMDy FMDD FMMon') || ', '
        || to_char(p_starts_at AT TIME ZONE p_time_zone, 'FMHH12:MI am');
$function$;

-- "9:30 am"
CREATE FUNCTION private.booking_time(p_at timestamptz, p_time_zone text)
RETURNS text
LANGUAGE sql
STABLE
SET search_path TO ''
AS $function$
    SELECT to_char(p_at AT TIME ZONE p_time_zone, 'FMHH12:MI am');
$function$;

-- ---------------------------------------------------------------------------
-- 4. Fan-out.
-- ---------------------------------------------------------------------------

-- Creates one in-app notification and, when p_email, queues its email.
CREATE FUNCTION private.notify(
    p_recipient_id uuid,
    p_actor_id     uuid,
    p_kind         text,
    p_title        text,
    p_body         text,
    p_booking_id   uuid,
    p_email        boolean,
    p_data         jsonb DEFAULT '{}'::jsonb)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
    v_id uuid;
BEGIN
    -- The account may have been deleted since the booking was made.
    IF p_recipient_id IS NULL THEN
        RETURN;
    END IF;

    INSERT INTO public.notifications (recipient_id, actor_id, kind, title, body, booking_id, data, read_at)
    VALUES (
        p_recipient_id, p_actor_id, p_kind, left(p_title, 120), left(p_body, 600), p_booking_id,
        coalesce(p_data, '{}'::jsonb),
        CASE WHEN p_actor_id = p_recipient_id THEN now() END)
    RETURNING id INTO v_id;

    IF p_email THEN
        INSERT INTO private.notification_deliveries (notification_id, channel) VALUES (v_id, 'email');
    END IF;
END;
$function$;

-- Records the booking event (audit trail) and tells the right people.
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
    v_services text;
    v_data     jsonb := jsonb_build_object('reference', p_booking.reference, 'status', p_booking.status);
BEGIN
    INSERT INTO public.booking_events (booking_id, event, actor_id, actor_role, from_status, to_status, details)
    VALUES (p_booking.id, p_event, v_actor, p_actor_role, p_from_status, p_booking.status, coalesce(p_details, '{}'::jsonb));

    SELECT string_agg(i.service_name, ', ' ORDER BY i.position) INTO v_services
    FROM public.booking_items i
    WHERE i.booking_id = p_booking.id;
    v_services := coalesce(v_services, 'your appointment');

    CASE p_event
        WHEN 'requested' THEN
            PERFORM private.notify(p_booking.provider_id, v_actor, 'booking_request', 'New booking request',
                format('%s requested %s on %s. Accept or decline before it starts.',
                       p_booking.client_name, v_services, v_when),
                p_booking.id, true, v_data);
            PERFORM private.notify(p_booking.client_id, v_actor, 'booking_requested', 'Request sent',
                format('%s will confirm your %s appointment soon. We''ll let you know as soon as they reply.',
                       p_booking.provider_name, v_when),
                p_booking.id, true, v_data);

        WHEN 'booked' THEN
            PERFORM private.notify(p_booking.provider_id, v_actor, 'booking_new', 'New booking',
                format('%s booked %s on %s.', p_booking.client_name, v_services, v_when),
                p_booking.id, true, v_data);
            PERFORM private.notify(p_booking.client_id, v_actor, 'booking_confirmed', 'Booking confirmed',
                format('%s with %s on %s. Pay %s in cash at your appointment.',
                       v_services, p_booking.provider_name, v_when, v_total),
                p_booking.id, true, v_data);

        WHEN 'confirmed' THEN
            PERFORM private.notify(p_booking.client_id, v_actor, 'booking_confirmed', 'Booking confirmed',
                format('%s accepted your request for %s. Pay %s in cash at your appointment.',
                       p_booking.provider_name, v_when, v_total),
                p_booking.id, true, v_data);

        WHEN 'declined' THEN
            PERFORM private.notify(p_booking.client_id, v_actor, 'booking_declined', 'Request declined',
                format('%s can''t take your booking on %s.', p_booking.provider_name, v_when)
                    || CASE WHEN v_reason IS NOT NULL THEN format(' Their note: "%s"', v_reason) ELSE '' END
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
                format('%s didn''t respond to your request for %s. Try booking another time.',
                       p_booking.provider_name, v_when),
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

        ELSE
            -- Audit-only events (e.g. payment_recorded) notify nobody.
            NULL;
    END CASE;
END;
$function$;

-- ---------------------------------------------------------------------------
-- 5. Email dispatch.
-- ---------------------------------------------------------------------------

-- Asks the Edge Function to process the given deliveries (or everything due).
-- Fire-and-forget: pg_net sends the request after the transaction commits and
-- never blocks or fails the caller.
CREATE FUNCTION private.dispatch_notification_deliveries(p_delivery_ids uuid[] DEFAULT NULL)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
    v_url text;
    v_key text;
BEGIN
    SELECT decrypted_secret INTO v_url FROM vault.decrypted_secrets WHERE name = 'project_url';
    SELECT decrypted_secret INTO v_key FROM vault.decrypted_secrets WHERE name = 'notifications_function_key';
    IF v_url IS NULL OR v_key IS NULL THEN
        RETURN;
    END IF;

    PERFORM net.http_post(
        url := rtrim(v_url, '/') || '/functions/v1/send-notifications',
        headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'Authorization', 'Bearer ' || v_key,
            'apikey', v_key),
        body := CASE
            WHEN p_delivery_ids IS NULL THEN '{}'::jsonb
            ELSE jsonb_build_object('delivery_ids', to_jsonb(p_delivery_ids))
        END,
        timeout_milliseconds := 15000);
EXCEPTION
    WHEN OTHERS THEN
        -- The sweeper retries; a booking must never fail because of email.
        RAISE WARNING 'notification dispatch failed: %', SQLERRM;
END;
$function$;

CREATE FUNCTION private.on_notification_deliveries_inserted()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
BEGIN
    PERFORM private.dispatch_notification_deliveries(ARRAY(SELECT id FROM new_rows));
    RETURN NULL;
END;
$function$;

CREATE TRIGGER notification_deliveries_dispatch
    AFTER INSERT ON private.notification_deliveries
    REFERENCING NEW TABLE AS new_rows
    FOR EACH STATEMENT EXECUTE FUNCTION private.on_notification_deliveries_inserted();

-- Claims deliveries for the Edge Function: marks them processing and returns
-- everything needed to render them. Service role only.
CREATE FUNCTION public.claim_notification_deliveries(
    p_delivery_ids uuid[]  DEFAULT NULL,
    p_limit        integer DEFAULT 20)
RETURNS TABLE (
    delivery_id     uuid,
    channel         text,
    attempt         smallint,
    recipient_email text,
    recipient_name  text,
    recipient_role  text,
    kind            text,
    title           text,
    body            text,
    created_at      timestamptz,
    booking         jsonb)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
BEGIN
    RETURN QUERY
    WITH due AS (
        SELECT d.id
        FROM private.notification_deliveries d
        WHERE d.status IN ('pending', 'retry')
          AND d.next_attempt_at <= now()
          AND (p_delivery_ids IS NULL OR d.id = ANY (p_delivery_ids))
        ORDER BY d.created_at
        LIMIT least(greatest(coalesce(p_limit, 20), 1), 100)
        FOR UPDATE SKIP LOCKED
    ),
    claimed AS (
        UPDATE private.notification_deliveries d
        SET status = 'processing', attempts = d.attempts + 1, updated_at = now()
        FROM due
        WHERE d.id = due.id
        RETURNING d.id, d.notification_id, d.channel, d.attempts
    )
    SELECT c.id,
           c.channel,
           c.attempts,
           p.email,
           nullif(btrim(concat_ws(' ', btrim(p.first_name), btrim(p.last_name))), ''),
           p.role,
           n.kind,
           n.title,
           n.body,
           n.created_at,
           CASE WHEN b.id IS NULL THEN NULL ELSE jsonb_build_object(
               'reference', b.reference,
               'status', b.status,
               'provider_name', b.provider_name,
               'client_name', b.client_name,
               'date', to_char(b.starts_at AT TIME ZONE b.time_zone, 'FMDay FMDD FMMonth YYYY'),
               'time_range', private.booking_time(b.starts_at, b.time_zone) || ' – ' || private.booking_time(b.ends_at, b.time_zone),
               'time_zone', b.time_zone,
               'time_zone_abbrev', (SELECT tz.abbrev FROM pg_catalog.pg_timezone_names tz WHERE tz.name = b.time_zone),
               'services', COALESCE((
                   SELECT jsonb_agg(jsonb_build_object(
                              'name', i.service_name,
                              'price', private.format_aud(i.price_cents)) ORDER BY i.position)
                   FROM public.booking_items i
                   WHERE i.booking_id = b.id), '[]'::jsonb),
               'total', private.format_aud(b.total_cents),
               'location_type', b.location_type,
               'address', b.address_text,
               'payment_method', b.payment_method,
               'payment_status', b.payment_status,
               'cancellation_window_hours', b.cancellation_window_hours,
               'cancellation_fee_percent', b.cancellation_fee_percent,
               'free_cancellation_until', private.booking_when(
                   b.starts_at - make_interval(hours => b.cancellation_window_hours), b.time_zone),
               'late_cancellation', b.late_cancellation,
               'cancellation_fee', CASE WHEN b.cancellation_fee_cents > 0
                                        THEN private.format_aud(b.cancellation_fee_cents) END)
           END
    FROM claimed c
    JOIN public.notifications n ON n.id = c.notification_id
    JOIN public.profiles p ON p.id = n.recipient_id
    LEFT JOIN public.bookings b ON b.id = n.booking_id;
END;
$function$;

-- Records the outcome of a claimed delivery. p_outcome:
--   sent    - delivered;
--   retry   - transient failure, tried again with backoff (gives up after 5);
--   failed  - permanent failure;
--   skipped - intentionally not sent (no address, stale, unsupported).
CREATE FUNCTION public.complete_notification_delivery(
    p_delivery_id         uuid,
    p_outcome             text,
    p_error               text DEFAULT NULL,
    p_provider_message_id text DEFAULT NULL)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
BEGIN
    IF p_outcome NOT IN ('sent', 'retry', 'failed', 'skipped') THEN
        RAISE EXCEPTION 'invalid_request' USING ERRCODE = '22023';
    END IF;

    UPDATE private.notification_deliveries d
    SET status = CASE
                     WHEN p_outcome = 'retry' AND d.attempts >= 5 THEN 'failed'
                     ELSE p_outcome
                 END,
        next_attempt_at = CASE
                              WHEN p_outcome = 'retry' THEN now() + make_interval(mins => power(2, d.attempts)::integer)
                              ELSE d.next_attempt_at
                          END,
        last_error = left(p_error, 500),
        provider_message_id = coalesce(p_provider_message_id, d.provider_message_id),
        sent_at = CASE WHEN p_outcome = 'sent' THEN now() ELSE d.sent_at END,
        updated_at = now()
    WHERE d.id = p_delivery_id
      AND d.status = 'processing';
END;
$function$;

-- ---------------------------------------------------------------------------
-- 6. Scheduled jobs.
-- ---------------------------------------------------------------------------

-- Requests nobody answered before the appointment time lapse.
CREATE FUNCTION private.expire_booking_requests()
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
            WHERE p.status = 'pending' AND p.starts_at <= now()
            ORDER BY p.starts_at
            LIMIT 200
            FOR UPDATE SKIP LOCKED)
        RETURNING b.*
    LOOP
        UPDATE public.booking_payments SET status = 'void', updated_at = now()
        WHERE booking_id = v_booking.id AND status = 'pending';
        PERFORM private.on_booking_event(v_booking, 'expired', 'system', 'pending');
        v_count := v_count + 1;
    END LOOP;
    RETURN v_count;
END;
$function$;

-- Day-before and starting-soon reminders for confirmed bookings. A reminder
-- is only sent if the booking was made before that reminder's window opened.
CREATE FUNCTION private.queue_booking_reminders()
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
        SET reminder_day_sent_at = now()
        WHERE b.id IN (
            SELECT p.id FROM public.bookings p
            WHERE p.status = 'confirmed'
              AND p.reminder_day_sent_at IS NULL
              AND p.starts_at > now() + interval '2 hours'
              AND p.starts_at <= now() + interval '24 hours'
              AND p.created_at <= p.starts_at - interval '24 hours'
            ORDER BY p.starts_at
            LIMIT 500
            FOR UPDATE SKIP LOCKED)
        RETURNING b.*
    LOOP
        PERFORM private.on_booking_event(v_booking, 'reminder_day', 'system', v_booking.status);
        v_count := v_count + 1;
    END LOOP;

    FOR v_booking IN
        UPDATE public.bookings b
        SET reminder_hour_sent_at = now()
        WHERE b.id IN (
            SELECT p.id FROM public.bookings p
            WHERE p.status = 'confirmed'
              AND p.reminder_hour_sent_at IS NULL
              AND p.starts_at > now()
              AND p.starts_at <= now() + interval '2 hours'
              AND p.created_at <= p.starts_at - interval '2 hours'
            ORDER BY p.starts_at
            LIMIT 500
            FOR UPDATE SKIP LOCKED)
        RETURNING b.*
    LOOP
        PERFORM private.on_booking_event(v_booking, 'reminder_hour', 'system', v_booking.status);
        v_count := v_count + 1;
    END LOOP;

    RETURN v_count;
END;
$function$;

-- Recovers stuck work and re-dispatches anything due.
CREATE FUNCTION private.sweep_notification_deliveries()
RETURNS void
LANGUAGE plpgsql
SET search_path TO ''
AS $function$
BEGIN
    -- Old news is worse than no news: don't email about stale events.
    UPDATE private.notification_deliveries
    SET status = 'skipped', last_error = 'stale', updated_at = now()
    WHERE status IN ('pending', 'retry')
      AND created_at < now() - interval '12 hours';

    -- A worker that died mid-send gets its claim back.
    UPDATE private.notification_deliveries
    SET status = 'retry', updated_at = now()
    WHERE status = 'processing'
      AND updated_at < now() - interval '10 minutes';

    IF EXISTS (
        SELECT 1 FROM private.notification_deliveries
        WHERE status IN ('pending', 'retry') AND next_attempt_at <= now()) THEN
        PERFORM private.dispatch_notification_deliveries(NULL);
    END IF;
END;
$function$;

SELECT cron.schedule('myglo-expire-booking-requests', '*/5 * * * *', 'SELECT private.expire_booking_requests();');
SELECT cron.schedule('myglo-booking-reminders', '*/10 * * * *', 'SELECT private.queue_booking_reminders();');
SELECT cron.schedule('myglo-notification-delivery-sweep', '* * * * *', 'SELECT private.sweep_notification_deliveries();');

-- ---------------------------------------------------------------------------
-- 7. Recipient actions.
-- ---------------------------------------------------------------------------

-- Marks the caller's notifications read (all unread ones when p_ids is NULL).
-- Runs as the caller, so RLS and the read_at column grant apply.
CREATE FUNCTION public.mark_notifications_read(p_ids uuid[] DEFAULT NULL)
RETURNS integer
LANGUAGE sql
SECURITY INVOKER
SET search_path TO ''
AS $function$
    WITH updated AS (
        UPDATE public.notifications
        SET read_at = now()
        WHERE recipient_id = (SELECT auth.uid())
          AND read_at IS NULL
          AND (p_ids IS NULL OR id = ANY (p_ids))
        RETURNING 1)
    SELECT count(*)::integer FROM updated;
$function$;

-- ---------------------------------------------------------------------------
-- 8. Privileges and realtime.
-- ---------------------------------------------------------------------------

REVOKE ALL ON ALL TABLES IN SCHEMA private FROM PUBLIC, anon, authenticated;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA private FROM PUBLIC, anon, authenticated;

REVOKE ALL ON FUNCTION public.mark_notifications_read(uuid[]) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.mark_notifications_read(uuid[]) TO authenticated;

REVOKE ALL ON FUNCTION public.claim_notification_deliveries(uuid[], integer) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.complete_notification_delivery(uuid, text, text, text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.claim_notification_deliveries(uuid[], integer) TO service_role;
GRANT EXECUTE ON FUNCTION public.complete_notification_delivery(uuid, text, text, text) TO service_role;

ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;
