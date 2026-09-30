# Myglo — Project Context

## What This Is
Myglo is a Flutter mobile app for salon service booking, launching in Gold Coast, Australia. 
Development is based in India. The app serves two distinct user types:
- **Clients** — browse and book salon services
- **Providers** — salons/individuals offering services, managing their availability and bookings

## Tech Stack
- **Framework:** Flutter (Dart)
- **Backend:** Supabase (auth, database, storage, realtime, edge functions)
- **Email:** Resend
- **Error monitoring:** Sentry
- **State management:** Riverpod
- **Navigation:** GoRouter
- **Data modeling:** Freezed
- **Networking:** Dio
- Additional tools may be added later — flag explicitly if a task needs something not listed here rather than assuming a package silently.

## Architecture & Conventions
- Client and provider flows are logically separate — a client should never see or trigger provider-only actions, and vice versa
- All network calls go through Dio with shared error interceptors — no raw HTTP calls
- Supabase: use Row Level Security-aware queries; never expose service-role keys client-side; prefer typed responses

## Domain-Specific Rules
- Timezone: Gold Coast is AEST/AEDT (no daylight saving in Queensland — verify current rule if relevant) — always be explicit about timezone handling in booking logic
- Currency: AUD, formatted per Australian conventions
- Booking edge cases to always consider: double-booking prevention, provider availability conflicts, cancellation windows, timezone mismatches
- Sensitive flows (payments, bookings, auth) require extra defensive handling — flag if a Supabase RLS policy review or DB transaction is needed

## Quality Bar
- Production-ready code: proper error handling, no unresolved TODOs, null-safety respected, no hardcoded values that belong in config/constants
- New error paths must be captured via Sentry, not silently swallowed
- Include/update unit or widget tests where applicable
- Code should pass `flutter analyze` clean

## What NOT To Do
- Don't introduce new dependencies without asking first
- Don't touch unrelated files outside the task scope
- Don't break existing tests
- Don't hardcode secrets or API keys

## Deliverable Format
- After completing a task, briefly summarize what changed and why, list files touched, and flag any assumptions made or decisions needing my input
- Run relevant `flutter analyze` / `flutter test` yourself and report results — don't just hand back code