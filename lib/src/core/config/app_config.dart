import '../location/geo_point.dart';

class AppConfig {
  AppConfig._();

  /// Digits in the emailed verification code. Must match
  /// Supabase Dashboard > Authentication > Providers > Email > "Email OTP Length".
  static const int emailOtpLength = 6;

  /// Minimum wait before another verification email may be requested. Supabase
  /// itself enforces 60 seconds between emails to the same address.
  static const Duration otpResendCooldown = Duration(seconds: 60);

  /// Upper bound for a Supabase request to receive a response. Prevents a
  /// dropped connection from leaving a spinner up forever.
  static const Duration requestTimeout = Duration(seconds: 60);

  /// Longest caption accepted on a post.
  static const int postCaptionMaxLength = 2200;

  /// Most photos a single post (carousel) may hold.
  static const int postMaxMedia = 10;

  /// Posts fetched per page of the Discover feed.
  static const int discoverPageSize = 18;

  /// How far from a provider's business address Discover looks for posts.
  /// The server clamps this to 1–100 km.
  static const double nearbyRadiusMetres = 25000;

  /// Where maps open when we don't know where the user is: Surfers Paradise,
  /// the centre of the Gold Coast launch area.
  static const GeoPoint mapDefaultCenter = GeoPoint(latitude: -28.0023, longitude: 153.4145);

  /// Zoom that shows most of the Gold Coast.
  static const double mapDefaultZoom = 11.5;

  /// Zoom close enough to place a pin on a building entrance.
  static const double mapStreetZoom = 17;

  /// Zoom for "near me": a few suburbs around the user.
  static const double mapNearbyZoom = 13.5;

  /// Most providers the map loads for one area. The server caps it at 300.
  static const int mapProvidersLimit = 200;

  /// Most cover photos on a provider profile. The database enforces the same.
  static const int coverPhotosMax = 5;

  /// Shortest search the server answers; shorter input shows suggestions.
  static const int searchMinLength = 2;

  /// Results per search. The server caps it at 50.
  static const int searchResultsLimit = 30;

  /// Recent searches remembered on this device.
  static const int recentSearchesMax = 8;

  /// Public site that shared post and profile links point at. The app opens
  /// these links itself once the site serves the app-link verification files
  /// (see docs/share_links.md).
  static const String shareLinkHost = 'myglo.app';

  /// Longest comment. The database enforces the same.
  static const int commentMaxLength = 500;

  /// Comments fetched per page. The server caps it at 100.
  static const int commentsPageSize = 30;

  /// Longest review text, and longest reply to one. The database enforces
  /// the same.
  static const int reviewMaxLength = 1000;

  /// Most photos on one review. The database enforces the same.
  static const int reviewMaxPhotos = 4;

  /// Reviews fetched per page. The server caps it at 50.
  static const int reviewsPageSize = 20;

  /// Reviews previewed on a profile or service before "See all".
  static const int reviewsPreviewCount = 3;

  /// Provider contacts (clients) fetched per page. The server caps it at 100.
  static const int contactsPageSize = 30;

  /// One client's bookings fetched per page in their contact sheet.
  static const int clientBookingsPageSize = 20;

  /// Pause after the last keystroke before searching contacts.
  static const Duration contactsSearchDebounce = Duration(milliseconds: 300);

  /// How long a post's like/comment counts stay cached after it leaves the
  /// screen, so going back to a feed shows the counts just seen.
  static const Duration postEngagementCacheFor = Duration(minutes: 10);

  /// Shorebird track the app takes patches from. Builds for internal testers
  /// can pass `--dart-define=SHOREBIRD_TRACK=staging` (see
  /// docs/releases_and_updates.md).
  static const String shorebirdTrack = String.fromEnvironment('SHOREBIRD_TRACK', defaultValue: 'stable');

  /// How often a running app looks for a new patch while it is in the
  /// foreground. It also looks on launch and when brought back.
  static const Duration appUpdateCheckInterval = Duration(minutes: 30);

  /// Least time between two automatic patch checks, so quickly switching apps
  /// doesn't hit the update server each time.
  static const Duration appUpdateMinCheckGap = Duration(minutes: 5);

  /// Share of production sessions sent to Sentry as performance traces.
  static const double sentryTracesSampleRate = 0.2;

  /// Share of production sessions recorded by Sentry Session Replay. Replays
  /// mask all text and images.
  static const double sentryReplaySessionSampleRate = 0.05;

  /// Share of sessions with an error whose replay is kept.
  static const double sentryReplayOnErrorSampleRate = 1.0;
}
