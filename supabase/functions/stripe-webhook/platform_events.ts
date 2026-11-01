// Snapshot events on Myglo's own account. Each one leads back to the object
// it's about, which is fetched from Stripe and applied as it is now:
//   payment_intent.*, charge.*   -> the PaymentIntent (payment, capture, refunds)
//   refund.*, charge.refund.*    -> the refund, then its PaymentIntent
//   charge.dispute.*             -> the dispute (holds or takes back the provider's share)
//   transfer.*                   -> the transfer to the provider (reversals)

import { syncPaymentIntent } from '../_shared/payment_intents.ts';
import { Stripe, stripe } from '../_shared/stripe.ts';
import { serviceRpc } from '../_shared/supabase.ts';

export async function handlePlatformEvent(event: Stripe.Event): Promise<string> {
  const object = event.data.object as { id?: string; object?: string };

  if (event.type.startsWith('charge.dispute.')) return await syncDispute(object.id!);
  if (event.type.startsWith('transfer.')) return await syncTransfer(object.id!);
  if (event.type.startsWith('refund.') || event.type.startsWith('charge.refund.')) return await syncRefund(object.id!);

  const intentId = paymentIntentOf(event);
  if (!intentId) return `ignored:${event.type}`;
  const applied = await syncPaymentIntent(intentId);
  return applied ? `payment_synced:${applied.status}/${applied.payment_status}` : 'unknown_payment_intent';
}

/** The PaymentIntent a payment or charge event is about. */
function paymentIntentOf(event: Stripe.Event): string | null {
  const object = event.data.object as { id?: string; payment_intent?: string | { id: string } | null };
  if (event.type.startsWith('payment_intent.')) return object.id ?? null;
  if (!event.type.startsWith('charge.')) return null;
  const intent = object.payment_intent;
  return typeof intent === 'string' ? intent : intent?.id ?? null;
}

async function syncRefund(refundId: string): Promise<string> {
  const refund = await stripe().refunds.retrieve(refundId);
  const mygloId = refund.metadata?.myglo_refund_id;
  await serviceRpc('apply_refund_state', {
    p_refund_id: mygloId ? mygloId : null,
    p_stripe_refund_id: refund.id,
    p_status: refund.status,
    p_failure_reason: refund.failure_reason ?? null,
  });
  const intent = typeof refund.payment_intent === 'string' ? refund.payment_intent : refund.payment_intent?.id;
  if (intent) await syncPaymentIntent(intent);
  return `refund_synced:${refund.status}`;
}

async function syncDispute(disputeId: string): Promise<string> {
  const dispute = await stripe().disputes.retrieve(disputeId);
  const intent = typeof dispute.payment_intent === 'string' ? dispute.payment_intent : dispute.payment_intent?.id;
  if (!intent) return 'dispute_without_payment_intent';
  const dueBy = dispute.evidence_details?.due_by;
  await serviceRpc('apply_dispute_state', {
    p_dispute_id: dispute.id,
    p_payment_intent_id: intent,
    p_amount_cents: dispute.amount,
    p_reason: dispute.reason,
    p_status: dispute.status,
    p_evidence_due_by: dueBy ? new Date(dueBy * 1000).toISOString() : null,
  });
  return `dispute_synced:${dispute.status}`;
}

async function syncTransfer(transferId: string): Promise<string> {
  const transfer = await stripe().transfers.retrieve(transferId);
  const bookingId = transfer.metadata?.booking_id;
  await serviceRpc('apply_transfer_state', {
    p_booking_id: bookingId ? bookingId : null,
    p_transfer_id: transfer.id,
    p_status: 'succeeded',
    p_reversed_cents: transfer.amount_reversed,
  });
  return `transfer_synced:${transfer.amount_reversed}`;
}
