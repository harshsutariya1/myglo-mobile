-- Background jobs and the Stripe event log.
--
-- Anything that has to reach an outside service after a database change
-- (capturing or refunding a payment, paying a provider, banning a suspended
-- account, alerting the admins) is queued here in the same transaction as the
-- change, then carried out by the jobs-worker Edge Function. That keeps the
-- database the single source of truth: a booking can't move on while its
-- money stays behind, because the job only exists if the change committed,
-- and a failed call is retried instead of lost.
--
-- Pipeline
--   RPC -> private.enqueue_job (same transaction)
--     -> pg_net POST /functions/v1/jobs-worker (after commit)
--     -> worker claims the job (FOR UPDATE SKIP LOCKED), calls the service
--        with the job's idempotency key, records the outcome.
--   A pg_cron sweeper re-dispatches anything due (retries with backoff) and
--   recovers claims from a worker that died.
--
-- The worker trusts nothing in the request except job ids, and the request
-- must also carry the jobs_worker_secret (Vault, generated below), which the
-- worker checks through check_jobs_worker_secret(). Amounts, accounts and
-- targets always come from the job row the database wrote.
--
-- Stripe webhooks are recorded in private.stripe_events so a redelivered
-- event is processed once.

-- ---------------------------------------------------------------------------
-- 1. Jobs.
-- ---------------------------------------------------------------------------

CREATE TABLE private.jobs (
    id               uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    kind             text        NOT NULL,
    -- Unique per piece of work (e.g. 'refund:<refund id>'); also sent to
    -- Stripe as its Idempotency-Key, so a retried job can't act twice.
    idempotency_key  text        NOT NULL,
    payload          jsonb       NOT NULL DEFAULT '{}'::jsonb,
    booking_id       uuid        REFERENCES public.bookings (id) ON DELETE SET NULL,
    status           text        NOT NULL DEFAULT 'pending',
    attempts         smallint    NOT NULL DEFAULT 0,
    max_attempts     smallint    NOT NULL DEFAULT 8,
    next_attempt_at  timestamptz NOT NULL DEFAULT now(),
    last_error       text,
    result           jsonb,
    completed_at     timestamptz,
    created_at       timestamptz NOT NULL DEFAULT now(),
    updated_at       timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT jobs_idempotency_key_unique UNIQUE (idempotency_key),
    CONSTRAINT jobs_kind CHECK (kind IN ('noop', 'admin_alert')),
    CONSTRAINT jobs_status CHECK (
        status IN ('pending', 'processing', 'succeeded', 'retry', 'failed', 'cancelled')),
    CONSTRAINT jobs_key_length CHECK (char_length(idempotency_key) BETWEEN 1 AND 200),
    CONSTRAINT jobs_attempts CHECK (attempts >= 0 AND max_attempts BETWEEN 1 AND 20)
);

COMMENT ON TABLE private.jobs IS
    'Outbox of calls to outside services (Stripe, Auth admin, email). Written by RPCs, run by the jobs-worker Edge Function.';

CREATE INDEX jobs_due_idx ON private.jobs (next_attempt_at)
    WHERE status IN ('pending', 'retry', 'processing');
CREATE INDEX jobs_booking_idx ON private.jobs (booking_id) WHERE booking_id IS NOT NULL;
CREATE INDEX jobs_failed_idx ON private.jobs (updated_at DESC) WHERE status = 'failed';

-- Queues a job and returns its id. Idempotent on p_key: queueing the same
-- work twice returns the existing job.
CREATE FUNCTION private.enqueue_job(
    p_kind       text,
    p_key        text,
    p_payload    jsonb       DEFAULT '{}'::jsonb,
    p_booking_id uuid        DEFAULT NULL,
    p_run_at     timestamptz DEFAULT NULL)
RETURNS uuid
LANGUAGE plpgsql
SET search_path TO ''
AS $function$
DECLARE
    v_id uuid;
