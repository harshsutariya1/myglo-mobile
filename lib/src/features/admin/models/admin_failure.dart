import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/utils/app_logger.dart';
import '../../../core/utils/network_error.dart';

/// Rethrows [error] from an admin call. Refusals the server raises on purpose
/// (no fresh two-factor code, invalid setting…) become an [AdminFailure] and
/// are only logged locally; anything else is reported to Sentry and rethrown
/// unchanged, so connectivity errors still reach the offline handling.
Never throwAdminError(Object error, StackTrace stackTrace, {required String action}) {
  if (error is PostgrestException) {
    final failure = AdminFailure.from(error);
    if (failure.isExpected) {
      AppLogger.w('$action refused: ${failure.code.key}', tag: AdminFailure.tag);
      Error.throwWithStackTrace(failure, stackTrace);
    }
  }
  AppLogger.e('$action failed', tag: AdminFailure.tag, error: error, stackTrace: stackTrace);
  Error.throwWithStackTrace(error, stackTrace);
}

/// Why an admin action was refused. The admin RPCs raise these keys as their
/// error message (see the admin foundation migration).
enum AdminFailureCode {
  notAuthenticated('not_authenticated'),
  adminRequired('admin_required'),

  /// The session hasn't passed two-factor.
  mfaRequired('mfa_required'),

  /// The last two-factor check is older than the admin session allows.
  sessionExpired('admin_session_expired'),

  /// A sensitive action needs a two-factor code from the last few minutes.
  reauthRequired('reauth_required'),
  reasonRequired('reason_required'),
  invalidSetting('invalid_setting'),
  invalidLocation('invalid_location'),
  invalidCity('invalid_city'),
  cityExists('city_exists'),
  notFound('not_found'),
  invalidRequest('invalid_request'),

  /// A refund larger than what's left to refund.
  invalidAmount('invalid_amount'),
  bookingNotCancellable('booking_not_cancellable'),
  settlementNotHoldable('settlement_not_holdable'),
  settlementNotHeld('settlement_not_held'),
  jobNotFailed('job_not_failed'),

  /// The request never reached the server (or its reply never came back).
  offline('offline'),
  unknown('unknown');

  const AdminFailureCode(this.key);

  final String key;

  static AdminFailureCode fromKey(String? key) {
    for (final code in values) {
      if (code.key == key) return code;
    }
    return unknown;
  }
}

/// An admin action the server refused, or that couldn't reach it, with copy
/// ready to show.
class AdminFailure implements Exception {
  const AdminFailure(this.code, {this.detail});

  static const tag = 'Admin';

  final AdminFailureCode code;

  /// The server's DETAIL, e.g. which setting was invalid.
  final String? detail;

  static AdminFailure from(Object error) {
    if (error is AdminFailure) return error;
    if (error is PostgrestException) {
      final detail = error.details is String ? error.details as String : null;
      return AdminFailure(AdminFailureCode.fromKey(error.message), detail: detail);
    }
    if (isConnectivityError(error)) return const AdminFailure(AdminFailureCode.offline);
    return const AdminFailure(AdminFailureCode.unknown);
  }

  bool get isExpected => code != AdminFailureCode.unknown;

  /// The session itself is no longer good enough: send the admin back to
  /// two-factor verification.
  bool get needsVerification =>
      code == AdminFailureCode.mfaRequired || code == AdminFailureCode.sessionExpired;

  String get message => switch (code) {
        AdminFailureCode.notAuthenticated => 'Your session ended. Please sign in again.',
        AdminFailureCode.adminRequired => "This account doesn't have admin access.",
        AdminFailureCode.mfaRequired => 'Enter your authenticator code to continue.',
        AdminFailureCode.sessionExpired => 'Your admin session expired. Enter your authenticator code to continue.',
        AdminFailureCode.reauthRequired => 'Confirm with a fresh authenticator code to make this change.',
        AdminFailureCode.reasonRequired => 'Add a reason (at least 3 characters).',
        AdminFailureCode.invalidSetting => detail == null || detail!.isEmpty
            ? "One of the values isn't allowed."
            : "That value isn't allowed ($detail).",
        AdminFailureCode.invalidLocation => 'Choose a centre inside Australia.',
        AdminFailureCode.invalidCity => 'Check the name, state and radius.',
        AdminFailureCode.cityExists => 'A city with that name and state already exists.',
        AdminFailureCode.notFound => "That record doesn't exist any more.",
        AdminFailureCode.invalidRequest => "That request wasn't valid.",
        AdminFailureCode.invalidAmount => "That's more than is left to refund on this booking.",
        AdminFailureCode.bookingNotCancellable => 'Only upcoming bookings and requests can be cancelled.',
        AdminFailureCode.settlementNotHoldable => "The provider's share has already been paid or settled.",
        AdminFailureCode.settlementNotHeld => "The provider's share isn't on hold.",
        AdminFailureCode.jobNotFailed => 'That job is no longer failed; it may already have been retried.',
        AdminFailureCode.offline => "You're offline. Check your connection and try again.",
        AdminFailureCode.unknown => 'Something went wrong. Please try again.',
      };

  @override
  String toString() => 'AdminFailure(${code.key})';
}
