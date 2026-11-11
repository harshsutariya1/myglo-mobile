-- Providers hide their business instead of deleting their account.
--
-- * A provider can hide their business from the marketplace
--   (provider_booking_settings.hidden_from_marketplace). While hidden they
--   drop out of search, the map, the home list, city counts, tag search and
--   the Discover feeds, have no free times and can't be booked. Bookings
--   they already have are untouched: they still see, answer, complete and
--   get paid for them, and the clients still see them.
-- * Providers no longer delete their own account in the app. Whether they
--   may is a platform setting (provider_self_deletion, off by default), so
--   it can be turned back on without an app release. delete_account()
--   itself is unchanged: support can still close a provider's account on
--   request, with every existing blocker (bookings, payouts, disputes).
--
-- "Unlisted" below means not discoverable and not bookable: suspended,
-- booking-blocked by an admin (private.is_unbookable) or hidden by the
-- provider.

-- ---------------------------------------------------------------------------
-- 1. The provider's own switch.
-- ---------------------------------------------------------------------------

ALTER TABLE public.provider_booking_settings
    ADD COLUMN hidden_from_marketplace boolean NOT NULL DEFAULT false,
    ADD COLUMN hidden_at timestamptz;

COMMENT ON COLUMN public.provider_booking_settings.hidden_from_marketplace IS
    'Set by the provider: not shown anywhere in the marketplace and not bookable. Existing bookings carry on.';
COMMENT ON COLUMN public.provider_booking_settings.hidden_at IS
    'When the provider last hid their business; null while listed. Set by a trigger.';

-- Providers change it like their other booking rules: a direct update of
-- their own row (row level security), refused while suspended
-- (provider_booking_settings_block_suspended). hidden_at isn't writable.
GRANT UPDATE (hidden_from_marketplace) ON public.provider_booking_settings TO authenticated;

CREATE FUNCTION private.stamp_marketplace_visibility()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO ''
AS $function$
BEGIN
    IF NEW.hidden_from_marketplace IS DISTINCT FROM OLD.hidden_from_marketplace THEN
        NEW.hidden_at := CASE WHEN NEW.hidden_from_marketplace THEN now() END;
    ELSE
        NEW.hidden_at := OLD.hidden_at;
    END IF;
    RETURN NEW;
END;
$function$;

CREATE TRIGGER provider_booking_settings_visibility
    BEFORE UPDATE ON public.provider_booking_settings
    FOR EACH ROW EXECUTE FUNCTION private.stamp_marketplace_visibility();

