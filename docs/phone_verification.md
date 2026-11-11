# Provider phone verification

Providers verify their mobile number in **Settings → Business profile →
Phone number** (`VerifyPhoneScreen`, route `/business/verify-phone`).

```
Enter number ──► Auth: updateUser(phone)          texts a 6-digit code
Enter code   ──► Auth: verifyOTP(phone_change)    number confirmed on the account
             ──► confirm_phone_verification()     server copies the confirmed number
                                                  to the profile, stamps phone_verified_at
```

- **Who sends the text:** Supabase Auth, through the SMS provider set in
  the dashboard. No package was added to the app.
- **What "verified" means:** `profiles.phone_verified_at` is set, and only
  `confirm_phone_verification()` sets it, reading the number from Auth, never
  from the app. Changing the profile's phone number any other way (the
  profile editor) clears it, so a verified number is always the one that got
  the code.
- **One number, one account:** Auth refuses a number another account has
  already confirmed (`phone_exists`).
- **Changing a verified number:** enter the new one on the same screen; the
  old one stays verified until the new code is accepted.
- **Rate limits:** one text per number per minute (the screen counts down)
  plus the project's hourly SMS limit, both set in the dashboard.

## Is it required?

Verification is asked for, not enforced. An unverified provider stays listed
and bookable, and the app keeps asking them to verify: a banner on the
provider home screen, a row under "needs attention" in My business, and the
status pill and "Phone number" row in Settings. Admins see whether a
provider's number is verified on the person's page.

To see who hasn't verified:

```sql
SELECT p.id, p.provider_name, p.phone_number
FROM public.profiles p
WHERE p.role = 'provider' AND p.phone_verified_at IS NULL;
```

## Phone numbers are required, and contact details follow the role

- Clients and providers must give a phone number: onboarding won't finish
  without one (`update_onboarding_details`), both profile editors require
  it, and a saved number can be changed but not removed (`phone_required`).
  Accounts created before this rule keep working without one until they
  next edit their profile.
- There are no "show my email / phone" switches any more. A provider's
  email and phone are always shown to signed-in users on their profile; a
  client's never are (`public_profiles`). Providers still get a client's
  phone number on that client's bookings. The `is_email_public` /
  `is_phone_public` columns remain only for app builds already installed.

## One-time setup (Supabase dashboard)

1. **An SMS provider account** (Twilio, Twilio Verify, MessageBird, Vonage
   or Textlocal). This is a new paid service: each code costs a few cents to
   an Australian mobile. For Australia, register an alphanumeric sender ID
   or buy a number with the provider.
2. **Authentication → Providers → Phone**: enable it, enter the SMS
   provider's credentials, keep **Enable phone confirmations ON** (with it
   off, Auth marks any typed number confirmed without texting), and leave
   **SMS OTP Length** at 6 (`AppConfig.smsOtpLength`). Suggested message:
   `Your Myglo code is {{ .Code }}. Don't share it.`
3. **Authentication → Rate limits**: set the hourly SMS limit to something
   sensible for launch (for example 30), so a bug or abuse can't run up a
   bill.
4. Apply the migration and verify a number on a real phone on both
   platforms.

## Testing

- `test/verify_phone_screen_test.dart`, `test/phone_numbers_test.dart` and
  the phone cases in `test/provider_settings_screen_test.dart`.
- `supabase/tests/phone_verification.sql`, inside a rolled-back transaction.
