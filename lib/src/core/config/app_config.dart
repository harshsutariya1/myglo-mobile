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
}
