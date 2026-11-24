-- Blocking: anyone can block another account (App Store guideline 1.2 for
-- apps with user content, and Google Play's UGC policy).
--
-- Blocking works both ways between the two accounts, and the person blocked
-- isn't told:
--   * neither sees the other's posts or comments (feeds, post pages, comment
--     lists, profile grids), so neither can like or comment on them;
--   * neither can follow the other, and existing follows between them end;
--   * a client and a provider who blocked each other can't make new
--     bookings together, and the provider leaves the client's search, map
--     and home list. Bookings they already have carry on, so nobody is left
--     without an appointment or a payout; either side can cancel as usual.
-- Unblocking undoes all of it except the ended follows.
--
-- Builds on 20261112120000 (private.is_unlisted, the feeds' visibility
-- patches).

-- ---------------------------------------------------------------------------
-- 1. Who blocked whom. Written only through block_user / unblock_user.
-- ---------------------------------------------------------------------------

CREATE TABLE public.user_blocks (
    blocker_id uuid        NOT NULL REFERENCES public.profiles (id) ON DELETE CASCADE,
    blocked_id uuid        NOT NULL REFERENCES public.profiles (id) ON DELETE CASCADE,
    created_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (blocker_id, blocked_id),
    CONSTRAINT user_blocks_not_self CHECK (blocker_id <> blocked_id)
);

-- The reverse lookup ("has anyone blocked me").
CREATE INDEX user_blocks_blocked_idx ON public.user_blocks (blocked_id, blocker_id);

COMMENT ON TABLE public.user_blocks IS
    'Accounts a user has blocked. Written through block_user / unblock_user; each user reads only their own blocks.';

ALTER TABLE public.user_blocks ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.user_blocks FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.user_blocks TO authenticated;

-- Only the blocker sees a block: the blocked person can't find out who
-- blocked them.
CREATE POLICY "Users see the blocks they made" ON public.user_blocks
    FOR SELECT TO authenticated
    USING ((SELECT auth.uid()) = blocker_id);

