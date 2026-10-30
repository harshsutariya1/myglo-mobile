-- Checks for the jobs outbox (20261031120000_jobs_and_stripe_events).
--
-- There is no local Supabase stack: run this against the project inside a
-- transaction that is rolled back, e.g. through the Supabase MCP execute_sql
-- tool or the SQL editor:
--
--   BEGIN;
--   \i supabase/tests/jobs.sql      -- or paste the file
--   ROLLBACK;
--
-- Every check raises an exception on failure, so a clean run ends with the
-- final NOTICE. Nothing is left behind once the transaction rolls back.

DO $test$
DECLARE
    v_id      uuid;
    v_again   uuid;
    v_claimed integer;
    v_status  text;
    v_job     private.jobs;
BEGIN
    -- Enqueue is idempotent on the key.
    v_id := private.enqueue_job('noop', 'test:jobs:1', '{"n": 1}');
    v_again := private.enqueue_job('noop', 'test:jobs:1', '{"n": 2}');
    IF v_id IS DISTINCT FROM v_again THEN
        RAISE EXCEPTION 'enqueue_job should return the existing job for a repeated key';
    END IF;
    IF (SELECT payload->>'n' FROM private.jobs WHERE id = v_id) <> '1' THEN
        RAISE EXCEPTION 'a repeated key must not overwrite the first payload';
    END IF;

    -- Unknown kinds are rejected.
    BEGIN
        PERFORM private.enqueue_job('launch_rockets', 'test:jobs:bad');
        RAISE EXCEPTION 'unknown job kind was accepted';
    EXCEPTION WHEN check_violation THEN
        NULL;
    END;

    -- Claim marks it processing and counts the attempt; a second claim gets nothing.
    SELECT count(*) INTO v_claimed FROM public.claim_jobs(ARRAY[v_id]);
    IF v_claimed <> 1 THEN RAISE EXCEPTION 'expected to claim 1 job, got %', v_claimed; END IF;
    SELECT count(*) INTO v_claimed FROM public.claim_jobs(ARRAY[v_id]);
    IF v_claimed <> 0 THEN RAISE EXCEPTION 'a processing job was claimed twice'; END IF;

    -- Retry schedules a backoff.
    v_status := public.complete_job(v_id, 'retry', 'timeout');
    SELECT * INTO v_job FROM private.jobs WHERE id = v_id;
    IF v_status <> 'retry' OR v_job.next_attempt_at <= now() THEN
        RAISE EXCEPTION 'retry should reschedule into the future (status %, next %)', v_status, v_job.next_attempt_at;
    END IF;

    -- Not due yet, so it can't be claimed.
    SELECT count(*) INTO v_claimed FROM public.claim_jobs(ARRAY[v_id]);
    IF v_claimed <> 0 THEN RAISE EXCEPTION 'a job was claimed before its retry time'; END IF;

    -- Completing a job that isn't processing does nothing.
    IF public.complete_job(v_id, 'succeeded') IS NOT NULL THEN
        RAISE EXCEPTION 'complete_job changed a job that was not processing';
    END IF;

    -- Exhausting the attempts fails the job and alerts the admins.
    UPDATE private.jobs SET next_attempt_at = now(), attempts = max_attempts - 1 WHERE id = v_id;
    PERFORM public.claim_jobs(ARRAY[v_id]);
    v_status := public.complete_job(v_id, 'retry', 'still timing out');
    IF v_status <> 'failed' THEN RAISE EXCEPTION 'expected failed after max attempts, got %', v_status; END IF;
    IF NOT EXISTS (SELECT 1 FROM private.jobs WHERE idempotency_key = 'alert:job_failed:' || v_id AND kind = 'admin_alert') THEN
        RAISE EXCEPTION 'a failed job should queue an admin alert';
    END IF;

    -- A failed alert doesn't alert again.
    v_id := (SELECT id FROM private.jobs WHERE idempotency_key = 'alert:job_failed:' || v_id);
    PERFORM public.claim_jobs(ARRAY[v_id]);
    PERFORM public.complete_job(v_id, 'failed', 'no recipients');
    IF EXISTS (SELECT 1 FROM private.jobs WHERE idempotency_key = 'alert:job_failed:' || v_id) THEN
        RAISE EXCEPTION 'a failed admin alert must not queue another alert';
    END IF;

    -- A dead worker's claim is recovered by the sweeper.
    v_id := private.enqueue_job('noop', 'test:jobs:stuck');
    PERFORM public.claim_jobs(ARRAY[v_id]);
    UPDATE private.jobs SET updated_at = now() - interval '11 minutes' WHERE id = v_id;
    PERFORM private.sweep_jobs();
    IF (SELECT status FROM private.jobs WHERE id = v_id) <> 'retry' THEN
        RAISE EXCEPTION 'sweep_jobs should return stuck claims to retry';
    END IF;

    -- Stripe events are processed once.
    IF NOT public.begin_stripe_event('evt_test_1', 'payment_intent.succeeded', false, NULL, 'platform') THEN
        RAISE EXCEPTION 'a new event should need processing';
    END IF;
    PERFORM public.finish_stripe_event('evt_test_1', 'boom');
    IF NOT public.begin_stripe_event('evt_test_1', 'payment_intent.succeeded', false, NULL, 'platform') THEN
        RAISE EXCEPTION 'a failed event should be processed again';
    END IF;
    PERFORM public.finish_stripe_event('evt_test_1');
    IF public.begin_stripe_event('evt_test_1', 'payment_intent.succeeded', false, NULL, 'platform') THEN
        RAISE EXCEPTION 'a processed event must not be processed again';
    END IF;

    -- The worker secret check.
    IF public.check_jobs_worker_secret('wrong') OR public.check_jobs_worker_secret(NULL) THEN
        RAISE EXCEPTION 'check_jobs_worker_secret accepted a wrong secret';
    END IF;
    IF NOT public.check_jobs_worker_secret(
        (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'jobs_worker_secret')) THEN
        RAISE EXCEPTION 'check_jobs_worker_secret rejected the real secret';
    END IF;

    -- API roles can't reach any of it.
    IF has_function_privilege('authenticated', 'public.claim_jobs(uuid[], integer)', 'EXECUTE')
       OR has_function_privilege('anon', 'public.complete_job(uuid, text, text, jsonb)', 'EXECUTE')
       OR has_function_privilege('authenticated', 'public.check_jobs_worker_secret(text)', 'EXECUTE')
       OR has_table_privilege('authenticated', 'private.jobs', 'SELECT') THEN
        RAISE EXCEPTION 'jobs API is reachable by an app role';
    END IF;

    RAISE NOTICE 'jobs.sql: all checks passed';
END;
$test$;