BEGIN
    INSERT INTO private.jobs (kind, idempotency_key, payload, booking_id, next_attempt_at)
    VALUES (p_kind, p_key, coalesce(p_payload, '{}'::jsonb), p_booking_id, coalesce(p_run_at, now()))
    ON CONFLICT (idempotency_key) DO NOTHING
    RETURNING id INTO v_id;

    IF v_id IS NULL THEN
        SELECT j.id INTO v_id FROM private.jobs j WHERE j.idempotency_key = p_key;
    END IF;
    RETURN v_id;
END;
$function$;

-- ---------------------------------------------------------------------------
-- 2. Dispatch to the worker.
-- ---------------------------------------------------------------------------

-- The worker's shared secret lives only in Vault; it is generated here so it
-- never appears in the repo or in a chat.
DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM vault.secrets WHERE name = 'jobs_worker_secret') THEN
        PERFORM vault.create_secret(
            encode(extensions.gen_random_bytes(32), 'hex'),
            'jobs_worker_secret',
            'Shared secret the jobs-worker Edge Function checks on every call');
    END IF;
END;
$do$;

-- Asks the worker to run the given jobs (or everything due). Fire-and-forget:
-- pg_net sends the request after the transaction commits and never blocks or
-- fails the caller. Reuses the project URL and gateway key already in Vault
-- for send-notifications.
CREATE FUNCTION private.dispatch_jobs(p_job_ids uuid[] DEFAULT NULL)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
    v_url    text;
    v_key    text;
    v_secret text;
BEGIN
    SELECT decrypted_secret INTO v_url FROM vault.decrypted_secrets WHERE name = 'project_url';
    SELECT decrypted_secret INTO v_key FROM vault.decrypted_secrets WHERE name = 'notifications_function_key';
    SELECT decrypted_secret INTO v_secret FROM vault.decrypted_secrets WHERE name = 'jobs_worker_secret';
    IF v_url IS NULL OR v_key IS NULL OR v_secret IS NULL THEN
        RETURN;
    END IF;

    PERFORM net.http_post(
        url := rtrim(v_url, '/') || '/functions/v1/jobs-worker',
        headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'Authorization', 'Bearer ' || v_key,
            'apikey', v_key,
            'x-myglo-worker-secret', v_secret),
        body := CASE
            WHEN p_job_ids IS NULL THEN '{}'::jsonb
            ELSE jsonb_build_object('job_ids', to_jsonb(p_job_ids))
        END,
        timeout_milliseconds := 30000);
EXCEPTION
    WHEN OTHERS THEN
        -- The sweeper retries; the caller's change must never fail here.
        RAISE WARNING 'job dispatch failed: %', SQLERRM;
END;
$function$;

CREATE FUNCTION private.on_jobs_inserted()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
    v_due uuid[];
BEGIN
    SELECT array_agg(id) INTO v_due FROM new_rows WHERE next_attempt_at <= now();
    IF v_due IS NOT NULL THEN
        PERFORM private.dispatch_jobs(v_due);
    END IF;
    RETURN NULL;
END;
$function$;

CREATE TRIGGER jobs_dispatch
    AFTER INSERT ON private.jobs
    REFERENCING NEW TABLE AS new_rows
    FOR EACH STATEMENT EXECUTE FUNCTION private.on_jobs_inserted();

-- ---------------------------------------------------------------------------
-- 3. Worker API (service role only).
-- ---------------------------------------------------------------------------

-- Whether the secret the worker received is the one in Vault.
CREATE FUNCTION public.check_jobs_worker_secret(p_secret text)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO ''
AS $function$
    SELECT coalesce(p_secret, '') <> ''
       AND EXISTS (
           SELECT 1 FROM vault.decrypted_secrets
           WHERE name = 'jobs_worker_secret' AND decrypted_secret = p_secret);
$function$;

-- Claims due jobs: marks them processing and returns them.
CREATE FUNCTION public.claim_jobs(
    p_job_ids uuid[]  DEFAULT NULL,
    p_limit   integer DEFAULT 10)
