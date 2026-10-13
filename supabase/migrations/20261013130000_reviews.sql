-- Ratings and reviews.
--
-- A client can review each of their COMPLETED bookings once: 1–5 stars and
-- optional text (up to 1000 characters). They can edit or delete it at any
-- time, so older bookings can be reviewed too. The review applies to every
-- service on the booking (`service_ids`, snapshotted) and to the provider.
-- The provider may post one public reply, which they can edit or remove.
--
-- Photos: a review can carry up to four photos (uploaded to the client's own
-- `post-media` folder). They are published as a Discovery post by the client,
-- tagged with the provider and the booking's first service, and approved
-- straight away because the booking is verified. The post belongs to the
-- review (`posts.review_id`): deleting the review deletes the post, and the
-- post's tag, service, photos and caption can only change through the review.
--
-- Every write goes through SECURITY DEFINER RPCs (`submit_review`,
-- `delete_review`, `reply_to_review`); clients only read. Per-provider totals
-- live in `provider_review_stats`, kept in step by a trigger, so search and
-- map results can show ratings without aggregating reviews.
--
-- Notifications: the provider hears about new reviews (and changed ratings)
-- in the app and by push; the client gets a thank-you email; the client hears
-- about the provider's first reply in the app and by push.

-- ---------------------------------------------------------------------------
-- 1. Tables.
-- ---------------------------------------------------------------------------

CREATE TABLE public.reviews (
    id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    booking_id    uuid NOT NULL UNIQUE REFERENCES public.bookings(id) ON DELETE CASCADE,
    provider_id   uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    client_id     uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    rating        smallint NOT NULL,
    body          text,
    service_ids   uuid[] NOT NULL DEFAULT '{}'::uuid[],
    service_names text[] NOT NULL DEFAULT '{}'::text[],
    reply         text,
    replied_at    timestamp with time zone,
    edited_at     timestamp with time zone,
    created_at    timestamp with time zone NOT NULL DEFAULT now(),
    updated_at    timestamp with time zone NOT NULL DEFAULT now(),
    CONSTRAINT reviews_rating CHECK (rating BETWEEN 1 AND 5),
    CONSTRAINT reviews_body_length CHECK (body IS NULL OR char_length(body) BETWEEN 1 AND 1000),
    CONSTRAINT reviews_reply_length CHECK (reply IS NULL OR char_length(reply) BETWEEN 1 AND 1000),
    CONSTRAINT reviews_reply_time CHECK ((reply IS NULL) = (replied_at IS NULL))
);

COMMENT ON TABLE public.reviews IS
    'Client reviews of completed bookings. Written only through RPCs (submit_review, delete_review, reply_to_review).';

CREATE INDEX reviews_provider_created_idx ON public.reviews (provider_id, created_at DESC, id DESC);
CREATE INDEX reviews_client_idx ON public.reviews (client_id);
CREATE INDEX reviews_service_ids_idx ON public.reviews USING gin (service_ids);

ALTER TABLE public.reviews ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Reviews are public to signed-in users" ON public.reviews
    FOR SELECT TO authenticated
    USING (true);

REVOKE ALL ON public.reviews FROM anon, authenticated;
GRANT SELECT ON public.reviews TO authenticated;

