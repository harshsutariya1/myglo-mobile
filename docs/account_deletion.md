# Account deletion

**Clients** delete their own account in the app: **Account Settings →
Delete Account**.

**Providers** don't, by default. They hide their business instead
(**Settings → Privacy & security → Hide my business**, see below) and email
support to close the account for good. Whether providers may delete their own
account is the platform setting `provider_self_deletion` (off by default),
enforced by the server and read by the app through `get_app_config`:

- Off: the provider settings screen has no "Delete account" row, and
  `begin_account_deletion` / `get_my_account_deletion_status` report the
  blocker `provider_deletion_disabled` for a provider who gets there anyway.
- On: providers get the same flow as clients, with the provider blockers
  below. Turn it on without an app release:

  ```sql
  UPDATE private.platform_settings SET provider_self_deletion = true WHERE id;
  ```

  or, in the app as an admin: **Admin → Settings → Platform settings →
  Accounts → "Providers can delete their own account"**.

> **Store review risk.** The App Store (guideline 5.1.1(v)) and Google Play
> require that anyone who can create an account in the app can also start
> deleting it in the app. Offering providers only "hide" plus an email
> address may be rejected. If a reviewer objects, turn the setting on.

**Closing a provider's account on request** (support): check it's the
account owner asking, then run `SELECT public.delete_account('<user id>');`
as the service role. It applies every blocker below except
`provider_deletion_disabled`, and queues the same clean-up jobs. The Stripe
balance check lives in the Edge Function, so check the connected account's
balance is empty in the Stripe Dashboard first.

## Hiding a business (providers)

`provider_booking_settings.hidden_from_marketplace`, set by the provider
(migration `20261112120000_provider_marketplace_visibility`). While hidden:

- they're left out of search, the map, the client home list, city counts,
  provider tagging in posts and the Discover feeds;
- they have no free times and can't be booked (`provider_not_accepting`),
  by any path;
- nothing is deleted: profile, services, reviews and posts are kept, and
  existing bookings carry on (the provider still answers, completes and is
  paid for them; clients still see them);
- a client who opens their profile from a favourite, an old booking or a
  shared link still sees it, without any times to book.

Showing the business again undoes all of it at once. The server treats a
hidden provider like one an admin has blocked (`private.is_unlisted`), so
every listing and booking path applies the same rule.

## How it works

```
App: Delete account screen
  │  get_my_account_deletion_status   → what's deleted, what blocks it
  │  password → signInWithPassword    → fresh "password" entry in the JWT amr
  ▼
delete-account (Edge Function, as the user)
  │  begin_account_deletion           → password checked < 10 min ago, no blockers
  │  provider? Stripe balance empty   → else 409 stripe_balance
  ▼
delete_account (service role, one transaction, row locks)
  │  re-checks blockers, scrubs kept records, logs, queues jobs,
  │  DELETE auth.users → cascades
  ▼
jobs-worker: purge_user_storage, close_connect_account (retried; admins
alerted if one fails)
```

The confirmation email goes to the old address (best effort, Resend).

## Blockers

Deletion waits until none of these are true. The screen explains each one.

| Code | Who | Clears when |
|---|---|---|
| `provider_deletion_disabled` | providers | `provider_self_deletion` is turned on (see above); not applied to `delete_account` run by support |
| `admin_account` | admins | never in the app: remove the row from `private.admins` |
| `account_suspended` | suspended users | an admin lifts it, or deletes on request (email) |
| `upcoming_bookings` | both | checkouts, unanswered requests and future confirmed bookings are cancelled or finished |
| `payouts_pending` | providers | settlements are transferred, ended card bookings complete, pending refunds settle |
| `open_disputes` | providers | the dispute closes |
| `stripe_balance` | providers | Stripe pays out the balance (Mondays); checked live by the function |

## What's deleted and what's kept

Deleted: the Auth user (sessions, identities), the profile and everything
that only belongs to it (services, schedule, settings, posts, comments,
likes, favourites, follows, reviews, notifications, push tokens, payout
account row), notifications that name the user, a waitlist row with the same
email, and their files in `profile-pics`, `post-media`, `service-images` and
`cover-photos`. A provider's Stripe connected account is closed.

Kept as financial records (tax law: five years), with the person's id set to
null: bookings, payments, refunds, settlements, payouts, disputes, reports
and booking events. The client's name becomes "Deleted account" and their
phone, notes and home address are removed. A provider's business name stays
on past bookings (it identifies the supplier on the client's receipt); their
studio address is removed. `private.account_deletions` records the user id,
role, closed Stripe account and time, with no personal details.

## Deploying

1. Migration `20261102120000_account_deletion` (applied 2026-11-02).
2. Edge Functions: `delete-account` (new, verify JWT on) and `jobs-worker`
   (new job kinds). Both deployed 2026-11-03 (`delete-account` v1,
   `jobs-worker` v11). To redeploy:

   ```bash
   supabase functions deploy jobs-worker --project-ref oyveznxdnbduqgaddklr
   ```

   ```bash
   supabase functions deploy delete-account --project-ref oyveznxdnbduqgaddklr
   ```

   Deploy `jobs-worker` first, so jobs queued by a deletion find a handler.
3. The Stripe restricted key already has what it needs: Balance (read, used
   on the connected account) and Connect Accounts v2 (write, for closing).
4. Optional secret `SUPPORT_EMAIL` (defaults to `hello@myglo.app`) for the
   confirmation email.

## Store listings

- **Google Play → App content → Data deletion**: needs a web page that tells
  people how to delete their account, including without the app (for
  example `https://myglo.app/delete-account`: the in-app steps, plus "email
  hello@myglo.app from your account's address").
- **Privacy policy**: say that accounts are deleted in the app, and what's
  kept (above).

## Testing

`supabase/tests/account_deletion.sql` (deletion) and
`supabase/tests/marketplace_visibility.sql` (hiding) run the whole flow inside a
rolled-back transaction (see `supabase/tests/jobs.sql` for how to run it).
App side: `test/account_deletion_test.dart`.
