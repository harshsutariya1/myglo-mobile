-- Moderation: reports, hiding content, suspending accounts and blocking a
-- provider's bookings.
--
-- * Clients and providers report posts, comments, reviews and providers;
--   clients report a booking that went wrong (from its start until
--   report_window_hours after its end). A booking report holds the
--   provider's share until an admin resolves it.
-- * Admins hide posts, comments and reviews. Hidden content is visible only
--   to its author (row level security), drops out of feeds and review
--   lists, and hidden reviews leave the provider's rating.
-- * A suspended account can't sign in (an Auth ban, set by the jobs worker)
--   and can't write anything, even with a session it still holds: triggers
--   refuse its writes, including through RPCs. Suspended providers, and
--   providers whose bookings are blocked, drop out of search, the map and
--   availability, and can't be booked.
-- Restrictions live in a private table no app role can read or write.

-- ---------------------------------------------------------------------------
-- 1. Restrictions on accounts.
-- ---------------------------------------------------------------------------

CREATE TABLE private.user_restrictions (
    user_id             uuid        PRIMARY KEY REFERENCES auth.users (id) ON DELETE CASCADE,
    suspended_at        timestamptz,
    suspended_reason    text,
    bookings_blocked_at timestamptz,
    bookings_blocked_reason text,
    -- Bumped on every suspension change so each Auth ban job is distinct.
    ban_version         integer     NOT NULL DEFAULT 0,
    updated_by          uuid,
    updated_at          timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT user_restrictions_text CHECK (
        char_length(suspended_reason) <= 500 AND char_length(bookings_blocked_reason) <= 500)
);

COMMENT ON TABLE private.user_restrictions IS
    'Suspensions and booking blocks. Written only by admin RPCs.';

