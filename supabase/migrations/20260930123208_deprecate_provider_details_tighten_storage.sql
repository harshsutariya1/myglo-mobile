-- APPLIED to project oyveznxdnbduqgaddklr on 2026-09-30 (version 20260930123208).
--
-- 1. provider_details is unused: provider fields live on public.profiles and
--    register_user_role no longer writes to it. Rename + revoke instead of DROP so this is
--    reversible. It has no inbound foreign keys; after verifying, run:
--        DROP TABLE public._deprecated_provider_details;
-- 2. Storage: constrain upload paths to the layout the app already uses, and stop granting
--    write policies to the `public` role.

ALTER TABLE public.provider_details RENAME TO _deprecated_provider_details;
REVOKE ALL ON public._deprecated_provider_details FROM anon, authenticated;
COMMENT ON TABLE public._deprecated_provider_details IS
    'Deprecated 2026-09-30: provider fields moved to public.profiles. Safe to DROP after verification.';

-- profile-pics: object name must be "<uid>.jpg"
DROP POLICY IF EXISTS "User can upload Profile Picture" ON storage.objects;
DROP POLICY IF EXISTS "User can update own Profile Picture" ON storage.objects;
CREATE POLICY "User can upload Profile Picture" ON storage.objects
    FOR INSERT TO authenticated
    WITH CHECK (bucket_id = 'profile-pics' AND name = (SELECT auth.uid())::text || '.jpg');
CREATE POLICY "User can update own Profile Picture" ON storage.objects
    FOR UPDATE TO authenticated
    USING (bucket_id = 'profile-pics' AND owner_id = (SELECT auth.uid())::text)
    WITH CHECK (bucket_id = 'profile-pics' AND name = (SELECT auth.uid())::text || '.jpg');

-- post-media / service-images: object name must be "<uid>/<file>"
DROP POLICY IF EXISTS "User can upload to Post Media" ON storage.objects;
DROP POLICY IF EXISTS "User can update own Post Media" ON storage.objects;
DROP POLICY IF EXISTS "User can delete own Post Media" ON storage.objects;
CREATE POLICY "User can upload to Post Media" ON storage.objects
    FOR INSERT TO authenticated
    WITH CHECK (bucket_id = 'post-media' AND (storage.foldername(name))[1] = (SELECT auth.uid())::text);
CREATE POLICY "User can update own Post Media" ON storage.objects
    FOR UPDATE TO authenticated
    USING (bucket_id = 'post-media' AND owner_id = (SELECT auth.uid())::text)
    WITH CHECK (bucket_id = 'post-media' AND (storage.foldername(name))[1] = (SELECT auth.uid())::text);
CREATE POLICY "User can delete own Post Media" ON storage.objects
    FOR DELETE TO authenticated
    USING (bucket_id = 'post-media' AND owner_id = (SELECT auth.uid())::text);

DROP POLICY IF EXISTS "Provider can upload Service Images" ON storage.objects;
DROP POLICY IF EXISTS "Provider can update own Service Images" ON storage.objects;
DROP POLICY IF EXISTS "Provider can delete own Service Images" ON storage.objects;
CREATE POLICY "Provider can upload Service Images" ON storage.objects
    FOR INSERT TO authenticated
    WITH CHECK (bucket_id = 'service-images' AND (storage.foldername(name))[1] = (SELECT auth.uid())::text);
CREATE POLICY "Provider can update own Service Images" ON storage.objects
    FOR UPDATE TO authenticated
    USING (bucket_id = 'service-images' AND owner_id = (SELECT auth.uid())::text)
    WITH CHECK (bucket_id = 'service-images' AND (storage.foldername(name))[1] = (SELECT auth.uid())::text);
CREATE POLICY "Provider can delete own Service Images" ON storage.objects
    FOR DELETE TO authenticated
    USING (bucket_id = 'service-images' AND owner_id = (SELECT auth.uid())::text);
