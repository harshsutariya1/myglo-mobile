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

### After the appointment: refunds, transfers, payouts and disputes

Money is worked out only in SQL. The jobs worker just carries out the Stripe
call with the amount the database gave it.

- **Cancellations.**
  - Cancelled in the free window (by anyone), declined, or cancelled by Myglo:
    the client gets a **full refund**. A hold is released instead of charged.
  - Late client cancellation or no-show: the provider keeps the late-fee %
    and the rest is refunded.
- **Completion.** A card booking completes when the provider marks it done,
  or automatically `auto_complete_after_hours` (24) after it ends. Completion
  schedules the provider's **settlement**: the amount kept, minus the Myglo fee
  (`platform_fee_percent` was snapshotted on the booking).
- **Transfers.** A settlement is transferred to the provider's connected
  account with `source_transaction` set to the charge, so it never draws on
  Myglo's balance. It waits (status `held`) while:
  - the provider's payout account isn't active (`payout_account`). It goes
    out by itself once they fix it;
  - a dispute is open (`dispute`);
  - the client has an open problem report on the booking (`report`). It goes
    out when an admin closes the last report;
  - an admin put it on hold (`admin`).
- **Payouts.** Stripe pays each provider's balance to their bank every Monday.
  The `/connect` webhook records each payout and tells the provider when it's
  paid or failed.
- **Disputes.** A new dispute holds the settlement, or reverses the transfer
  if it was already paid. The provider is told and the admins get an email.
  - Won: the provider is paid again.
  - Lost: the client keeps the money and the provider's share stays reversed.
    Stripe's dispute fee is charged to Myglo's balance; it isn't passed on to
    providers.
- **Admin refunds.** An admin can refund any part of what's left from the
  booking's page in the admin area. With **Recover from provider**, the part
  already transferred is reversed from the provider in proportion.

Every Stripe call has an idempotency key (`capture:<booking>`,
`refund:<refund id>`, `transfer:<booking>:<attempt>`…), so a retried job can't
act twice. Webhooks re-fetch the object from Stripe instead of trusting the
event, so events arriving late or out of order are harmless.

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

### 7. Go-live checklist

Tick these in order. Nothing here can be done from the app.

**Accounts and legal**

- [ ] Nexotec's live Stripe account is activated, and its Connect platform
      profile is complete (step 1, in live mode).
- [ ] Terms and Privacy cover: payment at booking, holds for requests, funds
      held until the appointment, the problem-report window, refunds, the
      late-cancellation fee, and that Myglo may suspend accounts and hide
      content.
- [ ] The accountant has decided GST on the Myglo fee (the app's tax-invoice
      tile stays "Soon" until then).
- [ ] Supabase is on Pro (daily backups, point-in-time recovery) before real
      money flows.

**Stripe, live mode**

- [ ] Payment methods set as in step 2.
- [ ] A live **restricted** key with the step 3 permissions, saved as
      `STRIPE_SECRET_KEY`. The webhook ignores events whose mode doesn't
      match the key, so change the key and the signing secrets together.
- [ ] The three live webhook destinations from step 4, and their three signing
      secrets.
- [ ] `STRIPE_PUBLISHABLE_KEY` in the release build's `.env` is `pk_live_…`.
- [ ] **Apple Pay:** Sam creates a Merchant ID in the Apple Developer account
      (for example `merchant.app.myglo`), then makes the Apple Pay certificate
      in Stripe (**Settings → Payment methods → Apple Pay → iOS
      certificates**). Then add the Apple Pay capability to `ios/Runner` and
      set `APPLE_PAY_MERCHANT_ID` in `.env`.
- [ ] **Google Pay:** production access in the Google Pay & Wallet Console.

**Myglo**

- [ ] At least two admin accounts with authenticators (`docs/admin.md`).
- [ ] Leaked-password protection is on (Supabase **Authentication →
      Policies**): admin accounts sign in with a password.
- [ ] Platform settings: Myglo fee 5.5%, fee-free period 14 days (admin area,
      **Settings → Platform settings**).
- [ ] `SENTRY_DSN_FUNCTIONS` is set, and a test error from a function shows up
      in Sentry.
- [ ] The two `myglo.app/stripe/connect/*` pages are live (step 6).
- [ ] A live smoke test with a real card and a small service: book, pay,
      complete, see the transfer in Stripe, then refund it from the admin area.

## Runbooks

Most problems show up in the admin area first: **Payments** lists open
disputes, held shares, failed transfers and failed background jobs. Admins
also get an email for each failed job, dispute and report. Each fix below is
audited.

### A client should get money back

Open the booking (**Payments**, search by reference) → **Refund**. Enter the
amount and a reason. Leave **Recover from provider** on if the provider has
already been paid and should give their part back. The refund runs as a job;
its status shows on the booking.

