import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../../core/utils/network_error.dart';

/// Why a review action was refused. The review RPCs raise these keys as
/// their error message (see the reviews migration).
enum ReviewFailureCode {
  notAuthenticated('not_authenticated'),
  invalidRating('invalid_rating'),
  reviewTooLong('review_too_long'),
  replyTooLong('reply_too_long'),
  tooManyPhotos('too_many_photos'),
  invalidPhotos('invalid_photos'),
  bookingNotFound('booking_not_found'),
  bookingNotCompleted('booking_not_completed'),
  providerUnavailable('provider_unavailable'),
  reviewNotFound('review_not_found'),

  /// A photo couldn't be prepared or uploaded.
  photoUploadFailed('photo_upload_failed'),

  /// The request never reached the server (or its reply never came back).
  offline('offline'),
  unknown('unknown');

  const ReviewFailureCode(this.key);

  final String key;

  static ReviewFailureCode fromKey(String? key) {
    for (final code in values) {
      if (code.key == key) return code;
    }
    return unknown;
  }
}

/// A review action that failed, with copy ready to show the user.
class ReviewFailure implements Exception {
  const ReviewFailure(this.code);

  final ReviewFailureCode code;

  /// Maps anything thrown by a review call to a [ReviewFailure].
  static ReviewFailure from(Object error) {
    if (error is ReviewFailure) return error;
    if (error is PostgrestException) return ReviewFailure(ReviewFailureCode.fromKey(error.message));
    if (isConnectivityError(error)) return const ReviewFailure(ReviewFailureCode.offline);
    return const ReviewFailure(ReviewFailureCode.unknown);
  }

  /// Expected refusals and outages aren't bugs, so they aren't reported to
  /// Sentry.
  bool get isExpected => code != ReviewFailureCode.unknown && code != ReviewFailureCode.photoUploadFailed;

  String get message => switch (code) {
        ReviewFailureCode.notAuthenticated => 'Your session has expired. Please sign in again.',
        ReviewFailureCode.invalidRating => 'Choose from 1 to 5 stars.',
        ReviewFailureCode.reviewTooLong =>
          'Reviews can be up to ${AppConfig.reviewMaxLength} characters. Please shorten yours.',
        ReviewFailureCode.replyTooLong =>
          'Replies can be up to ${AppConfig.reviewMaxLength} characters. Please shorten yours.',
        ReviewFailureCode.tooManyPhotos => 'You can add up to ${AppConfig.reviewMaxPhotos} photos.',
        ReviewFailureCode.invalidPhotos => "Some photos didn't upload properly. Please add them again.",
        ReviewFailureCode.bookingNotFound => "We couldn't find that booking.",
        ReviewFailureCode.bookingNotCompleted => 'You can review an appointment once it has been completed.',
        ReviewFailureCode.providerUnavailable => "This provider isn't on Myglo any more, so it can't be reviewed.",
        ReviewFailureCode.reviewNotFound => 'This review was removed or changed. Pull down to refresh.',
        ReviewFailureCode.photoUploadFailed => "We couldn't upload your photos. Please try again.",
        ReviewFailureCode.offline => 'You appear to be offline. Check your connection and try again.',
        ReviewFailureCode.unknown => 'Something went wrong. Please try again in a moment.',
      };

  @override
  String toString() => 'ReviewFailure(${code.key})';
}

/// Rethrows [error] from a review call as a [ReviewFailure]: expected
/// refusals are logged locally, anything else is reported to Sentry.
Never throwReviewError(Object error, StackTrace stackTrace, {required String action}) {
  final failure = ReviewFailure.from(error);
  if (failure.isExpected) {
    AppLogger.w('$action refused: ${failure.code.key}', tag: 'Reviews', error: error);
  } else {
    AppLogger.e('$action failed', tag: 'Reviews', error: error, stackTrace: stackTrace);
  }
  Error.throwWithStackTrace(failure, stackTrace);
}