CREATE TABLE public.provider_review_stats (
    provider_id    uuid PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
    review_count   integer NOT NULL DEFAULT 0 CHECK (review_count >= 0),
    rating_sum     integer NOT NULL DEFAULT 0 CHECK (rating_sum >= 0),
    stars_1        integer NOT NULL DEFAULT 0 CHECK (stars_1 >= 0),
    stars_2        integer NOT NULL DEFAULT 0 CHECK (stars_2 >= 0),
    stars_3        integer NOT NULL DEFAULT 0 CHECK (stars_3 >= 0),
    stars_4        integer NOT NULL DEFAULT 0 CHECK (stars_4 >= 0),
    stars_5        integer NOT NULL DEFAULT 0 CHECK (stars_5 >= 0),
    rating_average numeric(3, 2) GENERATED ALWAYS AS (
        CASE WHEN review_count > 0 THEN round(rating_sum::numeric / review_count, 2) END) STORED,
    updated_at     timestamp with time zone NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.provider_review_stats IS
    'Per-provider review totals, maintained by a trigger on reviews. Read-only for clients.';

ALTER TABLE public.provider_review_stats ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Review stats are public to signed-in users" ON public.provider_review_stats
    FOR SELECT TO authenticated
    USING (true);

REVOKE ALL ON public.provider_review_stats FROM anon, authenticated;
GRANT SELECT ON public.provider_review_stats TO authenticated;

-- Applies one review's rating to its provider's totals (p_delta is +1 or -1).
-- Removals only update an existing row: when the provider's own profile is
-- being deleted, inserting a stats row for them would fail the foreign key.
CREATE FUNCTION private.apply_review_stats(p_provider_id uuid, p_rating smallint, p_delta integer)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
BEGIN
    IF p_delta > 0 THEN
        INSERT INTO public.provider_review_stats AS s
            (provider_id, review_count, rating_sum, stars_1, stars_2, stars_3, stars_4, stars_5)
        VALUES (
            p_provider_id, 1, p_rating,
            (p_rating = 1)::integer, (p_rating = 2)::integer, (p_rating = 3)::integer,
            (p_rating = 4)::integer, (p_rating = 5)::integer)
        ON CONFLICT (provider_id) DO UPDATE SET
            review_count = s.review_count + 1,
            rating_sum   = s.rating_sum + p_rating,
            stars_1      = s.stars_1 + (p_rating = 1)::integer,
            stars_2      = s.stars_2 + (p_rating = 2)::integer,
            stars_3      = s.stars_3 + (p_rating = 3)::integer,
            stars_4      = s.stars_4 + (p_rating = 4)::integer,
            stars_5      = s.stars_5 + (p_rating = 5)::integer,
            updated_at   = now();
    ELSE
        UPDATE public.provider_review_stats s SET
            review_count = greatest(s.review_count - 1, 0),
            rating_sum   = greatest(s.rating_sum - p_rating, 0),
            stars_1      = greatest(s.stars_1 - (p_rating = 1)::integer, 0),
            stars_2      = greatest(s.stars_2 - (p_rating = 2)::integer, 0),
            stars_3      = greatest(s.stars_3 - (p_rating = 3)::integer, 0),
            stars_4      = greatest(s.stars_4 - (p_rating = 4)::integer, 0),
            stars_5      = greatest(s.stars_5 - (p_rating = 5)::integer, 0),
            updated_at   = now()
        WHERE s.provider_id = p_provider_id;
    END IF;
END;
$function$;

CREATE FUNCTION private.on_review_change()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
BEGIN
    IF TG_OP IN ('UPDATE', 'DELETE') THEN
        PERFORM private.apply_review_stats(OLD.provider_id, OLD.rating, -1);
    END IF;
    IF TG_OP IN ('INSERT', 'UPDATE') THEN
        PERFORM private.apply_review_stats(NEW.provider_id, NEW.rating, 1);
    END IF;
    RETURN NULL;
END;
$function$;

REVOKE ALL ON FUNCTION private.apply_review_stats(uuid, smallint, integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION private.on_review_change() FROM PUBLIC;

CREATE TRIGGER reviews_stats
    AFTER INSERT OR DELETE OR UPDATE OF rating, provider_id ON public.reviews
    FOR EACH ROW EXECUTE FUNCTION private.on_review_change();

-- ---------------------------------------------------------------------------
-- 2. Review photo posts.
-- ---------------------------------------------------------------------------

ALTER TABLE public.posts
    ADD COLUMN review_id uuid UNIQUE REFERENCES public.reviews(id) ON DELETE CASCADE;

COMMENT ON COLUMN public.posts.review_id IS
    'Set when the post holds a review''s photos. Managed by submit_review; the post is deleted with the review.';

-- Clients can't create review posts or change what a review post shows;
-- submit_review (running as the owner) can.
CREATE OR REPLACE FUNCTION public.protect_post_columns()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
BEGIN
    IF current_user IN ('anon', 'authenticated') THEN
        IF NEW.id IS DISTINCT FROM OLD.id
           OR NEW.author_id IS DISTINCT FROM OLD.author_id
           OR NEW.likes_count IS DISTINCT FROM OLD.likes_count
           OR NEW.comments_count IS DISTINCT FROM OLD.comments_count
           OR NEW.created_at IS DISTINCT FROM OLD.created_at
           OR NEW.review_id IS DISTINCT FROM OLD.review_id THEN
            RAISE EXCEPTION 'Protected post column cannot be modified directly' USING ERRCODE = '42501';
        END IF;
        IF OLD.review_id IS NOT NULL
           AND (NEW.tag_status IS DISTINCT FROM OLD.tag_status
                OR NEW.tagged_provider_id IS DISTINCT FROM OLD.tagged_provider_id
                OR NEW.service_id IS DISTINCT FROM OLD.service_id
                OR NEW.media_urls IS DISTINCT FROM OLD.media_urls
                OR NEW.caption IS DISTINCT FROM OLD.caption) THEN
            RAISE EXCEPTION 'review_post_locked' USING ERRCODE = '42501';
        END IF;
    END IF;
    RETURN NEW;
END;
$function$;

DROP POLICY IF EXISTS "Users can create posts" ON public.posts;

CREATE POLICY "Users can create posts" ON public.posts
    FOR INSERT TO authenticated
    WITH CHECK (
        (SELECT auth.uid()) = author_id
        AND review_id IS NULL
        AND (tagged_provider_id IS NULL OR tag_status = 'pending')
    );

-- ---------------------------------------------------------------------------
-- 3. Notification kinds, and notification data for the email renderer.
-- ---------------------------------------------------------------------------

ALTER TABLE public.notifications DROP CONSTRAINT notifications_kind;
ALTER TABLE public.notifications ADD CONSTRAINT notifications_kind CHECK (kind = ANY (ARRAY[
    'booking_request', 'booking_new', 'booking_requested', 'booking_confirmed', 'booking_declined',
    'booking_cancelled', 'booking_expired', 'booking_completed', 'booking_no_show', 'booking_reminder',
    'booking_request_reminder',
    'review_received', 'review_updated', 'review_thanks', 'review_reply']));

-- Same as before plus the notification's `data`, which review emails use.
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
    push_tokens text[],
    data jsonb)
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
               ORDER BY t.updated_at DESC) END,
           n.data
    FROM claimed c
    JOIN public.notifications n ON n.id = c.notification_id
    JOIN public.profiles p ON p.id = n.recipient_id
    LEFT JOIN public.bookings b ON b.id = n.booking_id;
