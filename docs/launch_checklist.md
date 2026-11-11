# Launch checklist

What is left before the app goes to the App Store and Google Play, in the
order to do it. Written 2026-11-11 after the production-readiness audit;
tick items off here as they're done.

## 1. Database (Supabase project `MyGlo_App`)

- [ ] Apply the three migrations, in order (they depend on each other):
  1. `20261111120000_lock_down_profile_writes_and_storage`
  2. `20261112120000_provider_marketplace_visibility`
  3. `20261113120000_phone_verification_and_contact_rules`
- [ ] Run the SQL checks inside a rolled-back transaction (see
      `supabase/tests/jobs.sql` for how): `account_deletion.sql`,
      `admin_security.sql`, `marketplace_visibility.sql`,
      `phone_verification.sql`.
- [ ] `spatial_ref_sys`: after migration 1, check whether the warning
      "spatial_ref_sys is still writable through the API" was raised. If so,
      open a Supabase support ticket asking them to revoke anon /
      authenticated writes on `public.spatial_ref_sys` (the table belongs to
      Supabase, so the project can't do it itself). Until then anyone could
      break every distance query.
- [ ] Remove the test data: run `supabase/seed/fake_salons_cleanup.sql`
      (20 seeded salons) and delete test bookings and test accounts. Or
      create a separate production project and point the release build at
      it.
- [ ] Decide the platform fee: it is 5.5% with 0 fee-free days in
      `private.platform_settings` (Admin → Platform settings), while the
      project notes say free for now.

## 2. Supabase Auth settings (dashboard)

- [ ] Emails → Templates → **Reset password**: paste
      `supabase/templates/recovery.html`. Without it password reset emails
      carry a link, not a code, and the in-app reset can't be finished.
- [ ] Providers → Email: minimum password length **8**; turn on **Prevent
      use of leaked passwords**.
- [ ] Providers → **Phone**: enable, add the SMS provider's credentials,
      keep **Enable phone confirmations ON**, SMS OTP length 6. See
      `docs/phone_verification.md`.
- [ ] Rate limits: set an hourly SMS limit (for example 30).

## 3. Accounts and keys

- [ ] **SMS provider** (Twilio or similar): open the account and register
      an Australian sender ID or number. New paid service.
- [ ] **Sentry**: revoke the auth token that was committed in `4aba69c`
      (`sentry.properties`, since deleted) and create a new one.
- [ ] **Stripe live mode**: live restricted key in the Edge Function
      secrets, three live webhook destinations with their signing secrets
      (`docs/payments.md`), live publishable key in the release `.env`.
- [ ] Release `.env`: production `SUPABASE_URL`, `SUPABASE_ANON_KEY`,
      `SENTRY_DSN`, `STRIPE_PUBLISHABLE_KEY`, `APPLE_PAY_MERCHANT_ID`.
- [ ] Google Maps keys: restrict the Android key to the app's package and
      signing certificate, and the iOS key to the bundle id.

## 4. Store requirements

- [ ] **Provider account deletion.** Providers hide their business instead
      of deleting, and email support to close the account. Apple (5.1.1(v))
      and Google Play expect in-app deletion for anyone who can sign up, so
      a reviewer may object. If one does: Admin → Platform settings →
      Accounts → turn on "Providers can delete their own account" (no new
      build needed).
- [ ] **Blocking users.** Posts and comments can be reported but a person
      can't block another. Apple's rules for user content (1.2) expect
      blocking; this still needs building.
- [ ] **"Soon" features inside flows** (discounts and multiple services in
      Add service, pausing a service, Afterpay, location tags, saving
      posts). The placeholder rows in the settings menus are gone; these
      remain and a reviewer may question them.
- [ ] **iPad.** The app is built for iPhone and iPad, so Apple reviews it on
      iPad and needs iPad screenshots. Test it there, or restrict the build
      to iPhone for v1 (iPad can be added later, never removed).
- [ ] Android app links: `assetlinks.json` on myglo.app must list the Play
      App Signing certificate (Play Console → App integrity), not only the
      upload key.
- [ ] Review accounts: a client and a provider login for both stores, with
      a bookable provider and Stripe test data the reviewer can use.
- [ ] Play Console: Data safety form, and the Data deletion web page
      (`docs/account_deletion.md`).
- [ ] App Store: privacy labels (they must cover Sentry session replay,
      location, phone number, payments), and the privacy policy URL
      `https://myglo.app/privacy`.
- [ ] Privacy policy and Terms: say that a provider's phone and email are
      shown to clients, that phone numbers are verified by SMS, and how
      accounts are closed.

## 5. Build and test on real devices

- [ ] A release build on Android and iOS (this work was only checked with
      `flutter analyze` and `flutter test`; no device build was made).
- [ ] Sign up → code → onboarding (phone is now required) → home, as a
      client and as a provider.
- [ ] Forgot password from sign-in, and Change password from settings.
- [ ] Provider: verify phone (real SMS), hide and show the business, check
      a hidden provider disappears for a client and existing bookings stay.
- [ ] A card booking end to end in Stripe live mode with a real card, then
      refund it.
- [ ] Push notifications on both platforms.
- [ ] Terms and Privacy links open from sign-in and settings.

## 6. After launch

- [ ] Set up CI (analyze + tests on every push); there is none.
- [ ] Bring the migrations folder and the database back in step: three
      migrations exist only in the database and one only in the repo.
- [ ] Look into the 8 notification emails recorded as failed.
- [ ] Admin: a "close account" action for providers, so support doesn't
      need SQL (`docs/account_deletion.md`).
