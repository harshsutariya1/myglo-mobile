# Password reset and change

One flow covers both a forgotten password and changing it while signed in
(`ResetPasswordScreen`, route `/reset-password?email=…`):

```
Sign-in: email → password field → "Forgot password?"      Settings → "Change password"
                         └──────────────┬───────────────────────────┘
                                        ▼
        resetPasswordForEmail(email)          emails a 6-digit code (sent as the screen opens)
                                        ▼
        verifyOTP(type: recovery)             code checked; the user is now signed in
                                        ▼
        updateUser(password)                  new password saved
        signOut(scope: others)                every other device is signed out (best effort)
                                        ▼
        forgotten: into the app (router guard picks home / onboarding)
        changed from settings: back to settings
```

- **No link to tap.** The email carries a code, like sign-up, so nothing
  depends on deep links or the mail app's browser.
- **Rate limits** are Supabase's: one email per address per minute (the
  screen shows the countdown) and the project's hourly email limit.
- **No account enumeration from this flow.** Supabase answers the same way
  whether or not the address has an account. (The sign-in screen itself
  already tells the two apart with `check_user_exists`.)
- **Leaving half-way.** The code signs the user in. Someone who closes the
  screen after the code but before choosing a password stays signed in, as
  they proved the inbox is theirs, with their old password unchanged.
- **Suspended accounts** can't reset: Auth refuses banned users and the
  screen says the account is suspended.
- **Admin accounts** aren't supported by this screen: an admin session needs
  two-factor first, so the router sends them there. Reset an admin's
  password from the Supabase dashboard.
- **Rules for the new password**: at least `AppConfig.passwordMinLength` (8)
  characters in the app; the server's own minimum and leaked-password check
  decide (a refusal is explained on the form).

## One-time setup (Supabase dashboard)

1. **Authentication → Emails → Templates → Reset password**: paste
   `supabase/templates/recovery.html`. Until this is done the email contains
   a link instead of a code and the flow can't be completed.
2. **Authentication → Providers → Email**: minimum password length 8, and
   turn on "Prevent use of leaked passwords". See
   `supabase/templates/README.md`.
3. Send yourself a reset from a test account and check the code arrives and
   works, on both platforms.

## Testing

`test/reset_password_flow_test.dart` covers the screen: the happy path from
sign-in and from settings, wrong and expired codes, suspended accounts,
password rules, a refused password, a lost session and the resend countdown.
