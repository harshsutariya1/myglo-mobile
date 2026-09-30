-- APPLIED to project oyveznxdnbduqgaddklr on 2026-09-30 (version 20260930122337).
--
-- Fixes an authorization bypass: `IF auth.uid() != p_id` is NULL (not true) for an
-- unauthenticated caller, so anon could run update_onboarding_details on any user.
-- Also blocks direct client edits of role / counters / email.

-- 1. register_user_role: reject unauthenticated callers (NULL auth.uid()), trust auth.users email,
--    stop writing to the deprecated provider_details table.
CREATE OR REPLACE FUNCTION public.register_user_role(p_id uuid, p_email text, p_role text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    v_email text;
BEGIN
    IF auth.uid() IS NULL OR auth.uid() IS DISTINCT FROM p_id THEN
        RAISE EXCEPTION 'Not authorized' USING ERRCODE = '42501';
    END IF;
    IF p_role IS NULL OR p_role NOT IN ('customer', 'provider') THEN
        RAISE EXCEPTION 'Invalid role';
    END IF;

    -- p_email is kept for client compatibility but ignored: the address comes from auth.users.
    SELECT email INTO v_email FROM auth.users WHERE id = p_id;
    IF v_email IS NULL THEN
        RAISE EXCEPTION 'Auth user not found';
    END IF;

    INSERT INTO public.profiles (id, email, role) VALUES (p_id, v_email, p_role)
    ON CONFLICT (id) DO NOTHING;
END;
$function$;

-- 2. update_onboarding_details: same NULL-uid fix, role is immutable once onboarded, basic input checks.
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
    v_role  text;
    v_first text;
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
        phone_number = p_phone,
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

-- 3. check_user_exists: case-insensitive.
CREATE OR REPLACE FUNCTION public.check_user_exists(p_email text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'auth'
AS $function$
BEGIN
    RETURN EXISTS (SELECT 1 FROM auth.users WHERE lower(email) = lower(btrim(p_email)));
END;
$function$;

-- 4. Grants: PUBLIC has EXECUTE by default, so revoke it explicitly.
REVOKE ALL ON FUNCTION public.register_user_role(uuid, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.register_user_role(uuid, text, text) TO authenticated;

REVOKE ALL ON FUNCTION public.update_onboarding_details(uuid, text, text, text, text, text, text, text, double precision, double precision) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.update_onboarding_details(uuid, text, text, text, text, text, text, text, double precision, double precision) TO authenticated;

-- Needed before sign-in (login vs sign-up decision), so anon keeps access.
REVOKE ALL ON FUNCTION public.check_user_exists(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.check_user_exists(text) TO anon, authenticated;

-- 5. Block direct client edits of privileged / derived columns. Definer functions
--    (onboarding RPC, counter triggers) run as their owner and are unaffected.
CREATE OR REPLACE FUNCTION public.protect_profile_columns()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
BEGIN
    IF current_user IN ('anon', 'authenticated') THEN
        IF NEW.id IS DISTINCT FROM OLD.id
           OR NEW.role IS DISTINCT FROM OLD.role
           OR NEW.email IS DISTINCT FROM OLD.email
           OR NEW.followers_count IS DISTINCT FROM OLD.followers_count
           OR NEW.following_count IS DISTINCT FROM OLD.following_count
           OR NEW.created_at IS DISTINCT FROM OLD.created_at THEN
            RAISE EXCEPTION 'Protected profile column cannot be modified directly' USING ERRCODE = '42501';
        END IF;
        NEW.updated_at := now();
    END IF;
    RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS protect_profile_columns ON public.profiles;
CREATE TRIGGER protect_profile_columns BEFORE UPDATE ON public.profiles
    FOR EACH ROW EXECUTE FUNCTION public.protect_profile_columns();

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
           OR NEW.created_at IS DISTINCT FROM OLD.created_at THEN
            RAISE EXCEPTION 'Protected post column cannot be modified directly' USING ERRCODE = '42501';
        END IF;
    END IF;
    RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS protect_post_columns ON public.posts;
CREATE TRIGGER protect_post_columns BEFORE UPDATE ON public.posts
    FOR EACH ROW EXECUTE FUNCTION public.protect_post_columns();

REVOKE ALL ON FUNCTION public.protect_profile_columns() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.protect_post_columns() FROM PUBLIC, anon, authenticated;
