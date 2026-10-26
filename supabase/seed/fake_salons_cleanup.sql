-- Removes everything created by fake_salons_seed.sql, plus anything testers
-- created against those salons (bookings, reviews and their photo posts,
-- favourites, notifications). Real accounts are only touched where they
-- point at a seeded salon.
--
-- Run `python3 supabase/seed/seed_salon_media.py purge` first: uploaded photos
-- live in Storage and can't be deleted from SQL.
--
-- Step 0 (only if testers reviewed a seeded salon): review photos sit in the
-- tester's own post-media folder, which purge can't reach. Run this query on
-- its own first and delete the files it lists in the dashboard
-- (Storage > post-media):
--
--   SELECT DISTINCT split_part(split_part(url, '/post-media/', 2), '?', 1) AS file_to_delete
--   FROM public.posts p
--   JOIN public.reviews r ON r.id = p.review_id
--   JOIN auth.users u ON u.id = r.provider_id
--   CROSS JOIN unnest(p.media_urls) AS url
--   WHERE u.email LIKE '%@seed.myglo.test' AND u.raw_user_meta_data ->> 'seed' = 'fake_salons';
--
-- Run as the postgres role (SQL editor). Runs in one transaction.

BEGIN;

CREATE TEMP TABLE seed_ids ON COMMIT DROP AS
SELECT id FROM auth.users
WHERE email LIKE '%@seed.myglo.test' AND raw_user_meta_data ->> 'seed' = 'fake_salons';

CREATE TEMP TABLE seed_bookings ON COMMIT DROP AS
SELECT id FROM public.bookings
WHERE provider_id IN (SELECT id FROM seed_ids) OR client_id IN (SELECT id FROM seed_ids);

CREATE TEMP TABLE seed_posts ON COMMIT DROP AS
SELECT id FROM public.posts
WHERE author_id IN (SELECT id FROM seed_ids)
   OR tagged_provider_id IN (SELECT id FROM seed_ids)
   OR service_id IN (SELECT id FROM public.services WHERE provider_id IN (SELECT id FROM seed_ids))
   OR review_id IN (SELECT id FROM public.reviews WHERE booking_id IN (SELECT id FROM seed_bookings));

DELETE FROM public.likes    WHERE post_id IN (SELECT id FROM seed_posts) OR user_id IN (SELECT id FROM seed_ids);
DELETE FROM public.comments WHERE post_id IN (SELECT id FROM seed_posts) OR author_id IN (SELECT id FROM seed_ids);
DELETE FROM public.posts    WHERE id IN (SELECT id FROM seed_posts);

DELETE FROM private.notification_deliveries
WHERE notification_id IN (
    SELECT id FROM public.notifications
    WHERE booking_id IN (SELECT id FROM seed_bookings)
       OR recipient_id IN (SELECT id FROM seed_ids)
       OR actor_id IN (SELECT id FROM seed_ids));
DELETE FROM public.notifications
WHERE booking_id IN (SELECT id FROM seed_bookings)
   OR recipient_id IN (SELECT id FROM seed_ids)
   OR actor_id IN (SELECT id FROM seed_ids);

DELETE FROM public.reviews          WHERE booking_id IN (SELECT id FROM seed_bookings);
DELETE FROM public.booking_events   WHERE booking_id IN (SELECT id FROM seed_bookings);
DELETE FROM public.booking_payments WHERE booking_id IN (SELECT id FROM seed_bookings);
DELETE FROM public.booking_items    WHERE booking_id IN (SELECT id FROM seed_bookings);
DELETE FROM public.bookings         WHERE id IN (SELECT id FROM seed_bookings);

DELETE FROM public.favourites WHERE provider_id IN (SELECT id FROM seed_ids) OR client_id IN (SELECT id FROM seed_ids);
DELETE FROM public.follows    WHERE following_id IN (SELECT id FROM seed_ids) OR follower_id IN (SELECT id FROM seed_ids);

DELETE FROM public.provider_review_stats     WHERE provider_id IN (SELECT id FROM seed_ids);
DELETE FROM public.provider_time_off         WHERE provider_id IN (SELECT id FROM seed_ids);
DELETE FROM public.provider_working_hours    WHERE provider_id IN (SELECT id FROM seed_ids);
DELETE FROM public.provider_booking_settings WHERE provider_id IN (SELECT id FROM seed_ids);
DELETE FROM public.services                  WHERE provider_id IN (SELECT id FROM seed_ids);
DELETE FROM private.push_tokens              WHERE user_id IN (SELECT id FROM seed_ids);

DELETE FROM public.profiles WHERE id IN (SELECT id FROM seed_ids);
DELETE FROM auth.users      WHERE id IN (SELECT id FROM seed_ids);

COMMIT;
