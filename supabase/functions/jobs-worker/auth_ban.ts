// Turns an account's Auth ban on or off to match its suspension, so a
// suspended account can't sign in or refresh its session. The job carries
// only the user id: whether to ban comes from the database when the job
// runs, so jobs that run late or out of order still leave the right state.

import { UUID } from '../_shared/http.ts';
import { serviceRpc, updateAuthUser } from '../_shared/supabase.ts';
import { failed, Job, JobResult, retry, succeeded } from './types.ts';

/** About a hundred years: Auth has no "until lifted" ban. */
const BAN_DURATION = '876000h';

/** payload: { user_id } */
export async function applyAuthBan(job: Job): Promise<JobResult> {
  const userId = typeof job.payload.user_id === 'string' ? job.payload.user_id : '';
  if (!UUID.test(userId)) return failed('user_id missing');

  const banned = await serviceRpc<boolean>('account_should_be_banned', { p_user_id: userId });
  const status = await updateAuthUser(userId, { ban_duration: banned ? BAN_DURATION : 'none' });
  if (status >= 200 && status < 300) return succeeded({ banned });
  // The account was deleted: there's nothing left to sign in to.
  if (status === 404) return succeeded({ banned, user_missing: true });

  const detail = `auth admin ${status}`;
  return status === 429 || status >= 500 ? retry(detail) : failed(detail);
}
