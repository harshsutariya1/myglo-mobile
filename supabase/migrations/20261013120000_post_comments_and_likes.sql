-- Comments on posts, and a faster, consistent like toggle.
--
-- Comments: signed-in users only, and only on posts they can see. 1–500
-- characters, no editing; authors delete their own, and a post's author can
-- remove any comment on it. A per-user rate limit stops floods. Before this,
-- anyone (even signed out) could read comments on hidden posts, and there was
-- no length limit.
--
-- Likes: `set_post_like` likes or unlikes and returns the post's new count in
-- the same round trip, so the app never shows a count older than its own
-- tap. `get_post_engagement` reads both counts plus the viewer's like at
-- once. Likes can only be added to posts the viewer can see, and a user's
-- likes are no longer readable by others (counts stay public).
--
-- Also closes a gap in post tagging: a client could create a post that tags
-- a provider with `tag_status = 'approved'` already set, skipping the
-- provider's approval.

-- ---------------------------------------------------------------------------
-- 1. Counters: never negative, and never null.
-- ---------------------------------------------------------------------------

ALTER TABLE public.posts
    ALTER COLUMN likes_count SET NOT NULL,
    ALTER COLUMN comments_count SET NOT NULL;

CREATE OR REPLACE FUNCTION public.update_post_likes_count()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE public.posts SET likes_count = likes_count + 1 WHERE id = NEW.post_id;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE public.posts SET likes_count = greatest(likes_count - 1, 0) WHERE id = OLD.post_id;
    END IF;
    RETURN NULL;
END;
$function$;

CREATE OR REPLACE FUNCTION public.update_post_comments_count()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE public.posts SET comments_count = comments_count + 1 WHERE id = NEW.post_id;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE public.posts SET comments_count = greatest(comments_count - 1, 0) WHERE id = OLD.post_id;
    END IF;
    RETURN NULL;
END;
$function$;

-- ---------------------------------------------------------------------------
-- 2. Comments.
-- ---------------------------------------------------------------------------

ALTER TABLE public.comments
    ALTER COLUMN created_at SET NOT NULL,
    ALTER COLUMN updated_at SET NOT NULL,
    ADD CONSTRAINT comments_content_length CHECK (char_length(content) BETWEEN 1 AND 500);

-- Listing a post's comments oldest first, keyset-paginated on (created_at, id).
DROP INDEX IF EXISTS public.idx_comments_post_id;
CREATE INDEX comments_post_created_idx ON public.comments (post_id, created_at, id);

-- The rate limit (and the author foreign key) look up by author and time.
DROP INDEX IF EXISTS public.idx_comments_author_id;
CREATE INDEX comments_author_created_idx ON public.comments (author_id, created_at DESC);

-- Trims the text, stamps the server time and enforces the rate limit.
CREATE FUNCTION private.before_comment_insert()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
BEGIN
    NEW.content := btrim(NEW.content);
    NEW.created_at := now();
    NEW.updated_at := now();
    IF (SELECT count(*) FROM public.comments c
        WHERE c.author_id = NEW.author_id AND c.created_at > now() - interval '1 minute') >= 10 THEN
        RAISE EXCEPTION 'comment_rate_limited' USING ERRCODE = 'P0001';
    END IF;
    RETURN NEW;
END;
$function$;

REVOKE ALL ON FUNCTION private.before_comment_insert() FROM PUBLIC;

CREATE TRIGGER before_comment_insert
    BEFORE INSERT ON public.comments
    FOR EACH ROW EXECUTE FUNCTION private.before_comment_insert();

DROP POLICY IF EXISTS "Comments viewable by everyone" ON public.comments;
DROP POLICY IF EXISTS "Users can insert own comments" ON public.comments;
DROP POLICY IF EXISTS "Users can update own comments" ON public.comments;
DROP POLICY IF EXISTS "Users can delete own comments" ON public.comments;

-- The subqueries run under the viewer's own posts policy, so a comment is
-- only as visible as its post.
CREATE POLICY "Comments on visible posts" ON public.comments
    FOR SELECT TO authenticated
    USING (EXISTS (SELECT 1 FROM public.posts p WHERE p.id = comments.post_id));

CREATE POLICY "Users comment on published posts" ON public.comments
    FOR INSERT TO authenticated
    WITH CHECK (
        (SELECT auth.uid()) = author_id
        AND EXISTS (
            SELECT 1 FROM public.posts p
            WHERE p.id = comments.post_id
              AND (p.tag_status = 'approved' OR p.author_id = (SELECT auth.uid())))
    );

CREATE POLICY "Authors and post owners delete comments" ON public.comments
    FOR DELETE TO authenticated
    USING (
        (SELECT auth.uid()) = author_id
        OR EXISTS (SELECT 1 FROM public.posts p WHERE p.id = comments.post_id AND p.author_id = (SELECT auth.uid()))
    );

REVOKE ALL ON public.comments FROM anon, authenticated;
GRANT SELECT, DELETE ON public.comments TO authenticated;
GRANT INSERT (id, post_id, author_id, content) ON public.comments TO authenticated;

