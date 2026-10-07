# Booking notifications

How clients and providers hear about bookings, what is already set up on the
`MyGlo_App` Supabase project, and what still needs doing.

## How it works

```
create_booking / respond / cancel / complete / no-show RPC
        │  (same transaction)
        ▼
private.on_booking_event ──► public.notifications            in-app inbox + banner (Realtime)
                        └──► private.notification_deliveries  email outbox (one row per email)
                                      │  after commit, via pg_net
                                      ▼
                         Edge Function: send-notifications ──► Resend ──► inbox
```

- **In-app.** Every booking change writes a row to `public.notifications` for
  each party. The app subscribes over Realtime: the bell badge, the
  notifications screen and the top-of-screen banner update live. Rows the
  signed-in user caused themselves are stored as already read and never pop a
  banner.
- **Email.** Important events also queue an email in
  `private.notification_deliveries` (an outbox). A trigger calls the
  `send-notifications` Edge Function through `pg_net` after the transaction
  commits, so a failed email can never roll back a booking. The function
  claims due rows (`FOR UPDATE SKIP LOCKED`), sends them through Resend with an
  idempotency key, and records the result. Failures retry with back-off; a
  cron sweep picks up anything missed.
- **Scheduled jobs** (`pg_cron`, all active):

  | Job | Schedule | What it does |
  | --- | --- | --- |
  | `myglo-expire-booking-requests` | every 5 min | Expires requests nobody answered before the start time and tells both sides |
  | `myglo-booking-reminders` | every 10 min | Day-before reminder (email + in-app) and a 2-hour in-app reminder |
  | `myglo-booking-request-reminders` | every 5 min | Reminds providers about requests they haven't answered (see below) |
  | `myglo-notification-delivery-sweep` | every minute | Re-sends emails that are due for a retry |

### Who gets what

| Event | Client | Provider |
| --- | --- | --- |
| Booking confirmed instantly (paid in the app, provider doesn't approve bookings; not live yet) | Booking confirmed (email) | New booking (email) |
| Request sent (every cash booking, or the provider approves bookings) | Request sent (email) | New booking request (email) |
| Request accepted | Booking confirmed (email) | — |
| Request declined | Request declined (email) | — |
| Client cancels | Booking cancelled (email) | Booking cancelled, with late-cancellation fee if any (never for cash) (email) |
| Provider cancels | Booking cancelled (email) | — |
| Request still unanswered | — | Request waiting for you, then Respond before it expires (email + in-app each) |
| Request expires | Request expired (email) | Request expired (in-app) |
| Completed | Thank-you (in-app) | — |
| No-show | Missed appointment (email) | — |
| Reminders | Day before (email), 2 hours before (in-app) | — |

### Reminders about unanswered requests

A request nobody answers expires at its start time, so the provider gets up to
two reminders, timed by how far ahead the request was made (T):

1. **Request waiting for you**: once it has waited 2 hours, or half of T if
   that's sooner.
2. **Respond before it expires**: 24 hours before the start, or a quarter of T
   before it if that's later.

| Request made | Reminder 1 | Reminder 2 |
| --- | --- | --- |
| 14 days ahead | 2 h after | 24 h before start |
| 24 hours ahead | 2 h after | 6 h before start |
| 5 hours ahead | 2 h after | 1 h 15 min before start |
| 2 hours ahead | 1 h after | 30 min before start |

Nothing is sent within 15 minutes of the start, once the provider responds, or
after the client withdraws. Each reminder goes out at most once
(`bookings.request_reminder_sent_at`, `request_final_reminder_sent_at`). There
are no quiet hours yet: emails can arrive overnight. Revisit when push
notifications land.

All times in notifications are Gold Coast time (AEST, UTC+10; Queensland has
no daylight saving).

## Already done

- Migrations `20261005120000_booking_engine.sql`,
  `20261005130000_booking_notifications.sql` and
  `20261005140000_booking_details_provider_fee.sql` are applied.
- Vault secrets the trigger uses to reach the function:
  - `project_url`: `https://oyveznxdnbduqgaddklr.supabase.co`
  - `notifications_function_key`: the project's anon (legacy JWT) key. It
    only lets the trigger *call* the function; the function itself uses the
    service-role key that Supabase injects, and only the service role can
    claim or complete deliveries.
- Edge Function `send-notifications` is deployed with JWT verification on.

## To do: turn on email

Until this is done, emails wait in the outbox (they are skipped once they're
more than 12 hours old, so nobody gets a stale "your booking is tomorrow").
In-app notifications already work.

1. **Verify the sending domain in Resend.** Add `myglo.app` (or the domain
   you'll send from) in the Resend dashboard and create the SPF and DKIM DNS
   records it lists. Mail from an unverified domain is rejected.
2. **Create an API key** in Resend with *Sending access* only.
3. **Store it as an Edge Function secret** (never in the app or the repo):

   ```bash
   supabase secrets set RESEND_API_KEY=re_xxx --project-ref oyveznxdnbduqgaddklr
   ```

   or Dashboard → Edge Functions → Secrets.
4. *(Optional)* Change the sender, which defaults to
   `Myglo <bookings@myglo.app>`:

   ```bash
   supabase secrets set NOTIFICATIONS_EMAIL_FROM="Myglo <bookings@myglo.app>" --project-ref oyveznxdnbduqgaddklr
   ```

Supabase makes new secrets available to the function without a redeploy.

### Checking it works

Make a test booking, then:

```sql
-- Latest deliveries and their state.
select d.status, d.attempts, d.last_error, d.sent_at, n.kind, n.title
from private.notification_deliveries d
join public.notifications n on n.id = d.notification_id
order by d.created_at desc
limit 20;
```

`sent` means Resend accepted it. `retry` with `last_error` explains what went
wrong (e.g. a missing key or an unverified domain); `failed` means Resend
rejected it permanently. Function logs are under Edge Functions →
`send-notifications` → Logs.

## Later: push notifications

Push isn't wired up yet; the outbox already accepts a `push` channel, so it
slots in without changing the booking logic.

1. **Firebase project** (under the Google account that owns Google Cloud).
   Add the iOS app (`app.myglo.myglo`) and the Android app.
2. **APNs key.** In the Apple Developer account create an APNs auth key
   (`.p8`) and upload it to Firebase → Project settings → Cloud Messaging.
3. **App side** (needs approval for new packages: `firebase_core`,
   `firebase_messaging`):
   - `flutterfire configure` to generate the Firebase options.
   - iOS: enable the *Push Notifications* and *Background Modes → Remote
     notifications* capabilities.
   - Android 13+: request the `POST_NOTIFICATIONS` permission at a sensible
     moment (e.g. after the first booking), not on launch.
   - After sign-in (and whenever the token refreshes) save the device token;
     delete it on sign-out.
   - Opening a notification should route to `/booking/:id` (client) or
     `/appointments/:id` (provider), as the in-app banner already does.
4. **Database:** a `public.push_tokens` table (user id, token, platform,
   updated at) with RLS so users only manage their own tokens; have
   `private.notify` also queue a `push` delivery when the recipient has
   tokens.
5. **Edge Function:** send `push` deliveries through the FCM HTTP v1 API using
   a Firebase service account stored as a function secret, and delete tokens
   FCM reports as unregistered.