To cancel an upcoming booking on Myglo's behalf, use **Cancel booking** on the
same page. It refunds in full (or releases a hold) and tells both sides.

### A transfer to a provider failed

The booking shows **Failed** and the job's error. Common causes:

- **The provider's account can't receive transfers.** Their account page
  shows what Stripe needs. Ask them to finish setup in the app's **Payments &
  payouts** screen. The settlement waits and goes out by itself when their
  account is active again; no retry is needed.
- **Anything else** (a Stripe outage, a permission missing from the restricted
  key): fix the cause, then **Retry** the job under **Failed background jobs**.
  The retry uses the same idempotency key, so it can't pay twice.

### A dispute was opened

1. The provider's share is already held (or reversed if it had been paid).
2. Respond in the **Stripe Dashboard → Payments → Disputes** before the
   deadline in the admin email. Myglo responds, not the provider. Useful
   evidence: the booking's history in the admin area, the provider's notes and
   photos, and messages with the client.
3. When Stripe decides, the webhook closes the dispute. A win pays the
   provider again; a loss keeps the share reversed.

### A refund failed

Rare; usually the client's card was closed. The booking shows the refund's
status and Stripe's reason, and the admins get an email from the failed job.
Contact the client and pay them back another way (for example a bank
transfer from Nexotec), and keep a record of it. The provider's share isn't
affected: the money is still in Myglo's balance.

### A job keeps failing

Look at the job's last error under **Failed background jobs**. Jobs retry
with backoff for up to 8 attempts, then alert the admins. After fixing the
cause, **Retry**. If the worker itself is down (every job failing), check the
`jobs-worker` logs in Supabase (**Edge Functions → jobs-worker → Logs**). The
`myglo-jobs-sweep` cron job picks everything up again once it's fixed.

### Webhooks stopped arriving

Check **Developers → Webhooks** in Stripe for failing deliveries. If the
signing secret was rotated, update the matching `STRIPE_WEBHOOK_SECRET_*`
secret. Then resend the failed events from the Stripe Dashboard. Each is
processed once (`private.stripe_events`), so resending is safe. The app's
sync call and the jobs worker also re-read PaymentIntents from Stripe, so
bookings don't stay stuck on a missed event.

### Rotate a key

1. Create the new restricted key (or roll a webhook signing secret) in Stripe.
2. Update the Supabase secret. Functions pick it up on their next start,
   within a minute.
3. Delete the old key in Stripe once the functions' logs show no Stripe auth
   errors.

Never paste keys into chats, issues or the repo.

## Sandbox test run

Run this once after set-up, and again before launch in live mode with a real
card and small amounts. You need one provider account, one client account and
one admin account (with its authenticator). Check results in the admin area
(**Payments**) and in the Stripe Dashboard.

1. **Provider onboarding.** Signed in as the provider: **Business → Payments &
   payouts → Continue with Stripe**. Use Stripe's test data (below). Back in
   the app the status shows card payments as ready, and under **How clients
   pay**, **Pay in the app** is on.
2. **Instant booking.** As the client, book a service and choose **Pay now in
   the app**. Pay with `4242 4242 4242 4242`. The booking is confirmed for
   both sides and shows "Visa •• 4242".
3. **3D Secure.** Book again with `4000 0025 0000 3155` and complete the
   challenge.
4. **Declined card.** `4000 0000 0000 9995` shows the decline, and the same
   checkout can be retried with 4242.
5. **Request with a hold.** Turn on **Approve each booking** for the provider
   (**Settings → Availability & bookings**).
   Book with 4242: the card is held, not charged. Accept it as the provider:
   it's charged. Book another and decline it: the hold is released. A third
   left unanswered expires at its reply-by time.
6. **Cancellations.** Cancel a paid booking inside the free window (full
   refund), and one late (refund minus the late fee).
7. **Completion and transfer.** Mark a paid booking complete as the provider.
   A transfer appears on the provider's connected account in Stripe, and
   **Earnings** shows it.
8. **Problem report.** On a booking that has started, the client taps
   **Report a problem**. The provider's share is held; resolving the report
   in **Moderation** releases it.
9. **Admin refund.** In **Payments**, open a completed booking and refund part
   of it with **Recover from provider** on. Stripe shows the refund and a
   transfer reversal.
10. **Dispute.** Pay with `4000 0000 0000 0259`. A dispute opens a few seconds
    later: the share is held or reversed, the provider is told, and admins get
    an email.
11. **Suspension.** In **People**, suspend the test client (fresh code). They
    are signed out within the hour and can't sign in again; lifting the
    suspension lets them back in.

Each step should leave no failed jobs under **Payments → Failed background
jobs**.

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
