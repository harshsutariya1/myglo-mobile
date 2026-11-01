import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/utils/app_logger.dart';
import '../../../../core/utils/network_error.dart';

/// Why a report was refused. `submit_report` raises these keys as its error
/// message (see the moderation migration).
enum ReportFailureCode {
  notAuthenticated('not_authenticated'),
  profileRequired('profile_required'),
  accountSuspended('account_suspended'),
  invalidRequest('invalid_request'),
  targetNotFound('report_target_not_found'),
  windowClosed('report_window_closed'),
  tooManyReports('too_many_reports'),

  /// The request never reached the server (or its reply never came back).
  offline('offline'),
  unknown('unknown');

  const ReportFailureCode(this.key);

  final String key;

  static ReportFailureCode fromKey(String? key) {
    for (final code in values) {
      if (code.key == key) return code;
    }
    return unknown;
  }
}

/// A report that couldn't be sent, with copy ready to show the user.
class ReportFailure implements Exception {
  const ReportFailure(this.code);

  final ReportFailureCode code;

  /// Maps anything thrown by a report call to a [ReportFailure].
  static ReportFailure from(Object error) {
    if (error is ReportFailure) return error;
    if (error is PostgrestException) return ReportFailure(ReportFailureCode.fromKey(error.message));
    if (isConnectivityError(error)) return const ReportFailure(ReportFailureCode.offline);
    return const ReportFailure(ReportFailureCode.unknown);
  }

  /// Expected refusals and outages aren't bugs, so they aren't reported to
  /// Sentry.
  bool get isExpected => code != ReportFailureCode.unknown && code != ReportFailureCode.invalidRequest;

  String get message => switch (code) {
    ReportFailureCode.notAuthenticated => 'Your session has expired. Please sign in again.',
    ReportFailureCode.profileRequired => 'Finish setting up your account to send reports.',
    ReportFailureCode.accountSuspended =>
      "Your account is suspended, so it can't send reports. Contact Myglo support if you think this is a mistake.",
    ReportFailureCode.targetNotFound => "This isn't available to report any more.",
    ReportFailureCode.windowClosed =>
      'Problems with a booking can be reported from the start of the appointment until shortly after it ends. '
          'For anything later, contact Myglo support.',
    ReportFailureCode.tooManyReports => "You've sent a lot of reports today. Please try again tomorrow.",
    ReportFailureCode.offline => 'You appear to be offline. Check your connection and try again.',
    ReportFailureCode.invalidRequest ||
    ReportFailureCode.unknown => "We couldn't send your report. Please try again in a moment.",
  };

  @override
  String toString() => 'ReportFailure(${code.key})';
}

/// Rethrows [error] from a report call as a [ReportFailure]: expected
/// refusals are logged locally, anything else is reported to Sentry.
Never throwReportError(Object error, StackTrace stackTrace, {required String action}) {
  final failure = ReportFailure.from(error);
  if (failure.isExpected) {
    AppLogger.w('$action refused: ${failure.code.key}', tag: 'Reports', error: error);
  } else {
    AppLogger.e('$action failed', tag: 'Reports', error: error, stackTrace: stackTrace);
  }
  Error.throwWithStackTrace(failure, stackTrace);
}