CREATE FUNCTION private.is_hidden_provider(p_provider_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SET search_path TO ''
AS $function$
    SELECT EXISTS (SELECT 1 FROM public.provider_booking_settings s
                   WHERE s.provider_id = p_provider_id AND s.hidden_from_marketplace);
$function$;

-- Not discoverable and not bookable, whoever decided it.
CREATE FUNCTION private.is_unlisted(p_provider_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SET search_path TO ''
AS $function$
    SELECT private.is_unbookable(p_provider_id) OR private.is_hidden_provider(p_provider_id);
$function$;

REVOKE ALL ON FUNCTION private.stamp_marketplace_visibility() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION private.is_hidden_provider(uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION private.is_unlisted(uuid) FROM PUBLIC, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 2. One-line changes to large functions. Each patch must match exactly
--    once, or the migration fails (as in 20261101140000).
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

-- Hidden providers drop out of search and the map (which also feeds the
-- client home list)...
SELECT pg_temp.patch_function('public.search_providers(text, double precision, double precision, integer)',
    'NOT private.is_unbookable(pr.id)',
    'NOT private.is_unlisted(pr.id)');
SELECT pg_temp.patch_function('public.map_providers(double precision, double precision, double precision, integer)',
    'NOT private.is_unbookable(pr.id)',
    'NOT private.is_unlisted(pr.id)');

-- ...have no free times...
SELECT pg_temp.patch_function('private.available_slots(uuid, integer, date, date)',
    'NOT private.is_unbookable(s.provider_id)',
    'NOT private.is_unlisted(s.provider_id)');

-- ...and can't be booked, whatever path the booking takes.
SELECT pg_temp.patch_function(
    'public.create_booking(uuid, uuid, uuid[], timestamptz, text, text, integer, text, jsonb, double precision, double precision, text, text)',
    'private.is_unbookable(p_provider_id)',
    'private.is_unlisted(p_provider_id)');
SELECT pg_temp.patch_function('private.check_booking_parties()',
    'private.is_unbookable(NEW.provider_id)',
    'private.is_unlisted(NEW.provider_id)');

-- Their posts leave the Discover feeds (they stay on the provider's own
-- profile and come back when the business is listed again).
SELECT pg_temp.patch_function('public.nearby_posts(double precision, timestamptz, integer)',
    'AND p.hidden_at IS NULL',
    'AND p.hidden_at IS NULL AND NOT private.is_hidden_provider(p.author_id)');
SELECT pg_temp.patch_function('public.posts_beyond_nearby(double precision, timestamptz, integer)',
    'AND p.hidden_at IS NULL',
    'AND p.hidden_at IS NULL AND NOT private.is_hidden_provider(p.author_id)');

-- City counts ("12 salons") only count providers a client can actually find.
CREATE OR REPLACE FUNCTION public.list_service_cities()
RETURNS TABLE(city_id uuid, name text, state text, latitude double precision, longitude double precision, radius_m integer, provider_count integer)
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path TO ''
AS $function$
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Not authorized' USING ERRCODE = '42501';
    END IF;

    RETURN QUERY
    SELECT c.id,
           btrim(c.name),
           btrim(c.state),
           public.st_y(c.centre::public.geometry),
           public.st_x(c.centre::public.geometry),
           c.radius_m,
           (SELECT count(*)::integer
            FROM public.profiles pr
            WHERE pr.role = 'provider'
              AND pr.coordinates IS NOT NULL
              AND NOT private.is_unlisted(pr.id)
              AND public.st_dwithin(pr.coordinates, c.centre, c.radius_m))
    FROM public.service_cities c
    WHERE c.is_active
    ORDER BY c.sort_order, lower(c.name);
END;
$function$;

-- ---------------------------------------------------------------------------
-- 3. public_profiles tells the app whether a provider is listed, so name
--    lookups (tagging a provider in a post) can leave unlisted ones out.
--    The view reads the tables as its owner, so the checks are written out
--    here instead of calling the private functions (which callers of the
--    view may not execute). Existing columns keep their order.
-- ---------------------------------------------------------------------------

CREATE OR REPLACE VIEW public.public_profiles
WITH (security_invoker = false, security_barrier = true) AS
SELECT id,
       role,
       first_name,
       last_name,
       profile_pic,
       bio,
       followers_count,
       following_count,
       provider_name,
       address_text,
       coordinates,
       created_at,
       updated_at,
       CASE WHEN is_email_public THEN email ELSE NULL::text END AS email,
       CASE WHEN is_phone_public THEN phone_number ELSE NULL::text END AS phone_number,
       cover_photos,
       (role IS DISTINCT FROM 'provider'
        OR NOT (EXISTS (SELECT 1 FROM public.provider_booking_settings s
                        WHERE s.provider_id = profiles.id AND s.hidden_from_marketplace)
                OR EXISTS (SELECT 1 FROM private.user_restrictions r
                           WHERE r.user_id = profiles.id
                             AND (r.suspended_at IS NOT NULL OR r.bookings_blocked_at IS NOT NULL)))) AS is_listed
FROM public.profiles;

-- ---------------------------------------------------------------------------
-- 4. Providers don't delete their own account unless the platform allows it.
-- ---------------------------------------------------------------------------

ALTER TABLE private.platform_settings
    ADD COLUMN provider_self_deletion boolean NOT NULL DEFAULT false;

COMMENT ON COLUMN private.platform_settings.provider_self_deletion IS
    'Whether providers may delete their own account in the app. Off: they hide their business instead and ask support to close the account.';

-- What stops the signed-in user deleting their own account: the platform
-- rule for providers first, then everything that blocks any deletion.
CREATE FUNCTION private.self_deletion_blockers(p_user_id uuid)
RETURNS jsonb
LANGUAGE sql
STABLE
SET search_path TO ''
AS $function$
    SELECT CASE
        WHEN EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = p_user_id AND p.role = 'provider')
             AND NOT coalesce((SELECT s.provider_self_deletion FROM private.platform_settings s WHERE s.id), false)
        THEN jsonb_build_array(jsonb_build_object('code', 'provider_deletion_disabled', 'count', 1))
        ELSE '[]'::jsonb
    END || private.account_deletion_blockers(p_user_id);
$function$;

REVOKE ALL ON FUNCTION private.self_deletion_blockers(uuid) FROM PUBLIC, anon, authenticated;

-- The two functions the user's own request goes through. delete_account()
-- (service role) keeps private.account_deletion_blockers.
SELECT pg_temp.patch_function('public.begin_account_deletion()',
    'private.account_deletion_blockers(v_uid)',
    'private.self_deletion_blockers(v_uid)');
SELECT pg_temp.patch_function('public.get_my_account_deletion_status()',
    'private.account_deletion_blockers(v_uid)',
    'private.self_deletion_blockers(v_uid)');

-- The app reads the rule up front, to decide whether to offer deletion.
CREATE OR REPLACE FUNCTION public.get_app_config()
RETURNS jsonb
LANGUAGE sql
STABLE SECURITY DEFINER
SET search_path TO ''
AS $function$
    SELECT jsonb_build_object(
        'map_provider', s.map_provider,
        'card_max_advance_days', s.card_max_advance_days,
        'checkout_hold_minutes', s.checkout_hold_minutes,
        'provider_self_deletion', s.provider_self_deletion)
    FROM private.platform_settings s WHERE s.id;
$function$;

-- Admins see and change it with the other platform settings
-- (admin_update_platform_settings: {"provider_self_deletion": true}).
SELECT pg_temp.patch_function('private.platform_settings_json()',
    '''report_window_hours'', s.report_window_hours,',
    '''report_window_hours'', s.report_window_hours,
        ''provider_self_deletion'', s.provider_self_deletion,');
SELECT pg_temp.patch_function('public.admin_update_platform_settings(jsonb, text)',
    '''report_window_hours''];',
    '''report_window_hours'', ''provider_self_deletion''];');
SELECT pg_temp.patch_function('public.admin_update_platform_settings(jsonb, text)',
    'report_window_hours = coalesce((p_changes->>''report_window_hours'')::smallint, s.report_window_hours),',
    'report_window_hours = coalesce((p_changes->>''report_window_hours'')::smallint, s.report_window_hours),
            provider_self_deletion = coalesce((p_changes->>''provider_self_deletion'')::boolean, s.provider_self_deletion),');
