-- Production-readiness hardening (2026-11-11 audit).
--
-- 1. Profiles could be inserted and deleted straight through the API.
--    The app does neither: profiles are created by register_user_role() and
--    removed by delete_account() (both SECURITY DEFINER). The leftover
--    policies let a signed-in user
--      * delete their own profile, skipping every account-deletion blocker
--        (upcoming paid bookings, settlements on their way, open disputes):
--        bookings lose their provider, the payout-account row cascades away
--        and the user can then onboard again under the other role;
--      * insert their own profile with any email, follower counts or role,
--        skipping register_user_role() (which takes the email from Auth).
--    Remove both paths. Updates stay (guarded by protect_profile_columns).
--
-- 2. The profile-pics bucket accepted any file type of any size. Give it
--    the same limits as the other image buckets.
--
-- 3. PostGIS's spatial_ref_sys sits in the exposed schema without RLS and
--    is writable by anon. Deleting its SRID 4326 row would break every
--    distance query. The table belongs to supabase_admin, so this REVOKE
--    may be a no-op on hosted Supabase (Postgres only warns); the DO block
--    below reports whether it worked. If it didn't, ask Supabase support to
--    revoke the grants or enable RLS on the table.

-- 1 -------------------------------------------------------------------------
DROP POLICY IF EXISTS "Users can insert own profile" ON public.profiles;
DROP POLICY IF EXISTS "Users can delete own profile" ON public.profiles;

REVOKE INSERT, DELETE, TRUNCATE, REFERENCES, TRIGGER ON public.profiles FROM anon, authenticated;
REVOKE SELECT, UPDATE ON public.profiles FROM anon;

-- 2 -------------------------------------------------------------------------
UPDATE storage.buckets
SET file_size_limit = 5242880,
    allowed_mime_types = ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/heic']
WHERE id = 'profile-pics';

-- 3 -------------------------------------------------------------------------
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER ON public.spatial_ref_sys FROM anon, authenticated;

DO $$
BEGIN
    IF has_table_privilege('anon', 'public.spatial_ref_sys', 'DELETE')
       OR has_table_privilege('authenticated', 'public.spatial_ref_sys', 'DELETE') THEN
        RAISE WARNING 'spatial_ref_sys is still writable through the API: ask Supabase support to revoke anon/authenticated writes on it';
    END IF;
END;
$$;
