-- Providers verify their phone number.
--
-- * The number is verified by Supabase Auth: the app asks Auth to change the
--   user's phone, Auth texts a code, and entering it confirms the number
--   (auth.users.phone / phone_confirmed_at; Auth also keeps a number to one
--   account). confirm_phone_verification() then copies the confirmed number
--   onto the profile and stamps profiles.phone_verified_at.
-- * Only that function can mark a profile verified. Changing the profile's
--   phone number any other way clears the mark, so a "verified" number is
--   always the one that received the code.
-- * Whether providers must be verified is a platform setting
--   (require_provider_phone_verification, off by default so nobody vanishes
--   before SMS is set up). While it is on, an unverified provider is
--   unlisted exactly like a hidden one (private.is_unlisted, from
--   20261112120000): out of search, the map, city counts and tag search,
--   with no free times and not bookable. Existing bookings carry on.
--
-- Needs the Phone provider with an SMS sender and phone confirmations turned
-- on in Supabase Auth (see docs/phone_verification.md).

-- ---------------------------------------------------------------------------
-- 1. The verified mark.
-- ---------------------------------------------------------------------------

ALTER TABLE public.profiles
    ADD COLUMN phone_verified_at timestamptz;

COMMENT ON COLUMN public.profiles.phone_verified_at IS
    'When phone_number was confirmed by an SMS code; null if it never was or the number changed since. Set only by confirm_phone_verification().';

-- App roles can update any profile column of their own row, so the mark is
-- protected here (as protect_profile_columns does for role and email).
CREATE FUNCTION private.guard_phone_verification()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO ''
AS $function$
BEGIN
    IF TG_OP = 'INSERT' THEN
        IF current_user IN ('anon', 'authenticated') THEN
            NEW.phone_verified_at := NULL;
        END IF;
        RETURN NEW;
    END IF;

    IF current_user IN ('anon', 'authenticated')
       AND NEW.phone_verified_at IS DISTINCT FROM OLD.phone_verified_at THEN
        RAISE EXCEPTION 'Protected profile column cannot be modified directly' USING ERRCODE = '42501';
    END IF;
    -- A different number hasn't received a code, whoever changed it. (The
    -- confirming function sets the number and the mark together, so the mark
    -- differs from the old one and is kept.)
    IF NEW.phone_number IS DISTINCT FROM OLD.phone_number
       AND NEW.phone_verified_at IS NOT DISTINCT FROM OLD.phone_verified_at THEN
        NEW.phone_verified_at := NULL;
    END IF;
    RETURN NEW;
END;
$function$;

CREATE TRIGGER profiles_guard_phone_verification
    BEFORE INSERT OR UPDATE ON public.profiles
    FOR EACH ROW EXECUTE FUNCTION private.guard_phone_verification();

-- Called by the app right after Auth accepted the SMS code. Trusts nothing
-- from the caller: the number and its confirmation are read from Auth.
CREATE FUNCTION public.confirm_phone_verification()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
    v_uid       uuid := auth.uid();
    v_phone     text;
    v_confirmed timestamptz;
    v_number    text;
    v_verified  timestamptz;
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'not_authenticated' USING ERRCODE = '42501';
    END IF;

    SELECT nullif(btrim(u.phone), ''), u.phone_confirmed_at INTO v_phone, v_confirmed
    FROM auth.users u WHERE u.id = v_uid;
    IF v_phone IS NULL OR v_confirmed IS NULL THEN
        RAISE EXCEPTION 'phone_not_verified' USING ERRCODE = 'P0001';
    END IF;

    -- Auth stores the number without the leading "+".
    v_number := '+' || ltrim(v_phone, '+');

    UPDATE public.profiles p
    SET phone_number = v_number,
        -- Keep the original time if this number was already verified.
        phone_verified_at = CASE
            WHEN p.phone_number = v_number AND p.phone_verified_at IS NOT NULL THEN p.phone_verified_at
            ELSE now()
        END,
        updated_at = now()
    WHERE p.id = v_uid
    RETURNING p.phone_verified_at INTO v_verified;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'profile_not_found' USING ERRCODE = 'P0002';
    END IF;

    RETURN jsonb_build_object('phone_number', v_number, 'phone_verified_at', v_verified);
