# Card payments (Stripe)

Myglo uses Stripe Connect with **separate charges and transfers**:

- **Charging.** Clients are charged on Myglo's (Nexotec's) own Stripe account.
  Nexotec is the merchant of record.
- **Paying providers.** Each provider has a connected account (Accounts v2,
  Express Dashboard). Their share is transferred once the appointment is
  completed, minus the Myglo fee.
- **Payouts.** Stripe pays providers out weekly, on Mondays.
- **Cash** works as before: always a request, and never a fee.

Server pieces:

| Piece | What it does |
|---|---|
| `private.jobs` + `jobs-worker` | Runs every Stripe call that follows a booking change (capture, cancel, refund, transfer), with idempotency keys and retries. |
| `connect` | Creates a provider's connected account, makes onboarding links, refreshes status, and opens their Express Dashboard. |
| `payments` | Card checkout for clients: creates (or reuses) the booking's PaymentIntent for Stripe's payment sheet, and checks Stripe when the app is waiting for the outcome. |
| `stripe-webhook` | Receives Stripe events: `/platform`, `/connect` and `/v2`, each with its own signing secret. |
| `private.provider_payout_accounts` | Each provider's account state. `provider_booking_settings.card_ready` says whether they can take card payments. |
| `apply_payment_intent_state()` | The only place a PaymentIntent's state reaches a booking. The webhook, the `payments` function and the jobs worker all fetch the PaymentIntent from Stripe and pass it here. |

### How a card booking moves

1. **Checkout.** The client picks "Card or Apple Pay / Google Pay". `create_booking`
   makes the booking `awaiting_payment`: it holds the time for
   `checkout_hold_minutes` (15) and the provider can't see it yet.
2. **Payment sheet.** `payments` creates a PaymentIntent for the amount the
   database set (cards only; Apple Pay and Google Pay are card payments).
   Instant bookings are charged straight away. Bookings that need the
   provider's approval are a **hold** (manual capture).
3. **Stripe's answer** (webhook, or the app's sync call):
   - paid: the booking is `confirmed`, and both sides are told;
   - card held: the booking is a `pending` request, which must be answered
     by `respond_by`. That's the earliest of the appointment start,
     `card_request_response_hours` (144) after the hold, and 2 hours
     before the hold on the card lapses.
4. **The provider answers.** Accepting captures the hold; declining, or not
   answering in time, releases it. Both run as background jobs.
5. **Unfinished checkouts** close when the hold on the time runs out. The
   PaymentIntent is cancelled first, so a payment made at the last moment
   still counts. Money that arrives on a checkout that's already closed is
   refunded automatically. Starting a new booking, or leaving the payment
   step, gives up the client's unfinished checkout straight away.

Card payments are only offered for appointments up to `card_max_advance_days`
(60) ahead, because Stripe can hold funds for a limited time. All three
settings are under **Settings → Platform settings** in the admin area.

Holds route co-badged debit cards over Visa/Mastercard, since eftpos can't
place holds. The app doesn't enable eftpos for Apple Pay, which avoids
Stripe's known failure for eftpos Apple Pay holds. The payment screen shows
the dual-network notice that Australian least-cost routing requires.

Refunds for cancelled or missed card bookings, transfers to providers and
disputes come with the payment lifecycle milestone.

## Set-up (sandbox first, then live)

Do these in the **MYGLO sandbox** now, then again in live mode before launch
(live mode needs the Nexotec account activated).

### 1. Connect platform

In the Stripe Dashboard, open **Connect**:

1. **Get started**: choose **Marketplace**. Complete the **platform profile**
   and accept that the platform is responsible for losses (refunds and
   disputes on connected accounts).
2. **Settings → Connect → Branding**:
   - name: Myglo
   - icon: the app icon
   - brand colour: `#FC69C3`
3. **Settings → Connect → Express Dashboard → Features**: turn **off**
   *Issue refunds*, *Manage disputes* and *manual payouts*. Myglo handles
   refunds and disputes, and payouts are weekly.
4. **Settings → Connect → Onboarding options → Countries**: Australia only.
5. If the Dashboard offers **Accounts v2**, turn it on.

### 2. Payment methods

**Settings → Payment methods** for the platform account:

- **On:** Cards, Apple Pay, Google Pay.
- **Off:** Link, Klarna, Zip and everything else. Afterpay comes later.

### 3. API keys

1. **Developers → API keys → Create restricted key**, named
   `myglo-supabase-functions`. Give it **only** these permissions:

   | Resource | Access |
   |---|---|
   | PaymentIntents | Write |
   | Charges | Read |
   | Refunds | Write |
   | Disputes | Read |
   | Balance, Balance transactions | Read |
   | Events | Read |
   | Connect: Accounts (v1 and v2) | Write |
   | Connect: Account links | Write |
   | Connect: Login links | Write |
   | Connect: Transfers (incl. reversals) | Write |
   | Connect: Balance settings | Write |
   | Connect: Payouts | Read |

   If a function later logs a Stripe permission error, it names the missing
   permission. Add it to this key; don't switch to the unrestricted secret key.

