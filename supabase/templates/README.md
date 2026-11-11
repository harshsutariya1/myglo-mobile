# Auth email templates

Templates are applied in the Supabase dashboard (or via `supabase config push` if this
project is ever linked to the CLI). They are versioned here so changes are reviewable.

| Template | Dashboard location | Notes |
|---|---|---|
| `confirmation.html` | Authentication > Emails > Confirm signup | Emails a numeric code (`{{ .Token }}`) instead of a link (`{{ .ConfirmationURL }}`). |
| `recovery.html` | Authentication > Emails > Reset password | Emails a numeric code for the in-app password reset (`ResetPasswordScreen`). With the default link template the app's reset flow can't work: there is no code to type. |

Related settings (Authentication > Providers > Email):

- **Confirm email**: must stay enabled.
- **Email OTP Length**: 6 (matches `AppConfig.emailOtpLength`; change both together).
- **Email OTP Expiration**: 3600 s or less.
- **Minimum password length**: 8 (matches `AppConfig.passwordMinLength`; change both together).
- **Prevent use of leaked passwords**: turn on. The app explains a refusal (`weak_password`).
- **Secure password change** can stay on or off: the reset flow always changes the password
  straight after a fresh code, which counts as a recent sign-in.
- If a "Magic Link" template is ever used, switch it to `{{ .Token }}` too.
