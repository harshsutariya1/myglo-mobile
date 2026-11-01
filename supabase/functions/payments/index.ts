// Card checkout for clients: the PaymentIntent behind Stripe's payment sheet.
//
// POST { "action": "checkout" | "sync", "booking_id": "<uuid>" } with the
// client's own Authorization header. Whether the caller may pay for that
// booking, and how much, is decided by the database (begin_card_checkout runs
// as them); this function never takes an amount or an id it can't check.
//
//   checkout  creates the booking's PaymentIntent the first time (automatic
//             capture for instant bookings, a hold for requests) and returns
//             its client secret for the payment sheet. Calling it again
//             returns the same PaymentIntent, so a retry can't charge twice.
//   sync      fetches the PaymentIntent from Stripe and applies it, for when
//             the app is waiting for the outcome and the webhook hasn't
//             landed yet.
//
// Secrets: STRIPE_SECRET_KEY (see _shared/stripe.ts).

import { errorJson, HttpError, json, preflight, readJson, requireUuid } from '../_shared/http.ts';
import {
  applyPaymentIntent,
  PAID_STATUSES,
  retrievePaymentIntent,
  syncPaymentIntent,
} from '../_shared/payment_intents.ts';
import { captureException } from '../_shared/sentry.ts';
import { describeStripeError, stripe, stripeConfigured } from '../_shared/stripe.ts';
import { RpcError, serviceRpc, supabaseConfigured, userRpc } from '../_shared/supabase.ts';

const FN = 'payments';

interface CheckoutContext {
  booking_id: string;
  reference: string;
  status: string;
  amount_cents: number;
  currency: string;
  capture_method: 'automatic' | 'manual';
  payment_intent_id: string | null;
  provider_id: string;
  provider_name: string;
  client_id: string;
  hold_expires_at: string | null;
}

Deno.serve(async (req: Request) => {
  const pre = preflight(req);
  if (pre) return pre;
  if (req.method !== 'POST') return json({ error: 'method_not_allowed' }, 405, req);
  if (!supabaseConfigured() || !stripeConfigured()) {
    await captureException(new Error('payments is missing Supabase or Stripe configuration'), { fn: FN });
    return json({ error: 'payments_unavailable' }, 503, req);
  }

  const authorization = req.headers.get('Authorization') ?? '';
  const body = await readJson(req);
  const action = body.action;

  try {
    const bookingId = requireUuid(body, 'booking_id');
    switch (action) {
      case 'checkout':
        return json(await checkout(authorization, bookingId), 200, req);
      case 'sync':
        return json(await sync(authorization, bookingId), 200, req);
      default:
        throw new HttpError(400, 'invalid_request', 'action must be checkout or sync');
    }
  } catch (error) {
    if (error instanceof RpcError && error.isExpected) {
      if (error.code === 'not_authenticated') return json({ error: 'not_authenticated' }, 401, req);
      // Postgres' own "permission denied" (e.g. a signed-out caller): no details.
      if (error.sqlState === '42501') return json({ error: 'not_allowed' }, 403, req);
      return json({ error: error.code }, error.code === 'booking_not_found' ? 404 : 409, req);
    }
    if (error instanceof HttpError) return errorJson(error, req);
    await captureException(error, { fn: FN, tags: { action: String(action) }, extra: { stripe: describeStripeError(error) } });
    return json({ error: 'payments_unavailable' }, 502, req);
  }
});

async function checkout(authorization: string, bookingId: string): Promise<Record<string, unknown>> {
  // Runs as the caller: refuses anyone but the booking's client, and closed checkouts.
  const ctx = await userRpc<CheckoutContext>(authorization, 'begin_card_checkout', { p_booking_id: bookingId });

  if (ctx.payment_intent_id) {
    const intent = await retrievePaymentIntent(ctx.payment_intent_id);
    if (PAID_STATUSES.has(intent.status) || intent.status === 'canceled') {
      // The app missed Stripe's answer: apply it and report where the booking is.
      const applied = await applyPaymentIntent(intent);
      if (intent.status === 'canceled') throw new HttpError(409, 'checkout_expired');
      return { paid: true, booking_status: applied?.status, payment_status: applied?.payment_status };
    }
    return sheet(intent, ctx);
  }

  const intent = await stripe().paymentIntents.create(
    {
      amount: ctx.amount_cents,
      currency: ctx.currency,
      capture_method: ctx.capture_method,
      // Cards, which includes Apple Pay and Google Pay. Nothing else is
      // offered until it's reviewed (Afterpay comes later).
      allowed_payment_method_types: ['card'],
      transfer_group: ctx.booking_id,
      description: `Myglo booking ${ctx.reference} with ${ctx.provider_name}`.slice(0, 200),
      metadata: {
        booking_id: ctx.booking_id,
        booking_reference: ctx.reference,
        provider_id: ctx.provider_id,
        client_id: ctx.client_id,
      },
    },
    // Two taps on "Pay" (or a retry after a timeout) get the same PaymentIntent.
    { idempotencyKey: `checkout-pi:${ctx.booking_id}` },
  );
  await serviceRpc('record_payment_intent', { p_booking_id: ctx.booking_id, p_payment_intent_id: intent.id });
  return sheet(intent, ctx);
}

function sheet(intent: { id: string; client_secret: string | null; livemode: boolean; status: string }, ctx: CheckoutContext) {
  if (!intent.client_secret) throw new Error(`PaymentIntent ${intent.id} has no client secret`);
  return {
    paid: false,
    client_secret: intent.client_secret,
    payment_intent_id: intent.id,
    status: intent.status,
    amount_cents: ctx.amount_cents,
    currency: ctx.currency,
    capture_method: ctx.capture_method,
    hold_expires_at: ctx.hold_expires_at,
    livemode: intent.livemode,
  };
}

async function sync(authorization: string, bookingId: string): Promise<Record<string, unknown>> {
  const intentId = await userRpc<string | null>(authorization, 'get_checkout_payment_intent', { p_booking_id: bookingId });
  if (!intentId) return { synced: false };
  const applied = await syncPaymentIntent(intentId);
  return { synced: true, booking_status: applied?.status, payment_status: applied?.payment_status };
}
