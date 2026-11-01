// Reading a PaymentIntent from Stripe into the state the database keeps
// (apply_payment_intent_state). Used by the payments function, the webhook
// and the jobs worker; none of them trust an event's copy of the object or
// the order events arrive in.

import { serviceRpc } from './supabase.ts';
import { Stripe, stripe } from './stripe.ts';

/** The booking a PaymentIntent belongs to, after its state was applied. */
export interface AppliedPayment {
  booking_id: string;
  status: string;
  payment_status: string;
}

/** Statuses in which the client's money is held or taken. */
export const PAID_STATUSES = new Set<string>(['succeeded', 'requires_capture']);

/** Statuses Stripe lets us cancel from. */
export const CANCELLABLE_STATUSES = new Set<string>([
  'requires_payment_method',
  'requires_confirmation',
  'requires_action',
  'requires_capture',
]);

/** The PaymentIntent with its latest charge (card details, refunds, hold expiry). */
export function retrievePaymentIntent(id: string): Promise<Stripe.PaymentIntent> {
  return stripe().paymentIntents.retrieve(id, { expand: ['latest_charge'] });
}

/** Fetches the PaymentIntent from Stripe and applies it. Null if Myglo doesn't know it. */
export async function syncPaymentIntent(id: string): Promise<AppliedPayment | null> {
  return await applyPaymentIntent(await retrievePaymentIntent(id));
}

/** Applies a PaymentIntent fetched with its latest charge expanded. */
export async function applyPaymentIntent(intent: Stripe.PaymentIntent): Promise<AppliedPayment | null> {
  const charge = typeof intent.latest_charge === 'object' ? intent.latest_charge : null;
  const card = charge?.payment_method_details?.card;
  const error = intent.last_payment_error;
  return await serviceRpc<AppliedPayment | null>('apply_payment_intent_state', {
    p_payment_intent_id: intent.id,
    p_status: intent.status,
    p_amount_cents: intent.amount,
    p_amount_received_cents: intent.amount_received,
    p_amount_refunded_cents: charge?.amount_refunded ?? 0,
    p_charge_id: charge?.id ?? null,
    p_capture_before: card?.capture_before ? new Date(card.capture_before * 1000).toISOString() : null,
    p_wallet: card?.wallet?.type ?? null,
    p_card_brand: card?.brand ?? null,
    p_card_last4: card?.last4 ?? null,
    p_failure_code: error?.decline_code ?? error?.code ?? null,
  });
}

/** Stripe refused because the PaymentIntent moved on (e.g. already paid or cancelled). */
export function isUnexpectedState(error: unknown): boolean {
  return error instanceof Stripe.errors.StripeError && error.code === 'payment_intent_unexpected_state';
}
