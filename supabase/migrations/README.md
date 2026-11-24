# Migrations

The files here are the source of truth for the database schema, in the order
their file names sort. They were applied to the live project
(`MyGlo_App`, `oyveznxdnbduqgaddklr`) one by one, through the Supabase MCP
server or the SQL editor, which records each under **its own timestamp**. So
the version in a file name doesn't match the version in the database's
migration history (`supabase_migrations.schema_migrations`).

**Never run `supabase db push` or `supabase migration up` against the live
project.** The CLI compares versions, would treat every file as new, and
would run them all again. Apply a new migration on its own (MCP
`apply_migration`, or paste it into the SQL editor), and run its checks in
`supabase/tests/` first.

Each migration that patches an existing function (`pg_temp.patch_function`)
fails instead of applying twice: the text it replaces must appear exactly
once.

| File | Version in the live database | Notes |
|---|---|---|
| `20260930122337_harden_rpcs_and_protect_columns.sql` | 20260930122337 |  |
| `20260930123208_deprecate_provider_details_tighten_storage.sql` | 20260930123208 |  |
| `20260930130000_restrict_profiles_select_public_view.sql` | — | Applied outside the migration history (the policy and view are live). |
| `20261003120000_client_favourites_and_nearby_posts.sql` | 20261003173202 |  |
| `20261005120000_booking_engine.sql` | 20261005131853 |  |
| `20261005130000_booking_notifications.sql` | 20261005132624 |  |
| `20261005140000_booking_details_provider_fee.sql` | 20261005150339 |  |
| `20261005160000_provider_business_stats.sql` | 20261005155950 |  |
| `20261007120000_cash_bookings_are_fee_free_requests.sql` | 20261007103233 |  |
| `20261007140000_booking_request_reminders.sql` | 20261007113950 |  |
| `20261009120000_push_notifications.sql` | 20261009115413 |  |
| `20261009130000_provider_cover_photos.sql` | 20261009115441 |  |
| `20261009140000_provider_search_and_map.sql` | 20261009115533 |  |
| `20261009150000_cover_photos_upload_policy_fix.sql` | 20261009125017 |  |
| `20261013120000_post_comments_and_likes.sql` | 20261013091844 |  |
| `20261013130000_reviews.sql` | 20261013092058 |  |
| `20261013140000_posts_beyond_nearby.sql` | 20261013130536 |  |
| `20261014120000_provider_contacts.sql` | 20261014113230 |  |
| `20261014130000_provider_contacts_email.sql` | 20261014120338 |  |
| `20261026120000_service_cities.sql` | 20261026164222 |  |
| `20261031120000_jobs_and_stripe_events.sql` | 20261030195928 |  |
| `20261031130000_admin_foundation.sql` | 20261030202342 |  |
| `20261031140000_provider_payouts.sql` | 20261101084755 |  |
| `20261101120000_card_checkout.sql` | 20261101091006 |  |
| `20261101130000_payment_lifecycle.sql` | 20261101094330 |  |
| `20261101140000_moderation_and_suspension.sql` | 20261101141702 | Also contains what the database recorded separately as `moderation_create_booking_refusal`, `moderation_review_stats_trigger` and `booking_events_without_admin_actor`. |
| `20261101150000_drop_duplicate_profiles_index.sql` | 20261101151437 |  |
| `20261102100000_business_stats_card_earnings.sql` | 20261102094204 |  |
| `20261102110000_business_overview.sql` | 20261102105338 |  |
| `20261102120000_account_deletion.sql` | 20261102180358 |  |
| `20261111120000_lock_down_profile_writes_and_storage.sql` | 20261124110226 | Applied 2026-11-24. |
| `20261112120000_provider_marketplace_visibility.sql` | 20261124110326 | Applied 2026-11-24. |
| `20261113120000_phone_verification_and_contact_rules.sql` | 20261124110701 | Applied 2026-11-24. |
| `20261124120000_user_blocking.sql` | 20261124110757 | Applied 2026-11-24. |
| `20261124130000_admin_account_closure.sql` | 20261124110925 | Applied 2026-11-24. |
| `20261124140000_platform_fee_free_at_launch.sql` | 20261124111002 | Applied 2026-11-24. |
