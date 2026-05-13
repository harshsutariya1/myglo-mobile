# MyGlo Project Guidelines

## Project Overview

MyGlo is an all-in-one Flutter beauty platform launching in Australia. It integrates social media-style visual discovery with professional booking software, connecting beauty lovers with local talent.

### Core Features

- **Visual Discovery Feed:** Instagram-like home page feed where users discover recent photos from nearby providers and other users.
- **Provider Profiles:** Verified portfolios for local talent to list services, upload work, and manage their business.
- **Booking System:** Instant booking capabilities with real-time available time slots.
- **Business Tools:** Business intelligence and client management tools for salons and providers.

## Architecture & Conventions

- **Framework:** Flutter (Android & iOS).
- **Tech Stack:** Primarily `riverpod` (state management), `go_router` (routing), `freezed` (data modeling), and `supabase` (backend). Use other established packages when required.
- **Domain Language:** Use terms like "Provider" (salon/talent), "Service User" (client), "Portfolio", and "Time Slots".
- **Design & Styling:** The design must be modern, creative, and aesthetic. Prioritize high-quality image displays for the feed and portfolios. The app should feel fast, highly responsive, and provide a seamless UX.
- **Quality & Security:** Code must be production-ready and secure by default.
- **Theme & Colors:** The design uses the following primary colors: `#fc69c3`, `#ffffff`, `#e06052`, `#ffb6a3`, and `#140000`.

## Development Priorities

- Ensure responsive and smooth scrolling for the visual feed.
- Focus on state management suitable for real-time booking and feed updates.
- Keep location-based discovery ("nearby providers") in mind when designing data models and queries.
