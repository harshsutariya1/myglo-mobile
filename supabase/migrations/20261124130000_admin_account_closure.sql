-- Admins close an account on its owner's request (providers can't delete
-- their own account in the app; anyone may email support).
--
-- The delete-account Edge Function runs the closure for an admin:
--   1. admin_begin_account_closure(user, reason), as the admin: needs a
--      fresh two-factor code and a reason, refuses admin accounts and
--      anything that blocks a deletion, and returns what the function needs.
--   2. The function checks the provider's Stripe balance is empty.
--   3. delete_account(user, p_by_admin => true), as the service role: the
--      same deletion as a self-deletion, re-checked under lock. A suspended
--      account can be closed this way (it can't close itself).
--   4. admin_record_account_closure(user, reason), as the admin: the audit
--      entry, written only once the account is really gone.

-- ---------------------------------------------------------------------------
-- 1. What blocks a closure by an admin: what blocks any deletion, except a
--    suspension.
-- ---------------------------------------------------------------------------

CREATE FUNCTION private.admin_closure_blockers(p_user_id uuid)
RETURNS jsonb
LANGUAGE sql
STABLE
SET search_path TO ''
AS $function$
    SELECT coalesce(jsonb_agg(b ORDER BY ord) FILTER (WHERE b->>'code' <> 'account_suspended'), '[]'::jsonb)
    FROM jsonb_array_elements(private.account_deletion_blockers(p_user_id)) WITH ORDINALITY AS t(b, ord);
$function$;

REVOKE ALL ON FUNCTION private.admin_closure_blockers(uuid) FROM PUBLIC, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 2. delete_account learns the admin path. Same body; only the blocker
--    check differs. The old one-argument version is replaced, and callers
--    that pass only p_user_id (the deployed function) keep working.
-- ---------------------------------------------------------------------------

DO $migrate$
DECLARE
    v_def text := pg_get_functiondef('public.delete_account(uuid)'::regprocedure);
BEGIN
    IF (length(v_def) - length(replace(v_def, 'public.delete_account(p_user_id uuid)', ''))) / length('public.delete_account(p_user_id uuid)') <> 1
       OR (length(v_def) - length(replace(v_def, 'v_blockers := private.account_deletion_blockers(p_user_id);', '')))
          / length('v_blockers := private.account_deletion_blockers(p_user_id);') <> 1 THEN
        RAISE EXCEPTION 'delete_account has changed; update this migration';
    END IF;
    v_def := replace(v_def,
        'public.delete_account(p_user_id uuid)',
        'public.delete_account(p_user_id uuid, p_by_admin boolean DEFAULT false)');
    v_def := replace(v_def,
        'v_blockers := private.account_deletion_blockers(p_user_id);',
        'v_blockers := CASE WHEN coalesce(p_by_admin, false)
        THEN private.admin_closure_blockers(p_user_id)
        ELSE private.account_deletion_blockers(p_user_id) END;');
    DROP FUNCTION public.delete_account(uuid);
    EXECUTE v_def;
END;
$migrate$;

COMMENT ON FUNCTION public.delete_account(uuid, boolean) IS
    'Deletes an account after begin_account_deletion or admin_begin_account_closure passed (service role only, from the delete-account function).';

REVOKE ALL ON FUNCTION public.delete_account(uuid, boolean) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.delete_account(uuid, boolean) TO service_role;

-- ---------------------------------------------------------------------------
-- 3. The admin's two steps.
-- ---------------------------------------------------------------------------

CREATE FUNCTION public.admin_begin_account_closure(p_user_id uuid, p_reason text)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
    v_blockers jsonb;
BEGIN
    PERFORM private.require_admin(true);
    PERFORM private.require_reason(p_reason);
    IF p_user_id IS NULL OR NOT EXISTS (SELECT 1 FROM auth.users u WHERE u.id = p_user_id) THEN
        RAISE EXCEPTION 'account_not_found' USING ERRCODE = 'P0002';
    END IF;

    v_blockers := private.admin_closure_blockers(p_user_id);
    IF jsonb_array_length(v_blockers) > 0 THEN
        RAISE EXCEPTION 'account_deletion_blocked' USING ERRCODE = 'P0001', DETAIL = v_blockers::text;
    END IF;

    RETURN jsonb_build_object(
        'user_id', p_user_id,
        'email', (SELECT u.email FROM auth.users u WHERE u.id = p_user_id),
        'role', (SELECT p.role FROM public.profiles p WHERE p.id = p_user_id),
        'stripe_account_id', (
            SELECT a.stripe_account_id FROM private.provider_payout_accounts a
            WHERE a.provider_id = p_user_id AND a.closed_at IS NULL));
END;
$function$;

COMMENT ON FUNCTION public.admin_begin_account_closure(uuid, text) IS
    'Admin, fresh two-factor: checks an account can be closed on its owner''s request. Called by the delete-account function.';

CREATE FUNCTION public.admin_record_account_closure(p_user_id uuid, p_reason text, p_role text DEFAULT NULL)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
BEGIN
    PERFORM private.require_admin();
    -- Only for an account that is really gone.
    IF EXISTS (SELECT 1 FROM auth.users u WHERE u.id = p_user_id) THEN
        RAISE EXCEPTION 'account_still_exists' USING ERRCODE = 'P0001';
    END IF;
    PERFORM private.audit('account.close', 'user', p_user_id::text, private.require_reason(p_reason),
        jsonb_build_object('role', p_role), NULL);
END;
$function$;

REVOKE ALL ON FUNCTION public.admin_begin_account_closure(uuid, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.admin_record_account_closure(uuid, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_begin_account_closure(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_record_account_closure(uuid, text, text) TO authenticated;
