# Account deletion

Clients and providers delete their own account in the app: **Account
Settings → Delete Account** (clients) or **Settings → Privacy & security →
Delete account** (providers). This is what the App Store (guideline
5.1.1(v)) and Google Play require.

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

`supabase/tests/account_deletion.sql` runs the whole flow inside a
rolled-back transaction (see `supabase/tests/jobs.sql` for how to run it).
App side: `test/account_deletion_test.dart`.