2. Save the key as a Supabase Edge Function secret **yourself**. Either use
   **Dashboard → Edge Functions → Secrets**, or run:

   ```bash
   supabase secrets set STRIPE_SECRET_KEY=rk_test_... --project-ref oyveznxdnbduqgaddklr
   ```

   Never paste secret keys into chats, issues or the repo.

3. Put the **publishable** key (`pk_test_...`) in the app's `.env` as
   `STRIPE_PUBLISHABLE_KEY`. It's public by design. The app uses it from the
   card checkout milestone onward.

### 4. Webhooks (event destinations)

Go to **Developers → Webhooks → Add destination**. Create three destinations,
all with API version **2026-09-30.endive**:

| Destination | Events from | Payload | URL | Events |
|---|---|---|---|---|
| Myglo platform | Your account | Snapshot | `https://oyveznxdnbduqgaddklr.supabase.co/functions/v1/stripe-webhook/platform` | `payment_intent.succeeded`, `payment_intent.amount_capturable_updated`, `payment_intent.payment_failed`, `payment_intent.canceled`, `payment_intent.processing`, `charge.refunded`, `charge.refund.updated`, `refund.updated`, `refund.failed`, `charge.dispute.created`, `charge.dispute.updated`, `charge.dispute.closed`, `charge.dispute.funds_withdrawn`, `charge.dispute.funds_reinstated`, `transfer.created`, `transfer.reversed`, `transfer.updated` |
| Myglo provider payouts | Connected accounts | Snapshot | `…/stripe-webhook/connect` | `payout.created`, `payout.updated`, `payout.paid`, `payout.failed`, `payout.canceled` |
| Myglo provider accounts | Connected accounts | Thin (v2) | `…/stripe-webhook/v2` | `v2.core.account.updated`, `v2.core.account[requirements].updated`, `v2.core.account[configuration.recipient].capability_status_updated`, `v2.core.account.closed` |

Save each signing secret (`whsec_...`) as a Supabase secret:
`STRIPE_WEBHOOK_SECRET_PLATFORM`, `STRIPE_WEBHOOK_SECRET_CONNECT` and
`STRIPE_WEBHOOK_SECRET_V2`.

### 5. Other secrets

| Secret | Value |
|---|---|
| `SENTRY_DSN_FUNCTIONS` | DSN of the Sentry project for server errors (it can be the app's project). |
| `ADMIN_ALERTS_EMAIL_FROM` | Optional. Defaults to `Myglo alerts <alerts@myglo.app>`. |
| `CONNECT_RETURN_URL` / `CONNECT_REFRESH_URL` | Optional. Default to `https://myglo.app/stripe/connect/return` and `/refresh`. |

### 6. Website pages for Connect onboarding

Stripe sends providers back to two pages when they finish or leave
onboarding. Add both to the myglo.app site:

- `/stripe/connect/return`: "You're all set. Go back to the Myglo app; your
  payout status updates there."
- `/stripe/connect/refresh`: "This link expired. Go back to the Myglo app and
  tap **Continue with Stripe** for a new one."

They need no logic. The app refreshes the provider's status when they return
to it, and the webhook keeps it current. Once iOS Associated Domains are set up
(see `docs/share_links.md`), these paths can open the app directly.

### 7. Before going live

- **Apple Pay:** Sam creates a Merchant ID in the Apple Developer account
  (for example `merchant.app.myglo`), then makes the Apple Pay certificate in
  Stripe (**Settings → Payment methods → Apple Pay → iOS certificates**).
  Then add the Apple Pay capability to `ios/Runner` and set
  `APPLE_PAY_MERCHANT_ID` in `.env`.
- **Google Pay:** request production access in the Google Pay & Wallet Console.
- **Live mode:** repeat steps 1–5 in live mode with new keys and secrets.
  Then set the Myglo fee (5.5%) and fee-free period (14 days) in the admin
  area under **Settings → Platform settings**.
- **Legal and accounts:**
  - Terms and Privacy must cover: payment at booking, holds for requests,
    funds held until the appointment, the 24-hour problem window, refunds and
    the late-cancellation fee.
  - The accountant decides GST on the fee.
  - Upgrade Supabase to Pro (backups) before real money flows.

## Test cards (sandbox)

| Card | Behaviour |
|---|---|
| 4242 4242 4242 4242 | Succeeds |
| 4000 0025 0000 3155 | Needs 3D Secure |
| 4000 0000 0000 9995 | Declined (insufficient funds) |
| 4000 0000 0000 0259 | Succeeds, then disputed |

Use any future expiry, any CVC and any postcode. For Connect onboarding in the
sandbox, use Stripe's test data: phone `000 000 0000`, SMS code `000-000`,
BSB `110-000` and account `000123456`.
