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
}
