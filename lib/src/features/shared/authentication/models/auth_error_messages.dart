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
  static const String suspended =
      'This account has been suspended. Contact Myglo support if you think this is a mistake.';

  static String forVerification(Object error) {
    if (error is AuthException) {
      if (_isBanned(error)) return suspended;
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
      if (_isBanned(error)) return suspended;
      if (_isRateLimit(error)) return rateLimited;
      return error.message;
    }
    if (isConnectivityError(error)) return offline;
    return generic;
  }

  static const String weakPassword =
      'That password is too easy to guess or has appeared in a data breach. Choose a different one.';
  static const String samePassword = 'Choose a password you haven\'t used on this account before.';
  static const String sessionExpired = 'That took a while. Request a new code and try again.';

  /// For choosing a new password after the reset code was accepted.
  static String forPasswordUpdate(Object error) {
    if (error is AuthException) {
      if (_isBanned(error)) return suspended;
      if (_isRateLimit(error)) return rateLimited;
      return switch (error.code) {
        'weak_password' => weakPassword,
        'same_password' => samePassword,
        'session_not_found' || 'session_expired' || 'reauthentication_needed' || 'no_authorization' => sessionExpired,
        _ => generic,
      };
    }
    if (isConnectivityError(error)) return offline;
    return generic;
  }

  /// Whether choosing a password failed because the reset session is gone,
  /// so the code step has to be done again.
  static bool needsNewCode(Object error) =>
      error is AuthException &&
      const {'session_not_found', 'session_expired', 'reauthentication_needed', 'no_authorization'}.contains(error.code);

  static const String phoneTaken = 'That number is already used by another Myglo account.';
  static const String phoneInvalid = "That doesn't look like a mobile number we can text. Check it and try again.";
  static const String smsFailed = "We couldn't send the text. Check the number and try again in a minute.";
  static const String smsUnavailable = "Phone verification isn't available right now. Please try again later.";
  static const String smsRateLimited = 'Too many texts requested. Please wait a few minutes and try again.';

  /// For texting a phone verification code.
  static String forPhoneCodeRequest(Object error) {
    if (error is AuthException) {
      if (_isBanned(error)) return suspended;
      return switch (error.code) {
        'phone_exists' => phoneTaken,
        'validation_failed' => phoneInvalid,
        'over_sms_send_rate_limit' => smsRateLimited,
        'sms_send_failed' => smsFailed,
        'phone_provider_disabled' => smsUnavailable,
        _ => _isRateLimit(error) ? smsRateLimited : generic,
      };
    }
    if (isConnectivityError(error)) return offline;
    return generic;
  }

  /// Suspended by Myglo's team (an Auth ban).
  static bool _isBanned(AuthException error) => error.code == 'user_banned';

  static bool _isRateLimit(AuthException error) =>
      error.statusCode == '429' ||
      error.code == 'over_email_send_rate_limit' ||
      error.code == 'over_sms_send_rate_limit' ||
      error.code == 'over_request_rate_limit';
}
