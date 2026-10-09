-- Push notifications (Firebase Cloud Messaging) for every in-app notification.
--
-- Devices register their FCM token after sign-in (register_push_token) and
-- remove it on sign-out (unregister_push_token). private.notify, which every
-- booking event and scheduled reminder already goes through, now also queues
-- a `push` delivery in the existing outbox whenever the recipient has a
-- registered device. The send-notifications Edge Function sends those through
-- the FCM HTTP v1 API and prunes tokens FCM reports as no longer registered.
--
-- Pushes are never sent for something the recipient did themselves (those
-- notifications are stored as already read), so nobody gets a push about
-- their own action.
--
-- Tokens live in the `private` schema, which PostgREST doesn't expose and
-- only the owner can use, so the only way in is through the functions below.

-- ---------------------------------------------------------------------------
-- 1. Device tokens.
-- ---------------------------------------------------------------------------

CREATE TABLE private.push_tokens (
    token      text        PRIMARY KEY,
    user_id    uuid        NOT NULL REFERENCES public.profiles (id) ON DELETE CASCADE,
    platform   text        NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT push_tokens_platform CHECK (platform IN ('android', 'ios')),
    CONSTRAINT push_tokens_token_length CHECK (char_length(token) BETWEEN 32 AND 4096)
);

COMMENT ON TABLE private.push_tokens IS
    'FCM registration tokens, one row per app install. Managed through register_push_token / unregister_push_token.';

CREATE INDEX push_tokens_user_idx ON private.push_tokens (user_id, updated_at DESC);

-- Not reachable by API roles (private schema), but keep RLS on so a future
-- grant can't expose every token by accident.
ALTER TABLE private.push_tokens ENABLE ROW LEVEL SECURITY;

-- Most devices one account keeps registered; older ones are dropped.
CREATE OR REPLACE FUNCTION public.register_push_token(p_token text, p_platform text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
    v_uid   uuid := auth.uid();
    v_token text := btrim(coalesce(p_token, ''));
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'Not authorized' USING ERRCODE = '42501';
    END IF;
    IF p_platform IS NULL OR p_platform NOT IN ('android', 'ios') THEN
        RAISE EXCEPTION 'invalid_platform' USING ERRCODE = '22023';
    END IF;
    IF char_length(v_token) NOT BETWEEN 32 AND 4096 THEN
        RAISE EXCEPTION 'invalid_token' USING ERRCODE = '22023';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM public.profiles WHERE id = v_uid) THEN
        RAISE EXCEPTION 'Profile not found' USING ERRCODE = '42501';
    END IF;

    -- A token belongs to one install; whoever is signed in there now owns it
    -- (e.g. after someone else signed out on a shared device).
    INSERT INTO private.push_tokens (token, user_id, platform)
    VALUES (v_token, v_uid, p_platform)
    ON CONFLICT (token) DO UPDATE
        SET user_id = EXCLUDED.user_id,
            platform = EXCLUDED.platform,
            updated_at = now();

    DELETE FROM private.push_tokens
    WHERE user_id = v_uid
      AND token IN (
          SELECT token FROM private.push_tokens
          WHERE user_id = v_uid
          ORDER BY updated_at DESC
          OFFSET 10);
END;
$function$;

CREATE OR REPLACE FUNCTION public.unregister_push_token(p_token text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Not authorized' USING ERRCODE = '42501';
    END IF;
    DELETE FROM private.push_tokens
    WHERE token = btrim(coalesce(p_token, ''))
      AND user_id = auth.uid();
END;
$function$;

-- For the Edge Function: drops tokens FCM says are unregistered or invalid.
CREATE OR REPLACE FUNCTION public.remove_push_tokens(p_tokens text[])
 RETURNS integer
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
    WITH removed AS (
        DELETE FROM private.push_tokens WHERE token = ANY (coalesce(p_tokens, '{}'::text[]))
        RETURNING 1)
    SELECT count(*)::integer FROM removed;
$function$;

REVOKE ALL ON FUNCTION public.register_push_token(text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.register_push_token(text, text) TO authenticated;
REVOKE ALL ON FUNCTION public.unregister_push_token(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.unregister_push_token(text) TO authenticated;
REVOKE ALL ON FUNCTION public.remove_push_tokens(text[]) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.remove_push_tokens(text[]) TO service_role;

-- ---------------------------------------------------------------------------
-- 2. Queue a push alongside every notification the recipient didn't cause.
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION private.notify(
    p_recipient_id uuid,
    p_actor_id uuid,
    p_kind text,
    p_title text,
    p_body text,
    p_booking_id uuid,
    p_email boolean,
    p_data jsonb DEFAULT '{}'::jsonb)
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

    IF p_actor_id IS DISTINCT FROM p_recipient_id
       AND EXISTS (SELECT 1 FROM private.push_tokens t WHERE t.user_id = p_recipient_id) THEN
        INSERT INTO private.notification_deliveries (notification_id, channel) VALUES (v_id, 'push');
    END IF;
END;
$function$;

-- ---------------------------------------------------------------------------
-- 3. Hand the Edge Function what a push needs: ids to route the tap and the
--    recipient's current device tokens.
-- ---------------------------------------------------------------------------

DROP FUNCTION public.claim_notification_deliveries(uuid[], integer);

CREATE FUNCTION public.claim_notification_deliveries(p_delivery_ids uuid[] DEFAULT NULL::uuid[], p_limit integer DEFAULT 20)
 RETURNS TABLE(
    delivery_id uuid,
    channel text,
    attempt smallint,
    recipient_email text,
    recipient_name text,
    recipient_role text,
    kind text,
    title text,
    body text,
    created_at timestamp with time zone,
    booking jsonb,
    notification_id uuid,
    booking_id uuid,
    push_tokens text[])
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
           END,
           n.id,
           n.booking_id,
           CASE WHEN c.channel = 'push' THEN ARRAY(
               SELECT t.token FROM private.push_tokens t
               WHERE t.user_id = n.recipient_id
               ORDER BY t.updated_at DESC) END
    FROM claimed c
    JOIN public.notifications n ON n.id = c.notification_id
    JOIN public.profiles p ON p.id = n.recipient_id
    LEFT JOIN public.bookings b ON b.id = n.booking_id;
END;
$function$;

REVOKE ALL ON FUNCTION public.claim_notification_deliveries(uuid[], integer) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.claim_notification_deliveries(uuid[], integer) TO service_role;
