// Runs queued background jobs (private.jobs): Stripe payment, refund and
// transfer calls, Auth admin calls and admin alert emails.
//
// The database calls this function through pg_net right after a job is
// queued, and the myglo-jobs-sweep cron job calls it every minute for retries
// (see migration 20261031120000_jobs_and_stripe_events). Each call must carry
// the x-myglo-worker-secret header, checked against Vault.
//
// Jobs are claimed atomically (FOR UPDATE SKIP LOCKED), so two invocations
// never run the same job, and every outside call uses the job's idempotency
// key, so a job that's retried after a crash can't act twice. The request
// body is only `{ "job_ids": [...] }` (or `{}` for everything due): what each
// job does, and with what amounts, comes from the row the database wrote.
//
// Secrets: see _shared/stripe.ts, _shared/sentry.ts and admin_alert.ts.

import { json, UUID } from '../_shared/http.ts';
import { captureException } from '../_shared/sentry.ts';
import { RpcError, serviceRpc, supabaseConfigured } from '../_shared/supabase.ts';
import { sendAdminAlert } from './admin_alert.ts';
import { cancelPaymentIntent, capturePayment, refundPayment, reverseTransfer, transfer } from './payments.ts';
import { Job, JobHandler, JobResult, retry, succeeded } from './types.ts';

const FN = 'jobs-worker';
const BATCH_SIZE = 10;
/** Stop claiming new work well before the platform's request limit. */
const TIME_BUDGET_MS = 45_000;

const HANDLERS: Record<string, JobHandler> = {
  noop: () => Promise.resolve(succeeded()),
  admin_alert: sendAdminAlert,
  cancel_payment_intent: cancelPaymentIntent,
  capture_payment: capturePayment,
  refund_payment: refundPayment,
  transfer,
  reverse_transfer: reverseTransfer,
};

Deno.serve(async (req: Request) => {
  if (req.method !== 'POST') return json({ error: 'method_not_allowed' }, 405);
  if (!supabaseConfigured()) {
    await captureException(new Error('Supabase environment missing'), { fn: FN });
    return json({ error: 'misconfigured' }, 500);
  }

  const secret = req.headers.get('x-myglo-worker-secret') ?? '';
  try {
    if (!(await serviceRpc<boolean>('check_jobs_worker_secret', { p_secret: secret }))) {
      return json({ error: 'forbidden' }, 403);
    }
  } catch (error) {
    await captureException(error, { fn: FN, tags: { stage: 'auth' } });
    return json({ error: 'auth_check_failed' }, 500);
  }

  const ids = await requestedIds(req);
  const startedAt = Date.now();
  const results: { id: string; kind: string; outcome: string }[] = [];

  while (Date.now() - startedAt < TIME_BUDGET_MS) {
    let jobs: Job[];
    try {
      jobs = await serviceRpc<Job[]>('claim_jobs', { p_job_ids: ids, p_limit: BATCH_SIZE });
    } catch (error) {
      await captureException(error, { fn: FN, tags: { stage: 'claim' } });
      return json({ error: 'claim_failed', processed: results }, 500);
    }
    if (jobs.length === 0) break;

    results.push(...await Promise.all(jobs.map(run)));
    // Specific ids are a one-shot request; a sweep keeps going while work is due.
    if (ids) break;
  }

  return json({ processed: results.length, results });
});

async function run(job: Job): Promise<{ id: string; kind: string; outcome: string }> {
  const handler = HANDLERS[job.kind];
  let result: JobResult;
  if (!handler) {
    // Deployed code older than the database: try again once the new worker is live.
    result = retry(`no handler for job kind ${job.kind}`);
  } else {
    try {
      result = await handler(job);
    } catch (error) {
      result = retry(error instanceof Error ? error.message : String(error));
      // A refusal from our own database function is a bug, not a blip.
      if (error instanceof RpcError && error.isExpected) result = { outcome: 'failed', error: result.error };
      await captureException(error, {
        fn: FN,
        tags: { job_kind: job.kind },
        extra: { job_id: job.job_id, booking_id: job.booking_id, attempt: job.attempt },
      });
    }
  }

  try {
    const status = await serviceRpc<string | null>('complete_job', {
      p_job_id: job.job_id,
      p_outcome: result.outcome,
      p_error: result.error ?? null,
      p_result: result.result ?? null,
    });
    if (result.outcome !== 'succeeded') {
      console.warn(`${FN}: ${job.kind} ${job.job_id} ${status ?? result.outcome}: ${result.error ?? ''}`);
    }
    return { id: job.job_id, kind: job.kind, outcome: status ?? result.outcome };
  } catch (error) {
    // The claim lapses and the sweeper retries; idempotency keys make that safe.
    await captureException(error, { fn: FN, tags: { stage: 'complete', job_kind: job.kind }, extra: { job_id: job.job_id } });
    return { id: job.job_id, kind: job.kind, outcome: 'unrecorded' };
  }
}

/** Job ids from the body, or null to process everything due. */
async function requestedIds(req: Request): Promise<string[] | null> {
  try {
    const body = await req.json();
    if (Array.isArray(body?.job_ids)) {
      return body.job_ids.filter((id: unknown) => typeof id === 'string' && UUID.test(id)).slice(0, 50);
    }
  } catch {
    // An empty body means "sweep".
  }
  return null;
}
