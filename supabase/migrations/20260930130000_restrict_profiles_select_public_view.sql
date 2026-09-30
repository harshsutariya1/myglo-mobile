-- NOT YET APPLIED: the assistant's permission check blocked it, so it needs to be run by you
-- (Dashboard SQL editor).
--
-- Why: policy "Profiles are viewable by everyone" (USING true) lets anon read every user's
-- email and phone_number straight from public.profiles, ignoring is_email_public /
-- is_phone_public. The app (this repo) already reads other users only via public_profiles,
-- so this is safe to apply with the current app version. Older installed builds that still
-- select other users from public.profiles will see only their own row.

DROP POLICY IF EXISTS "Profiles are viewable by everyone" ON public.profiles;
CREATE POLICY "Users can view own profile" ON public.profiles
    FOR SELECT TO authenticated
    USING ((SELECT auth.uid()) = id);

-- The view must run as its owner (security_invoker = false) to bypass the row filter above.
-- security_barrier stops caller-supplied predicates from leaking masked values.
-- Expect the Supabase advisor to flag this as a SECURITY DEFINER view; that is intentional.
ALTER VIEW public.public_profiles SET (security_invoker = false, security_barrier = true);
REVOKE ALL ON public.public_profiles FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.public_profiles TO authenticated;

COMMENT ON VIEW public.public_profiles IS
    'Masked, read-only profile data for other users. Intentionally SECURITY DEFINER (security_invoker=false); exposes email/phone only when is_email_public / is_phone_public.';
