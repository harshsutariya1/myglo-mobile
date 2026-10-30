-- Admin foundation: admin accounts, server-side two-factor checks, the audit
-- log, admin-controlled platform settings and the first admin RPCs.
--
-- Security model
--   * Admins are separate, admin-only accounts listed in private.admins.
--     Only the database owner can add or remove one (SQL; see docs/admin.md).
--     An admin account can never also be a client or provider: adding an
--     account that has a profile is refused, and an admin can't create one.
--   * Every admin RPC is SECURITY DEFINER and starts with
--     private.require_admin(), which checks, from the caller's JWT:
--       - they are in private.admins;
--       - the session is aal2 (TOTP verified);
--       - the TOTP was verified within the last 12 hours (admin sessions are
--         shorter than everyone else's);
--       - for sensitive actions (fees, refunds, suspensions, hiding content),
--         within the last 5 minutes, otherwise 'reauth_required' so the app
--         asks for a fresh code.
--     Nothing in the app is trusted; routes and buttons are convenience only.
--   * Admin reads go through these RPCs. No RLS policy is widened, so admin
--     data never becomes reachable from a normal account.
--   * Every admin change writes private.admin_audit_log in the same
--     transaction. The log rejects UPDATE, DELETE and TRUNCATE for everyone.
--   * app_metadata.myglo_admin is set on admin accounts so the app can route
--     them; it is a hint only and grants nothing.

-- ---------------------------------------------------------------------------
-- 1. Admin accounts.
-- ---------------------------------------------------------------------------

CREATE TABLE private.admins (
    user_id      uuid        PRIMARY KEY REFERENCES auth.users (id) ON DELETE CASCADE,
    display_name text        NOT NULL,
    note         text,
    created_at   timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT admins_display_name CHECK (char_length(btrim(display_name)) BETWEEN 1 AND 80)
);

COMMENT ON TABLE private.admins IS
    'Admin-only accounts. Written only by the database owner (SQL). See docs/admin.md.';

CREATE FUNCTION private.is_admin(p_user_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO ''
AS $function$
    SELECT p_user_id IS NOT NULL AND EXISTS (SELECT 1 FROM private.admins a WHERE a.user_id = p_user_id);
$function$;

-- An admin account must not be a client or provider.
CREATE FUNCTION private.before_admin_insert()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO ''
AS $function$
BEGIN
    IF EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = NEW.user_id) THEN
        RAISE EXCEPTION 'admin_account_has_profile'
            USING ERRCODE = '22023',
                  HINT = 'Create a dedicated account for the admin; client and provider accounts cannot be admins.';
    END IF;
    RETURN NEW;
END;
$function$;

CREATE TRIGGER admins_before_insert
    BEFORE INSERT ON private.admins
    FOR EACH ROW EXECUTE FUNCTION private.before_admin_insert();

-- Mirrors admin membership into app_metadata (server-only, signed into the
-- JWT) so the app can send admins to the admin area. A hint, not a grant.
CREATE FUNCTION private.sync_admin_app_metadata()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE auth.users
        SET raw_app_meta_data = coalesce(raw_app_meta_data, '{}'::jsonb) || '{"myglo_admin": true}'::jsonb
        WHERE id = NEW.user_id;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE auth.users
        SET raw_app_meta_data = coalesce(raw_app_meta_data, '{}'::jsonb) - 'myglo_admin'
        WHERE id = OLD.user_id;
    END IF;
    RETURN NULL;
END;
$function$;

CREATE TRIGGER admins_sync_app_metadata
    AFTER INSERT OR DELETE ON private.admins
    FOR EACH ROW EXECUTE FUNCTION private.sync_admin_app_metadata();

-- Profiles can be inserted directly (policy "Users can insert own profile")
-- and by register_user_role; both are refused for admin accounts.
CREATE FUNCTION private.before_profile_insert_not_admin()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
BEGIN
    IF private.is_admin(NEW.id) THEN
        RAISE EXCEPTION 'admin_accounts_cannot_have_profiles' USING ERRCODE = '42501';
    END IF;
    RETURN NEW;
END;
$function$;

CREATE TRIGGER profiles_not_admin
    BEFORE INSERT ON public.profiles
    FOR EACH ROW EXECUTE FUNCTION private.before_profile_insert_not_admin();

-- ---------------------------------------------------------------------------
-- 2. Admin session checks.
-- ---------------------------------------------------------------------------

-- When the caller's session last passed TOTP, from the JWT's amr claim.
CREATE FUNCTION private.jwt_totp_verified_at()
RETURNS timestamptz
LANGUAGE sql
STABLE
SET search_path TO ''
AS $function$
    SELECT to_timestamp(max((m->>'timestamp')::double precision))
    FROM jsonb_array_elements(
             CASE WHEN jsonb_typeof(auth.jwt()->'amr') = 'array' THEN auth.jwt()->'amr' ELSE '[]'::jsonb END) m
    WHERE m->>'method' = 'totp';
$function$;

-- Admin sessions last 12 hours from the last TOTP; sensitive actions need a
-- TOTP from the last 5 minutes. Constants, not settings: an admin can't
-- loosen their own checks.
CREATE FUNCTION private.admin_session_hours() RETURNS integer LANGUAGE sql IMMUTABLE SET search_path TO '' AS 'SELECT 12';
CREATE FUNCTION private.admin_reauth_seconds() RETURNS integer LANGUAGE sql IMMUTABLE SET search_path TO '' AS 'SELECT 300';

-- Raises unless the caller is an admin with a valid two-factor session.
-- p_fresh: the action is sensitive and needs a TOTP from the last 5 minutes.
-- Returns the admin's user id.
CREATE FUNCTION private.require_admin(p_fresh boolean DEFAULT false)
RETURNS uuid
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
    v_uid  uuid := auth.uid();
    v_totp timestamptz;
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'not_authenticated' USING ERRCODE = '42501';
    END IF;
    IF NOT private.is_admin(v_uid) THEN
        RAISE EXCEPTION 'admin_required' USING ERRCODE = '42501';
    END IF;
    IF coalesce(auth.jwt()->>'aal', 'aal1') <> 'aal2' THEN
        RAISE EXCEPTION 'mfa_required' USING ERRCODE = '42501';
    END IF;

    v_totp := private.jwt_totp_verified_at();
    IF v_totp IS NULL OR v_totp < now() - make_interval(hours => private.admin_session_hours()) THEN
        RAISE EXCEPTION 'admin_session_expired' USING ERRCODE = '42501';
    END IF;
    IF p_fresh AND v_totp < now() - make_interval(secs => private.admin_reauth_seconds()) THEN
        RAISE EXCEPTION 'reauth_required' USING ERRCODE = '42501';
    END IF;
    RETURN v_uid;
END;
$function$;

-- The caller's own admin status, for routing. Everyone may ask about
-- themselves; it reveals nothing about anyone else.
CREATE FUNCTION public.get_admin_status()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
    v_uid  uuid := auth.uid();
    v_totp timestamptz;
BEGIN
    IF v_uid IS NULL OR NOT private.is_admin(v_uid) THEN
        RETURN jsonb_build_object('is_admin', false);
    END IF;
    v_totp := private.jwt_totp_verified_at();
    RETURN jsonb_build_object(
        'is_admin', true,
        'display_name', (SELECT a.display_name FROM private.admins a WHERE a.user_id = v_uid),
        'aal', coalesce(auth.jwt()->>'aal', 'aal1'),
        'totp_verified_at', v_totp,
        'session_expires_at', v_totp + make_interval(hours => private.admin_session_hours()),
        'reauth_seconds', private.admin_reauth_seconds());
END;
$function$;

-- ---------------------------------------------------------------------------
-- 3. Audit log (append-only).
-- ---------------------------------------------------------------------------

CREATE TABLE private.admin_audit_log (
    id          bigint      GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    -- No foreign key: the record outlives the admin's account.
    admin_id    uuid        NOT NULL,
    admin_email text,
    action      text        NOT NULL,
    target_type text,
    target_id   text,
    reason      text,
    before      jsonb,
    after       jsonb,
    session_id  text,
    aal         text,
    created_at  timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE private.admin_audit_log IS
    'Every admin change, written in the same transaction. Append-only: UPDATE, DELETE and TRUNCATE are rejected.';

CREATE INDEX admin_audit_log_created_idx ON private.admin_audit_log (created_at DESC);
CREATE INDEX admin_audit_log_target_idx ON private.admin_audit_log (target_type, target_id, created_at DESC);

CREATE FUNCTION private.reject_audit_log_change()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO ''
AS $function$
BEGIN
    RAISE EXCEPTION 'admin_audit_log_is_append_only' USING ERRCODE = '42501';
END;
$function$;

CREATE TRIGGER admin_audit_log_no_update_delete
    BEFORE UPDATE OR DELETE ON private.admin_audit_log
    FOR EACH ROW EXECUTE FUNCTION private.reject_audit_log_change();

CREATE TRIGGER admin_audit_log_no_truncate
    BEFORE TRUNCATE ON private.admin_audit_log
    FOR EACH STATEMENT EXECUTE FUNCTION private.reject_audit_log_change();

-- Records an admin action by the caller.
CREATE FUNCTION private.audit(
    p_action      text,
    p_target_type text,
    p_target_id   text,
    p_reason      text  DEFAULT NULL,
    p_before      jsonb DEFAULT NULL,
    p_after       jsonb DEFAULT NULL)
RETURNS void
LANGUAGE sql
SECURITY DEFINER
SET search_path TO ''
AS $function$
    INSERT INTO private.admin_audit_log
        (admin_id, admin_email, action, target_type, target_id, reason, before, after, session_id, aal)
    VALUES (
        auth.uid(),
        auth.jwt()->>'email',
        p_action,
        p_target_type,
        p_target_id,
        nullif(btrim(p_reason), ''),
        p_before,
        p_after,
        auth.jwt()->>'session_id',
        auth.jwt()->>'aal');
$function$;

-- A reason for a change: required, 3–500 characters.
CREATE FUNCTION private.require_reason(p_reason text)
RETURNS text
LANGUAGE plpgsql
IMMUTABLE
SET search_path TO ''
AS $function$
BEGIN
    IF char_length(btrim(coalesce(p_reason, ''))) NOT BETWEEN 3 AND 500 THEN
        RAISE EXCEPTION 'reason_required' USING ERRCODE = '22023';
    END IF;
    RETURN btrim(p_reason);
END;
$function$;

-- ---------------------------------------------------------------------------
-- 4. Platform settings (admin-controlled).
-- ---------------------------------------------------------------------------

ALTER TABLE private.platform_settings
    ADD COLUMN default_cancellation_window_hours smallint NOT NULL DEFAULT 24,
    ADD COLUMN default_cancellation_fee_percent  smallint NOT NULL DEFAULT 0,
    -- The only map provider in v1; the switch point for a future change.
    ADD COLUMN map_provider                      text     NOT NULL DEFAULT 'google',
    -- How long an unpaid card checkout holds its slot.
    ADD COLUMN checkout_hold_minutes             smallint NOT NULL DEFAULT 15,
    -- How long a provider has to answer a card request (card holds last ~7 days).
    ADD COLUMN card_request_response_hours       smallint NOT NULL DEFAULT 144,
    -- Card payments only for appointments this close (Stripe holds funds ≤ 90 days).
    ADD COLUMN card_max_advance_days             smallint NOT NULL DEFAULT 60,
    -- Card bookings complete themselves this long after they end.
    ADD COLUMN auto_complete_after_hours         smallint NOT NULL DEFAULT 24,
    -- Clients can report a problem until this long after the end.
    ADD COLUMN report_window_hours               smallint NOT NULL DEFAULT 24,
    ADD COLUMN updated_by                        uuid,
    ADD CONSTRAINT platform_settings_default_window CHECK (default_cancellation_window_hours BETWEEN 0 AND 168),
    ADD CONSTRAINT platform_settings_default_fee CHECK (default_cancellation_fee_percent BETWEEN 0 AND 100),
    ADD CONSTRAINT platform_settings_map_provider CHECK (map_provider IN ('google')),
    ADD CONSTRAINT platform_settings_checkout_hold CHECK (checkout_hold_minutes BETWEEN 5 AND 60),
    ADD CONSTRAINT platform_settings_card_response CHECK (card_request_response_hours BETWEEN 1 AND 156),
    ADD CONSTRAINT platform_settings_card_advance CHECK (card_max_advance_days BETWEEN 1 AND 85),
    ADD CONSTRAINT platform_settings_auto_complete CHECK (auto_complete_after_hours BETWEEN 1 AND 168),
    ADD CONSTRAINT platform_settings_report_window CHECK (report_window_hours BETWEEN 1 AND 168);

COMMENT ON COLUMN private.platform_settings.fee_free_days IS
    'Days without Myglo commission for each provider, counted from when their card payments are first enabled.';

-- New providers start with the platform's default cancellation policy.
CREATE OR REPLACE FUNCTION private.ensure_provider_booking_settings()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
    v_window smallint := 24;
    v_fee    smallint := 0;
BEGIN
    IF NEW.role = 'provider' THEN
        SELECT s.default_cancellation_window_hours, s.default_cancellation_fee_percent
        INTO v_window, v_fee
        FROM private.platform_settings s WHERE s.id;

        INSERT INTO public.provider_booking_settings (provider_id, cancellation_window_hours, cancellation_fee_percent)
        VALUES (NEW.id, coalesce(v_window, 24), coalesce(v_fee, 0))
        ON CONFLICT (provider_id) DO NOTHING;
    END IF;
    RETURN NULL;
END;
$function$;

-- Settings every signed-in app may read.
CREATE FUNCTION public.get_app_config()
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO ''
AS $function$
    SELECT jsonb_build_object('map_provider', s.map_provider)
    FROM private.platform_settings s WHERE s.id;
$function$;

CREATE FUNCTION private.platform_settings_json()
RETURNS jsonb
LANGUAGE sql
STABLE
SET search_path TO ''
AS $function$
    SELECT jsonb_build_object(
        'platform_fee_percent', s.platform_fee_percent,
        'fee_free_days', s.fee_free_days,
        'default_cancellation_window_hours', s.default_cancellation_window_hours,
        'default_cancellation_fee_percent', s.default_cancellation_fee_percent,
        'map_provider', s.map_provider,
        'checkout_hold_minutes', s.checkout_hold_minutes,
        'card_request_response_hours', s.card_request_response_hours,
        'card_max_advance_days', s.card_max_advance_days,
        'auto_complete_after_hours', s.auto_complete_after_hours,
        'report_window_hours', s.report_window_hours,
        'updated_at', s.updated_at,
        'updated_by', (SELECT a.display_name FROM private.admins a WHERE a.user_id = s.updated_by))
    FROM private.platform_settings s WHERE s.id;
$function$;

CREATE FUNCTION public.admin_get_platform_settings()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO ''
AS $function$
BEGIN
    PERFORM private.require_admin();
    RETURN private.platform_settings_json();
END;
$function$;

-- Changes any of the settings in p_changes (keys as in admin_get_platform_settings).
-- Sensitive: needs a fresh TOTP, a reason, and is audited with before/after.
-- Fee changes apply to bookings made from now on; existing bookings keep the
-- fee they were made with.
CREATE FUNCTION public.admin_update_platform_settings(p_changes jsonb, p_reason text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
    v_admin  uuid;
    v_reason text;
    v_before jsonb;
    v_after  jsonb;
    v_key    text;
    v_allowed constant text[] := ARRAY[
        'platform_fee_percent', 'fee_free_days', 'default_cancellation_window_hours',
        'default_cancellation_fee_percent', 'map_provider', 'checkout_hold_minutes',
        'card_request_response_hours', 'card_max_advance_days', 'auto_complete_after_hours',
        'report_window_hours'];
BEGIN
    v_admin := private.require_admin(true);
    v_reason := private.require_reason(p_reason);
    IF p_changes IS NULL OR jsonb_typeof(p_changes) <> 'object' OR p_changes = '{}'::jsonb THEN
        RAISE EXCEPTION 'invalid_request' USING ERRCODE = '22023';
    END IF;
    FOR v_key IN SELECT jsonb_object_keys(p_changes) LOOP
        IF NOT v_key = ANY (v_allowed) OR jsonb_typeof(p_changes->v_key) = 'null' THEN
            RAISE EXCEPTION 'invalid_setting' USING ERRCODE = '22023', DETAIL = v_key;
        END IF;
    END LOOP;

    v_before := private.platform_settings_json();

    BEGIN
        UPDATE private.platform_settings s SET
            platform_fee_percent = coalesce((p_changes->>'platform_fee_percent')::numeric(5,2), s.platform_fee_percent),
            fee_free_days = coalesce((p_changes->>'fee_free_days')::integer, s.fee_free_days),
            default_cancellation_window_hours = coalesce((p_changes->>'default_cancellation_window_hours')::smallint, s.default_cancellation_window_hours),
            default_cancellation_fee_percent = coalesce((p_changes->>'default_cancellation_fee_percent')::smallint, s.default_cancellation_fee_percent),
            map_provider = coalesce(p_changes->>'map_provider', s.map_provider),
            checkout_hold_minutes = coalesce((p_changes->>'checkout_hold_minutes')::smallint, s.checkout_hold_minutes),
            card_request_response_hours = coalesce((p_changes->>'card_request_response_hours')::smallint, s.card_request_response_hours),
            card_max_advance_days = coalesce((p_changes->>'card_max_advance_days')::smallint, s.card_max_advance_days),
            auto_complete_after_hours = coalesce((p_changes->>'auto_complete_after_hours')::smallint, s.auto_complete_after_hours),
            report_window_hours = coalesce((p_changes->>'report_window_hours')::smallint, s.report_window_hours),
            updated_at = now(),
            updated_by = v_admin
        WHERE s.id;
    EXCEPTION
        WHEN check_violation OR invalid_text_representation OR numeric_value_out_of_range THEN
            RAISE EXCEPTION 'invalid_setting' USING ERRCODE = '22023', DETAIL = SQLERRM;
    END;

    v_after := private.platform_settings_json();
    PERFORM private.audit('platform_settings.update', 'platform_settings', 'singleton', v_reason,
        v_before - 'updated_at' - 'updated_by', v_after - 'updated_at' - 'updated_by');
    RETURN v_after;
END;
$function$;

-- ---------------------------------------------------------------------------
-- 5. Dashboard, people (read-only for now) and the audit log.
-- ---------------------------------------------------------------------------

CREATE FUNCTION public.admin_get_dashboard()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO ''
AS $function$
BEGIN
    PERFORM private.require_admin();
    RETURN jsonb_build_object(
        'providers', (SELECT count(*) FROM public.profiles WHERE role = 'provider'),
        'clients', (SELECT count(*) FROM public.profiles WHERE role = 'customer'),
        'new_users_7d', (SELECT count(*) FROM public.profiles WHERE created_at >= now() - interval '7 days'),
        'bookings_upcoming', (SELECT count(*) FROM public.bookings
                              WHERE status IN ('pending', 'confirmed') AND starts_at > now()),
        'bookings_pending', (SELECT count(*) FROM public.bookings
                             WHERE status = 'pending' AND starts_at > now()),
        'bookings_7d', (SELECT count(*) FROM public.bookings WHERE created_at >= now() - interval '7 days'),
        'failed_jobs', (SELECT count(*) FROM private.jobs WHERE status = 'failed'
                        AND updated_at >= now() - interval '30 days'),
        'generated_at', now());
END;
$function$;

-- Clients and providers matching a search (name, business name, email,
-- phone or exact id), newest first.
CREATE FUNCTION public.admin_search_users(
    p_query  text    DEFAULT NULL,
    p_role   text    DEFAULT NULL,
    p_limit  integer DEFAULT 30,
    p_offset integer DEFAULT 0)
RETURNS TABLE (
    user_id       uuid,
    role          text,
    display_name  text,
    business_name text,
    email         text,
    phone         text,
    avatar_url    text,
    created_at    timestamptz,
    last_sign_in  timestamptz)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
    v_query text := nullif(btrim(coalesce(p_query, '')), '');
    v_like  text;
BEGIN
    PERFORM private.require_admin();
    IF p_role IS NOT NULL AND p_role NOT IN ('customer', 'provider') THEN
        RAISE EXCEPTION 'invalid_request' USING ERRCODE = '22023';
    END IF;
    v_like := '%' || replace(replace(replace(coalesce(v_query, ''), '\', '\\'), '%', '\%'), '_', '\_') || '%';

    RETURN QUERY
    SELECT p.id,
           p.role,
           nullif(btrim(concat_ws(' ', btrim(p.first_name), btrim(p.last_name))), ''),
           p.provider_name,
           u.email::text,
           p.phone_number,
           p.profile_pic,
           p.created_at,
           u.last_sign_in_at
    FROM public.profiles p
    JOIN auth.users u ON u.id = p.id
    WHERE (p_role IS NULL OR p.role = p_role)
      AND (v_query IS NULL
           OR p.id::text = v_query
           OR concat_ws(' ', p.first_name, p.last_name) ILIKE v_like
           OR p.provider_name ILIKE v_like
           OR u.email ILIKE v_like
           OR p.phone_number ILIKE v_like)
    ORDER BY p.created_at DESC, p.id
    LIMIT least(greatest(coalesce(p_limit, 30), 1), 100)
    OFFSET greatest(coalesce(p_offset, 0), 0);
END;
$function$;

-- One client or provider: profile, account, booking activity.
CREATE FUNCTION public.admin_get_user(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
    v_result jsonb;
BEGIN
    PERFORM private.require_admin();

    SELECT jsonb_build_object(
        'user_id', p.id,
        'role', p.role,
        'first_name', p.first_name,
        'last_name', p.last_name,
        'business_name', p.provider_name,
        'email', u.email,
        'email_confirmed_at', u.email_confirmed_at,
        'phone', p.phone_number,
        'avatar_url', p.profile_pic,
        'address', p.address_text,
        'created_at', p.created_at,
        'last_sign_in', u.last_sign_in_at,
        'banned_until', u.banned_until,
        'bookings', (
            SELECT jsonb_build_object(
                'total', count(*),
                'upcoming', count(*) FILTER (WHERE b.status IN ('pending', 'confirmed') AND b.starts_at > now()),
                'completed', count(*) FILTER (WHERE b.status = 'completed'),
                'cancelled', count(*) FILTER (WHERE b.status = 'cancelled'),
                'no_show', count(*) FILTER (WHERE b.status = 'no_show'),
                'declined', count(*) FILTER (WHERE b.status IN ('declined', 'expired')))
            FROM public.bookings b
            WHERE (p.role = 'provider' AND b.provider_id = p.id)
               OR (p.role = 'customer' AND b.client_id = p.id)),
        'booking_settings', CASE WHEN p.role = 'provider' THEN (
            SELECT jsonb_build_object(
                'accepts_bookings', s.accepts_bookings,
                'requires_approval', s.requires_approval,
                'cancellation_window_hours', s.cancellation_window_hours,
                'cancellation_fee_percent', s.cancellation_fee_percent,
                'offers_studio', s.offers_studio,
                'offers_mobile', s.offers_mobile)
            FROM public.provider_booking_settings s WHERE s.provider_id = p.id) END,
        'recent_bookings', coalesce((
            SELECT jsonb_agg(r ORDER BY r.starts_at DESC)
            FROM (
                SELECT b.id, b.reference, b.status, b.starts_at, b.total_cents, b.payment_method,
                       b.payment_status,
                       CASE WHEN p.role = 'provider' THEN b.client_name ELSE b.provider_name END AS other_party
                FROM public.bookings b
                WHERE (p.role = 'provider' AND b.provider_id = p.id)
                   OR (p.role = 'customer' AND b.client_id = p.id)
                ORDER BY b.starts_at DESC
                LIMIT 10) r), '[]'::jsonb))
    INTO v_result
    FROM public.profiles p
    JOIN auth.users u ON u.id = p.id
    WHERE p.id = p_user_id;

    IF v_result IS NULL THEN
        RAISE EXCEPTION 'not_found' USING ERRCODE = 'P0002';
    END IF;
    RETURN v_result;
END;
$function$;

-- Newest audit entries first; page with p_before_id.
CREATE FUNCTION public.admin_list_audit_log(
    p_before_id   bigint  DEFAULT NULL,
    p_limit       integer DEFAULT 50,
    p_target_type text    DEFAULT NULL,
    p_target_id   text    DEFAULT NULL)
RETURNS TABLE (
    id          bigint,
    admin_email text,
    admin_name  text,
    action      text,
    target_type text,
    target_id   text,
    reason      text,
    before      jsonb,
    after       jsonb,
    created_at  timestamptz)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO ''
AS $function$
BEGIN
    PERFORM private.require_admin();
    RETURN QUERY
    SELECT l.id, l.admin_email, a.display_name, l.action, l.target_type, l.target_id, l.reason,
           l.before, l.after, l.created_at
    FROM private.admin_audit_log l
    LEFT JOIN private.admins a ON a.user_id = l.admin_id
    WHERE (p_before_id IS NULL OR l.id < p_before_id)
      AND (p_target_type IS NULL OR l.target_type = p_target_type)
      AND (p_target_id IS NULL OR l.target_id = p_target_id)
    ORDER BY l.id DESC
    LIMIT least(greatest(coalesce(p_limit, 50), 1), 200);
END;
$function$;

-- ---------------------------------------------------------------------------
-- 6. Service cities.
-- ---------------------------------------------------------------------------

CREATE FUNCTION public.admin_list_service_cities()
RETURNS TABLE (
    city_id        uuid,
    name           text,
    state          text,
    latitude       double precision,
    longitude      double precision,
    radius_m       integer,
    sort_order     integer,
    is_active      boolean,
    provider_count integer,
    updated_at     timestamptz)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO ''
AS $function$
BEGIN
    PERFORM private.require_admin();
    RETURN QUERY
    SELECT c.id, btrim(c.name), btrim(c.state),
           public.st_y(c.centre::public.geometry), public.st_x(c.centre::public.geometry),
           c.radius_m, c.sort_order, c.is_active,
           (SELECT count(*)::integer FROM public.profiles pr
            WHERE pr.role = 'provider' AND pr.coordinates IS NOT NULL
              AND public.st_dwithin(pr.coordinates, c.centre, c.radius_m)),
           c.updated_at
    FROM public.service_cities c
    ORDER BY c.sort_order, lower(c.name);
END;
$function$;

CREATE FUNCTION private.service_city_json(p_id uuid)
RETURNS jsonb
LANGUAGE sql
STABLE
SET search_path TO ''
AS $function$
    SELECT jsonb_build_object(
        'name', c.name, 'state', c.state,
        'latitude', public.st_y(c.centre::public.geometry), 'longitude', public.st_x(c.centre::public.geometry),
        'radius_m', c.radius_m, 'sort_order', c.sort_order, 'is_active', c.is_active)
    FROM public.service_cities c WHERE c.id = p_id;
$function$;

-- Adds a city (p_city_id NULL, placed last) or edits one. Returns its id.
CREATE FUNCTION public.admin_save_service_city(
    p_city_id   uuid,
    p_name      text,
    p_state     text,
    p_latitude  double precision,
    p_longitude double precision,
    p_radius_m  integer,
    p_is_active boolean,
    p_reason    text DEFAULT NULL)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
    v_id     uuid := p_city_id;
    v_before jsonb;
BEGIN
    PERFORM private.require_admin();
    IF p_latitude IS NULL OR p_longitude IS NULL
       OR p_latitude NOT BETWEEN -44 AND -9 OR p_longitude NOT BETWEEN 112 AND 154 THEN
        RAISE EXCEPTION 'invalid_location' USING ERRCODE = '22023';
    END IF;

    BEGIN
        IF v_id IS NULL THEN
            INSERT INTO public.service_cities (name, state, centre, radius_m, sort_order, is_active)
            VALUES (btrim(p_name), upper(btrim(p_state)),
                    public.st_setsrid(public.st_makepoint(p_longitude, p_latitude), 4326)::public.geography,
                    p_radius_m,
                    coalesce((SELECT max(sort_order) + 1 FROM public.service_cities), 1),
                    coalesce(p_is_active, true))
            RETURNING id INTO v_id;
        ELSE
            v_before := private.service_city_json(v_id);
            IF v_before IS NULL THEN
                RAISE EXCEPTION 'not_found' USING ERRCODE = 'P0002';
            END IF;
            UPDATE public.service_cities SET
                name = btrim(p_name),
                state = upper(btrim(p_state)),
                centre = public.st_setsrid(public.st_makepoint(p_longitude, p_latitude), 4326)::public.geography,
                radius_m = p_radius_m,
                is_active = coalesce(p_is_active, is_active)
            WHERE id = v_id;
        END IF;
    EXCEPTION
        WHEN unique_violation THEN
            RAISE EXCEPTION 'city_exists' USING ERRCODE = '22023';
        WHEN check_violation OR not_null_violation THEN
            RAISE EXCEPTION 'invalid_city' USING ERRCODE = '22023';
    END;

    PERFORM private.audit(
        CASE WHEN p_city_id IS NULL THEN 'service_city.create' ELSE 'service_city.update' END,
        'service_city', v_id::text, p_reason, v_before, private.service_city_json(v_id));
    RETURN v_id;
END;
$function$;

-- Puts the cities in the given order (ids not listed keep their place after).
CREATE FUNCTION public.admin_reorder_service_cities(p_city_ids uuid[])
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
BEGIN
    PERFORM private.require_admin();
    IF p_city_ids IS NULL OR cardinality(p_city_ids) = 0 THEN
        RAISE EXCEPTION 'invalid_request' USING ERRCODE = '22023';
    END IF;
    UPDATE public.service_cities c
    SET sort_order = o.position
    FROM unnest(p_city_ids) WITH ORDINALITY AS o(id, position)
    WHERE c.id = o.id;
    UPDATE public.service_cities c
    SET sort_order = cardinality(p_city_ids) + c.sort_order
    WHERE NOT c.id = ANY (p_city_ids);
    PERFORM private.audit('service_city.reorder', 'service_city', NULL, NULL, NULL, to_jsonb(p_city_ids));
END;
$function$;

-- ---------------------------------------------------------------------------
-- 7. Admin alert recipients (jobs-worker, service role only).
-- ---------------------------------------------------------------------------

CREATE FUNCTION public.list_admin_alert_recipients()
RETURNS TABLE (email text)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO ''
AS $function$
    SELECT u.email::text
    FROM private.admins a
    JOIN auth.users u ON u.id = a.user_id
    WHERE u.email IS NOT NULL
      AND (u.banned_until IS NULL OR u.banned_until < now());
$function$;

-- ---------------------------------------------------------------------------
-- 8. Privileges.
-- ---------------------------------------------------------------------------

REVOKE ALL ON private.admins, private.admin_audit_log FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION private.is_admin(uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION private.before_admin_insert() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION private.sync_admin_app_metadata() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION private.before_profile_insert_not_admin() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION private.jwt_totp_verified_at() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION private.admin_session_hours() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION private.admin_reauth_seconds() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION private.require_admin(boolean) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION private.reject_audit_log_change() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION private.audit(text, text, text, text, jsonb, jsonb) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION private.require_reason(text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION private.platform_settings_json() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION private.service_city_json(uuid) FROM PUBLIC, anon, authenticated;

REVOKE ALL ON FUNCTION public.get_admin_status() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.get_app_config() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.admin_get_platform_settings() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.admin_update_platform_settings(jsonb, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.admin_get_dashboard() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.admin_search_users(text, text, integer, integer) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.admin_get_user(uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.admin_list_audit_log(bigint, integer, text, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.admin_list_service_cities() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.admin_save_service_city(uuid, text, text, double precision, double precision, integer, boolean, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.admin_reorder_service_cities(uuid[]) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.list_admin_alert_recipients() FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION public.get_admin_status() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_app_config() TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_get_platform_settings() TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_update_platform_settings(jsonb, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_get_dashboard() TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_search_users(text, text, integer, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_get_user(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_list_audit_log(bigint, integer, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_list_service_cities() TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_save_service_city(uuid, text, text, double precision, double precision, integer, boolean, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_reorder_service_cities(uuid[]) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_admin_alert_recipients() TO service_role;