CREATE FUNCTION private.is_suspended(p_user_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SET search_path TO ''
AS $function$
    SELECT EXISTS (SELECT 1 FROM private.user_restrictions r WHERE r.user_id = p_user_id AND r.suspended_at IS NOT NULL);
$function$;

-- Suspended, or a provider whose bookings are blocked: not bookable.
CREATE FUNCTION private.is_unbookable(p_provider_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SET search_path TO ''
AS $function$
    SELECT EXISTS (SELECT 1 FROM private.user_restrictions r
                   WHERE r.user_id = p_provider_id
                     AND (r.suspended_at IS NOT NULL OR r.bookings_blocked_at IS NOT NULL));
$function$;

-- Refuses writes by a suspended account, whatever path they take.
CREATE FUNCTION private.block_suspended_writes()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
BEGIN
    IF auth.uid() IS NOT NULL AND private.is_suspended(auth.uid()) THEN
        RAISE EXCEPTION 'account_suspended' USING ERRCODE = '42501';
    END IF;
    RETURN NEW;
END;
$function$;

CREATE TRIGGER posts_block_suspended BEFORE INSERT OR UPDATE ON public.posts
    FOR EACH ROW EXECUTE FUNCTION private.block_suspended_writes();
CREATE TRIGGER comments_block_suspended BEFORE INSERT OR UPDATE ON public.comments
    FOR EACH ROW EXECUTE FUNCTION private.block_suspended_writes();
CREATE TRIGGER likes_block_suspended BEFORE INSERT ON public.likes
    FOR EACH ROW EXECUTE FUNCTION private.block_suspended_writes();
CREATE TRIGGER follows_block_suspended BEFORE INSERT ON public.follows
    FOR EACH ROW EXECUTE FUNCTION private.block_suspended_writes();
CREATE TRIGGER favourites_block_suspended BEFORE INSERT ON public.favourites
    FOR EACH ROW EXECUTE FUNCTION private.block_suspended_writes();
CREATE TRIGGER services_block_suspended BEFORE INSERT OR UPDATE ON public.services
    FOR EACH ROW EXECUTE FUNCTION private.block_suspended_writes();
CREATE TRIGGER reviews_block_suspended BEFORE INSERT OR UPDATE ON public.reviews
    FOR EACH ROW EXECUTE FUNCTION private.block_suspended_writes();
CREATE TRIGGER profiles_block_suspended BEFORE UPDATE ON public.profiles
    FOR EACH ROW EXECUTE FUNCTION private.block_suspended_writes();
CREATE TRIGGER provider_booking_settings_block_suspended BEFORE UPDATE ON public.provider_booking_settings
    FOR EACH ROW EXECUTE FUNCTION private.block_suspended_writes();
CREATE TRIGGER provider_working_hours_block_suspended BEFORE INSERT OR UPDATE ON public.provider_working_hours
    FOR EACH ROW EXECUTE FUNCTION private.block_suspended_writes();
CREATE TRIGGER provider_time_off_block_suspended BEFORE INSERT OR UPDATE ON public.provider_time_off
    FOR EACH ROW EXECUTE FUNCTION private.block_suspended_writes();

-- New bookings: neither side may be suspended, and the provider must be
-- bookable (create_booking surfaces these as its usual refusals).
CREATE FUNCTION private.check_booking_parties()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
BEGIN
    IF private.is_suspended(NEW.client_id) THEN
        RAISE EXCEPTION 'account_suspended' USING ERRCODE = '42501';
    END IF;
    IF private.is_unbookable(NEW.provider_id) THEN
        RAISE EXCEPTION 'provider_not_accepting' USING ERRCODE = 'P0001';
    END IF;
    RETURN NEW;
END;
$function$;

CREATE TRIGGER bookings_check_parties BEFORE INSERT ON public.bookings
    FOR EACH ROW EXECUTE FUNCTION private.check_booking_parties();
-- A suspended account can't accept, cancel or complete bookings either
-- (Myglo, the other party and the server's own jobs still can).
CREATE TRIGGER bookings_block_suspended BEFORE UPDATE ON public.bookings
    FOR EACH ROW EXECUTE FUNCTION private.block_suspended_writes();

-- ---------------------------------------------------------------------------
-- 2. Hidden content.
-- ---------------------------------------------------------------------------

ALTER TABLE public.posts
    ADD COLUMN hidden_at timestamptz, ADD COLUMN hidden_by uuid, ADD COLUMN hidden_reason text,
    ADD CONSTRAINT posts_hidden_reason CHECK (char_length(hidden_reason) <= 500);
ALTER TABLE public.comments
    ADD COLUMN hidden_at timestamptz, ADD COLUMN hidden_by uuid, ADD COLUMN hidden_reason text,
    ADD CONSTRAINT comments_hidden_reason CHECK (char_length(hidden_reason) <= 500);
ALTER TABLE public.reviews
    ADD COLUMN hidden_at timestamptz, ADD COLUMN hidden_by uuid, ADD COLUMN hidden_reason text,
    ADD CONSTRAINT reviews_hidden_reason CHECK (char_length(hidden_reason) <= 500);

-- Restrictive: on top of each table's existing read policies.
CREATE POLICY "Hidden posts are visible only to their author" ON public.posts
    AS RESTRICTIVE FOR SELECT TO anon, authenticated
    USING (hidden_at IS NULL OR (SELECT auth.uid()) = author_id);
CREATE POLICY "Hidden comments are visible only to their author" ON public.comments
    AS RESTRICTIVE FOR SELECT TO anon, authenticated
    USING (hidden_at IS NULL OR (SELECT auth.uid()) = author_id);
CREATE POLICY "Hidden reviews are visible only to their author" ON public.reviews
    AS RESTRICTIVE FOR SELECT TO anon, authenticated
    USING (hidden_at IS NULL OR (SELECT auth.uid()) = client_id);

-- Only admin RPCs set the hidden columns (they run as the table owner).
CREATE FUNCTION private.protect_hidden_columns()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO ''
AS $function$
BEGIN
    IF current_user IN ('anon', 'authenticated')
       AND (NEW.hidden_at, NEW.hidden_by, NEW.hidden_reason) IS DISTINCT FROM (OLD.hidden_at, OLD.hidden_by, OLD.hidden_reason) THEN
        RAISE EXCEPTION 'hidden_columns_are_protected' USING ERRCODE = '42501';
    END IF;
    RETURN NEW;
END;
$function$;

CREATE TRIGGER posts_protect_hidden BEFORE UPDATE ON public.posts
    FOR EACH ROW EXECUTE FUNCTION private.protect_hidden_columns();
CREATE TRIGGER comments_protect_hidden BEFORE UPDATE ON public.comments
    FOR EACH ROW EXECUTE FUNCTION private.protect_hidden_columns();
CREATE TRIGGER reviews_protect_hidden BEFORE UPDATE ON public.reviews
    FOR EACH ROW EXECUTE FUNCTION private.protect_hidden_columns();

-- Hidden reviews don't count towards a provider's rating.
CREATE OR REPLACE FUNCTION private.on_review_change()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
BEGIN
    IF TG_OP IN ('UPDATE', 'DELETE') AND OLD.hidden_at IS NULL THEN
        PERFORM private.apply_review_stats(OLD.provider_id, OLD.rating, -1);
    END IF;
    IF TG_OP IN ('INSERT', 'UPDATE') AND NEW.hidden_at IS NULL THEN
        PERFORM private.apply_review_stats(NEW.provider_id, NEW.rating, 1);
    END IF;
    RETURN NULL;
END;
$function$;

DROP TRIGGER reviews_stats ON public.reviews;
CREATE TRIGGER reviews_stats AFTER INSERT OR DELETE OR UPDATE OF rating, provider_id, hidden_at ON public.reviews
    FOR EACH ROW EXECUTE FUNCTION private.on_review_change();

-- Reviews for a provider, service or booking. A hidden review is listed
-- only to its author, marked is_hidden.
DROP FUNCTION public.list_reviews(uuid, uuid, uuid, timestamptz, uuid, integer);
CREATE FUNCTION public.list_reviews(
    p_provider_id uuid DEFAULT NULL,
    p_service_id  uuid DEFAULT NULL,
    p_booking_id  uuid DEFAULT NULL,
    p_before      timestamptz DEFAULT NULL,
    p_before_id   uuid DEFAULT NULL,
    p_limit       integer DEFAULT 20)
RETURNS TABLE(id uuid, booking_id uuid, provider_id uuid, client_id uuid, reviewer_name text, reviewer_avatar_url text,
              rating smallint, body text, service_ids uuid[], service_names text[], photo_urls text[], post_id uuid,
              reply text, replied_at timestamptz, edited_at timestamptz, created_at timestamptz, is_hidden boolean)
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
           r.created_at,
           r.hidden_at IS NOT NULL
    FROM public.reviews r
    LEFT JOIN public.profiles pr ON pr.id = r.client_id
    LEFT JOIN public.posts p ON p.review_id = r.id
    WHERE (p_provider_id IS NULL OR r.provider_id = p_provider_id)
      AND (p_service_id IS NULL OR r.service_ids @> ARRAY[p_service_id])
      AND (p_booking_id IS NULL OR r.booking_id = p_booking_id)
      AND (r.hidden_at IS NULL OR r.client_id = auth.uid())
      AND (p_before IS NULL
           OR (r.created_at, r.id) < (p_before, coalesce(p_before_id, 'ffffffff-ffff-ffff-ffff-ffffffffffff'::uuid)))
    ORDER BY r.created_at DESC, r.id DESC
    LIMIT least(greatest(coalesce(p_limit, 20), 1), 50);
END;
$function$;

REVOKE ALL ON FUNCTION public.list_reviews(uuid, uuid, uuid, timestamptz, uuid, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_reviews(uuid, uuid, uuid, timestamptz, uuid, integer) TO authenticated;

-- ---------------------------------------------------------------------------
-- 3. One-line changes to large read functions. Each patch must match
--    exactly once, or the migration fails.
-- ---------------------------------------------------------------------------

CREATE FUNCTION pg_temp.patch_function(p_function regprocedure, p_from text, p_to text)
RETURNS void
LANGUAGE plpgsql
AS $function$
DECLARE
    v_def   text := pg_get_functiondef(p_function);
    v_count integer := (length(v_def) - length(replace(v_def, p_from, ''))) / length(p_from);
BEGIN
    IF v_count <> 1 THEN
        RAISE EXCEPTION 'patch of % matched % times', p_function, v_count;
    END IF;
    EXECUTE replace(v_def, p_from, p_to);
END;
$function$;

-- Hidden posts drop out of the Discover feeds.
SELECT pg_temp.patch_function('public.nearby_posts(double precision, timestamptz, integer)',
    'WHERE p.tag_status = ''approved''',
    'WHERE p.tag_status = ''approved'' AND p.hidden_at IS NULL');
SELECT pg_temp.patch_function('public.posts_beyond_nearby(double precision, timestamptz, integer)',
    'WHERE p.tag_status = ''approved''',
    'WHERE p.tag_status = ''approved'' AND p.hidden_at IS NULL');

-- Suspended or booking-blocked providers drop out of search and the map.
SELECT pg_temp.patch_function('public.search_providers(text, double precision, double precision, integer)',
    'WHERE pr.role = ''provider''',
    'WHERE pr.role = ''provider'' AND NOT private.is_unbookable(pr.id)');
SELECT pg_temp.patch_function('public.map_providers(double precision, double precision, double precision, integer)',
    'WHERE pr.role = ''provider''',
    'WHERE pr.role = ''provider'' AND NOT private.is_unbookable(pr.id)');

-- ...have no free times...
SELECT pg_temp.patch_function('private.available_slots(uuid, integer, date, date)',
    'AND s.accepts_bookings',
    'AND s.accepts_bookings AND NOT private.is_unbookable(s.provider_id)');

-- ...and booking them says so, before any check on the time.
SELECT pg_temp.patch_function(
    'public.create_booking(uuid, uuid, uuid[], timestamptz, text, text, integer, text, jsonb, double precision, double precision, text, text)',
    'IF NOT FOUND OR NOT v_settings.accepts_bookings THEN',
    'IF NOT FOUND OR NOT v_settings.accepts_bookings OR private.is_unbookable(p_provider_id) THEN');

-- Booking events and notifications name their actor by profile. Admins have
-- none (the audit log records which admin acted), so an admin's cancellation
-- or refund is recorded without an actor instead of failing.
SELECT pg_temp.patch_function('private.on_booking_event(public.bookings, text, text, text, jsonb)',
    'v_actor    uuid := auth.uid();',
    'v_actor    uuid := (SELECT pr.id FROM public.profiles pr WHERE pr.id = auth.uid());');

-- ---------------------------------------------------------------------------
-- 4. Reports.
-- ---------------------------------------------------------------------------

CREATE TABLE public.reports (
    id          uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    reporter_id uuid        REFERENCES public.profiles (id) ON DELETE SET NULL,
    target_type text        NOT NULL,
    target_id   uuid        NOT NULL,
    reason      text        NOT NULL,
    details     text,
    status      text        NOT NULL DEFAULT 'open',
    resolution  text,
    resolved_by uuid,
    resolved_at timestamptz,
    created_at  timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT reports_target_type CHECK (target_type IN ('post', 'comment', 'review', 'provider', 'booking')),
    CONSTRAINT reports_reason CHECK (reason IN (
        'spam', 'inappropriate', 'harassment', 'scam', 'fake', 'safety',
        'no_show', 'service_not_as_described', 'overcharged', 'other')),
    CONSTRAINT reports_status CHECK (status IN ('open', 'resolved', 'dismissed')),
    CONSTRAINT reports_text CHECK (char_length(details) <= 1000 AND char_length(resolution) <= 500)
);

CREATE INDEX reports_open_idx ON public.reports (created_at DESC) WHERE status = 'open';
CREATE INDEX reports_target_idx ON public.reports (target_type, target_id);
CREATE INDEX reports_reporter_idx ON public.reports (reporter_id, created_at DESC);

COMMENT ON TABLE public.reports IS 'Reports about content, providers and bookings. Written through submit_report and admin RPCs only.';

ALTER TABLE public.reports ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.reports FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.reports TO authenticated;
CREATE POLICY "Reporters can view own reports" ON public.reports
    FOR SELECT TO authenticated
    USING ((SELECT auth.uid()) = reporter_id);

-- Reports something the caller can see. A repeat of the caller's own open
-- report on the same thing returns that report. Rate-limited.
CREATE FUNCTION public.submit_report(p_target_type text, p_target_id uuid, p_reason text, p_details text DEFAULT NULL)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
    v_uid      uuid := auth.uid();
    v_details  text := nullif(btrim(p_details), '');
    v_existing uuid;
    v_booking  public.bookings%ROWTYPE;
    v_platform private.platform_settings%ROWTYPE;
    v_id       uuid;
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'not_authenticated' USING ERRCODE = '42501';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM public.profiles WHERE id = v_uid) THEN
        RAISE EXCEPTION 'profile_required' USING ERRCODE = '42501';
    END IF;
    IF private.is_suspended(v_uid) THEN
        RAISE EXCEPTION 'account_suspended' USING ERRCODE = '42501';
    END IF;
    IF p_target_type NOT IN ('post', 'comment', 'review', 'provider', 'booking') OR p_target_id IS NULL
       OR p_reason NOT IN ('spam', 'inappropriate', 'harassment', 'scam', 'fake', 'safety',
                           'no_show', 'service_not_as_described', 'overcharged', 'other')
       OR char_length(v_details) > 1000 THEN
        RAISE EXCEPTION 'invalid_request' USING ERRCODE = '22023';
    END IF;

    SELECT id INTO v_existing FROM public.reports
    WHERE reporter_id = v_uid AND target_type = p_target_type AND target_id = p_target_id AND status = 'open';
    IF FOUND THEN
        RETURN v_existing;
    END IF;
    IF (SELECT count(*) FROM public.reports WHERE reporter_id = v_uid AND created_at > now() - interval '24 hours') >= 20 THEN
        RAISE EXCEPTION 'too_many_reports' USING ERRCODE = 'P0001';
    END IF;

    -- Only things the caller can see, and not their own.
    IF NOT (CASE p_target_type
        WHEN 'post' THEN EXISTS (SELECT 1 FROM public.posts p
                                 WHERE p.id = p_target_id AND p.author_id <> v_uid AND p.hidden_at IS NULL
                                   AND (p.tag_status = 'approved' OR p.tagged_provider_id = v_uid))
        WHEN 'comment' THEN EXISTS (SELECT 1 FROM public.comments c JOIN public.posts p ON p.id = c.post_id
                                    WHERE c.id = p_target_id AND c.author_id <> v_uid AND c.hidden_at IS NULL
                                      AND p.hidden_at IS NULL
                                      AND (p.tag_status = 'approved' OR p.author_id = v_uid OR p.tagged_provider_id = v_uid))
        WHEN 'review' THEN EXISTS (SELECT 1 FROM public.reviews r
                                   WHERE r.id = p_target_id AND r.client_id <> v_uid AND r.hidden_at IS NULL)
        WHEN 'provider' THEN EXISTS (SELECT 1 FROM public.profiles pr
                                     WHERE pr.id = p_target_id AND pr.role = 'provider' AND pr.id <> v_uid)
        ELSE true
    END) THEN
        RAISE EXCEPTION 'report_target_not_found' USING ERRCODE = 'P0002';
    END IF;

    IF p_target_type = 'booking' THEN
        -- The client, from the start until the report window after the end.
        SELECT * INTO v_platform FROM private.platform_settings WHERE id;
        SELECT * INTO v_booking FROM public.bookings WHERE id = p_target_id FOR UPDATE;
        IF NOT FOUND OR v_booking.client_id IS DISTINCT FROM v_uid THEN
            RAISE EXCEPTION 'report_target_not_found' USING ERRCODE = 'P0002';
        END IF;
        IF v_booking.status NOT IN ('confirmed', 'completed', 'no_show')
           OR now() < v_booking.starts_at
           OR now() > v_booking.ends_at + make_interval(hours => v_platform.report_window_hours) THEN
            RAISE EXCEPTION 'report_window_closed' USING ERRCODE = 'P0001',
                DETAIL = jsonb_build_object('window_hours', v_platform.report_window_hours)::text;
        END IF;
    END IF;

    INSERT INTO public.reports (reporter_id, target_type, target_id, reason, details)
    VALUES (v_uid, p_target_type, p_target_id, p_reason, v_details)
    RETURNING id INTO v_id;

    -- A problem with a booking holds the provider's share until it's looked at.
    IF p_target_type = 'booking' THEN
        UPDATE public.booking_settlements
        SET status = 'held', hold_reason = 'report', updated_at = now()
        WHERE booking_id = p_target_id AND status IN ('scheduled', 'held')
          AND coalesce(hold_reason, '') <> 'admin';
        PERFORM private.on_booking_event(v_booking, 'reported', 'client', v_booking.status,
            jsonb_build_object('report_id', v_id, 'reason', p_reason));
    END IF;

    PERFORM private.enqueue_job('admin_alert', 'alert:report:' || v_id,
        jsonb_build_object(
            'severity', CASE WHEN p_reason IN ('safety', 'harassment') OR p_target_type = 'booking' THEN 'high' ELSE 'normal' END,
            'subject', format('New report: %s (%s)', p_target_type, replace(p_reason, '_', ' ')),
            'body', coalesce(v_details, 'No details given.'),
            'report_id', v_id),
        CASE WHEN p_target_type = 'booking' THEN p_target_id END);
    RETURN v_id;
END;
$function$;

-- An open booking report holds the provider's share like a dispute does.
SELECT pg_temp.patch_function('private.process_settlement(uuid)',
    'v_hold := CASE',
    'v_hold := CASE
        WHEN EXISTS (SELECT 1 FROM public.reports rp
                     WHERE rp.target_type = ''booking'' AND rp.target_id = p_booking_id AND rp.status = ''open'') THEN ''report''');

-- ---------------------------------------------------------------------------
-- 5. Admin: reports and content.
-- ---------------------------------------------------------------------------

-- What a report points at, in a few words, for the moderation queue.
CREATE FUNCTION private.report_target_summary(p_type text, p_id uuid)
RETURNS jsonb
LANGUAGE sql
STABLE
SET search_path TO ''
AS $function$
    SELECT CASE p_type
        WHEN 'post' THEN (SELECT jsonb_build_object(
                'text', left(p.caption, 300), 'media_url', p.media_urls[1], 'author_id', p.author_id,
                'author_name', coalesce(nullif(btrim(a.provider_name), ''), btrim(concat_ws(' ', a.first_name, a.last_name))),
                'hidden', p.hidden_at IS NOT NULL)
            FROM public.posts p LEFT JOIN public.profiles a ON a.id = p.author_id WHERE p.id = p_id)
        WHEN 'comment' THEN (SELECT jsonb_build_object(
                'text', left(c.content, 300), 'author_id', c.author_id, 'post_id', c.post_id,
                'author_name', coalesce(nullif(btrim(a.provider_name), ''), btrim(concat_ws(' ', a.first_name, a.last_name))),
                'hidden', c.hidden_at IS NOT NULL)
            FROM public.comments c LEFT JOIN public.profiles a ON a.id = c.author_id WHERE c.id = p_id)
        WHEN 'review' THEN (SELECT jsonb_build_object(
                'text', left(r.body, 300), 'rating', r.rating, 'author_id', r.client_id, 'provider_id', r.provider_id,
                'author_name', btrim(concat_ws(' ', a.first_name, a.last_name)),
                'hidden', r.hidden_at IS NOT NULL)
            FROM public.reviews r LEFT JOIN public.profiles a ON a.id = r.client_id WHERE r.id = p_id)
        WHEN 'provider' THEN (SELECT jsonb_build_object(
                'text', coalesce(nullif(btrim(a.provider_name), ''), btrim(concat_ws(' ', a.first_name, a.last_name))),
                'author_id', a.id, 'suspended', private.is_suspended(a.id), 'bookings_blocked', private.is_unbookable(a.id))
            FROM public.profiles a WHERE a.id = p_id)
        WHEN 'booking' THEN (SELECT jsonb_build_object(
                'text', b.reference || ' · ' || b.client_name || ' with ' || b.provider_name,
                'reference', b.reference, 'status', b.status, 'payment_method', b.payment_method,
                'payment_status', b.payment_status, 'total_cents', b.total_cents, 'starts_at', b.starts_at,
                'author_id', b.provider_id,
                'settlement_status', (SELECT s.status FROM public.booking_settlements s WHERE s.booking_id = b.id))
            FROM public.bookings b WHERE b.id = p_id)
    END;
$function$;

CREATE FUNCTION public.admin_list_reports(p_status text DEFAULT 'open', p_limit integer DEFAULT 30, p_offset integer DEFAULT 0)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO ''
AS $function$
BEGIN
    PERFORM private.require_admin();
    RETURN coalesce((
        SELECT jsonb_agg(row_to_json(x) ORDER BY x.created_at DESC) FROM (
            SELECT r.id, r.target_type, r.target_id, r.reason, r.details, r.status, r.resolution,
                   r.resolved_at, r.created_at, r.reporter_id,
                   btrim(concat_ws(' ', rp.first_name, rp.last_name)) AS reporter_name,
                   (SELECT count(*) FROM public.reports o
                    WHERE o.target_type = r.target_type AND o.target_id = r.target_id) AS reports_on_target,
                   private.report_target_summary(r.target_type, r.target_id) AS target
            FROM public.reports r
            LEFT JOIN public.profiles rp ON rp.id = r.reporter_id
            WHERE p_status IS NULL OR r.status = p_status
            ORDER BY r.created_at DESC
            LIMIT least(greatest(coalesce(p_limit, 30), 1), 100) OFFSET greatest(coalesce(p_offset, 0), 0)) x), '[]'::jsonb);
END;
$function$;

-- Closes a report. A booking with no other open reports gets its
-- provider's share back on its way. Audited.
CREATE FUNCTION public.admin_resolve_report(p_report_id uuid, p_status text, p_note text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
    v_note   text;
    v_report public.reports%ROWTYPE;
BEGIN
    PERFORM private.require_admin();
    v_note := private.require_reason(p_note);
    IF p_status NOT IN ('resolved', 'dismissed') THEN
        RAISE EXCEPTION 'invalid_request' USING ERRCODE = '22023';
    END IF;
    SELECT * INTO v_report FROM public.reports WHERE id = p_report_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'not_found' USING ERRCODE = 'P0002';
    END IF;
    IF v_report.status <> 'open' THEN
        RAISE EXCEPTION 'report_closed' USING ERRCODE = 'P0001';
    END IF;

    UPDATE public.reports
    SET status = p_status, resolution = v_note, resolved_by = auth.uid(), resolved_at = now()
    WHERE id = p_report_id;

    IF v_report.target_type = 'booking' AND NOT EXISTS (
        SELECT 1 FROM public.reports o
        WHERE o.target_type = 'booking' AND o.target_id = v_report.target_id AND o.status = 'open') THEN
        UPDATE public.booking_settlements
        SET status = 'scheduled', hold_reason = NULL, updated_at = now()
        WHERE booking_id = v_report.target_id AND status = 'held' AND hold_reason = 'report';
        PERFORM private.process_settlement(v_report.target_id);
    END IF;

    PERFORM private.audit(p_status || '_report', 'report', p_report_id::text, v_note,
        jsonb_build_object('status', 'open', 'target_type', v_report.target_type, 'target_id', v_report.target_id),
        jsonb_build_object('status', p_status));
END;
$function$;

-- Hides (or shows again) a post, comment or review. Hiding a review hides
-- the post with its photos too. Needs a fresh authenticator code; audited.
CREATE FUNCTION public.admin_set_content_hidden(p_target_type text, p_target_id uuid, p_hidden boolean, p_reason text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
    v_admin  uuid := auth.uid();
    v_reason text;
    v_count  integer;
BEGIN
    PERFORM private.require_admin(true);
    v_reason := private.require_reason(p_reason);
    IF p_hidden IS NULL THEN
        RAISE EXCEPTION 'invalid_request' USING ERRCODE = '22023';
    END IF;

    CASE p_target_type
        WHEN 'post' THEN
            UPDATE public.posts
            SET hidden_at = CASE WHEN p_hidden THEN coalesce(hidden_at, now()) END,
                hidden_by = CASE WHEN p_hidden THEN v_admin END,
                hidden_reason = CASE WHEN p_hidden THEN v_reason END
            WHERE id = p_target_id;
            GET DIAGNOSTICS v_count = ROW_COUNT;
        WHEN 'comment' THEN
            UPDATE public.comments
            SET hidden_at = CASE WHEN p_hidden THEN coalesce(hidden_at, now()) END,
                hidden_by = CASE WHEN p_hidden THEN v_admin END,
                hidden_reason = CASE WHEN p_hidden THEN v_reason END
            WHERE id = p_target_id;
            GET DIAGNOSTICS v_count = ROW_COUNT;
        WHEN 'review' THEN
            UPDATE public.reviews
            SET hidden_at = CASE WHEN p_hidden THEN coalesce(hidden_at, now()) END,
                hidden_by = CASE WHEN p_hidden THEN v_admin END,
                hidden_reason = CASE WHEN p_hidden THEN v_reason END
            WHERE id = p_target_id;
            GET DIAGNOSTICS v_count = ROW_COUNT;
            UPDATE public.posts
            SET hidden_at = CASE WHEN p_hidden THEN coalesce(hidden_at, now()) END,
                hidden_by = CASE WHEN p_hidden THEN v_admin END,
                hidden_reason = CASE WHEN p_hidden THEN v_reason END
            WHERE review_id = p_target_id;
        ELSE
            RAISE EXCEPTION 'invalid_request' USING ERRCODE = '22023';
    END CASE;
    IF v_count = 0 THEN
        RAISE EXCEPTION 'not_found' USING ERRCODE = 'P0002';
    END IF;

    PERFORM private.audit(CASE WHEN p_hidden THEN 'hide_content' ELSE 'show_content' END,
        p_target_type, p_target_id::text, v_reason, NULL, jsonb_build_object('hidden', p_hidden));
END;
$function$;

-- ---------------------------------------------------------------------------
-- 6. Admin: suspending accounts and blocking bookings.
-- ---------------------------------------------------------------------------

-- Cancels a booking on Myglo's behalf: full refund (or hold released) and
-- both sides told.
CREATE FUNCTION private.cancel_by_myglo(p_booking public.bookings, p_reason text)
RETURNS void
LANGUAGE plpgsql
SET search_path TO ''
AS $function$
DECLARE
    v_booking public.bookings%ROWTYPE;
    v_from    text := p_booking.status;
BEGIN
    UPDATE public.bookings
    SET status = 'cancelled', cancelled_by = 'system', cancelled_at = now(),
        cancellation_reason = 'Cancelled by Myglo support',
        payment_status = CASE WHEN payment_status IN ('pending', 'requires_payment', 'authorized') THEN 'void'
                              ELSE payment_status END,
        updated_at = now()
    WHERE id = p_booking.id
    RETURNING * INTO v_booking;
    UPDATE public.booking_payments SET status = 'void', updated_at = now()
    WHERE booking_id = p_booking.id AND status = 'pending';
    PERFORM private.release_card_hold(v_booking);
    IF v_booking.payment_method <> 'cash' AND v_booking.payment_status IN ('paid', 'partially_refunded') THEN
        PERFORM private.queue_refund(v_booking, private.refundable_cents(v_booking.id), 'myglo_cancelled', 'admin',
                                     auth.uid(), p_reason);
        PERFORM private.schedule_settlement(v_booking, 0);
    END IF;
    PERFORM private.on_booking_event(v_booking, 'cancelled', 'admin', v_from, jsonb_build_object('reason', p_reason));
END;
$function$;

CREATE OR REPLACE FUNCTION public.admin_cancel_booking(p_booking_id uuid, p_reason text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
    v_reason  text;
    v_booking public.bookings%ROWTYPE;
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
    PERFORM private.cancel_by_myglo(v_booking, v_reason);
    PERFORM private.audit('cancel_booking', 'booking', p_booking_id::text, v_reason,
        jsonb_build_object('status', v_booking.status), jsonb_build_object('status', 'cancelled'));
END;
$function$;

-- Suspends an account (or lifts it): sign-in is blocked by an Auth ban
-- (jobs worker) and every write is refused. Optionally cancels the
-- account's upcoming bookings with full refunds. Needs a fresh
-- authenticator code; audited. Returns how many bookings were cancelled.
CREATE FUNCTION public.admin_set_suspension(
    p_user_id         uuid,
    p_suspended       boolean,
    p_reason          text,
    p_cancel_upcoming boolean DEFAULT false)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
    v_reason    text;
    v_before    private.user_restrictions%ROWTYPE;
    v_after     private.user_restrictions%ROWTYPE;
    v_booking   public.bookings%ROWTYPE;
    v_cancelled integer := 0;
BEGIN
    PERFORM private.require_admin(true);
    v_reason := private.require_reason(p_reason);
    IF p_suspended IS NULL OR NOT EXISTS (SELECT 1 FROM public.profiles WHERE id = p_user_id) THEN
        RAISE EXCEPTION 'not_found' USING ERRCODE = 'P0002';
    END IF;
    SELECT * INTO v_before FROM private.user_restrictions WHERE user_id = p_user_id FOR UPDATE;

    INSERT INTO private.user_restrictions AS r (user_id, suspended_at, suspended_reason, ban_version, updated_by)
    VALUES (p_user_id, CASE WHEN p_suspended THEN now() END, CASE WHEN p_suspended THEN v_reason END, 1, auth.uid())
    ON CONFLICT (user_id) DO UPDATE SET
        suspended_at = CASE WHEN p_suspended THEN coalesce(r.suspended_at, now()) END,
        suspended_reason = CASE WHEN p_suspended THEN v_reason END,
        ban_version = r.ban_version + 1,
        updated_by = auth.uid(),
        updated_at = now()
    RETURNING * INTO v_after;

    -- The worker applies whatever the database says when it runs.
    PERFORM private.enqueue_job('auth_ban', 'auth-ban:' || p_user_id || ':' || v_after.ban_version,
        jsonb_build_object('user_id', p_user_id));

    IF p_suspended AND coalesce(p_cancel_upcoming, false) THEN
        FOR v_booking IN
            SELECT * FROM public.bookings b
            WHERE (b.client_id = p_user_id OR b.provider_id = p_user_id)
              AND b.status IN ('pending', 'confirmed') AND b.starts_at > now()
            ORDER BY b.starts_at
            FOR UPDATE
        LOOP
            PERFORM private.cancel_by_myglo(v_booking, v_reason);
            v_cancelled := v_cancelled + 1;
        END LOOP;
    END IF;

    PERFORM private.audit(CASE WHEN p_suspended THEN 'suspend_account' ELSE 'unsuspend_account' END,
        'user', p_user_id::text, v_reason,
        jsonb_build_object('suspended_at', v_before.suspended_at),
        jsonb_build_object('suspended_at', v_after.suspended_at, 'cancelled_bookings', v_cancelled));
    RETURN v_cancelled;
END;
$function$;

-- Stops (or lets again) clients booking a provider, without suspending
-- them. Existing bookings are kept. Needs a fresh authenticator code; audited.
CREATE FUNCTION public.admin_set_bookings_blocked(p_provider_id uuid, p_blocked boolean, p_reason text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
    v_reason text;
    v_before private.user_restrictions%ROWTYPE;
BEGIN
    PERFORM private.require_admin(true);
    v_reason := private.require_reason(p_reason);
    IF p_blocked IS NULL OR NOT EXISTS (SELECT 1 FROM public.profiles WHERE id = p_provider_id AND role = 'provider') THEN
        RAISE EXCEPTION 'not_found' USING ERRCODE = 'P0002';
    END IF;
    SELECT * INTO v_before FROM private.user_restrictions WHERE user_id = p_provider_id FOR UPDATE;

    INSERT INTO private.user_restrictions AS r (user_id, bookings_blocked_at, bookings_blocked_reason, updated_by)
    VALUES (p_provider_id, CASE WHEN p_blocked THEN now() END, CASE WHEN p_blocked THEN v_reason END, auth.uid())
    ON CONFLICT (user_id) DO UPDATE SET
        bookings_blocked_at = CASE WHEN p_blocked THEN coalesce(r.bookings_blocked_at, now()) END,
        bookings_blocked_reason = CASE WHEN p_blocked THEN v_reason END,
        updated_by = auth.uid(),
        updated_at = now();

    -- Clients picking a time see the change straight away.
    PERFORM private.bump_availability(ARRAY[p_provider_id]);

    PERFORM private.audit(CASE WHEN p_blocked THEN 'block_bookings' ELSE 'unblock_bookings' END,
        'user', p_provider_id::text, v_reason,
        jsonb_build_object('bookings_blocked_at', v_before.bookings_blocked_at),
        jsonb_build_object('blocked', p_blocked));
END;
$function$;

-- An account's restrictions and reports, for the admin's account page.
CREATE FUNCTION public.admin_get_moderation_state(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
    v_restrictions private.user_restrictions%ROWTYPE;
BEGIN
    PERFORM private.require_admin();
    SELECT * INTO v_restrictions FROM private.user_restrictions WHERE user_id = p_user_id;
    RETURN jsonb_build_object(
        'suspended_at', v_restrictions.suspended_at,
        'suspended_reason', v_restrictions.suspended_reason,
        'bookings_blocked_at', v_restrictions.bookings_blocked_at,
        'bookings_blocked_reason', v_restrictions.bookings_blocked_reason,
        'upcoming_bookings', (SELECT count(*) FROM public.bookings b
                              WHERE (b.client_id = p_user_id OR b.provider_id = p_user_id)
                                AND b.status IN ('pending', 'confirmed') AND b.starts_at > now()),
        'open_reports_about', (SELECT count(*) FROM public.reports r
                               WHERE r.status = 'open'
                                 AND ((r.target_type = 'provider' AND r.target_id = p_user_id)
                                      OR (r.target_type = 'booking' AND r.target_id IN (
                                              SELECT b.id FROM public.bookings b WHERE b.provider_id = p_user_id))
                                      OR (r.target_type = 'post' AND r.target_id IN (
                                              SELECT p.id FROM public.posts p WHERE p.author_id = p_user_id))
                                      OR (r.target_type = 'comment' AND r.target_id IN (
                                              SELECT c.id FROM public.comments c WHERE c.author_id = p_user_id))
                                      OR (r.target_type = 'review' AND r.target_id IN (
                                              SELECT rv.id FROM public.reviews rv WHERE rv.client_id = p_user_id)))),
        'reports_made', (SELECT count(*) FROM public.reports r WHERE r.reporter_id = p_user_id));
END;
$function$;

-- Whether the Auth ban should be on, for the jobs worker (service role).
CREATE FUNCTION public.account_should_be_banned(p_user_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO ''
AS $function$
    SELECT private.is_suspended(p_user_id);
$function$;

ALTER TABLE private.jobs DROP CONSTRAINT jobs_kind;
ALTER TABLE private.jobs ADD CONSTRAINT jobs_kind CHECK (kind IN (
    'noop', 'admin_alert', 'cancel_payment_intent', 'capture_payment', 'refund_payment',
    'transfer', 'reverse_transfer', 'auth_ban'));

-- ---------------------------------------------------------------------------
-- 7. Privileges.
-- ---------------------------------------------------------------------------

REVOKE ALL ON private.user_restrictions FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION private.is_suspended(uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION private.is_unbookable(uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION private.block_suspended_writes() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION private.check_booking_parties() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION private.protect_hidden_columns() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION private.report_target_summary(text, uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION private.cancel_by_myglo(public.bookings, text) FROM PUBLIC, anon, authenticated;

REVOKE ALL ON FUNCTION public.submit_report(text, uuid, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.submit_report(text, uuid, text, text) TO authenticated;

REVOKE ALL ON FUNCTION public.admin_list_reports(text, integer, integer) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.admin_resolve_report(uuid, text, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.admin_set_content_hidden(text, uuid, boolean, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.admin_set_suspension(uuid, boolean, text, boolean) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.admin_set_bookings_blocked(uuid, boolean, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.admin_get_moderation_state(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_list_reports(text, integer, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_resolve_report(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_set_content_hidden(text, uuid, boolean, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_set_suspension(uuid, boolean, text, boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_set_bookings_blocked(uuid, boolean, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_get_moderation_state(uuid) TO authenticated;

REVOKE ALL ON FUNCTION public.account_should_be_banned(uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.account_should_be_banned(uuid) TO service_role;
