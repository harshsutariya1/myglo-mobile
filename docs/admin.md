# Admin accounts and the admin area

The admin area lives inside the Myglo app. Admin accounts are separate,
admin-only accounts: they never have a client or provider profile, and a
client or provider account can't be made an admin.

## How access is enforced

Nothing in the app grants admin access. The app only routes admin accounts to
the admin area; the database decides what they can do.

- **Admin list.** `private.admins` lists admin accounts. Only the database
  owner (SQL editor or migrations) can change it, and no API role can read it.
- **Every admin RPC** (`public.admin_*`) starts with `private.require_admin()`.
  That function checks four things in the caller's JWT:
  1. The caller is in `private.admins`. Otherwise it raises `admin_required`.
  2. The session is `aal2`, meaning it passed TOTP. Otherwise it raises
     `mfa_required`.
  3. The last TOTP was within **12 hours**. Otherwise it raises
     `admin_session_expired`.
  4. For sensitive changes (fees and settings, refunds, suspensions, hiding
     content), the last TOTP was within **5 minutes**. Otherwise it raises
     `reauth_required`, and the app asks for a new code and retries.
- **Stripe and Auth admin calls** never run from the app. A sensitive admin
  action queues a job in the same transaction that checked the admin and
  wrote the audit log. The `jobs-worker` Edge Function then carries it out
  with Stripe's or Auth's own keys.
- **Audit log.** Every admin change is written to `private.admin_audit_log`
  in the same transaction. It records the admin, the action, the target, the
  reason, before/after values, the session id and the assurance level. The
  table rejects `UPDATE`, `DELETE` and `TRUNCATE` for everyone, including the
  owner.
- **Idle lock.** The app locks the admin area after 15 minutes idle or in the
  background, and asks for a code again. The server limits above apply
  regardless.

## Add an admin

1. Use a dedicated email, such as `harsh.admin@myglo.app`. Don't use the
   email of a client or provider account.
2. In the Supabase dashboard, go to **Authentication → Users → Add user →
   Create new user**. Enter the email and a strong password, and tick
   **Auto Confirm User**.
3. In **SQL Editor**, run:

   ```sql
   insert into private.admins (user_id, display_name)
   select id, 'Harsh' from auth.users where email = 'harsh.admin@myglo.app';
   ```

   It fails with `admin_account_has_profile` if that account already has a
   client or provider profile.
4. Sign in to the app with that email and password. The app asks you to set up
   an authenticator (Google Authenticator, 1Password, Microsoft Authenticator…):
   - Tap **Open in authenticator app**, or copy the setup key into the app.
   - Enter the 6-digit code it shows.

   Every later sign-in asks for a code.

## Remove an admin

```sql
delete from private.admins
where user_id = (select id from auth.users where email = 'old.admin@myglo.app');
```

Their next request is refused. Their audit history is kept. Delete the auth
user too if the account isn't needed any more.

## Reset a lost authenticator

Another admin (or the database owner) removes the admin's TOTP factor. The
admin then sets up a new authenticator at their next sign-in.

```sql
delete from auth.mfa_factors
where user_id = (select id from auth.users where email = 'harsh.admin@myglo.app');
```

If the account might be compromised, also change its password in
**Authentication → Users**, which signs out its sessions.

## Useful audit queries

```sql
-- Last 50 admin changes
select created_at, admin_email, action, target_type, target_id, reason, before, after
from private.admin_audit_log order by id desc limit 50;

-- Everything done to one account or booking
select * from private.admin_audit_log
where target_id = '<uuid>' order by id;
```

## Moderation

### Reports

Clients and providers report posts, comments, reviews and providers from the
app's menus. Clients also report a problem with a booking, from its start
until **Problem reports allowed after the end** (24 h) after it ends.

- Reports are private. The reported person isn't told who sent them.
- A person can have one open report per thing they report. They can send at
  most 20 reports a day.
- Every report emails the admins. Safety, harassment and booking reports are
  marked **[Action needed]**.
- A booking report **holds the provider's share** until an admin closes it.

The **Moderation** tab lists open, resolved and dismissed reports. Open one to
see what was reported, then:

- **Hide** the post, comment or review (fresh code). Hidden content is
  visible only to its author. A hidden review also leaves the provider's
  rating, and its photos are hidden with it. **Show again** reverses it.
- Jump to the **author's account**, the **reporter**, or the **booking and
  payment** to refund or cancel.
- **Resolve** (something was done) or **Dismiss** (nothing needed), with a
  note. Closing the last open report on a booking releases the provider's
  share, unless it's held for another reason. Refund first if the client is
  owed money.

### Suspending an account

On an account's page (**People**), **Suspend account** needs a reason and a
fresh code. A suspension:

- bans the account in Supabase Auth through the jobs worker, so it can't sign
  in or refresh its session. A session already open lasts at most until its
  access token expires (an hour);
- makes the database refuse every change the account tries in the meantime:
  posts, comments, likes, reviews, bookings, profile and settings;
- removes a suspended provider from search, the map and booking;
- optionally cancels the account's upcoming bookings on Myglo's behalf. Card
  payments are refunded in full and both sides are told.

**Lift suspension** reverses the ban and the write block. Cancelled bookings
stay cancelled.

### Stopping a provider's bookings

**Stop new bookings** (providers only, fresh code) removes the provider from
search, the map and free times, and refuses new bookings. Their existing
bookings go ahead and they can still use the app. **Allow bookings** reverses
it.

### Queries

```sql
-- Open reports, oldest first
select created_at, target_type, reason, details from public.reports
where status = 'open' order by created_at;

-- Accounts that are suspended or can't be booked
select u.email, r.* from private.user_restrictions r join auth.users u on u.id = r.user_id
where r.suspended_at is not null or r.bookings_blocked_at is not null;
```

## Platform settings

All settings live in `private.platform_settings` and are edited from
**Settings → Platform settings** in the admin area. Each change needs a reason
and a fresh code, and is audited. Fee changes apply to bookings made after the
change; existing bookings keep the fee they were made with.

| Setting | Default | Allowed |
|---|---|---|
| Myglo fee | 0% (development) | 0–100% |
| Fee-free period, from a provider's first card payments | 0 days | 0–3650 |
| Default free-cancellation window (new providers) | 24 h | 0–168 h |
| Default late-cancellation fee (new providers) | 0% | 0–100% |
| Checkout hold while a client pays | 15 min | 5–60 min |
| Reply time for card requests | 144 h | 1–156 h |
| Card bookings up to | 60 days ahead | 1–85 days |
| Card bookings auto-complete after the end | 24 h | 1–168 h |
| Problem reports allowed after the end | 24 h | 1–168 h |
| Map provider | Google | Google only in v1 |
