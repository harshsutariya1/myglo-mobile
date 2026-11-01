// Snapshot events from connected accounts: payouts from a provider's Stripe
// balance to their bank. The payout is fetched from the provider's account
// and applied as it is now.

import { Stripe, stripe } from '../_shared/stripe.ts';
import { serviceRpc } from '../_shared/supabase.ts';

export async function handleConnectEvent(event: Stripe.Event): Promise<string> {
  if (!event.type.startsWith('payout.') || !event.account) return `ignored:${event.type}`;
  const payoutId = (event.data.object as { id: string }).id;
  const payout = await stripe().payouts.retrieve(payoutId, {}, { stripeAccount: event.account });
  await serviceRpc('apply_payout_state', {
    p_stripe_account_id: event.account,
    p_payout_id: payout.id,
    p_amount_cents: payout.amount,
    p_currency: payout.currency,
    p_status: payout.status,
    p_arrival_date: payout.arrival_date ? new Date(payout.arrival_date * 1000).toISOString().slice(0, 10) : null,
    p_failure_code: payout.failure_code ?? null,
    p_failure_message: payout.failure_message ?? null,
  });
  return `payout_synced:${payout.status}`;
}