END;
$function$;

COMMENT ON FUNCTION public.confirm_phone_verification() IS
    'Copies the caller''s SMS-confirmed phone number from Auth onto their profile and marks it verified.';

REVOKE ALL ON FUNCTION private.guard_phone_verification() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.confirm_phone_verification() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.confirm_phone_verification() TO authenticated;

-- ---------------------------------------------------------------------------
-- 2. The requirement (platform setting) and what it does to listings.
-- ---------------------------------------------------------------------------

ALTER TABLE private.platform_settings
    ADD COLUMN require_provider_phone_verification boolean NOT NULL DEFAULT false;

COMMENT ON COLUMN private.platform_settings.require_provider_phone_verification IS
    'While on, providers without a verified phone number are unlisted: not discoverable and not bookable.';

CREATE FUNCTION private.lacks_required_phone(p_provider_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SET search_path TO ''
AS $function$
    SELECT coalesce((SELECT s.require_provider_phone_verification FROM private.platform_settings s WHERE s.id), false)
       AND NOT EXISTS (SELECT 1 FROM public.profiles p
                       WHERE p.id = p_provider_id AND p.phone_verified_at IS NOT NULL);
$function$;

REVOKE ALL ON FUNCTION private.lacks_required_phone(uuid) FROM PUBLIC, anon, authenticated;

-- Search, the map, availability, booking and city counts all ask this one
-- function, so the requirement applies to every one of them.
CREATE OR REPLACE FUNCTION private.is_unlisted(p_provider_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SET search_path TO ''
AS $function$
    SELECT private.is_unbookable(p_provider_id)
        OR private.is_hidden_provider(p_provider_id)
        OR private.lacks_required_phone(p_provider_id);
$function$;

-- The same rule for public_profiles.is_listed (tag search). Written out
-- because the view reads tables as its owner but can't call private
-- functions for its callers. Columns keep their order.
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
                             AND (r.suspended_at IS NOT NULL OR r.bookings_blocked_at IS NOT NULL))
                OR (profiles.phone_verified_at IS NULL
                    AND coalesce((SELECT ps.require_provider_phone_verification
                                  FROM private.platform_settings ps WHERE ps.id), false)))) AS is_listed
FROM public.profiles;

-- ---------------------------------------------------------------------------
-- 3. The app and the admin settings know about the requirement.
-- ---------------------------------------------------------------------------

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
        'provider_self_deletion', s.provider_self_deletion,
        'require_provider_phone_verification', s.require_provider_phone_verification)
    FROM private.platform_settings s WHERE s.id;
$function$;

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

-- admin_update_platform_settings: {"require_provider_phone_verification": true}.
SELECT pg_temp.patch_function('private.platform_settings_json()',
    '''provider_self_deletion'', s.provider_self_deletion,',
    '''provider_self_deletion'', s.provider_self_deletion,
        ''require_provider_phone_verification'', s.require_provider_phone_verification,');
SELECT pg_temp.patch_function('public.admin_update_platform_settings(jsonb, text)',
    '''provider_self_deletion''];',
    '''provider_self_deletion'', ''require_provider_phone_verification''];');
SELECT pg_temp.patch_function('public.admin_update_platform_settings(jsonb, text)',
    'provider_self_deletion = coalesce((p_changes->>''provider_self_deletion'')::boolean, s.provider_self_deletion),',
    'provider_self_deletion = coalesce((p_changes->>''provider_self_deletion'')::boolean, s.provider_self_deletion),
            require_provider_phone_verification = coalesce((p_changes->>''require_provider_phone_verification'')::boolean, s.require_provider_phone_verification),');