-- Whether a and b blocked each other, either way round.
CREATE FUNCTION private.is_blocked_between(p_a uuid, p_b uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SET search_path TO ''
AS $function$
    SELECT p_a IS NOT NULL AND p_b IS NOT NULL AND p_a <> p_b
       AND EXISTS (SELECT 1 FROM public.user_blocks ub
                   WHERE (ub.blocker_id = p_a AND ub.blocked_id = p_b)
                      OR (ub.blocker_id = p_b AND ub.blocked_id = p_a));
$function$;

REVOKE ALL ON FUNCTION private.is_blocked_between(uuid, uuid) FROM PUBLIC, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 2. Row level security needs the check as the signed-in user. It lives in
--    its own schema, which the API doesn't expose: callable from policies,
--    not as an RPC (so nobody can ask "has X blocked me").
-- ---------------------------------------------------------------------------

CREATE SCHEMA IF NOT EXISTS rls;
REVOKE ALL ON SCHEMA rls FROM PUBLIC;
GRANT USAGE ON SCHEMA rls TO authenticated;

CREATE FUNCTION rls.is_blocked_with(p_other uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO ''
AS $function$
    SELECT private.is_blocked_between((SELECT auth.uid()), p_other);
$function$;

REVOKE ALL ON FUNCTION rls.is_blocked_with(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rls.is_blocked_with(uuid) TO authenticated;

-- Restrictive: applies on top of every existing policy. Posts and comments
-- hidden this way also can't be liked or commented on (those policies and
-- set_post_like need the post to be visible).
CREATE POLICY "Blocked accounts don't see each other's posts" ON public.posts
    AS RESTRICTIVE FOR SELECT TO authenticated
    USING (NOT rls.is_blocked_with(author_id));

CREATE POLICY "Blocked accounts don't see each other's comments" ON public.comments
    AS RESTRICTIVE FOR SELECT TO authenticated
    USING (NOT rls.is_blocked_with(author_id));

CREATE POLICY "Blocked accounts can't follow each other" ON public.follows
    AS RESTRICTIVE FOR INSERT TO authenticated
    WITH CHECK (NOT rls.is_blocked_with(following_id));

-- ---------------------------------------------------------------------------
-- 3. Block, unblock, list.
-- ---------------------------------------------------------------------------

CREATE FUNCTION public.block_user(p_user_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
    v_uid uuid := auth.uid();
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'not_authenticated' USING ERRCODE = '42501';
    END IF;
    IF p_user_id IS NULL OR p_user_id = v_uid THEN
        RAISE EXCEPTION 'invalid_block' USING ERRCODE = '22023';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = v_uid) THEN
        RAISE EXCEPTION 'not_authenticated' USING ERRCODE = '42501';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = p_user_id) THEN
        RAISE EXCEPTION 'user_not_found' USING ERRCODE = 'P0002';
    END IF;
    -- A runaway client can't fill the table.
    IF (SELECT count(*) FROM public.user_blocks ub WHERE ub.blocker_id = v_uid) >= 1000 THEN
        RAISE EXCEPTION 'too_many_blocks' USING ERRCODE = 'P0001';
    END IF;

    INSERT INTO public.user_blocks (blocker_id, blocked_id)
    VALUES (v_uid, p_user_id)
    ON CONFLICT (blocker_id, blocked_id) DO NOTHING;

    -- Follows between them end, both ways (the follow-count trigger keeps
    -- the counts right).
    DELETE FROM public.follows f
    WHERE (f.follower_id = v_uid AND f.following_id = p_user_id)
       OR (f.follower_id = p_user_id AND f.following_id = v_uid);
END;
$function$;

COMMENT ON FUNCTION public.block_user(uuid) IS
    'Blocks an account for the caller (both ways: posts, comments, follows and new bookings). Idempotent.';

CREATE FUNCTION public.unblock_user(p_user_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
    v_uid uuid := auth.uid();
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'not_authenticated' USING ERRCODE = '42501';
    END IF;
    DELETE FROM public.user_blocks ub WHERE ub.blocker_id = v_uid AND ub.blocked_id = p_user_id;
END;
$function$;

-- The caller's blocked accounts, newest first, with what the app shows.
CREATE FUNCTION public.list_blocked_users()
RETURNS TABLE(user_id uuid, display_name text, avatar_url text, role text, blocked_at timestamptz)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
    v_uid uuid := auth.uid();
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'not_authenticated' USING ERRCODE = '42501';
    END IF;
    RETURN QUERY
    SELECT ub.blocked_id,
           coalesce(
               CASE WHEN p.role = 'provider' THEN nullif(btrim(p.provider_name), '') END,
               nullif(btrim(concat_ws(' ', btrim(p.first_name), btrim(p.last_name))), ''),
               'Myglo member'),
           p.profile_pic,
           p.role,
           ub.created_at
    FROM public.user_blocks ub
    JOIN public.profiles p ON p.id = ub.blocked_id
    WHERE ub.blocker_id = v_uid
    ORDER BY ub.created_at DESC;
END;
$function$;

REVOKE ALL ON FUNCTION public.block_user(uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.unblock_user(uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.list_blocked_users() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.block_user(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.unblock_user(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_blocked_users() TO authenticated;

-- ---------------------------------------------------------------------------
-- 4. The security-definer reads, which skip row level security, get the
--    same rule. Each patch must match exactly once, or the migration fails.
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

-- Discover feeds.
SELECT pg_temp.patch_function('public.nearby_posts(double precision, timestamptz, integer)',
    'AND p.author_id <> v_uid',
    'AND p.author_id <> v_uid AND NOT private.is_blocked_between(v_uid, p.author_id)');
SELECT pg_temp.patch_function('public.posts_beyond_nearby(double precision, timestamptz, integer)',
    'AND p.author_id <> v_uid',
    'AND p.author_id <> v_uid AND NOT private.is_blocked_between(v_uid, p.author_id)');

-- Provider search and the map (which also feeds the client home list).
SELECT pg_temp.patch_function('public.search_providers(text, double precision, double precision, integer)',
    'NOT private.is_unlisted(pr.id)',
    'NOT private.is_unlisted(pr.id) AND NOT private.is_blocked_between(auth.uid(), pr.id)');
SELECT pg_temp.patch_function('public.map_providers(double precision, double precision, double precision, integer)',
    'NOT private.is_unlisted(pr.id)',
    'NOT private.is_unlisted(pr.id) AND NOT private.is_blocked_between(auth.uid(), pr.id)');

-- New bookings between them are refused like any provider not taking
-- bookings (the client isn't told they were blocked).
SELECT pg_temp.patch_function(
    'public.create_booking(uuid, uuid, uuid[], timestamptz, text, text, integer, text, jsonb, double precision, double precision, text, text)',
    'private.is_unlisted(p_provider_id)',
    'private.is_unlisted(p_provider_id) OR private.is_blocked_between(auth.uid(), p_provider_id)');
SELECT pg_temp.patch_function('private.check_booking_parties()',
    'private.is_unlisted(NEW.provider_id)',
    'private.is_unlisted(NEW.provider_id) OR private.is_blocked_between(NEW.client_id, NEW.provider_id)');
