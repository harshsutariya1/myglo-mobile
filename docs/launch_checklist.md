# Launch checklist

What is left before the app goes to the App Store and Google Play, in the
order to do it. Status as of 2026-11-24. Everything that could be done in
code is done (see "Done" at the end); what remains needs approval, a
dashboard, an account, a device or a decision.

## 1. Database migrations — done 2026-11-24

All six are applied to the live project (versions in
`supabase/migrations/README.md`), every check in `supabase/tests/` passed in
rolled-back transactions, and the `delete-account` function is redeployed
(version 2). The platform fee is now 0%.

- [ ] `spatial_ref_sys` is still writable by anonymous API users (Supabase
      owns the table, so the migration couldn't revoke it). Open a Supabase
      support ticket asking them to revoke anon / authenticated writes on
      `public.spatial_ref_sys`, or to enable RLS on it.

Testers on build 1.0.0+4 now need a phone number to finish onboarding (the
old build lets them skip it and the server refuses). Ship 1.0.0+5 to testers
soon.

## 2. Merge the code

- [ ] Review and merge the pull request in **myglo-mobile**
      (`claude/mobile-app-production-readiness-04lsyh` → `main`). CI runs
      analyze, the 612 tests and an Edge Function type-check on it.
- [ ] Review and merge the pull request in **myglo-website**
      (→ `master`), so Netlify publishes `/delete-account`.

## 3. Supabase dashboard (Authentication)

- [ ] Emails → Templates → **Reset password**: paste
      `supabase/templates/recovery.html`. Without it the in-app password
      reset can't be finished (the email has a link, not a code).
- [ ] Providers → Email: minimum password length **8**.
- [ ] Providers → Email: turn on **Prevent use of leaked passwords**.
- [ ] Providers → **Phone**: enable, enter the SMS provider's credentials,
      keep **Enable phone confirmations ON**, SMS OTP length 6, message
      `Your Myglo code is {{ .Code }}. Don't share it.`
- [ ] Rate limits: an hourly SMS limit (for example 30).

## 4. Accounts only you (or Sam) can open or change

- [ ] **SMS provider** (Twilio or similar): open the account and register
      an Australian sender ID or number. A few cents per text. Phone
      verification sends nothing until this exists.
- [ ] **Sentry**: revoke the auth token committed in `4aba69c`
      (`sentry.properties`, still in git history) and create a new one.
- [ ] **Stripe** (Sam): activate live mode; create the three live webhook
      destinations (`docs/payments.md`); register Apple Pay merchant
      `merchant.app.myglo`; then set the Edge Function secrets
      `STRIPE_SECRET_KEY` (live restricted key) and
      `STRIPE_WEBHOOK_SECRET_PLATFORM`, `_CONNECT`, `_V2` together.
- [ ] Edge Function secret `SENTRY_DSN_FUNCTIONS`: check it's set and a
      test error reaches Sentry.
- [ ] **Google Cloud** (Sam): restrict the Android Maps key to package
      `app.myglo.myglo` and the Play signing certificate, and the iOS key to
      bundle id `app.myglo.myglo`.

## 5. Release build (on your Mac)

- [ ] `.env` with production values: `SUPABASE_URL`, `SUPABASE_ANON_KEY`,
      `SENTRY_DSN`, `STRIPE_PUBLISHABLE_KEY` (`pk_live_…`),
      `APPLE_PAY_MERCHANT_ID`.
- [ ] `ios/Flutter/Secrets.xcconfig` (`GOOGLE_MAPS_API_KEY`) and
      `android/local.properties` (`MAPS_API_KEY`).
- [ ] `android/key.properties` and the upload keystore (backed up).
- [ ] `SENTRY_AUTH_TOKEN` (the new one) for symbol uploads.
- [ ] `scripts/shorebird_build.sh release android` and `… ios`. The version
      is already 1.0.0+5. This must be a store release, not a patch.
- [ ] In the iOS archive, check the push entitlement says `production`.

## 6. Website and legal

- [ ] `public/.well-known/assetlinks.json`: add the **Play App Signing**
      certificate SHA-256 (Play Console → App integrity).
- [ ] Privacy Policy and Terms (the PDFs in `public/legal/`): say that a
      provider's phone and email are shown to clients, that phone numbers
      are verified by SMS, that users can block each other, and how
      accounts are closed (clients in the app, providers through support).
      `/delete-account` promises a reply to emailed deletion requests within
      30 days; change the page if that isn't right.

## 7. Store listings

App Store Connect:
- [ ] Privacy labels: name, email, phone, location, photos, payment info
      (Stripe), crash and usage data (Sentry, including session replay).
- [ ] Privacy policy URL `https://myglo.app/privacy`.
- [ ] iPhone screenshots (the app no longer runs on iPad).
- [ ] Review notes and logins: a client and a provider account, a
      bookable provider, and a note that providers close their account
      through support. If a reviewer insists on in-app deletion for
      providers: Admin → Platform settings → Accounts → "Providers can
      delete their own account" (no new build needed).

Google Play Console:
- [ ] Data safety form (same data as above).
- [ ] App content → Data deletion: `https://myglo.app/delete-account`.
- [ ] App access: the same review logins.
- [ ] Content rating and target audience questionnaires.

## 8. Test on real devices (Android and iPhone)

- [ ] Sign up → code → onboarding (phone required) → home, as a client and
      as a provider.
- [ ] Forgot password, and Change password.
- [ ] Provider: verify phone with a real SMS; hide and show the business.
- [ ] Block and unblock from a post, a comment and a provider profile.
- [ ] Admin: close a test account.
- [ ] A live card booking with a real card, then refund it.
- [ ] Push notifications, Terms / Privacy / Contact support.

## 9. On launch day

- [ ] Delete the 20 demo salons (`supabase/seed/fake_salons_cleanup.sql`)
      and the test bookings and accounts, once reviewers no longer need
      them.

## Done (in code, 2026-11-11 to 2026-11-24)

Password reset and change; provider "hide my business"; providers can't
self-delete (server setting, admin switch); phone verification; phone
required for everyone; contact details shown by role; Terms and Privacy
links; blocking; admin account closure; placeholder features removed;
iPhone-only; build 1.0.0+5; CI; Edge Function type-checks;
`/delete-account` page on the website; migrations documented against the
live database; platform fee 0% (in migration 6).
