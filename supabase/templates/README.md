# Auth email templates

Templates are applied in the Supabase dashboard (or via `supabase config push` if this
project is ever linked to the CLI). They are versioned here so changes are reviewable.

| Template | Dashboard location | Notes |
|---|---|---|
| `confirmation.html` | Authentication > Emails > Confirm signup | Emails a numeric code (`{{ .Token }}`) instead of a link (`{{ .ConfirmationURL }}`). |

Related settings (Authentication > Providers > Email):

- **Confirm email**: must stay enabled.
- **Email OTP Length**: 6 (matches `AppConfig.emailOtpLength`; change both together).
- **Email OTP Expiration**: 3600 s or less.
- If a "Magic Link" template is ever used, switch it to `{{ .Token }}` too.