END;
$function$;

REVOKE ALL ON FUNCTION public.claim_notification_deliveries(uuid[], integer) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.claim_notification_deliveries(uuid[], integer) TO service_role;

-- ---------------------------------------------------------------------------
-- 4. Writing reviews.
-- ---------------------------------------------------------------------------

-- "★★★★☆"
CREATE FUNCTION private.review_stars(p_rating integer)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO ''
AS $function$
    SELECT repeat('★', p_rating) || repeat('☆', 5 - p_rating);
$function$;

REVOKE ALL ON FUNCTION private.review_stars(integer) FROM PUBLIC;

-- Creates the caller's review of one of their completed bookings, or updates
-- it if they already left one.
--
-- p_photo_urls: NULL keeps the current photos; an empty array removes them
-- (the app then deletes the files); otherwise up to four public URLs of
-- images the caller uploaded to their own post-media folder, in order.
CREATE FUNCTION public.submit_review(
    p_booking_id uuid,
    p_rating integer,
    p_body text DEFAULT NULL,
    p_photo_urls text[] DEFAULT NULL)
 RETURNS public.reviews
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
    v_uid           uuid := auth.uid();
    v_body          text := nullif(btrim(coalesce(p_body, '')), '');
    v_folder        text;
    v_url           text;
    v_file          text;
    v_booking       public.bookings%ROWTYPE;
    v_existing      public.reviews%ROWTYPE;
    v_review        public.reviews%ROWTYPE;
    v_is_new        boolean;
    v_service_ids   uuid[];
    v_service_names text[];
    v_services      text;
    v_post_id       uuid;
    v_excerpt       text;
    v_data          jsonb;
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'not_authenticated' USING ERRCODE = '42501';
    END IF;
    IF p_rating IS NULL OR p_rating NOT BETWEEN 1 AND 5 THEN
        RAISE EXCEPTION 'invalid_rating' USING ERRCODE = '22023';
    END IF;
    IF char_length(v_body) > 1000 THEN
        RAISE EXCEPTION 'review_too_long' USING ERRCODE = '22023';
    END IF;

    IF p_photo_urls IS NOT NULL THEN
        v_folder := '/storage/v1/object/public/post-media/' || v_uid::text || '/';
        IF cardinality(p_photo_urls) > 4 THEN
            RAISE EXCEPTION 'too_many_photos' USING ERRCODE = '22023';
        END IF;
        IF array_position(p_photo_urls, NULL) IS NOT NULL
           OR cardinality(p_photo_urls) <> (SELECT count(DISTINCT u) FROM unnest(p_photo_urls) u) THEN
            RAISE EXCEPTION 'invalid_photos' USING ERRCODE = '22023';
        END IF;
        FOREACH v_url IN ARRAY p_photo_urls LOOP
            v_file := split_part(substr(v_url, strpos(v_url, v_folder) + char_length(v_folder)), '?', 1);
            IF char_length(v_url) > 600
               OR v_url !~ '^https://[^/?#]+/'
               OR strpos(v_url, v_folder) = 0
               OR v_file !~ '^[A-Za-z0-9._-]+$'
               OR NOT EXISTS (
                   SELECT 1 FROM storage.objects o
                   WHERE o.bucket_id = 'post-media' AND o.name = v_uid::text || '/' || v_file) THEN
                RAISE EXCEPTION 'invalid_photos' USING ERRCODE = '22023';
            END IF;
        END LOOP;
    END IF;

    -- Locking the booking serialises two submissions for it.
    SELECT * INTO v_booking FROM public.bookings WHERE id = p_booking_id FOR UPDATE;
    IF NOT FOUND OR v_booking.client_id IS DISTINCT FROM v_uid THEN
        RAISE EXCEPTION 'booking_not_found' USING ERRCODE = 'P0002';
    END IF;
    IF v_booking.status <> 'completed' THEN
        RAISE EXCEPTION 'booking_not_completed' USING ERRCODE = 'P0001';
    END IF;
    IF v_booking.provider_id IS NULL THEN
        RAISE EXCEPTION 'provider_unavailable' USING ERRCODE = 'P0001';
    END IF;

    SELECT coalesce(array_agg(i.service_id ORDER BY i.position) FILTER (WHERE i.service_id IS NOT NULL), '{}'::uuid[]),
           coalesce(array_agg(i.service_name ORDER BY i.position), '{}'::text[])
    INTO v_service_ids, v_service_names
    FROM public.booking_items i
    WHERE i.booking_id = p_booking_id;
    v_services := coalesce(nullif(array_to_string(v_service_names, ', '), ''), 'your appointment');

    SELECT * INTO v_existing FROM public.reviews WHERE booking_id = p_booking_id;
    v_is_new := NOT FOUND;

    IF v_is_new THEN
        INSERT INTO public.reviews (booking_id, provider_id, client_id, rating, body, service_ids, service_names)
        VALUES (p_booking_id, v_booking.provider_id, v_uid, p_rating, v_body, v_service_ids, v_service_names)
        RETURNING * INTO v_review;
    ELSE
        UPDATE public.reviews r
        SET rating = p_rating,
            body = v_body,
            edited_at = CASE WHEN r.rating IS DISTINCT FROM p_rating OR r.body IS DISTINCT FROM v_body
                             THEN now() ELSE r.edited_at END,
            updated_at = now()
        WHERE r.id = v_existing.id
        RETURNING * INTO v_review;
    END IF;

    -- The photo post follows the review.
    SELECT p.id INTO v_post_id FROM public.posts p WHERE p.review_id = v_review.id;
    IF p_photo_urls IS NOT NULL AND cardinality(p_photo_urls) = 0 THEN
        DELETE FROM public.posts p WHERE p.review_id = v_review.id;
    ELSIF p_photo_urls IS NOT NULL AND v_post_id IS NULL THEN
        INSERT INTO public.posts (author_id, media_urls, caption, service_id, tagged_provider_id, tag_status, review_id)
        VALUES (v_uid, p_photo_urls, v_body, v_service_ids[1], v_booking.provider_id, 'approved', v_review.id);
    ELSIF p_photo_urls IS NOT NULL THEN
        UPDATE public.posts p SET media_urls = p_photo_urls, caption = v_body, updated_at = now()
        WHERE p.id = v_post_id;
    ELSIF v_post_id IS NOT NULL THEN
        UPDATE public.posts p SET caption = v_body, updated_at = now()
        WHERE p.id = v_post_id AND p.caption IS DISTINCT FROM v_body;
    END IF;

    v_excerpt := CASE
        WHEN v_body IS NULL THEN NULL
        WHEN char_length(v_body) > 140 THEN left(v_body, 139) || '…'
        ELSE v_body
    END;
    v_data := jsonb_build_object(
        'review_id', v_review.id,
        'rating', p_rating,
        'body', left(v_body, 1000),
        'services', to_jsonb(v_service_names),
        'provider_id', v_booking.provider_id,
        'provider_name', v_booking.provider_name,
        'client_name', v_booking.client_name);

    IF v_is_new THEN
        PERFORM private.notify(v_booking.provider_id, v_uid, 'review_received',
            format('New %s-star review', p_rating),
            format('%s %s reviewed %s', private.review_stars(p_rating), v_booking.client_name, v_services)
                || CASE WHEN v_excerpt IS NOT NULL THEN format(': "%s"', v_excerpt) ELSE '.' END,
            p_booking_id, false, v_data);
        -- Actor and recipient are the same, so this is filed as read and
        -- never pushed; the email is the thank-you.
        PERFORM private.notify(v_uid, v_uid, 'review_thanks', 'Thanks for your review',
            format('Your %s-star review of %s with %s is now live on their profile.',
                   p_rating, v_services, v_booking.provider_name),
            p_booking_id, true, v_data);
    ELSIF v_existing.rating IS DISTINCT FROM p_rating THEN
        PERFORM private.notify(v_booking.provider_id, v_uid, 'review_updated', 'Review updated',
            format('%s changed their rating for %s from %s to %s stars.',
                   v_booking.client_name, v_services, v_existing.rating, p_rating),
            p_booking_id, false, v_data);
    END IF;

    RETURN v_review;
