# Myglo — Project Context

## What This Is
Myglo is a Flutter mobile app for salon service booking, launching in Gold Coast, Australia. 
Development is based in India. The app serves three distinct user types:
- **Clients** — browse and book salon services
- **Providers** — salons/individuals offering services, managing their availability and bookings
- **Admin** — platform operators with full control over the platform (e.g. platform fee and fee-free period, map provider selection, user and provider management). The admin part will be developed later and is not built yet; until then, anything admin-controllable ships with a safe default stored in server-side config rather than hardcoded in the app

## Tech Stack
- **Framework:** Flutter (Dart)
- **Backend:** Supabase (auth, database, storage, realtime, edge functions)
- **Email:** Resend
- **Error monitoring:** Sentry
- **State management:** Riverpod
- **Navigation:** GoRouter
- **Data modeling:** Freezed
- **Networking:** `package:http` (Supabase traffic uses the shared `ConnectivityAwareHttpClient`). Dio is not used — don't add it
- **Maps & location (planned):** Google Maps Platform only for v1 (Sam, the Australian co-founder, owns the Google Cloud and Stripe accounts). Mapbox is not used and no second provider ships in v1
- **Payments (planned):** Stripe Connect (Express accounts) on an Australian platform account; full upfront payment with a cancellation policy
- Additional tools may be added later — flag explicitly if a task needs something not listed here rather than assuming a package silently.

## Architecture & Conventions
- Client, provider and admin flows are logically separate — a client should never see or trigger provider-only actions, a provider should never see or trigger admin-only actions, and so on. Admin-only actions must be enforced server-side (RLS / RPC role checks), never just hidden in the UI
- Network calls use `package:http` and go through a shared client with timeouts, connectivity-failure reporting and Sentry capture (see `ConnectivityAwareHttpClient`) — no ad-hoc `http.get` calls with their own error handling. Use the Supabase client for backend calls and edge functions
- Supabase: use Row Level Security-aware queries; never expose service-role keys client-side; prefer typed responses
- Maps: keep all map code behind small app-owned interfaces (e.g. map view, location picker, geocoder) so no screen depends directly on the Google Maps SDK. This keeps a later provider switch possible. Never mix one vendor's data (geocoding/search results) with another vendor's map. Do not build dual-provider or auto-switch logic until real usage data justifies it; a server-side `map_provider` flag controlled from the future admin panel is the intended switch point
- Location: providers have exact salon locations at launch (coordinates stored in `profiles.coordinates`, PostGIS `geography`). Clients who deny location permission pick an area from a curated list of Gold Coast cities/suburbs (admin-managed table with centre coordinates). Clients' saved location should be coarse, not precise. Never expose exact coordinates beyond what the public queries need

## Domain-Specific Rules
- Timezone: Gold Coast is AEST/AEDT (no daylight saving in Queensland — verify current rule if relevant) — always be explicit about timezone handling in booking logic
- Currency: AUD, formatted per Australian conventions
- Booking edge cases to always consider: double-booking prevention, provider availability conflicts, cancellation windows, timezone mismatches
- Sensitive flows (payments, bookings, auth) require extra defensive handling — flag if a Supabase RLS policy review or DB transaction is needed
- Platform fee: the fee percentage and the fee-free period are admin-controlled configuration, not constants in the app. The fee-free period applies per provider (starting from each provider's own onboarding), and admin will be able to change it for every provider at once. Until the admin panel exists the fee is free (0%) for development. Compute fees server-side only and store the fee amount on each booking at payment time

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