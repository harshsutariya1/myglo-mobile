// Card payment calls the database queues: cancelling a PaymentIntent
// (closing a checkout, releasing a hold), capturing a held payment,
// refunding, and paying providers their share (transfers and reversals).
// Each Stripe call carries the job's idempotency key, and every handler
// finishes by reading the result back from Stripe and applying it, so the
// database always ends with Stripe's real state.

import {
  applyPaymentIntent,
  CANCELLABLE_STATUSES,
  isUnexpectedState,
  PAID_STATUSES,
  retrievePaymentIntent,
  syncPaymentIntent,
} from '../_shared/payment_intents.ts';
import { captureException } from '../_shared/sentry.ts';
import { describeStripeError, isTransientStripeError, Stripe, stripe } from '../_shared/stripe.ts';
import { serviceRpc } from '../_shared/supabase.ts';
import { failed, Job, JobResult, retry, succeeded } from './types.ts';

const FN = 'jobs-worker';

/**
 * payload: { payment_intent_id, mode: 'checkout' | 'release' }
 *
 * 'checkout' closes an unpaid checkout. If the client paid at the last
 * moment, that payment is applied instead of cancelled.
 * 'release' lets go of a hold (declined, lapsed or withdrawn request).
 */
export async function cancelPaymentIntent(job: Job): Promise<JobResult> {
  const id = paymentIntentId(job);
  if (!id) return failed('payment_intent_id missing');
  const release = job.payload.mode === 'release';

  return await stripeCall(job, async () => {
    let intent = await retrievePaymentIntent(id);
    if (!release && PAID_STATUSES.has(intent.status)) {
      const applied = await applyPaymentIntent(intent);
      return succeeded({ outcome: 'paid_before_close', status: intent.status, booking_status: applied?.status });
    }
    if (intent.status === 'processing') return retry('payment is still processing');

    if (CANCELLABLE_STATUSES.has(intent.status)) {
      try {
        intent = await stripe().paymentIntents.cancel(
          id,
          { cancellation_reason: 'abandoned', expand: ['latest_charge'] },
          { idempotencyKey: job.idempotency_key },
        );
      } catch (error) {
        if (!isUnexpectedState(error)) throw error;
        intent = await retrievePaymentIntent(id);
      }
    }
    // Applied whatever Stripe says now: cancelled closes the checkout or
    // voids the hold; a payment that slipped through is refunded by the
    // database's own rules.
    const applied = await applyPaymentIntent(intent);
    return succeeded({ status: intent.status, booking_status: applied?.status });
  });
}

/** payload: { payment_intent_id }. Captures a hold the provider accepted. */
export async function capturePayment(job: Job): Promise<JobResult> {
  const id = paymentIntentId(job);
  if (!id) return failed('payment_intent_id missing');

  return await stripeCall(job, async () => {
    let intent = await retrievePaymentIntent(id);
    if (intent.status === 'requires_capture') {
      try {
        intent = await stripe().paymentIntents.capture(
          id,
          { expand: ['latest_charge'] },
          { idempotencyKey: job.idempotency_key },
        );
      } catch (error) {
        if (!isUnexpectedState(error)) throw error;
        intent = await retrievePaymentIntent(id);
      }
    }
    const applied = await applyPaymentIntent(intent);
    if (intent.status === 'processing') return retry('capture is still processing');
    if (intent.status === 'succeeded' || intent.status === 'canceled') {
      // 'canceled' means the hold lapsed; the database flagged it for admins.
      return succeeded({ status: intent.status, payment_status: applied?.payment_status });
    }
    return failed(`cannot capture a payment in status ${intent.status}`);
  });
}

/**
 * payload: { payment_intent_id, amount_cents, reason, refund_id? }. Refunds
 * the given amount; refund_id is Myglo's booking_refunds row (absent for a
 * payment that reached a closed checkout).
 */
export async function refundPayment(job: Job): Promise<JobResult> {
  const id = paymentIntentId(job);
  const amount = Number(job.payload.amount_cents);
  const refundId = typeof job.payload.refund_id === 'string' ? job.payload.refund_id : null;
  if (!id) return failed('payment_intent_id missing');
  if (!Number.isInteger(amount) || amount <= 0) return failed('amount_cents must be a positive whole number');

  return await stripeCall(job, async () => {
    const refund = await stripe().refunds.create(
      {
        payment_intent: id,
        amount,
        reason: 'requested_by_customer',
        metadata: {
          booking_id: String(job.booking_id ?? job.payload.booking_id ?? ''),
          myglo_refund_id: refundId ?? '',
          myglo_reason: String(job.payload.reason ?? ''),
          job_id: job.job_id,
        },
      },
      { idempotencyKey: job.idempotency_key },
    );
    if (refundId) {
      await serviceRpc('apply_refund_state', {
        p_refund_id: refundId,
        p_stripe_refund_id: refund.id,
        p_status: refund.status,
        p_failure_reason: refund.failure_reason ?? null,
      });
    }
    if (refund.status === 'failed' || refund.status === 'canceled') {
      return failed(`refund ${refund.id} ${refund.status}: ${refund.failure_reason ?? 'no reason given'}`);
    }
    const applied = await syncPaymentIntent(id);
    return succeeded({ refund_id: refund.id, refund_status: refund.status, payment_status: applied?.payment_status });
  });
}

