# Share links (posts and provider profiles)

The app shares two kinds of public link through the system share sheet:

| What | Link | Opens in the app |
| --- | --- | --- |
| A post | `https://myglo.app/p/<post id>` | `SharedPostScreen` (both roles) |
| A provider profile | `https://myglo.app/provider/<provider id>` | `PublicProviderProfileScreen` (clients; providers land on their home) |

The host comes from `AppConfig.shareLinkHost`. Sharing works today: the
sheet opens and the link can be sent anywhere. **Tapping a link opens the app
only after the three steps below are done.** Until then it opens
myglo.app in the browser, so the website must also answer those paths (step 1).

If a link arrives while the person is signed out or still loading, the
router remembers it (`PendingSharedLink`) and opens it once they're signed
in and onboarded.

## 1. Website (myglo.app on Netlify)

Whoever owns the website repo needs to add the following. Serve every file
over HTTPS at exactly these paths, with no redirects.

### `/.well-known/assetlinks.json` (Android App Links)

```json
[
  {
    "relation": ["delegate_permission/common.handle_all_urls"],
    "target": {
      "namespace": "android_app",
      "package_name": "app.myglo.myglo",
      "sha256_cert_fingerprints": [
        "PLAY_APP_SIGNING_SHA256",
        "UPLOAD_KEY_SHA256"
      ]
    }
  }
]
```

- `PLAY_APP_SIGNING_SHA256`: Play Console → the app → *Test and release* →
  *App integrity* → *App signing* → "App signing key certificate", SHA-256.
  Sam owns the Play account, so Sam reads it out; it's a public fingerprint,
  not a secret.
- `UPLOAD_KEY_SHA256`: the same page, "Upload key certificate". It's only
  needed for builds you sideload yourself. For debug builds, run
  `./gradlew signingReport` in `android/` and add the debug SHA-256 *only
  while testing*. Remove it again before launch.

### `/.well-known/apple-app-site-association` (iOS Universal Links)

No file extension, served as `Content-Type: application/json`:

```json
{
  "applinks": {
    "details": [
      {
        "appIDs": ["APPLE_TEAM_ID.app.myglo.myglo"],
        "components": [
          { "/": "/p/*" },
          { "/": "/provider/*" }
        ]
      }
    ]
  }
}
```

`APPLE_TEAM_ID` is the 10-character Team ID in Sam's Apple Developer account
(*Membership details*).

On Netlify, set the content type in `netlify.toml` (or `_headers`):

```toml
[[headers]]
  for = "/.well-known/apple-app-site-association"
  [headers.values]
    Content-Type = "application/json"
```

### Fallback pages for `/p/:id` and `/provider/:id`

People without the app, and everyone until step 2/3 is done, land on the
website. Add a simple page for both paths instead of a 404: "Open this in
the Myglo app", the App Store / Google Play badges, and a link to the home
page. Keep it generic. The page doesn't need to load the post or profile, so
nothing private can leak and no database access is needed.

## 2. Android (already done in the app)

`AndroidManifest.xml` has an `autoVerify` intent filter for
`https://myglo.app/p/…` and `https://myglo.app/provider/…`. Android checks
`assetlinks.json` when the app is installed or updated. After the website
files go live:

```bash
adb shell pm verify-app-links --re-verify app.myglo.myglo
```

```bash
adb shell pm get-app-links app.myglo.myglo
```

`myglo.app: verified` means links open the app. To try one:

```bash
adb shell am start -a android.intent.action.VIEW -d "https://myglo.app/p/POST_ID"
```

## 3. iOS (needs Sam's Apple account)

This step is deliberately not committed. Adding the entitlement before the
App ID has the capability breaks signed device builds for anyone whose
Apple account role can't change capabilities.

1. In Xcode, open `ios/Runner.xcworkspace` → *Runner* target →
   *Signing & Capabilities* → **+ Capability** → *Associated Domains*.
2. Add `applinks:myglo.app`. Xcode creates `Runner/Runner.entitlements` and
   turns on Associated Domains for the App ID `app.myglo.myglo` (this needs
   an Admin or Account Holder role, i.e. Sam).
3. Commit the entitlements file and the project change.

Test on a simulator with `xcrun simctl openurl booted https://myglo.app/p/POST_ID`.
Apple caches the association file through its CDN, so a change to it can
take a while to reach devices.
