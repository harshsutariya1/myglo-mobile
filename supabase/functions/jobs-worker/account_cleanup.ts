// Clean-up after an account is deleted (delete_account queues both jobs):
// its files in Storage, and its Stripe connected account.

import { UUID } from '../_shared/http.ts';
import { describeStripeError, isTransientStripeError, Stripe, stripe } from '../_shared/stripe.ts';
import { serviceRpc } from '../_shared/supabase.ts';
import { failed, Job, JobResult, retry, succeeded } from './types.ts';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? '';
const SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
const STORAGE_TIMEOUT_MS = 20_000;
/** Pages of up to 1000 files; a user with more is finished on the retry. */
const MAX_PAGES = 5;

interface StoredFile {
  bucket_id: string;
  name: string;
}

/**
 * payload: { user_id }. Deletes every file of a deleted account. The list
 * comes from the database, which refuses while the account still exists.
 */
export async function purgeUserStorage(job: Job): Promise<JobResult> {
  const userId = typeof job.payload.user_id === 'string' ? job.payload.user_id : '';
  if (!UUID.test(userId)) return failed('user_id missing');

  let removed = 0;
  for (let page = 0; page < MAX_PAGES; page++) {
    const files = await serviceRpc<StoredFile[]>('list_deleted_account_files', { p_user_id: userId });
    if (files.length === 0) return succeeded({ removed });

    const byBucket = new Map<string, string[]>();
    for (const file of files) {
      byBucket.set(file.bucket_id, [...(byBucket.get(file.bucket_id) ?? []), file.name]);
    }
    for (const [bucket, names] of byBucket) {
      const status = await removeFiles(bucket, names);
      if (status < 200 || status >= 300) {
        const detail = `storage ${status} removing from ${bucket}`;
        return status === 429 || status >= 500 ? retry(detail) : failed(detail);
      }
      removed += names.length;
    }
  }
  return retry(`more files left after removing ${removed}`);
}

async function removeFiles(bucket: string, names: string[]): Promise<number> {
  const response = await fetch(`${SUPABASE_URL}/storage/v1/object/${encodeURIComponent(bucket)}`, {
    method: 'DELETE',
    headers: {
      apikey: SERVICE_ROLE_KEY,
      Authorization: `Bearer ${SERVICE_ROLE_KEY}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ prefixes: names }),
    signal: AbortSignal.timeout(STORAGE_TIMEOUT_MS),
  });
  // Drain the body so the connection is released.
  await response.text();
  return response.status;
}

/**
 * payload: { stripe_account_id }. Closes a deleted provider's connected
 * account (Accounts v2, recipient configuration). The delete-account
 * function only lets a provider go once its balance is empty; if Stripe
 * still refuses, the job fails and the admins are alerted.
 */
export async function closeConnectAccount(job: Job): Promise<JobResult> {
  const accountId = typeof job.payload.stripe_account_id === 'string' ? job.payload.stripe_account_id : '';
  if (!accountId.startsWith('acct_')) return failed('stripe_account_id missing');

  try {
    const account = await stripe().v2.core.accounts.retrieve(accountId);
    if (account.closed) return succeeded({ already_closed: true });
    await stripe().v2.core.accounts.close(
      accountId,
      { applied_configurations: account.applied_configurations },
      { idempotencyKey: job.idempotency_key },
    );
    return succeeded({ closed: true });
  } catch (error) {
    if (error instanceof Stripe.errors.StripeError && error.statusCode === 404) {
      return succeeded({ account_missing: true });
    }
    const detail = describeStripeError(error);
    return isTransientStripeError(error) ? retry(detail) : failed(detail);
  }
}