RETURNS TABLE (
    job_id          uuid,
    kind            text,
    idempotency_key text,
    payload         jsonb,
    booking_id      uuid,
    attempt         smallint)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
BEGIN
    RETURN QUERY
    WITH due AS (
        SELECT j.id
        FROM private.jobs j
        WHERE j.status IN ('pending', 'retry')
          AND j.next_attempt_at <= now()
          AND (p_job_ids IS NULL OR j.id = ANY (p_job_ids))
        ORDER BY j.next_attempt_at, j.created_at
        LIMIT least(greatest(coalesce(p_limit, 10), 1), 50)
        FOR UPDATE SKIP LOCKED
    )
    UPDATE private.jobs j
    SET status = 'processing', attempts = j.attempts + 1, updated_at = now()
    FROM due
    WHERE j.id = due.id
    RETURNING j.id, j.kind, j.idempotency_key, j.payload, j.booking_id, j.attempts;
END;
$function$;

-- Records the outcome of a claimed job. p_outcome:
--   succeeded - done (p_result is kept for the audit trail);
--   retry     - transient failure, tried again with backoff (1, 2, 4 … 60
--               minutes), failed after max_attempts;
--   failed    - permanent failure; the admins are alerted.
CREATE FUNCTION public.complete_job(
    p_job_id  uuid,
    p_outcome text,
    p_error   text  DEFAULT NULL,
    p_result  jsonb DEFAULT NULL)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
    v_job private.jobs;
BEGIN
    IF p_outcome NOT IN ('succeeded', 'retry', 'failed') THEN
        RAISE EXCEPTION 'invalid_request' USING ERRCODE = '22023';
    END IF;

    UPDATE private.jobs j
    SET status = CASE
                     WHEN p_outcome = 'retry' AND j.attempts >= j.max_attempts THEN 'failed'
                     ELSE p_outcome
                 END,
        next_attempt_at = CASE
                              WHEN p_outcome = 'retry'
                                  THEN now() + make_interval(mins => least(power(2, j.attempts - 1)::integer, 60))
                              ELSE j.next_attempt_at
                          END,
        last_error = left(p_error, 1000),
        result = coalesce(p_result, j.result),
        completed_at = CASE WHEN p_outcome IN ('succeeded', 'failed') THEN now() ELSE j.completed_at END,
        updated_at = now()
    WHERE j.id = p_job_id
      AND j.status = 'processing'
    RETURNING j.* INTO v_job;

    IF NOT FOUND THEN
        RETURN NULL;
    END IF;

    PERFORM private.on_job_finished(v_job);
    RETURN v_job.status;
END;
$function$;

-- Hook for what happens after a job settles. Later migrations replace it to
-- react to failed money jobs; for now a failed job only alerts the admins
-- (never for a failed alert, which would loop).
CREATE FUNCTION private.on_job_finished(p_job private.jobs)
RETURNS void
LANGUAGE plpgsql
SET search_path TO ''
AS $function$
BEGIN
    IF p_job.status = 'failed' AND p_job.kind <> 'admin_alert' THEN
        PERFORM private.enqueue_job(
            'admin_alert',
            'alert:job_failed:' || p_job.id,
            jsonb_build_object(
                'severity', 'high',
                'subject', 'Background job failed: ' || p_job.kind,
                'body', 'Job ' || p_job.id || ' (' || p_job.kind || ') failed after '
                        || p_job.attempts || ' attempts: ' || coalesce(p_job.last_error, 'no error recorded'),
                'job_id', p_job.id,
                'booking_id', p_job.booking_id));
    END IF;
END;
$function$;

-- ---------------------------------------------------------------------------
-- 4. Sweeper.
-- ---------------------------------------------------------------------------

