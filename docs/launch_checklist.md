# Launch checklist

Everything that has to be done by hand before the app goes to the App Store
and Google Play, grouped by where it's done. First written 2026-11-11 after
the production-readiness audit; status re-checked against the live Supabase
project on 2026-11-24. Tick items off here as they're done.

## 1. Code

- [ ] Merge branch `claude/mobile-app-production-readiness-04lsyh` into
      `main` (4 commits: audit fixes, password reset, hide business,
      phone verification and contact rules). Nothing below works in the
      app until a build is made from it.

## 2. Supabase database (project `MyGlo_App`)

Checked 2026-11-24: none of these is done.

- [ ] Apply the three migrations, in order (each builds on the one before):
  1. `20261111120000_lock_down_profile_writes_and_storage`
  2. `20261112120000_provider_marketplace_visibility`
  3. `20261113120000_phone_verification_and_contact_rules`

  Apply them before releasing the new build: the build calls functions
  and columns they add.
- [ ] Run the SQL checks inside a rolled-back transaction (see
      `supabase/tests/jobs.sql` for how): `account_deletion.sql`,
      `admin_security.sql`, `marketplace_visibility.sql`,
      `phone_verification.sql`.
- [ ] `spatial_ref_sys`: anyone can still write to it (checked 2026-11-24).
      After migration 1, if it warns "spatial_ref_sys is still writable
      through the API", open a Supabase support ticket asking them to
      revoke anon / authenticated writes on `public.spatial_ref_sys`.
      Until then anyone could break every distance query.
- [ ] Remove the test data: 20 seeded salons (`@seed.myglo.test`, run
      `supabase/seed/fake_salons_cleanup.sql`), 17 test bookings and test
      accounts. Or create a separate production project and point the
      release build at it.
- [ ] Decide the platform fee: it is 5.5% with 0 fee-free days
      (Admin → Platform settings), while the project notes say free for
      now.

## 3. Supabase Auth (dashboard)

- [ ] Emails → Templates → **Reset password**: paste
      `supabase/templates/recovery.html`. Without it the reset email has a
      link, not a code, and the in-app reset can't be finished.
- [ ] Providers → Email: minimum password length **8**.
- [ ] Providers → Email: turn on **Prevent use of leaked passwords** (still
      off on 2026-11-24).
- [ ] Providers → **Phone**: enable, add the SMS provider's credentials,
      keep **Enable phone confirmations ON**, SMS OTP length 6, message
      `Your Myglo code is {{ .Code }}. Don't share it.` See
      `docs/phone_verification.md`.
- [ ] Rate limits: set an hourly SMS limit (for example 30).

## 4. Edge Function secrets (Dashboard → Edge Functions → Secrets)

Email (Resend) and push (Firebase) are working: emails and pushes have been
delivered since October.

- [ ] Stripe live: `STRIPE_SECRET_KEY` (a live restricted key, permissions
      in `docs/payments.md`) and the three live webhook signing secrets
      `STRIPE_WEBHOOK_SECRET_PLATFORM`, `_CONNECT`, `_V2`. Change the key and
      the secrets together: the webhook ignores events from the other mode.
      Only test-mode Stripe events exist so far.
- [ ] `SENTRY_DSN_FUNCTIONS` set, and a test error shows up in Sentry.

## 5. Other accounts

- [ ] **SMS provider** (Twilio or similar): open the account and register
      an Australian sender ID or number. New paid service, a few cents per
      text. Phone verification sends nothing until this exists.
- [ ] **Sentry**: revoke the auth token that was committed in `4aba69c`
      (`sentry.properties`, since deleted from the repo but still in its
      history) and create a new one for symbol uploads.
