// The Stripe client every function shares, pinned to one SDK and API version
// so a Stripe release can't change behaviour underneath us.
//
// Secrets
//   STRIPE_SECRET_KEY  a restricted key (rk_test_… / rk_live_…) with only the
//                      permissions listed in docs/payments.md.

import Stripe from 'npm:stripe@23.0.0';

export { Stripe };

export const STRIPE_API_VERSION = '2026-09-30.endive';

const SECRET_KEY = Deno.env.get('STRIPE_SECRET_KEY') ?? '';

let client: Stripe | null = null;

export function stripeConfigured(): boolean {
  return SECRET_KEY !== '';
}

/** The shared client. Throws if STRIPE_SECRET_KEY isn't set. */
export function stripe(): Stripe {
  if (!SECRET_KEY) throw new Error('STRIPE_SECRET_KEY is not set');
  client ??= new Stripe(SECRET_KEY, {
    apiVersion: STRIPE_API_VERSION as Stripe.LatestApiVersion,
    httpClient: Stripe.createFetchHttpClient(),
    maxNetworkRetries: 2,
    timeout: 20_000,
    appInfo: { name: 'myglo-edge', url: 'https://myglo.app' },
  });
  return client;
}

/** Web Crypto, for verifying webhook signatures in Deno. */
export const cryptoProvider = Stripe.createSubtleCryptoProvider();

/** Whether the configured key is a live-mode key. */
export function stripeLivemode(): boolean {
  return SECRET_KEY.startsWith('sk_live_') || SECRET_KEY.startsWith('rk_live_');
}

/**
 * Whether a failed Stripe call may succeed if tried again later: network
 * problems, rate limits, Stripe-side errors and an idempotent request still
 * in flight. Everything else (bad request, permissions, a declined card)
 * fails the same way every time.
 */
export function isTransientStripeError(error: unknown): boolean {
  if (!(error instanceof Stripe.errors.StripeError)) return true;
  if (
    error instanceof Stripe.errors.StripeConnectionError ||
    error instanceof Stripe.errors.StripeRateLimitError ||
    error instanceof Stripe.errors.StripeAPIError
  ) {
    return true;
  }
  const status = error.statusCode ?? 0;
  return status === 409 || status >= 500 || error.code === 'lock_timeout';
}

/** A short, log-safe description of a Stripe error. */
export function describeStripeError(error: unknown): string {
  if (error instanceof Stripe.errors.StripeError) {
    return [error.type, error.code, error.statusCode, error.message].filter(Boolean).join(' · ');
  }
  return error instanceof Error ? error.message : String(error);
}