-- One page of a post's comments, oldest first, with each author's public
-- name and photo. Runs as the caller, so the comments policy applies.
CREATE FUNCTION public.list_post_comments(
    p_post_id uuid,
    p_after timestamp with time zone DEFAULT NULL,
    p_after_id uuid DEFAULT NULL,
    p_limit integer DEFAULT 30)
 RETURNS TABLE(
    id uuid,
    post_id uuid,
    author_id uuid,
    author_name text,
    author_avatar_url text,
    author_role text,
    content text,
    created_at timestamp with time zone)
 LANGUAGE sql
 STABLE
 SET search_path TO ''
AS $function$
    SELECT c.id,
           c.post_id,
           c.author_id,
           coalesce(
               CASE WHEN pp.role = 'provider' THEN nullif(btrim(pp.provider_name), '') END,
               nullif(btrim(concat_ws(' ', btrim(pp.first_name), btrim(pp.last_name))), ''),
               nullif(btrim(pp.provider_name), ''),
               'Myglo member'),
           pp.profile_pic,
           pp.role,
           c.content,
           c.created_at
    FROM public.comments c
    LEFT JOIN public.public_profiles pp ON pp.id = c.author_id
    WHERE c.post_id = p_post_id
      AND (p_after IS NULL OR (c.created_at, c.id) > (p_after, coalesce(p_after_id, '00000000-0000-0000-0000-000000000000'::uuid)))
    ORDER BY c.created_at, c.id
    LIMIT least(greatest(coalesce(p_limit, 30), 1), 100);
$function$;

REVOKE ALL ON FUNCTION public.list_post_comments(uuid, timestamp with time zone, uuid, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_post_comments(uuid, timestamp with time zone, uuid, integer) TO authenticated;

-- ---------------------------------------------------------------------------
-- 3. Likes.
-- ---------------------------------------------------------------------------

DROP POLICY IF EXISTS "Likes viewable by everyone" ON public.likes;
DROP POLICY IF EXISTS "Users can insert own likes" ON public.likes;

CREATE POLICY "Users view own likes" ON public.likes
    FOR SELECT TO authenticated
    USING ((SELECT auth.uid()) = user_id);

CREATE POLICY "Users like visible posts" ON public.likes
    FOR INSERT TO authenticated
    WITH CHECK (
        (SELECT auth.uid()) = user_id
        AND EXISTS (SELECT 1 FROM public.posts p WHERE p.id = likes.post_id)
    );

REVOKE ALL ON public.likes FROM anon, authenticated;
GRANT SELECT, DELETE ON public.likes TO authenticated;
GRANT INSERT (post_id, user_id) ON public.likes TO authenticated;

-- Likes (p_liked = true) or unlikes the post as the caller and returns the
-- post's count afterwards. Idempotent: repeating either is a no-op.
CREATE FUNCTION public.set_post_like(p_post_id uuid, p_liked boolean)
 RETURNS TABLE(likes_count integer, liked boolean)
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
DECLARE
    v_uid uuid := auth.uid();
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'not_authenticated' USING ERRCODE = '42501';
    END IF;
    IF p_liked IS NULL THEN
        RAISE EXCEPTION 'invalid_like' USING ERRCODE = '22023';
    END IF;
    PERFORM 1 FROM public.posts p WHERE p.id = p_post_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'post_not_found' USING ERRCODE = 'P0002';
    END IF;

    IF p_liked THEN
        INSERT INTO public.likes (post_id, user_id) VALUES (p_post_id, v_uid)
        ON CONFLICT (post_id, user_id) DO NOTHING;
    ELSE
        DELETE FROM public.likes l WHERE l.post_id = p_post_id AND l.user_id = v_uid;
    END IF;

    RETURN QUERY SELECT p.likes_count, p_liked FROM public.posts p WHERE p.id = p_post_id;
END;
$function$;

REVOKE ALL ON FUNCTION public.set_post_like(uuid, boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.set_post_like(uuid, boolean) TO authenticated;

-- A post's current counts and whether the caller likes it. No row when the
-- post doesn't exist or isn't visible to the caller.
CREATE FUNCTION public.get_post_engagement(p_post_id uuid)
 RETURNS TABLE(likes_count integer, comments_count integer, liked boolean)
 LANGUAGE sql
 STABLE
 SET search_path TO ''
AS $function$
    SELECT p.likes_count,
           p.comments_count,
           EXISTS (SELECT 1 FROM public.likes l WHERE l.post_id = p.id AND l.user_id = (SELECT auth.uid()))
    FROM public.posts p
    WHERE p.id = p_post_id;
$function$;

REVOKE ALL ON FUNCTION public.get_post_engagement(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_post_engagement(uuid) TO authenticated;

-- ---------------------------------------------------------------------------
-- 4. Posts: a client's tag always starts pending.
-- ---------------------------------------------------------------------------

DROP POLICY IF EXISTS "Users can create posts" ON public.posts;

-- Checked after the BEFORE INSERT trigger, which approves untagged posts.
CREATE POLICY "Users can create posts" ON public.posts
    FOR INSERT TO authenticated
    WITH CHECK (
        (SELECT auth.uid()) = author_id
        AND (tagged_provider_id IS NULL OR tag_status = 'pending')
    );