- [ ] **Stripe** (Sam's account): activate live mode, create the three live
      webhook destinations (`docs/payments.md`), and register the Apple Pay
      merchant id `merchant.app.myglo` with Stripe for live payments.
- [ ] **Google Cloud** (Sam's account): restrict the Android Maps key to
      package `app.myglo.myglo` plus the Play signing certificate, and the
      iOS key to bundle id `app.myglo.myglo`.

## 6. Release build (on the machine that builds)

- [ ] `.env`: production `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SENTRY_DSN`,
      `STRIPE_PUBLISHABLE_KEY` (`pk_live_…`), `APPLE_PAY_MERCHANT_ID`.
      Public values only: `.env` ships inside the app.
- [ ] `ios/Flutter/Secrets.xcconfig` with `GOOGLE_MAPS_API_KEY`, and
      `android/local.properties` with `MAPS_API_KEY`.
- [ ] `android/key.properties` and the upload keystore (backed up in the
      password manager), see `docs/releases_and_updates.md`.
- [ ] `SENTRY_AUTH_TOKEN` (the new one) for symbol uploads.
- [ ] Bump `version:` in `pubspec.yaml` (it is `1.0.0+4`). This has to be a
      store release, not a Shorebird patch: the Android label and the iOS
      Info.plist changed.
- [ ] Build with `scripts/shorebird_build.sh release android` / `ios`.
- [ ] iOS: check the archived build's push entitlement is `production`
      (the entitlements file says `development`; automatic signing should
      switch it for App Store builds).

## 7. Website (myglo.app, Netlify)

- [ ] Add a **delete-account** page (e.g. `https://myglo.app/delete-account`)
      for Google Play's Data deletion field: how clients delete in the app,
      how providers ask support, and "email hello@myglo.app from your
      account's address" for anyone without the app.
- [ ] `/.well-known/assetlinks.json`: add the **Play App Signing**
      certificate SHA-256 (Play Console → App integrity), not only the
      upload key's.
- [ ] Privacy policy and Terms: say that a provider's phone and email are
      shown to clients, that phone numbers are verified by SMS, and how
      accounts are closed (clients in the app, providers through support).

## 8. Store listings

App Store Connect:
- [ ] Privacy labels: email, phone, name, coarse and precise location,
      photos, payment info (Stripe), crash and usage data (Sentry, incl.
      session replay).
- [ ] Privacy policy URL `https://myglo.app/privacy`.
- [ ] iPad: the app is built for iPhone and iPad, so Apple reviews it on
      iPad and needs iPad screenshots. Test it there, or restrict to iPhone
      for v1 (iPad can be added later, never removed).
- [ ] Review accounts: a client and a provider login, a bookable provider,
      and a note that providers hide their business and close accounts
      through support. If the reviewer objects (guideline 5.1.1(v)):
      Admin → Platform settings → Accounts → "Providers can delete their
      own account", no new build needed.

Google Play Console:
- [ ] Data safety form (same data as above).
- [ ] App content → Data deletion: the website page above.
- [ ] App access: the same review logins.
- [ ] Content rating and target audience questionnaires.

## 9. Still to build (blockers for store review)

- [ ] **Blocking users.** Posts and comments can be reported but nobody can
      block anyone; Apple's user-content rules (1.2) expect blocking.
- [ ] **"Soon" features inside flows**: discounts and multiple services in
      Add service, pausing a service, Afterpay, location tags, saving
      posts. Hide them or build them.
- [ ] Admin "close account" action for providers, so support doesn't need
      SQL (`docs/account_deletion.md`). Not a blocker, but needed as soon as
      a provider asks.

## 10. Test on real devices (Android and iOS)

- [ ] Sign up → code → onboarding (phone now required) → home, as a client
      and as a provider.
- [ ] Forgot password from sign-in, and Change password from settings.
- [ ] Provider: verify phone with a real SMS; hide and show the business;
      a hidden provider disappears for a client, existing bookings stay.
- [ ] A live card booking with a real card, then refund it.
- [ ] Push notifications, Terms and Privacy links, Contact support.

## After launch

- [ ] CI (analyze + tests on every push); there is none.
- [ ] Bring the migrations folder and the database back in step: three
      migrations exist only in the database and one only in the repo.