/**
 * payload: { booking_id, amount_cents, destination, source_transaction }.
 * Pays the provider their share from the client's charge.
 */
export async function transfer(job: Job): Promise<JobResult> {
  const bookingId = String(job.payload.booking_id ?? job.booking_id ?? '');
  const amount = Number(job.payload.amount_cents);
  const destination = String(job.payload.destination ?? '');
  const source = String(job.payload.source_transaction ?? '');
  if (!bookingId || !/^acct_/.test(destination) || !/^(ch|py)_/.test(source)) return failed('transfer payload incomplete');
  if (!Number.isInteger(amount) || amount <= 0) return failed('amount_cents must be a positive whole number');

  try {
    const created = await stripe().transfers.create(
      {
        amount,
        currency: 'aud',
        destination,
        source_transaction: source,
        transfer_group: bookingId,
        description: `Myglo booking ${bookingId}`,
        metadata: { booking_id: bookingId, job_id: job.job_id },
      },
      { idempotencyKey: job.idempotency_key },
    );
    await serviceRpc('apply_transfer_state', {
      p_booking_id: bookingId,
      p_transfer_id: created.id,
      p_status: 'succeeded',
      p_reversed_cents: created.amount_reversed,
    });
    return succeeded({ transfer_id: created.id });
  } catch (error) {
    if (error instanceof Stripe.errors.StripeError && !isTransientStripeError(error)) {
      // Recorded on the settlement so admins see it (and the job alert fires).
      await serviceRpc('apply_transfer_state', {
        p_booking_id: bookingId,
        p_transfer_id: null,
        p_status: 'failed',
        p_failure_reason: describeStripeError(error).slice(0, 200),
      });
    }
    return await stripeCall(job, () => Promise.reject(error));
  }
}

/** payload: { booking_id, transfer_id, amount_cents, reason }. Takes part of a provider's share back. */
export async function reverseTransfer(job: Job): Promise<JobResult> {
  const bookingId = String(job.payload.booking_id ?? job.booking_id ?? '');
  const transferId = String(job.payload.transfer_id ?? '');
  const amount = Number(job.payload.amount_cents);
  if (!/^tr_/.test(transferId)) return failed('transfer_id missing');
  if (!Number.isInteger(amount) || amount <= 0) return failed('amount_cents must be a positive whole number');

  return await stripeCall(job, async () => {
    await stripe().transfers.createReversal(
      transferId,
      { amount, metadata: { booking_id: bookingId, myglo_reason: String(job.payload.reason ?? ''), job_id: job.job_id } },
      { idempotencyKey: job.idempotency_key },
    );
    const current = await stripe().transfers.retrieve(transferId);
    await serviceRpc('apply_transfer_state', {
      p_booking_id: bookingId || null,
      p_transfer_id: transferId,
      p_status: 'succeeded',
      p_reversed_cents: current.amount_reversed,
    });
    return succeeded({ transfer_id: transferId, amount_reversed: current.amount_reversed });
  });
}

function paymentIntentId(job: Job): string | null {
  const id = job.payload.payment_intent_id;
  return typeof id === 'string' && /^pi_[A-Za-z0-9]+$/.test(id) ? id : null;
}

/**
 * Runs a Stripe call. Transient problems (network, rate limits, Stripe
 * outages) are retried with backoff; anything that would fail the same way
 * again (bad request, missing permission) fails the job, which alerts admins.
 */
async function stripeCall(job: Job, call: () => Promise<JobResult>): Promise<JobResult> {
  try {
    return await call();
  } catch (error) {
    const description = describeStripeError(error);
    if (error instanceof Stripe.errors.StripeError && !isTransientStripeError(error)) {
      await captureException(error, {
        fn: FN,
        tags: { job_kind: job.kind, stripe_code: error.code ?? 'none' },
        extra: { job_id: job.job_id, booking_id: job.booking_id, stripe: description },
      });
      return failed(description);
    }
    throw error;
  }
}
