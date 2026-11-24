// Deletes the caller's Myglo account (Settings → Delete account).
//
// POST {} with the user's own Authorization header, sent right after the app
// re-checked their password (signInWithPassword), so the token's amr claim
// shows a password check from the last 10 minutes. Who is being deleted
// comes only from that token; the request body is ignored.
//
//   1. begin_account_deletion runs as the user: refuses a stale password
//      check (reauth_required) or anything that blocks deletion
//      (account_deletion_blocked, with the blockers).
//   2. A provider's Stripe balance must be empty: money still waiting for a
//      payout would otherwise be stranded in a closed account.
//   3. delete_account (service role) re-checks under lock and deletes. Files
//      and the Stripe account are removed by the jobs worker afterwards.
//   4. A confirmation email goes to the old address (best effort).
//
// Admin closure (an account's owner asked support to close it): POST
// { "user_id": "<uuid>", "reason": "<why>" } with an admin's Authorization
// header and a fresh two-factor code. admin_begin_account_closure checks the
// admin and the account (as the admin), the Stripe balance is checked the
// same way, delete_account runs with p_by_admin (a suspended account can be
// closed this way), and admin_record_account_closure writes the audit entry
// once the account is gone. The owner gets the confirmation email.
//
// Responses: 200 { deleted: true }; 409 { error: "deletion_blocked",
// blockers: [{ code, count?, amount_cents? }] }; 401/403 { error } for
// not_authenticated / reauth_required; 502/503 { error:
// "deletion_unavailable" } for outages (reported to Sentry).
//
// Secrets: STRIPE_SECRET_KEY (_shared/stripe.ts), RESEND_API_KEY and the
// optional NOTIFICATIONS_EMAIL_FROM (as send-notifications), Sentry
// (_shared/sentry.ts).

import { json, preflight } from '../_shared/http.ts';
import { captureException } from '../_shared/sentry.ts';
import { describeStripeError, Stripe, stripe, stripeConfigured } from '../_shared/stripe.ts';
import { RpcError, serviceRpc, supabaseConfigured, userRpc } from '../_shared/supabase.ts';

const FN = 'delete-account';
const RESEND_API_KEY = Deno.env.get('RESEND_API_KEY') ?? '';
const EMAIL_FROM = Deno.env.get('NOTIFICATIONS_EMAIL_FROM') ?? 'Myglo <bookings@myglo.app>';
const SUPPORT_EMAIL = Deno.env.get('SUPPORT_EMAIL') ?? 'hello@myglo.app';
const SEND_TIMEOUT_MS = 10_000;

interface DeletionContext {
  user_id: string;
  email: string | null;
  role?: string | null;
  stripe_account_id: string | null;
}

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/** `{ user_id, reason }` when an admin is closing someone's account, else null. */
async function readAdminRequest(req: Request): Promise<{ userId: string; reason: string } | null | 'invalid'> {
  let body: unknown;
  try {
    const text = await req.text();
    body = text.trim() === '' ? {} : JSON.parse(text);
  } catch {
    return 'invalid';
  }
  if (!body || typeof body !== 'object' || Array.isArray(body)) return 'invalid';
  const { user_id: userId, reason } = body as Record<string, unknown>;
  if (userId === undefined) return null;
  if (typeof userId !== 'string' || !UUID.test(userId) || typeof reason !== 'string') return 'invalid';
  return { userId, reason };
}

interface Blocker {
  code: string;
  count?: number;
  amount_cents?: number;
}

