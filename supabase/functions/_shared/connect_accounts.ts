// Reading a provider's Stripe connected account (Accounts v2) into the state
// the database keeps (apply_connect_account_state). Used by the connect
// function when a provider returns from onboarding and by the webhook when
// Stripe reports a change.

import { serviceRpc } from './supabase.ts';
import { Stripe, stripe } from './stripe.ts';

const INCLUDE: Stripe.V2.Core.AccountRetrieveParams.Include[] = ['configuration.recipient', 'requirements'];

/** Fetches the account from Stripe and stores its state. Returns the provider id. */
export async function syncConnectAccount(accountId: string): Promise<string | null> {
  const account = await stripe().v2.core.accounts.retrieve(accountId, { include: INCLUDE });
  return applyAccount(account);
}

export async function applyAccount(account: Stripe.V2.Core.Account): Promise<string | null> {
  const balance = account.configuration?.recipient?.capabilities?.stripe_balance;
  const transfers = balance?.stripe_transfers;
  const entries = account.requirements?.entries ?? [];

  // What the provider has to do now, and what Stripe is still checking.
  const due = entries
    .filter((e) => e.awaiting_action_from === 'user' && e.minimum_deadline.status !== 'eventually_due')
    .map((e) => e.description);
  const pending = entries
    .filter((e) => e.awaiting_action_from === 'stripe')
    .map((e) => e.description);
  const deadline = account.requirements?.summary?.minimum_deadline?.time ?? null;
  const disabledReason = transfers?.status_details?.[0]?.code ?? null;

  return await serviceRpc<string | null>('apply_connect_account_state', {
    p_stripe_account_id: account.id,
    p_transfers_status: transfers?.status ?? 'pending',
    p_payouts_enabled: balance?.payouts?.status === 'active',
    p_requirements_due: unique(due),
    p_requirements_pending: unique(pending),
    p_requirements_deadline: deadline,
    p_disabled_reason: disabledReason,
    p_closed: account.closed === true,
  });
}

function unique(values: string[]): string[] {
  return [...new Set(values)].slice(0, 50);
}
