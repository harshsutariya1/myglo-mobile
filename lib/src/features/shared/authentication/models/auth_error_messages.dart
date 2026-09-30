import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/utils/network_error.dart';

/// User-facing text for auth failures. Keeps raw Supabase messages (which are
/// developer-oriented) out of the UI.
class AuthErrorMessages {
  AuthErrorMessages._();

  static const String invalidCode =
      'That code is incorrect or has expired. Check your email or request a new code.';
  static const String rateLimited =
      'Too many attempts. Please wait a minute and try again.';
  static const String offline =
      'No connection. Please check your internet and try again.';
  static const String generic = 'Something went wrong. Please try again.';

  static String forVerification(Object error) {
    if (error is AuthException) {
      final message = error.message.toLowerCase();
      if (error.code == 'otp_expired' ||
          error.code == 'otp_disabled' ||
          message.contains('expired') ||
          message.contains('invalid')) {
        return invalidCode;
      }
      if (_isRateLimit(error)) return rateLimited;
      return error.message;
    }
    if (isConnectivityError(error)) return offline;
    return generic;
  }

  static String forSending(Object error) {
    if (error is AuthException) {
      if (_isRateLimit(error)) return rateLimited;
      return error.message;
    }
    if (isConnectivityError(error)) return offline;
    return generic;
  }

  static bool _isRateLimit(AuthException error) =>
      error.statusCode == '429' ||
      error.code == 'over_email_send_rate_limit' ||
      error.code == 'over_request_rate_limit';
}
