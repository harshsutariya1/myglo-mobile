// Stripe Connect for providers: set up the account that receives their
// payouts, refresh its status, and open their Stripe Express Dashboard.
//
// POST { "action": "onboard" | "status" | "dashboard" } with the provider's
// own Authorization header. Who the caller is, and whether they're a
// provider, is decided by the database (begin_payments_setup runs as them);
// this function never trusts ids from the request.
//
//   onboard    creates the provider's connected account the first time
//              (Accounts v2: Express Dashboard, recipient configuration,
//              Myglo responsible for fees and losses, weekly payouts) and
//              returns a one-time Stripe onboarding link.
//   status     fetches the account from Stripe, stores its state and
//              returns get_my_payments_setup (used when the provider
//              returns from onboarding, before the webhook lands).
//   dashboard  returns a one-time Express Dashboard login link.
//
// Secrets: STRIPE_SECRET_KEY (see _shared/stripe.ts); optional
// CONNECT_RETURN_URL / CONNECT_REFRESH_URL (default myglo.app pages).

import { errorJson, HttpError, json, preflight, readJson } from '../_shared/http.ts';
import { syncConnectAccount } from '../_shared/connect_accounts.ts';
import { captureException } from '../_shared/sentry.ts';
import { describeStripeError, stripe, stripeConfigured } from '../_shared/stripe.ts';
import { RpcError, serviceRpc, supabaseConfigured, userRpc } from '../_shared/supabase.ts';

const FN = 'connect';
const RETURN_URL = Deno.env.get('CONNECT_RETURN_URL') ?? 'https://myglo.app/stripe/connect/return';
const REFRESH_URL = Deno.env.get('CONNECT_REFRESH_URL') ?? 'https://myglo.app/stripe/connect/refresh';

interface SetupContext {
  provider_id: string;
  email: string | null;
  business_name: string | null;
  stripe_account_id: string | null;
  details_ready: boolean;
}

Deno.serve(async (req: Request) => {
  const pre = preflight(req);
  if (pre) return pre;
  if (req.method !== 'POST') return json({ error: 'method_not_allowed' }, 405, req);
  if (!supabaseConfigured() || !stripeConfigured()) {
    await captureException(new Error('connect is missing Supabase or Stripe configuration'), { fn: FN });
    return json({ error: 'payments_unavailable' }, 503, req);
  }

  const authorization = req.headers.get('Authorization') ?? '';
  const body = await readJson(req);
  const action = body.action;

  try {
    // Runs as the caller: refuses anyone who isn't a provider.
    const ctx = await userRpc<SetupContext>(authorization, 'begin_payments_setup');
    switch (action) {
      case 'onboard':
        return json({ url: await onboardingLink(ctx) }, 200, req);
      case 'status':
        if (ctx.stripe_account_id) await syncConnectAccount(ctx.stripe_account_id);
        return json(await userRpc(authorization, 'get_my_payments_setup'), 200, req);
      case 'dashboard':
        if (!ctx.stripe_account_id) throw new HttpError(409, 'not_onboarded');
        return json({ url: (await stripe().accounts.createLoginLink(ctx.stripe_account_id)).url }, 200, req);
      default:
        throw new HttpError(400, 'invalid_request', 'action must be onboard, status or dashboard');
    }
  } catch (error) {
    if (error instanceof RpcError && error.isExpected) {
      return json({ error: error.code }, error.status === 401 ? 401 : 403, req);
    }
    if (error instanceof HttpError) return errorJson(error, req);
    await captureException(error, { fn: FN, tags: { action: String(action) }, extra: { stripe: describeStripeError(error) } });
    return json({ error: 'payments_unavailable' }, 502, req);
  }
});

/** The provider's account (created on first use) and a fresh onboarding link. */
async function onboardingLink(ctx: SetupContext): Promise<string> {
  const accountId = ctx.stripe_account_id ?? await createAccount(ctx);
  const link = await stripe().v2.core.accountLinks.create({
    account: accountId,
    use_case: {
      type: ctx.details_ready ? 'account_update' : 'account_onboarding',
      ...(ctx.details_ready
        ? { account_update: { refresh_url: REFRESH_URL, return_url: RETURN_URL } }
        : { account_onboarding: { refresh_url: REFRESH_URL, return_url: RETURN_URL } }),
    },
  });
  return link.url;
}

async function createAccount(ctx: SetupContext): Promise<string> {
  const account = await stripe().v2.core.accounts.create(
    {
      contact_email: ctx.email ?? undefined,
      display_name: ctx.business_name ?? undefined,
      dashboard: 'express',
      identity: { country: 'au' },
      defaults: {
        currency: 'aud',
        locales: ['en-AU'],
        responsibilities: { fees_collector: 'application', losses_collector: 'application' },
      },
      configuration: {
        recipient: { capabilities: { stripe_balance: { stripe_transfers: { requested: true } } } },
      },
      metadata: { myglo_provider_id: ctx.provider_id },
      include: ['configuration.recipient', 'requirements'],
    },
    // One account per provider, even if two set-up taps race.
    { idempotencyKey: `connect-account:${ctx.provider_id}` },
  );

  await serviceRpc('save_connect_account', { p_provider_id: ctx.provider_id, p_stripe_account_id: account.id });

  // Weekly payouts (Mondays): fewer Stripe payout fees, and a buffer for
  // refunds or disputes reported shortly after an appointment.
  try {
    await stripe().balanceSettings.update(
      { payments: { payouts: { schedule: { interval: 'weekly', weekly_payout_days: ['monday'] } } } },
      { stripeAccount: account.id },
    );
  } catch (error) {
    // Not fatal for onboarding; an admin can set it in the Stripe Dashboard.
    await captureException(error, { fn: FN, tags: { stage: 'payout_schedule' }, extra: { account: account.id } });
  }
  return account.id;
}
