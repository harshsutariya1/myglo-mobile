-- Reminders to providers about booking requests they haven't answered.
--
-- Every cash booking is a request the provider must accept (see
-- 20261007120000_cash_bookings_are_fee_free_requests.sql), and a request
-- nobody answers expires at its start time. To stop requests lapsing
-- unnoticed, the provider gets up to two reminders, in-app and by email,
-- spaced by how far ahead the request was made (T = starts_at - created_at):
--
--   1. "Request waiting for you": once the request has waited 2 hours, or
--      half of T if that's sooner.
--   2. "Respond before it expires": 24 hours before the start, or a quarter
--      of T before it if that's later. Always after reminder 1, and never in
--      the same run as it.
--
--   Request made           Reminder 1          Reminder 2
--   14 days ahead          2 h after           24 h before start
--   24 hours ahead         2 h after           6 h before start
--   5 hours ahead          2 h after           1 h 15 min before start
--   2 hours ahead          1 h after           30 min before start
--
-- Nothing is sent within 15 minutes of the start (the request is about to
-- lapse anyway), once the provider has responded, or after the client
-- withdraws. Each reminder is recorded on the booking so it's sent at most
-- once, and in the audit trail (booking_events) like every other event.
--
-- The reminder columns don't affect availability, so updating them doesn't
-- bump availability_version (the booking update trigger only looks at
-- status and times).

-- ---------------------------------------------------------------------------
-- 1. Tracking columns and notification kind.
-- ---------------------------------------------------------------------------

ALTER TABLE public.bookings
    ADD COLUMN request_reminder_sent_at       timestamptz,
    ADD COLUMN request_final_reminder_sent_at timestamptz;

COMMENT ON COLUMN public.bookings.request_reminder_sent_at IS
    'When the provider was first reminded about this unanswered request.';
COMMENT ON COLUMN public.bookings.request_final_reminder_sent_at IS
    'When the provider was last reminded, before this unanswered request expires.';

ALTER TABLE public.notifications
    DROP CONSTRAINT notifications_kind,
    ADD CONSTRAINT notifications_kind CHECK (kind IN (
        'booking_request', 'booking_new', 'booking_requested', 'booking_confirmed', 'booking_declined',
        'booking_cancelled', 'booking_expired', 'booking_completed', 'booking_no_show', 'booking_reminder',
        'booking_request_reminder'));

-- ---------------------------------------------------------------------------
-- 2. Notification copy (same function as before, plus the two reminders).
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

        WHEN 'request_reminder' THEN
            PERFORM private.notify(p_booking.provider_id, NULL, 'booking_request_reminder', 'Request waiting for you',
                format('%s is waiting to hear about %s on %s. Accept or decline so they can plan.',
                       p_booking.client_name, v_services, v_when),
                p_booking.id, true, v_data);

        WHEN 'request_final_reminder' THEN
            PERFORM private.notify(p_booking.provider_id, NULL, 'booking_request_reminder', 'Respond before it expires',
                format('%s''s request for %s on %s still needs an answer. If you don''t accept or decline, '
                       || 'it expires at %s and the time opens up for other clients.',
                       p_booking.client_name, v_services, v_when,
                       private.booking_time(p_booking.starts_at, p_booking.time_zone)),
                p_booking.id, true, v_data);

        ELSE
            -- Audit-only events (e.g. payment_recorded) notify nobody.
            NULL;
    END CASE;
END;
$function$;

-- ---------------------------------------------------------------------------
-- 3. Scheduled job.
-- ---------------------------------------------------------------------------

CREATE FUNCTION private.queue_booking_request_reminders()
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
              AND p.starts_at > now() + interval '15 minutes'
              AND now() >= p.created_at + least(interval '2 hours', (p.starts_at - p.created_at) / 2)
            ORDER BY p.starts_at
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
              AND p.starts_at > now() + interval '15 minutes'
              AND now() >= p.starts_at - least(interval '24 hours', (p.starts_at - p.created_at) / 4)
            ORDER BY p.starts_at
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

COMMENT ON FUNCTION private.queue_booking_request_reminders() IS
    'Reminds providers about booking requests they have not answered (run by pg_cron every 5 minutes).';

REVOKE ALL ON FUNCTION private.queue_booking_request_reminders() FROM PUBLIC, anon, authenticated;

SELECT cron.schedule('myglo-booking-request-reminders', '*/5 * * * *', 'SELECT private.queue_booking_request_reminders();');
