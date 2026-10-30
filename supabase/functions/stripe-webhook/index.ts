// Receives Stripe webhooks. Deployed without JWT verification: every request
// is authenticated by its Stripe signature instead, with a separate signing
// secret per event destination:
//
//   /stripe-webhook/platform  snapshot events on Myglo's own account
//                             (PaymentIntents, charges, refunds, disputes,
//                             transfers)                 STRIPE_WEBHOOK_SECRET_PLATFORM
//   /stripe-webhook/connect   snapshot events from connected accounts
//                             (payouts)                  STRIPE_WEBHOOK_SECRET_CONNECT
//   /stripe-webhook/v2        thin v2 events (connected account
//                             requirements, capabilities, closure)
//                                                        STRIPE_WEBHOOK_SECRET_V2
//
// Each event is recorded in private.stripe_events and processed once. A
// handler never trusts the event's copy of an object or the order events
// arrive in: it fetches the object's current state from Stripe and applies
// that with an idempotent database function. Events from the other mode
// (live vs test) are ignored.

import { json } from '../_shared/http.ts';
import { captureException } from '../_shared/sentry.ts';
import { cryptoProvider, describeStripeError, Stripe, stripe, stripeConfigured, stripeLivemode } from '../_shared/stripe.ts';
import { serviceRpc, supabaseConfigured } from '../_shared/supabase.ts';
import { handleConnectEvent } from './connect_events.ts';
import { handlePlatformEvent } from './platform_events.ts';
import { handleV2Event } from './v2_events.ts';

const FN = 'stripe-webhook';

type Source = 'platform' | 'connect' | 'v2';

const SECRETS: Record<Source, string> = {
  platform: Deno.env.get('STRIPE_WEBHOOK_SECRET_PLATFORM') ?? '',
  connect: Deno.env.get('STRIPE_WEBHOOK_SECRET_CONNECT') ?? '',
  v2: Deno.env.get('STRIPE_WEBHOOK_SECRET_V2') ?? '',
};

/** What the handlers need from either kind of event. */
interface Received {
  id: string;
  type: string;
  livemode: boolean;
  account: string | null;
  snapshot?: Stripe.Event;
  thin?: Stripe.V2.Core.EventNotification;
}

Deno.serve(async (req: Request) => {
  if (req.method !== 'POST') return json({ error: 'method_not_allowed' }, 405);
  const source = new URL(req.url).pathname.split('/').filter(Boolean).pop() as Source;
  const secret = SECRETS[source];
  if (!secret) return json({ error: 'unknown_endpoint' }, 404);
  if (!supabaseConfigured() || !stripeConfigured()) {
    await captureException(new Error('stripe-webhook is missing configuration'), { fn: FN });
    return json({ error: 'misconfigured' }, 500);
  }

  const signature = req.headers.get('stripe-signature') ?? '';
  const raw = await req.text();

  let event: Received;
  try {
    event = await verify(source, raw, signature, secret);
  } catch (error) {
    console.warn(`${FN}: rejected a ${source} request with a bad signature`, describeStripeError(error));
    return json({ error: 'invalid_signature' }, 400);
  }

  if (event.livemode !== stripeLivemode()) {
    // A live event reaching the test deployment (or the reverse): not ours.
    return json({ ignored: 'other_mode' });
  }

  let fresh: boolean;
  try {
    fresh = await serviceRpc<boolean>('begin_stripe_event', {
      p_id: event.id,
      p_type: event.type,
      p_livemode: event.livemode,
      p_account: event.account,
      p_source: source,
    });
  } catch (error) {
    await captureException(error, { fn: FN, tags: { stage: 'record', type: event.type } });
    return json({ error: 'record_failed' }, 500);
  }
  if (!fresh) return json({ duplicate: true });

  try {
    const outcome = await handle(source, event);
    await serviceRpc('finish_stripe_event', { p_id: event.id });
    return json({ received: true, outcome });
  } catch (error) {
    const detail = error instanceof Error ? error.message : String(error);
    await serviceRpc('finish_stripe_event', { p_id: event.id, p_error: detail }).catch(() => {});
    await captureException(error, {
      fn: FN,
      tags: { source, type: event.type },
      extra: { event_id: event.id, stripe: describeStripeError(error) },
    });
    // Stripe retries with backoff for up to three days.
    return json({ error: 'processing_failed' }, 500);
  }
});

async function verify(source: Source, raw: string, signature: string, secret: string): Promise<Received> {
  if (source === 'v2') {
    const thin = await stripe().parseEventNotificationAsync(raw, signature, secret, undefined, cryptoProvider);
    return {
      id: thin.id,
      type: thin.type,
      livemode: thin.livemode,
      account: typeof thin.context === 'string' ? thin.context : thin.context?.toString() ?? null,
      thin,
    };
  }
  const snapshot = await stripe().webhooks.constructEventAsync(raw, signature, secret, undefined, cryptoProvider);
  return { id: snapshot.id, type: snapshot.type, livemode: snapshot.livemode, account: snapshot.account ?? null, snapshot };
}

function handle(source: Source, event: Received): Promise<string> {
  switch (source) {
    case 'v2':
      return handleV2Event(event.thin!);
    case 'connect':
      return handleConnectEvent(event.snapshot!);
    case 'platform':
      return handlePlatformEvent(event.snapshot!);
  }
}
