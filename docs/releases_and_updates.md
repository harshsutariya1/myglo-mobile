# Releases, over-the-air updates and crash reporting

How store releases and Shorebird patches are built, how the app picks up a
patch, and how Sentry is wired up.

## How a patch reaches users

```
scripts/shorebird_build.sh patch android|ios
        │  shorebird patch + Sentry symbol upload
        ▼
Shorebird (stable track) ──► app checks: launch, back to foreground, every 30 min
                                   │  newer patch?
                                   ▼
                     downloads silently in the background (nothing shown)
                                   │  installed
                                   ▼
          Home screen banner "Update ready"  [Restart]
                                   │  tap
                                   ▼
          [◌ Restarting] ──► Android: process restart into the patch
                             iOS: asked to close and reopen the app
```

- `shorebird.yaml` has `auto_update: false`. Instead, `ShorebirdUpdateService`
  (`lib/src/core/services/shorebird_update_service.dart`) checks and
  downloads, so patches are also found when the app is resumed or left open,
  not only on launch. `ShorebirdUpdateWatcher` triggers the checks.
  `AppUpdateBanner`, at the top of the client and provider home screens,
  takes no space until a patch has finished downloading. It then asks for a
  restart.
- Settings → "Check for updates" checks immediately and downloads any patch
  it finds. Once the patch is downloaded, the same tile restarts into it.
- A failed download isn't shown. The next check retries it, and only the
  first failure per app run is reported to Sentry.
- Patches are small: Shorebird downloads only the changed Dart code, as a
  compressed diff.
- A patch only loads when the native process starts. On Android, "Restart"
  relaunches the process (`restart_app`, `RestartMode.process`). iOS has no
  supported way for an app to relaunch itself: an engine restart keeps the
  old code, and calling `exit()` goes against Apple's guidelines. So on iOS,
  "Restart" explains how to close and reopen the app. Either way, a
  downloaded patch is applied on the next cold start, even if the user never
  taps Restart.
- If a patch is rolled back in the Shorebird console, the next check finds
  this and the banner offers "Restart" to return to the base release.
- Debug builds and anything built with plain `flutter build` don't include
  the updater, so the banner never shows there.

Timings (`AppConfig.appUpdateCheckInterval`, `appUpdateMinCheckGap`) and the
track (`AppConfig.shorebirdTrack`) live in `lib/src/core/config/app_config.dart`.

## One-time setup

1. **Shorebird.** Install the CLI and run `shorebird login`. The app id is in
   `shorebird.yaml`, which is not secret.
2. **Sentry auth token.** Create an **Organization Auth Token** in Sentry
   (Settings → Developer Settings → Organization Tokens). It only needs the
   default scopes, which include `project:releases` and `org:read`. Keep it
   out of git: export it as `SENTRY_AUTH_TOKEN`, or put it in
   `sentry.properties` (gitignored) as `auth_token=...`. On CI, store it as a
   masked secret.
3. **Android upload key.** Create an upload keystore once and enrol it in
   Play App Signing:

   ```bash
   keytool -genkey -v -keystore ~/keys/myglo-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```

   Then create `android/key.properties`, which is gitignored:

   ```properties
   storeFile=/absolute/path/to/myglo-upload.jks
   storePassword=...
   keyAlias=upload
   keyPassword=...
   ```

   Back the keystore and passwords up in the team password manager. Without
   this file, `bundleRelease` fails on purpose, so a debug-signed bundle
   can't be shipped.
4. **`.env`** must hold the production `SUPABASE_URL`, `SUPABASE_ANON_KEY` and
   `SENTRY_DSN`. Optionally set `SENTRY_ENVIRONMENT`, e.g. `staging`;
   otherwise it is `production` for release builds. `.env` is bundled inside
   the app, so it must only ever hold public client values.

## Store release (new native build)

Bump `version:` in `pubspec.yaml`, then run:

```bash
scripts/shorebird_build.sh release android
```

```bash
scripts/shorebird_build.sh release ios
```

Upload the `.aab` / `.ipa` that Shorebird prints to Play Console /
App Store Connect as usual.

A store release is needed whenever native code, plugins, `pubspec.yaml`
dependencies or assets change. Patches can only change Dart code.

For example, iOS push notifications (2026-10-26) need a new iOS store
release: the Push Notifications entitlement, the `remote-notification`
background mode and the Dart code that turns iOS push on ship together.
Patching just the Dart change onto an older iOS build would leave the app
waiting for an APNs token that a build without the entitlement never gets.

## Patch (OTA fix)

```bash
scripts/shorebird_build.sh patch android --release-version=1.0.0+1
```

```bash
scripts/shorebird_build.sh patch ios --release-version=1.0.0+1
```

To try a patch on internal testers first, use
`patch ... --track=staging` on a build made with
`-- --dart-define=SHOREBIRD_TRACK=staging`. Then promote it in the Shorebird
console.

Patches can't be tested on the iOS Simulator. Use a real device, or
`shorebird preview`.

## Sentry

- Initialised in `lib/src/core/utils/app_init.dart`, with the app wrapped in
  `SentryWidget` and `SentryNavigatorObserver` on the router.
- **Environment:** `production` / `profile` / `development` by build mode,
  or `SENTRY_ENVIRONMENT` from `.env`.
- **Sampling (release builds):** 20% of traces, 5% of sessions recorded by
  Session Replay (all text and images masked), and 100% of sessions that hit
  an error. Debug builds trace everything and record no replays. Values are
  in `AppConfig`.
- **Tags:** every event carries `shorebird.patch` (`base` or the patch
  number). Filter by it to see whether a patch introduced a crash.
- **User:** only the opaque Supabase user id. No email or IP
  (`sendDefaultPii = false`).
- **Error capture:** Sentry captures framework (`FlutterError.onError`) and
  platform (`PlatformDispatcher.onError`) errors itself. The app's own
  handlers only log them, so each error is reported once. Everything logged
  through `AppLogger.e` / `AppLogger.f` with an `error` is reported.
  Connectivity errors become breadcrumbs instead.
- **Symbols:** builds use `--split-debug-info` and the script uploads the
  symbols after every release and patch, so Dart stack traces symbolicate.
  The script doesn't obfuscate. To obfuscate, add `--obfuscate` after `--` in
  the script, and also upload the obfuscation map
  (`dart_symbol_map_path`) for readable issue titles.
- **Shorebird engine symbols (optional):** native engine frames come from
  Shorebird's engine fork. Their symbols can be downloaded using the engine
  revision that `shorebird doctor` prints, per Shorebird's "Uploading symbols"
  guide.
