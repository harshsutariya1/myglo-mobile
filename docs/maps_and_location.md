# Maps, location and search

## Google Maps keys

The Maps SDK keys are **not** in the repo. Each machine that builds the app
needs them in two untracked files:

| Platform | File | Entry |
| --- | --- | --- |
| Android | `android/local.properties` (or `MAPS_API_KEY` env var) | `MAPS_API_KEY=AIza...` |
| iOS | `ios/Flutter/Secrets.xcconfig` (copy `Secrets.example.xcconfig`) | `GOOGLE_MAPS_API_KEY = AIza...` |

Without a key the app shows a "Map unavailable" placeholder instead of a
blank map (Android) or a crash (iOS); everything else keeps working.

In Google Cloud, restrict each key:

- **Android key:** *Android apps* → package `app.myglo.myglo` with the SHA-1
  of every signing key (debug keystore, upload key, and the Play App Signing
  key from Play Console). API restriction: *Maps SDK for Android*.
- **iOS key:** *iOS apps* → bundle id `app.myglo.myglo`. API restriction:
  *Maps SDK for iOS*.

Mobile dynamic maps are free on Google Maps Platform; no Places or Geocoding
web APIs are used.

## Where the code is

Screens only use the app-owned interfaces in `lib/src/core/maps/` and
`lib/src/core/location/`; only `core/maps/google/google_app_map.dart` talks to
the Google SDK.

| Piece | File |
| --- | --- |
| Map widget and controller | `core/maps/app_map.dart` |
| Myglo map style (hides other businesses) | `core/maps/map_style.dart` |
| Avatar pins, cluster bubbles | `core/maps/marker_icons.dart`, `core/maps/map_clustering.dart` |
| Device location and permission | `core/location/device_location.dart` |
| Address ↔ coordinates (device geocoder, free) | `core/location/address_geocoder.dart` |

## Features

- **Clients – map** (`/map`, map button on Home): providers around the map
  centre, avatar pins that group into bubbles when crowded, a swipeable card
  per provider and "near me". Location is asked for once when the map opens;
  without it the map stays on the Gold Coast.
- **Clients – search** (`/search`, search bar on Home): matches provider
  names, service names and categories and studio suburbs, with recent
  searches (per account, on the device) and category shortcuts.
- **Providers – studio location** (`/business/location`, from Settings or
  Where you work): drag the map under the pin, use the current location or
  search an address. The address text is pre-filled from the pin by the
  device's geocoder and the provider can edit it before saving.

## Privacy

- A client's location is never stored. Search sends it rounded to about
  100 m, only to sort results.
- `search_providers` and `map_providers` return public fields only. A
  provider who only does mobile visits is shown at an approximate spot
  (rounded to about 1 km) with no street address, and the profile screen
  says "Mobile service" instead of their address.
- Known gap: `public_profiles` still returns `address_text` and
  `coordinates` for every provider, including mobile-only ones. The app no
  longer shows them, but tightening the view needs a migration (see the
  task summary).