CREATE FUNCTION private.sweep_jobs()
RETURNS void
LANGUAGE plpgsql
SET search_path TO ''
AS $function$
BEGIN
    -- A worker that died mid-call gets its claim back. Stripe calls carry
    -- idempotency keys, so running the job again can't act twice.
    UPDATE private.jobs
    SET status = 'retry', updated_at = now()
    WHERE status = 'processing'
      AND updated_at < now() - interval '10 minutes';

    IF EXISTS (
        SELECT 1 FROM private.jobs
        WHERE status IN ('pending', 'retry') AND next_attempt_at <= now()) THEN
        PERFORM private.dispatch_jobs(NULL);
    END IF;
END;
$function$;

SELECT cron.schedule('myglo-jobs-sweep', '* * * * *', 'SELECT private.sweep_jobs();');

-- ---------------------------------------------------------------------------
-- 5. Stripe event log.
-- ---------------------------------------------------------------------------

CREATE TABLE private.stripe_events (
    id            text        PRIMARY KEY,
    type          text        NOT NULL,
    livemode      boolean     NOT NULL,
    -- Connected account the event came from (Connect events only).
    account       text,
    source        text        NOT NULL,
    received_at   timestamptz NOT NULL DEFAULT now(),
    processed_at  timestamptz,
    attempts      smallint    NOT NULL DEFAULT 0,
    last_error    text,
    CONSTRAINT stripe_events_source CHECK (source IN ('platform', 'connect', 'v2'))
);

COMMENT ON TABLE private.stripe_events IS
    'Every Stripe webhook event received, so redeliveries are processed once.';

CREATE INDEX stripe_events_unprocessed_idx ON private.stripe_events (received_at)
    WHERE processed_at IS NULL;

-- Records an incoming event. Returns true when it still needs processing
-- (new, or an earlier attempt failed), false when it was already processed.
CREATE FUNCTION public.begin_stripe_event(
    p_id       text,
    p_type     text,
    p_livemode boolean,
    p_account  text,
    p_source   text)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
    v_processed timestamptz;
BEGIN
    INSERT INTO private.stripe_events (id, type, livemode, account, source, attempts)
    VALUES (p_id, p_type, p_livemode, p_account, p_source, 1)
    ON CONFLICT (id) DO UPDATE
        SET attempts = private.stripe_events.attempts + 1
    RETURNING processed_at INTO v_processed;
    RETURN v_processed IS NULL;
END;
$function$;

-- Marks an event processed, or records why processing failed (Stripe then
-- redelivers it, because the webhook answers with an error).
CREATE FUNCTION public.finish_stripe_event(p_id text, p_error text DEFAULT NULL)
RETURNS void
LANGUAGE sql
SECURITY DEFINER
SET search_path TO ''
AS $function$
    UPDATE private.stripe_events
    SET processed_at = CASE WHEN p_error IS NULL THEN now() END,
        last_error = left(p_error, 1000)
    WHERE id = p_id;
$function$;

-- ---------------------------------------------------------------------------
-- 6. Privileges.
-- ---------------------------------------------------------------------------

REVOKE ALL ON private.jobs, private.stripe_events FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION private.enqueue_job(text, text, jsonb, uuid, timestamptz) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION private.dispatch_jobs(uuid[]) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION private.on_jobs_inserted() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION private.on_job_finished(private.jobs) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION private.sweep_jobs() FROM PUBLIC, anon, authenticated;

REVOKE ALL ON FUNCTION public.check_jobs_worker_secret(text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.claim_jobs(uuid[], integer) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.complete_job(uuid, text, text, jsonb) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.begin_stripe_event(text, text, boolean, text, text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.finish_stripe_event(text, text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.check_jobs_worker_secret(text) TO service_role;
GRANT EXECUTE ON FUNCTION public.claim_jobs(uuid[], integer) TO service_role;
GRANT EXECUTE ON FUNCTION public.complete_job(uuid, text, text, jsonb) TO service_role;
GRANT EXECUTE ON FUNCTION public.begin_stripe_event(text, text, boolean, text, text) TO service_role;
GRANT EXECUTE ON FUNCTION public.finish_stripe_event(text, text) TO service_role;
