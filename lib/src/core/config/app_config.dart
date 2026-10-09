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
}