END;
$function$;

REVOKE ALL ON FUNCTION public.submit_review(uuid, integer, text, text[]) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.submit_review(uuid, integer, text, text[]) TO authenticated;

-- Deletes the caller's review (and its photo post). Returns the photo URLs
-- that were on the post so the app can delete the files.
CREATE FUNCTION public.delete_review(p_review_id uuid)
 RETURNS text[]
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
    v_uid    uuid := auth.uid();
    v_review public.reviews%ROWTYPE;
    v_media  text[];
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'not_authenticated' USING ERRCODE = '42501';
    END IF;
    SELECT * INTO v_review FROM public.reviews WHERE id = p_review_id FOR UPDATE;
    IF NOT FOUND OR v_review.client_id IS DISTINCT FROM v_uid THEN
        RAISE EXCEPTION 'review_not_found' USING ERRCODE = 'P0002';
    END IF;
    SELECT p.media_urls INTO v_media FROM public.posts p WHERE p.review_id = p_review_id;
    DELETE FROM public.reviews WHERE id = p_review_id;
    RETURN coalesce(v_media, '{}'::text[]);
END;
$function$;

REVOKE ALL ON FUNCTION public.delete_review(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.delete_review(uuid) TO authenticated;

-- Sets (or, with empty text, removes) the provider's public reply. The
-- client is notified the first time a reply appears.
CREATE FUNCTION public.reply_to_review(p_review_id uuid, p_reply text)
 RETURNS public.reviews
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
    v_uid      uuid := auth.uid();
    v_reply    text := nullif(btrim(coalesce(p_reply, '')), '');
    v_review   public.reviews%ROWTYPE;
    v_had      boolean;
    v_provider text;
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'not_authenticated' USING ERRCODE = '42501';
    END IF;
    IF char_length(v_reply) > 1000 THEN
        RAISE EXCEPTION 'reply_too_long' USING ERRCODE = '22023';
    END IF;
    SELECT * INTO v_review FROM public.reviews WHERE id = p_review_id FOR UPDATE;
    IF NOT FOUND OR v_review.provider_id IS DISTINCT FROM v_uid THEN
        RAISE EXCEPTION 'review_not_found' USING ERRCODE = 'P0002';
    END IF;
    v_had := v_review.reply IS NOT NULL;

    UPDATE public.reviews r
    SET reply = v_reply,
        replied_at = CASE
            WHEN v_reply IS NULL THEN NULL
            WHEN r.reply IS DISTINCT FROM v_reply THEN now()
            ELSE r.replied_at
        END,
        updated_at = now()
    WHERE r.id = p_review_id
    RETURNING * INTO v_review;

    IF NOT v_had AND v_reply IS NOT NULL THEN
        SELECT b.provider_name INTO v_provider FROM public.bookings b WHERE b.id = v_review.booking_id;
        PERFORM private.notify(v_review.client_id, v_uid, 'review_reply',
            format('%s replied to your review', coalesce(v_provider, 'Your provider')),
            CASE WHEN char_length(v_reply) > 200 THEN left(v_reply, 199) || '…' ELSE v_reply END,
            v_review.booking_id, false,
            jsonb_build_object('review_id', v_review.id, 'provider_id', v_review.provider_id));
    END IF;

    RETURN v_review;
END;
$function$;

REVOKE ALL ON FUNCTION public.reply_to_review(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.reply_to_review(uuid, text) TO authenticated;

-- ---------------------------------------------------------------------------
-- 5. Reading reviews.
-- ---------------------------------------------------------------------------

-- One page of reviews, newest first, for a provider, a service or a single
-- booking (at least one is required). Reviewers are shown as "First L." with
-- their profile photo. Keyset-paginated on (created_at, id).
CREATE FUNCTION public.list_reviews(
    p_provider_id uuid DEFAULT NULL,
    p_service_id uuid DEFAULT NULL,
    p_booking_id uuid DEFAULT NULL,
    p_before timestamp with time zone DEFAULT NULL,
    p_before_id uuid DEFAULT NULL,
    p_limit integer DEFAULT 20)
 RETURNS TABLE(
    id uuid,
    booking_id uuid,
    provider_id uuid,
    client_id uuid,
    reviewer_name text,
    reviewer_avatar_url text,
    rating smallint,
    body text,
    service_ids uuid[],
    service_names text[],
    photo_urls text[],
    post_id uuid,
    reply text,
    replied_at timestamp with time zone,
    edited_at timestamp with time zone,
    created_at timestamp with time zone)
 LANGUAGE plpgsql
 STABLE
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'not_authenticated' USING ERRCODE = '42501';
    END IF;
    IF p_provider_id IS NULL AND p_service_id IS NULL AND p_booking_id IS NULL THEN
        RAISE EXCEPTION 'review_filter_required' USING ERRCODE = '22023';
    END IF;

    RETURN QUERY
    SELECT r.id,
           r.booking_id,
           r.provider_id,
           r.client_id,
           coalesce(nullif(btrim(pr.first_name), ''), 'Myglo client')
               || coalesce(' ' || upper(left(nullif(btrim(pr.last_name), ''), 1)) || '.', ''),
           pr.profile_pic,
           r.rating,
           r.body,
           r.service_ids,
           r.service_names,
           coalesce(p.media_urls, '{}'::text[]),
           p.id,
           r.reply,
           r.replied_at,
           r.edited_at,
           r.created_at
    FROM public.reviews r
    LEFT JOIN public.profiles pr ON pr.id = r.client_id
    LEFT JOIN public.posts p ON p.review_id = r.id
    WHERE (p_provider_id IS NULL OR r.provider_id = p_provider_id)
      AND (p_service_id IS NULL OR r.service_ids @> ARRAY[p_service_id])
      AND (p_booking_id IS NULL OR r.booking_id = p_booking_id)
      AND (p_before IS NULL
           OR (r.created_at, r.id) < (p_before, coalesce(p_before_id, 'ffffffff-ffff-ffff-ffff-ffffffffffff'::uuid)))
    ORDER BY r.created_at DESC, r.id DESC
    LIMIT least(greatest(coalesce(p_limit, 20), 1), 50);
END;
$function$;

REVOKE ALL ON FUNCTION public.list_reviews(uuid, uuid, uuid, timestamp with time zone, uuid, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_reviews(uuid, uuid, uuid, timestamp with time zone, uuid, integer) TO authenticated;

-- Totals for one service's reviews (a provider's come from
-- provider_review_stats).
CREATE FUNCTION public.get_service_review_summary(p_service_id uuid)
 RETURNS TABLE(
    review_count integer,
    rating_average numeric,
    stars_1 integer,
    stars_2 integer,
    stars_3 integer,
    stars_4 integer,
    stars_5 integer)
 LANGUAGE sql
 STABLE
 SET search_path TO ''
AS $function$
    SELECT count(*)::integer,
           round(avg(r.rating), 2),
           (count(*) FILTER (WHERE r.rating = 1))::integer,
           (count(*) FILTER (WHERE r.rating = 2))::integer,
           (count(*) FILTER (WHERE r.rating = 3))::integer,
           (count(*) FILTER (WHERE r.rating = 4))::integer,
           (count(*) FILTER (WHERE r.rating = 5))::integer
    FROM public.reviews r
    WHERE r.service_ids @> ARRAY[p_service_id];
$function$;

REVOKE ALL ON FUNCTION public.get_service_review_summary(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_service_review_summary(uuid) TO authenticated;

-- ---------------------------------------------------------------------------
-- 6. Bookings show whether they've been reviewed (columns appended; options
--    restated because CREATE OR REPLACE VIEW would otherwise reset them).
-- ---------------------------------------------------------------------------

CREATE OR REPLACE VIEW public.booking_details
WITH (security_invoker = true)
AS
SELECT b.id,
    b.reference,
    b.client_id,
    b.provider_id,
        CASE
            WHEN b.status = 'pending'::text AND b.starts_at <= now() THEN 'expired'::text
            ELSE b.status
        END AS status,
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
    COALESCE(( SELECT jsonb_agg(jsonb_build_object('service_id', i.service_id, 'name', i.service_name, 'category', i.category, 'duration_minutes', i.duration_minutes, 'price_cents', i.price_cents) ORDER BY i."position") AS jsonb_agg
           FROM public.booking_items i
          WHERE i.booking_id = b.id), '[]'::jsonb) AS items,
        CASE
            WHEN b.provider_id = (( SELECT auth.uid() AS uid)) THEN b.platform_fee_cents
            ELSE NULL::integer
        END AS platform_fee_cents,
    rv.id AS review_id,
    rv.rating AS review_rating
   FROM public.bookings b
     LEFT JOIN public.public_profiles pp ON pp.id = b.provider_id
     LEFT JOIN public.public_profiles cp ON cp.id = b.client_id
     LEFT JOIN public.reviews rv ON rv.booking_id = b.id;

-- ---------------------------------------------------------------------------
-- 7. Ratings in search and map results (columns appended).
-- ---------------------------------------------------------------------------

DROP FUNCTION public.map_providers(double precision, double precision, double precision, integer);

CREATE FUNCTION public.map_providers(p_latitude double precision, p_longitude double precision, p_radius_m double precision DEFAULT 20000, p_limit integer DEFAULT 200)
 RETURNS TABLE(provider_id uuid, provider_name text, profile_pic text, cover_photo text, address_text text, latitude double precision, longitude double precision, approximate_location boolean, distance_km double precision, categories text[], service_count integer, min_price numeric, accepts_bookings boolean, offers_studio boolean, offers_mobile boolean, rating_average numeric, review_count integer)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
    v_radius double precision := least(greatest(coalesce(p_radius_m, 20000), 500), 100000);
    v_limit  integer := least(greatest(coalesce(p_limit, 200), 1), 300);
    v_origin public.geography;
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Not authorized' USING ERRCODE = '42501';
    END IF;
    IF p_latitude IS NULL OR p_longitude IS NULL
       OR p_latitude NOT BETWEEN -90 AND 90 OR p_longitude NOT BETWEEN -180 AND 180 THEN
        RAISE EXCEPTION 'invalid_location' USING ERRCODE = '22023';
    END IF;
    v_origin := public.st_setsrid(public.st_makepoint(p_longitude, p_latitude), 4326)::public.geography;

    RETURN QUERY
    WITH nearby AS (
        SELECT pr.id,
               coalesce(nullif(btrim(pr.provider_name), ''),
                        nullif(btrim(concat_ws(' ', btrim(pr.first_name), btrim(pr.last_name))), ''),
                        'Provider') AS display_name,
               pr.profile_pic,
               pr.cover_photos[1] AS cover_photo,
               pr.address_text,
               coalesce(bs.offers_studio, true) AS studio,
               coalesce(bs.offers_mobile, false) AS mobile,
               coalesce(bs.accepts_bookings, true) AS accepting,
               private.public_provider_point(pr.coordinates, bs.offers_studio) AS point
        FROM public.profiles pr
        LEFT JOIN public.provider_booking_settings bs ON bs.provider_id = pr.id
        WHERE pr.role = 'provider'
          AND pr.coordinates IS NOT NULL
          AND public.st_dwithin(pr.coordinates, v_origin, v_radius)
    )
    SELECT n.id,
           n.display_name,
           n.profile_pic,
           n.cover_photo,
           CASE WHEN n.studio THEN n.address_text END,
           public.st_y(n.point::public.geometry),
           public.st_x(n.point::public.geometry),
           NOT n.studio,
           round((public.st_distance(n.point, v_origin) / 1000)::numeric, 1)::double precision,
           st.categories,
           st.service_count,
           st.min_price,
           n.accepting,
           n.studio,
           n.mobile,
           rs.rating_average,
           coalesce(rs.review_count, 0)
    FROM nearby n
    CROSS JOIN LATERAL (
        SELECT count(*)::integer AS service_count,
               min(s.price) AS min_price,
               coalesce(array_agg(DISTINCT btrim(s.category))
                            FILTER (WHERE nullif(btrim(s.category), '') IS NOT NULL), '{}'::text[]) AS categories
        FROM public.services s
        WHERE s.provider_id = n.id
    ) st
    LEFT JOIN public.provider_review_stats rs ON rs.provider_id = n.id
    ORDER BY public.st_distance(n.point, v_origin)
    LIMIT v_limit;
END;
$function$;

REVOKE ALL ON FUNCTION public.map_providers(double precision, double precision, double precision, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.map_providers(double precision, double precision, double precision, integer) TO authenticated, service_role;

DROP FUNCTION public.search_providers(text, double precision, double precision, integer);

CREATE FUNCTION public.search_providers(p_query text, p_latitude double precision DEFAULT NULL::double precision, p_longitude double precision DEFAULT NULL::double precision, p_limit integer DEFAULT 30)
 RETURNS TABLE(provider_id uuid, provider_name text, profile_pic text, cover_photo text, address_text text, approximate_location boolean, distance_km double precision, categories text[], service_count integer, min_price numeric, matched_services jsonb, accepts_bookings boolean, offers_studio boolean, offers_mobile boolean, rating_average numeric, review_count integer)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
    v_query    text := left(lower(btrim(regexp_replace(coalesce(p_query, ''), '\s+', ' ', 'g'))), 80);
    v_limit    integer := least(greatest(coalesce(p_limit, 30), 1), 50);
    v_words    text[];
    v_patterns text[];
    v_contains text;
    v_prefix   text;
    v_origin   public.geography;
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Not authorized' USING ERRCODE = '42501';
    END IF;
    IF char_length(v_query) < 2 THEN
        RETURN;
    END IF;

    -- LIKE patterns with the wildcards in the user's text escaped.
    SELECT array_agg(w ORDER BY ord) INTO v_words
    FROM (
        SELECT DISTINCT ON (w) w, ord
        FROM unnest(string_to_array(v_query, ' ')) WITH ORDINALITY AS t(w, ord)
        WHERE w <> ''
        ORDER BY w, ord
    ) words;
    v_words := v_words[1:6];
    v_patterns := ARRAY(
        SELECT '%' || replace(replace(replace(w, '\', '\\'), '%', '\%'), '_', '\_') || '%'
        FROM unnest(v_words) AS w);
    v_prefix := replace(replace(replace(v_query, '\', '\\'), '%', '\%'), '_', '\_') || '%';
    v_contains := '%' || v_prefix;

    IF p_latitude BETWEEN -90 AND 90 AND p_longitude BETWEEN -180 AND 180 THEN
        v_origin := public.st_setsrid(public.st_makepoint(p_longitude, p_latitude), 4326)::public.geography;
    END IF;

    RETURN QUERY
    WITH candidates AS (
        SELECT pr.id,
               coalesce(nullif(btrim(pr.provider_name), ''),
                        nullif(btrim(concat_ws(' ', btrim(pr.first_name), btrim(pr.last_name))), ''),
                        'Provider') AS display_name,
               pr.profile_pic,
               pr.cover_photos[1] AS cover_photo,
               pr.address_text,
               coalesce(bs.offers_studio, true) AS studio,
               coalesce(bs.offers_mobile, false) AS mobile,
               coalesce(bs.accepts_bookings, true) AS accepting,
               private.public_provider_point(pr.coordinates, bs.offers_studio) AS point,
               lower(concat_ws(' ',
                   pr.provider_name, pr.first_name, pr.last_name,
                   CASE WHEN coalesce(bs.offers_studio, true) THEN pr.address_text END,
                   (SELECT string_agg(concat_ws(' ', s.name, s.category), ' ')
                    FROM public.services s WHERE s.provider_id = pr.id))) AS haystack
        FROM public.profiles pr
        LEFT JOIN public.provider_booking_settings bs ON bs.provider_id = pr.id
        WHERE pr.role = 'provider'
    ),
    matches AS (
        SELECT c.*,
               st.service_count,
               st.min_price,
               st.categories,
               ms.matched,
               (CASE
                    WHEN lower(c.display_name) = v_query THEN 100
                    WHEN lower(c.display_name) LIKE v_prefix THEN 60
                    WHEN lower(c.display_name) LIKE v_contains THEN 40
                    ELSE 0
                END
                + CASE WHEN ms.matched IS NOT NULL THEN 25 ELSE 0 END
                + CASE WHEN c.studio AND lower(coalesce(c.address_text, '')) LIKE v_contains THEN 10 ELSE 0 END
               ) AS score,
               CASE WHEN v_origin IS NOT NULL AND c.point IS NOT NULL
                    THEN round((public.st_distance(c.point, v_origin) / 1000)::numeric, 1)::double precision
               END AS km
        FROM candidates c
        CROSS JOIN LATERAL (
            SELECT count(*)::integer AS service_count,
                   min(s.price) AS min_price,
                   coalesce(array_agg(DISTINCT btrim(s.category))
                                FILTER (WHERE nullif(btrim(s.category), '') IS NOT NULL), '{}'::text[]) AS categories
            FROM public.services s
            WHERE s.provider_id = c.id
        ) st
        LEFT JOIN LATERAL (
            SELECT jsonb_agg(jsonb_build_object(
                       'id', m.id,
                       'name', m.name,
                       'category', m.category,
                       'price', m.price,
                       'duration_minutes', m.duration_minutes)
                   ORDER BY m.rank DESC, m.name) AS matched
            FROM (
                SELECT s.id, s.name, s.category, s.price, s.duration_minutes,
                       CASE WHEN lower(s.name) LIKE v_contains THEN 2
                            WHEN lower(s.name) LIKE ANY (v_patterns) THEN 1
                            ELSE 0 END AS rank
                FROM public.services s
                WHERE s.provider_id = c.id
                  AND (lower(s.name) LIKE ANY (v_patterns)
                       OR lower(coalesce(s.category, '')) LIKE ANY (v_patterns))
                ORDER BY rank DESC, s.name
                LIMIT 3
            ) m
        ) ms ON true
        WHERE c.haystack LIKE ALL (v_patterns)
    )
    SELECT m.id,
           m.display_name,
           m.profile_pic,
           m.cover_photo,
           CASE WHEN m.studio THEN m.address_text END,
           NOT m.studio,
           m.km,
           m.categories,
           m.service_count,
           m.min_price,
           m.matched,
           m.accepting,
           m.studio,
           m.mobile,
           rs.rating_average,
           coalesce(rs.review_count, 0)
    FROM matches m
    LEFT JOIN public.provider_review_stats rs ON rs.provider_id = m.id
    ORDER BY m.score DESC, m.km ASC NULLS LAST, lower(m.display_name)
    LIMIT v_limit;
END;
$function$;

REVOKE ALL ON FUNCTION public.search_providers(text, double precision, double precision, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.search_providers(text, double precision, double precision, integer) TO authenticated, service_role;
