// Snapshot events on Myglo's own account. PaymentIntent, refund, dispute and
// transfer handling is added with card checkout and the payment lifecycle.

import { Stripe } from '../_shared/stripe.ts';

export function handlePlatformEvent(event: Stripe.Event): Promise<string> {
  return Promise.resolve(`ignored:${event.type}`);
}