Deno.serve(async (req: Request) => {
  const pre = preflight(req);
  if (pre) return pre;
  if (req.method !== 'POST') return json({ error: 'method_not_allowed' }, 405, req);
  if (!supabaseConfigured()) {
    await captureException(new Error('delete-account is missing Supabase configuration'), { fn: FN });
    return json({ error: 'deletion_unavailable' }, 503, req);
  }

  const authorization = req.headers.get('Authorization') ?? '';
  const adminRequest = await readAdminRequest(req);
  if (adminRequest === 'invalid') return json({ error: 'invalid_request' }, 400, req);

  let ctx: DeletionContext;
  try {
    ctx = adminRequest
      ? await userRpc<DeletionContext>(authorization, 'admin_begin_account_closure', {
        p_user_id: adminRequest.userId,
        p_reason: adminRequest.reason,
      })
      : await userRpc<DeletionContext>(authorization, 'begin_account_deletion');
  } catch (error) {
    return await refusal(error, req, adminRequest ? 'admin_begin' : 'begin');
  }

  if (ctx.stripe_account_id) {
    if (!stripeConfigured()) {
      await captureException(new Error('delete-account needs STRIPE_SECRET_KEY for a provider'), { fn: FN });
      return json({ error: 'deletion_unavailable' }, 503, req);
    }
    try {
      const owed = await stripeBalanceCents(ctx.stripe_account_id);
      if (owed !== null) {
        return json({ error: 'deletion_blocked', blockers: [{ code: 'stripe_balance', amount_cents: owed }] }, 409, req);
      }
    } catch (error) {
      await captureException(error, {
        fn: FN,
        tags: { stage: 'stripe_balance' },
        extra: { account: ctx.stripe_account_id, stripe: describeStripeError(error) },
      });
      return json({ error: 'deletion_unavailable' }, 502, req);
    }
  }

  try {
    await serviceRpc('delete_account', { p_user_id: ctx.user_id, p_by_admin: adminRequest !== null });
  } catch (error) {
    return await refusal(error, req, 'delete');
  }

  if (adminRequest) {
    try {
      await userRpc(authorization, 'admin_record_account_closure', {
        p_user_id: ctx.user_id,
        p_reason: adminRequest.reason,
        p_role: ctx.role ?? null,
      });
    } catch (error) {
      // The account is gone; only the audit entry is missing. Worth an alert,
      // not a failure (retrying would find no account to close).
      await captureException(error, { fn: FN, tags: { stage: 'admin_audit' }, extra: { user_id: ctx.user_id } });
    }
  }

  if (ctx.email) await sendConfirmation(ctx.email, adminRequest !== null);
  return json({ deleted: true }, 200, req);
});

/** Maps a refusal from the database to a response; anything else is an outage. */
async function refusal(error: unknown, req: Request, stage: string): Promise<Response> {
  if (error instanceof RpcError && error.isExpected) {
    switch (error.code) {
      case 'account_deletion_blocked':
        return json({ error: 'deletion_blocked', blockers: parseBlockers(error.details) }, 409, req);
      case 'not_authenticated':
        return json({ error: 'not_authenticated' }, 401, req);
      case 'account_not_found':
        // An admin closing an account that's already gone; for a user
        // deleting themselves, their session outlived the account.
        return stage === 'admin_begin'
          ? json({ error: 'account_not_found' }, 404, req)
          : json({ error: 'not_authenticated' }, 401, req);
      case 'reauth_required':
      case 'admin_required':
      case 'mfa_required':
      case 'admin_session_expired':
      case 'reason_required':
        return json({ error: error.code }, error.code === 'reason_required' ? 400 : 403, req);
    }
  }
  if (error instanceof RpcError && error.status === 401) {
    return json({ error: 'not_authenticated' }, 401, req);
  }
  await captureException(error, { fn: FN, tags: { stage } });
  return json({ error: 'deletion_unavailable' }, 502, req);
}

function parseBlockers(details: string | null): Blocker[] {
  try {
    const parsed = JSON.parse(details ?? '[]');
    return Array.isArray(parsed) ? parsed : [];
  } catch {
    return [];
  }
}

/**
 * The connected account's Stripe balance (available plus pending), in cents,
 * or null when it's empty. Any non-zero bucket counts, including a negative
 * one. An account Stripe no longer has holds nothing.
 */
async function stripeBalanceCents(accountId: string): Promise<number | null> {
  let balance: Stripe.Balance;
  try {
    balance = await stripe().balance.retrieve({}, { stripeAccount: accountId });
  } catch (error) {
    if (error instanceof Stripe.errors.StripeError && error.code === 'account_invalid') return null;
    throw error;
  }
  const buckets = [...balance.available, ...balance.pending];
  if (buckets.every((b) => b.amount === 0)) return null;
  return buckets.reduce((sum, b) => sum + b.amount, 0);
}

async function sendConfirmation(to: string, byAdmin: boolean): Promise<void> {
  if (!RESEND_API_KEY) return;
  try {
    const response = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: { Authorization: `Bearer ${RESEND_API_KEY}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({
        from: EMAIL_FROM,
        to: [to],
        subject: 'Your Myglo account has been deleted',
        text: [
          'Hi,',
          '',
          byAdmin
            ? 'Your Myglo account and the personal details in it have been deleted, as you asked us.'
            : 'Your Myglo account and the personal details in it have been deleted, as you asked in the app.',
          'Records of past bookings and payments that we must keep by law no longer include your name or contact details.',
          '',
          `If you didn't do this, contact ${SUPPORT_EMAIL} straight away.`,
          '',
          'Myglo',
        ].join('\n'),
        tags: [{ name: 'category', value: 'account_deleted' }],
      }),
      signal: AbortSignal.timeout(SEND_TIMEOUT_MS),
    });
    if (!response.ok) throw new Error(`resend ${response.status}: ${await response.text()}`);
    await response.body?.cancel();
  } catch (error) {
    // The account is already gone; a missed email isn't worth failing for.
    await captureException(error, { fn: FN, tags: { stage: 'confirmation_email' } });
  }
}
