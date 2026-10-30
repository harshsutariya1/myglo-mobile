// Snapshot events from connected accounts. Payout tracking for the
// provider's Financials screen is added with the payment lifecycle.

import { Stripe } from '../_shared/stripe.ts';

export function handleConnectEvent(event: Stripe.Event): Promise<string> {
  return Promise.resolve(`ignored:${event.type}`);
}
