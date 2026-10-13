import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/app_config.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/utils/network_error.dart';

/// Why posting or removing a comment failed, with copy ready to show.
enum CommentFailureCode {
  /// Too many comments in the last minute (`comment_rate_limited`).
  rateLimited,

  /// Empty, or longer than [AppConfig.commentMaxLength].
  invalidLength,

  /// The post was deleted or hidden, or the comment isn't the viewer's.
  notAllowed,
  offline,
  unknown,
}

class CommentFailure implements Exception {
  const CommentFailure(this.code);

  final CommentFailureCode code;

  /// Maps anything thrown by a comments call to a [CommentFailure].
  static CommentFailure from(Object error) {
    if (error is CommentFailure) return error;
    if (error is PostgrestException) {
      if (error.message == 'comment_rate_limited') return const CommentFailure(CommentFailureCode.rateLimited);
      // check_violation, row-level security / privilege, foreign key.
      return switch (error.code) {
        '23514' => const CommentFailure(CommentFailureCode.invalidLength),
        '42501' || '23503' => const CommentFailure(CommentFailureCode.notAllowed),
        _ => const CommentFailure(CommentFailureCode.unknown),
      };
    }
    if (isConnectivityError(error)) return const CommentFailure(CommentFailureCode.offline);
    return const CommentFailure(CommentFailureCode.unknown);
  }

  /// Expected refusals aren't bugs, so they aren't reported to Sentry.
  bool get isExpected => code != CommentFailureCode.unknown;

  String get message => switch (code) {
        CommentFailureCode.rateLimited => "You're commenting very quickly. Please wait a moment and try again.",
        CommentFailureCode.invalidLength =>
          'Comments need between 1 and ${AppConfig.commentMaxLength} characters.',
        CommentFailureCode.notAllowed => "This post isn't available for comments any more.",
        CommentFailureCode.offline => 'You appear to be offline. Check your connection and try again.',
        CommentFailureCode.unknown => 'Something went wrong. Please try again in a moment.',
      };

  @override
  String toString() => 'CommentFailure(${code.name})';
}

/// Rethrows [error] from a comments call as a [CommentFailure]: expected
/// refusals are logged locally, anything else is reported to Sentry.
Never throwCommentError(Object error, StackTrace stackTrace, {required String action}) {
  final failure = CommentFailure.from(error);
  if (failure.isExpected) {
    AppLogger.w('$action refused: ${failure.code.name}', tag: 'Comments', error: error);
  } else {
    AppLogger.e('$action failed', tag: 'Comments', error: error, stackTrace: stackTrace);
  }
  Error.throwWithStackTrace(failure, stackTrace);
}
