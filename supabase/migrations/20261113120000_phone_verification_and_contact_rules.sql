-- Phone verification for providers, and one rule for contact details.
--
-- * Providers verify their phone number. Supabase Auth texts the code and
--   confirms the number (auth.users.phone / phone_confirmed_at; Auth also
--   keeps a number to one account). confirm_phone_verification() then copies
--   the confirmed number onto the profile and stamps
--   profiles.phone_verified_at. Only that function can mark a profile
--   verified; changing the number any other way clears the mark.
--   Verification is asked for, not enforced: an unverified provider stays
--   listed and bookable, and the app keeps prompting them.
-- * A phone number is required for clients and providers: onboarding refuses
--   to finish without one, and a saved number can be changed but not removed.
-- * Whether contact details are public is no longer each person's choice.
--   A provider's email and phone are always shown to signed-in users (they
--   are business contact details); a client's never are. Providers still get
--   a client's number on that client's bookings. The is_email_public /
--   is_phone_public columns stay for app builds already installed, but
--   nothing reads them any more.
--
-- Needs the Phone provider with an SMS sender and phone confirmations turned
-- on in Supabase Auth (see docs/phone_verification.md). Builds on
-- 20261112120000 (public_profiles.is_listed).

-- ---------------------------------------------------------------------------
-- 1. The verified mark, and the rule that a number can't be removed.
-- ---------------------------------------------------------------------------

ALTER TABLE public.profiles
    ADD COLUMN phone_verified_at timestamptz;

COMMENT ON COLUMN public.profiles.phone_verified_at IS
    'When phone_number was confirmed by an SMS code; null if it never was or the number changed since. Set only by confirm_phone_verification().';

-- App roles can update any profile column of their own row, so the mark is
-- protected here (as protect_profile_columns does for role and email).
CREATE FUNCTION private.guard_phone_number()
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

    IF current_user IN ('anon', 'authenticated') THEN
        IF NEW.phone_verified_at IS DISTINCT FROM OLD.phone_verified_at THEN
            RAISE EXCEPTION 'Protected profile column cannot be modified directly' USING ERRCODE = '42501';
        END IF;
        IF btrim(coalesce(NEW.phone_number, '')) = '' AND btrim(coalesce(OLD.phone_number, '')) <> '' THEN
            RAISE EXCEPTION 'phone_required' USING ERRCODE = '22023',
                DETAIL = 'A phone number can be changed but not removed.';
        END IF;
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

CREATE TRIGGER profiles_guard_phone_number
    BEFORE INSERT OR UPDATE ON public.profiles
    FOR EACH ROW EXECUTE FUNCTION private.guard_phone_number();

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

REVOKE ALL ON FUNCTION private.guard_phone_number() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.confirm_phone_verification() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.confirm_phone_verification() TO authenticated;

-- ---------------------------------------------------------------------------
-- 2. Onboarding needs a phone number (clients and providers).
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.update_onboarding_details(
    p_id uuid, p_role text, p_first_name text, p_last_name text, p_phone text, p_profile_pic text,
    p_provider_name text DEFAULT NULL::text, p_address_text text DEFAULT NULL::text,
    p_longitude double precision DEFAULT NULL::double precision, p_latitude double precision DEFAULT NULL::double precision)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
    v_role   text;
    v_first  text;
    v_phone  text := btrim(coalesce(p_phone, ''));
    v_digits integer := char_length(regexp_replace(coalesce(p_phone, ''), '\D', '', 'g'));
BEGIN
    IF auth.uid() IS NULL OR auth.uid() IS DISTINCT FROM p_id THEN
        RAISE EXCEPTION 'Not authorized' USING ERRCODE = '42501';
    END IF;
    IF p_role IS NULL OR p_role NOT IN ('customer', 'provider') THEN
        RAISE EXCEPTION 'Invalid role: %', p_role;
    END IF;
    IF btrim(coalesce(p_first_name, '')) = '' OR btrim(coalesce(p_last_name, '')) = '' THEN
        RAISE EXCEPTION 'First and last name are required';
    END IF;
    IF char_length(p_first_name) > 100 OR char_length(p_last_name) > 100 THEN
        RAISE EXCEPTION 'Name is too long';
    END IF;
    IF v_phone = '' THEN
        RAISE EXCEPTION 'A phone number is required';
    END IF;
    IF v_phone !~ '^[+0-9(][0-9 ()-]*$' OR v_digits < 8 OR v_digits > 15 OR char_length(v_phone) > 20 THEN
        RAISE EXCEPTION 'Enter a valid phone number';
    END IF;

    SELECT role, first_name INTO v_role, v_first FROM public.profiles WHERE id = p_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Profile not found: %', p_id;
    END IF;
    IF v_role IS DISTINCT FROM p_role AND btrim(coalesce(v_first, '')) <> '' THEN
        RAISE EXCEPTION 'Role cannot be changed after onboarding' USING ERRCODE = '42501';
    END IF;

    UPDATE public.profiles
    SET
        role = p_role,
        first_name = p_first_name,
        last_name = p_last_name,
        phone_number = v_phone,
        profile_pic = p_profile_pic,
        provider_name = CASE WHEN p_role = 'provider' THEN p_provider_name ELSE NULL END,
        address_text = CASE WHEN p_role = 'provider' THEN p_address_text ELSE NULL END,
        coordinates = CASE
            WHEN p_role = 'provider' AND p_longitude IS NOT NULL AND p_latitude IS NOT NULL
                THEN ST_SetSRID(ST_MakePoint(p_longitude, p_latitude), 4326)::geography
            WHEN p_role = 'provider' THEN coordinates
            ELSE NULL
        END,
        updated_at = now()
    WHERE id = p_id;
END;
$function$;

-- ---------------------------------------------------------------------------
-- 3. Contact details by role, not by switch. Columns keep their order;
--    is_listed is unchanged from 20261112120000.
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
       CASE WHEN role = 'provider' THEN email ELSE NULL::text END AS email,
       CASE WHEN role = 'provider' THEN phone_number ELSE NULL::text END AS phone_number,
       cover_photos,
       (role IS DISTINCT FROM 'provider'
        OR NOT (EXISTS (SELECT 1 FROM public.provider_booking_settings s
                        WHERE s.provider_id = profiles.id AND s.hidden_from_marketplace)
                OR EXISTS (SELECT 1 FROM private.user_restrictions r
                           WHERE r.user_id = profiles.id
                             AND (r.suspended_at IS NOT NULL OR r.bookings_blocked_at IS NOT NULL)))) AS is_listed
FROM public.profiles;

-- ---------------------------------------------------------------------------
-- 4. Admins see whether a number is verified and whether a business is hidden.
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

SELECT pg_temp.patch_function('public.admin_get_user(uuid)',
    '''phone'', p.phone_number,',
    '''phone'', p.phone_number,
        ''phone_verified_at'', p.phone_verified_at,');
SELECT pg_temp.patch_function('public.admin_get_user(uuid)',
    '''accepts_bookings'', s.accepts_bookings,',
    '''accepts_bookings'', s.accepts_bookings,
                ''hidden_from_marketplace'', s.hidden_from_marketplace,');
