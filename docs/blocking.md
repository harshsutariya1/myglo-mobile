# Blocking

Anyone can block another account: from a post (⋯ → Block), a comment
(⋯ → Block), a provider's profile (⋯ → Block) or a review (⋯ → Block).
Blocked accounts are listed, with Unblock, in **Account Settings → Blocked
Accounts** (clients) and **Settings → Privacy & security → Blocked accounts**
(providers). This is what App Store guideline 1.2 and Google Play's
user-generated content policy ask for, together with reporting.

## What a block does

Both ways between the two accounts, enforced by the database
(migration `20261124120000_user_blocking`):

- neither sees the other's posts or comments: Discover feeds, post pages,
  comment lists and profile grids (row level security on `posts` and
  `comments`, plus the security-definer feeds), so neither can like or
  comment on the other's posts;
- neither can follow the other, and follows between them end;
- a client and a provider can't make new bookings together, and the
  provider leaves the client's search, map and home list. The client is
  told the provider isn't taking bookings, not that they were blocked;
- bookings they already have carry on (either side can cancel as usual), so
  nobody loses an appointment or a payout.

The blocked person isn't told and can't find out who blocked them:
`user_blocks` rows are visible only to the blocker, and the check row level
security uses lives in the `rls` schema, which the API doesn't expose.

Unblocking undoes all of it except the follows that ended.

## Limits

- 1000 blocks per account (`too_many_blocks`).
- A provider's public profile can still be opened from an old link or
  booking; it just has no times to book.
- Reviews stay visible: they come from completed bookings and are moderated
  through reports.

## Testing

- `test/blocking_test.dart` (dialog, failures, Blocked accounts screen).
- `supabase/tests/user_blocking.sql`, inside a rolled-back transaction.
