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

## Push notifications

Every in-app notification is also pushed to the recipient's phone through
Firebase Cloud Messaging, except ones about something they did themselves.
Push is live on **Android**; iOS follows once APNs is set up (see below).

```
private.notify ──► public.notifications                      (in-app, as before)
              ├──► private.notification_deliveries 'email'   (important events)
              └──► private.notification_deliveries 'push'    (recipient has a registered phone)
                              │
                              ▼
            Edge Function send-notifications ──► FCM HTTP v1 ──► phone
```

- **Devices.** After sign-in the app registers this install's FCM token with
  `register_push_token` (tokens live in `private.push_tokens`, reachable only
  through RPCs). Signing out calls `unregister_push_token` first, and a token
  is re-assigned when someone else signs in on the same phone. FCM's
  "unregistered" replies prune dead tokens automatically.
- **Asking for permission.** Never on launch. Providers see a "Never miss a
  booking request" card on their home screen; clients see one on the booking
  confirmation. Both settings screens have a Push notifications switch;
  when Android has blocked notifications it opens the system settings.
- **What a push looks like.** Title and body are the notification's own.
  Android posts it to the "Bookings" channel (high importance) with the
  Myglo icon. A repeat delivery replaces the earlier one instead of stacking.
  Pushes older than 2 hours are skipped (the inbox still has them).
- **Tapping one** opens the booking (`/booking/:id` for clients,
  `/appointments/:id` for providers), including when it launched the app.
  With the app open, nothing is shown by the system: the in-app banner
  covers it.

### To do: turn on sending

Until this is done, push deliveries are queued and retried, then marked
`failed`; in-app and email keep working.

1. Firebase console → Project settings → **Service accounts** → *Generate new
   private key*. This downloads a JSON file. Keep it out of the repo and chat.
2. Store the whole JSON as an Edge Function secret:

   ```bash
   supabase secrets set FIREBASE_SERVICE_ACCOUNT="$(cat path/to/service-account.json)" --project-ref oyveznxdnbduqgaddklr
   ```

   or Dashboard → Edge Functions → Secrets (paste the JSON as the value).

Check deliveries with the query above (`channel = 'push'`).

### To do: iOS

1. Apple Developer → Keys → create an **APNs** key (`.p8`) and upload it in
   Firebase → Project settings → Cloud Messaging → Apple app configuration.
2. In Xcode, add the **Push Notifications** capability and **Background
   Modes → Remote notifications** to the Runner target (needs a provisioning
   profile with push enabled).
3. Enable iOS in the app: `FirebasePushMessaging.isSupported` (in
   `lib/src/features/shared/notifications/push/push_messaging.dart`) and the
   `'android'` platform passed to `register_push_token` in
   `push_notifications_controller.dart`.
