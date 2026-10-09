-- Fixes cover photo uploads failing with "infinite recursion detected in
-- policy" (42P17): the upload policy from 20261009130000 counted rows in
-- storage.objects from inside a policy on storage.objects, which Postgres
-- refuses. The checks now run in a SECURITY DEFINER function, which reads
-- the table without re-applying its policies.

CREATE OR REPLACE FUNCTION public.can_upload_cover_photo()
 RETURNS boolean
 LANGUAGE sql
 STABLE
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
    -- Providers only, with a cap so their folder can't grow without bound
    -- (five slots plus room for in-flight replacements).
    SELECT EXISTS (
               SELECT 1 FROM public.profiles pr
               WHERE pr.id = (SELECT auth.uid()) AND pr.role = 'provider')
           AND (SELECT count(*) FROM storage.objects o
                WHERE o.bucket_id = 'cover-photos'
                  AND (storage.foldername(o.name))[1] = (SELECT auth.uid())::text) < 12;
$function$;

REVOKE ALL ON FUNCTION public.can_upload_cover_photo() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.can_upload_cover_photo() TO authenticated;

DROP POLICY "Provider can upload Cover Photos" ON storage.objects;

CREATE POLICY "Provider can upload Cover Photos" ON storage.objects
    FOR INSERT TO authenticated
    WITH CHECK (
        bucket_id = 'cover-photos'
        AND (storage.foldername(name))[1] = (SELECT auth.uid())::text
        AND (SELECT public.can_upload_cover_photo()));
