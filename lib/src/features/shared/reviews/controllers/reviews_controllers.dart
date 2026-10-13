import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../discovery_feed/controllers/discovery_feed_controller.dart';
import '../../../discovery_feed/controllers/service_posts_controller.dart';
import '../../../discovery_feed/controllers/user_posts_controller.dart';
import '../../../discovery_feed/models/post_repository.dart';
import '../../authentication/controllers/user_profile_provider.dart';
import '../../bookings/controllers/booking_controllers.dart';
import '../models/review.dart';
import '../models/review_failure.dart';
import '../models/review_summary.dart';
import '../models/reviews_repository.dart';

/// Which reviews: a provider's, or one service's.
typedef ReviewQuery = ({String? providerId, String? serviceId});

/// A provider's review totals (rating, count, star breakdown).
final providerReviewSummaryProvider = FutureProvider.autoDispose.family<ReviewSummary, String>((ref, providerId) {
  return ref.watch(reviewsRepositoryProvider).providerSummary(providerId);
});

/// One service's review totals.
final serviceReviewSummaryProvider = FutureProvider.autoDispose.family<ReviewSummary, String>((ref, serviceId) {
  return ref.watch(reviewsRepositoryProvider).serviceSummary(serviceId);
});

/// The newest few reviews for [ReviewQuery], previewed on a profile or service.
final reviewsPreviewProvider = FutureProvider.autoDispose.family<List<Review>, ReviewQuery>((ref, query) {
  return ref.watch(reviewsRepositoryProvider).list(
        providerId: query.providerId,
        serviceId: query.serviceId,
        limit: AppConfig.reviewsPreviewCount,
      );
});

/// The review of one booking, if the client left one.
final bookingReviewProvider = FutureProvider.autoDispose.family<Review?, String>((ref, bookingId) async {
  final reviews = await ref.watch(reviewsRepositoryProvider).list(bookingId: bookingId, limit: 1);
  return reviews.firstOrNull;
});

/// A loaded list of reviews, possibly with more to fetch.
class ReviewPage {
  const ReviewPage({required this.items, required this.hasMore, this.loadingMore = false, this.loadMoreFailed = false});

  final List<Review> items;
  final bool hasMore;
  final bool loadingMore;
  final bool loadMoreFailed;

  ReviewPage copyWith({List<Review>? items, bool? hasMore, bool? loadingMore, bool? loadMoreFailed}) => ReviewPage(
        items: items ?? this.items,
        hasMore: hasMore ?? this.hasMore,
        loadingMore: loadingMore ?? this.loadingMore,
        loadMoreFailed: loadMoreFailed ?? this.loadMoreFailed,
      );
}

final reviewListProvider =
    AsyncNotifierProvider.autoDispose.family<ReviewListController, ReviewPage, ReviewQuery>(ReviewListController.new);

/// Every review for a [ReviewQuery], newest first, paged on demand.
class ReviewListController extends AsyncNotifier<ReviewPage> {
  ReviewListController(this.query);

  final ReviewQuery query;

  int get _pageSize => AppConfig.reviewsPageSize;

  @override
  Future<ReviewPage> build() async {
    final items = await ref.read(reviewsRepositoryProvider).list(
          providerId: query.providerId,
          serviceId: query.serviceId,
          limit: _pageSize,
        );
    return ReviewPage(items: items, hasMore: items.length >= _pageSize);
  }

  /// Appends the next page. Failures keep what's loaded, and scrolling won't
  /// retry on its own after one; pass [retry] when the viewer asks to.
  Future<void> loadMore({bool retry = false}) async {
    final current = state.value;
    if (current == null || !current.hasMore || current.loadingMore || current.items.isEmpty) return;
    if (current.loadMoreFailed && !retry) return;
    state = AsyncData(current.copyWith(loadingMore: true, loadMoreFailed: false));
    try {
      final next = await ref.read(reviewsRepositoryProvider).list(
            providerId: query.providerId,
            serviceId: query.serviceId,
            before: current.items.last,
            limit: _pageSize,
          );
      if (!ref.mounted) return;
      final known = {for (final review in current.items) review.id};
      state = AsyncData(ReviewPage(
        items: [...current.items, ...next.where((review) => known.add(review.id))],
        hasMore: next.length >= _pageSize,
      ));
    } catch (_) {
      // Already reported by the repository.
      if (ref.mounted) state = AsyncData(current.copyWith(loadingMore: false, loadMoreFailed: true));
    }
  }
}

/// Writing, editing, deleting and replying to reviews. Each method throws a
/// [ReviewFailure] whose message can be shown as is.
final reviewActionsProvider = Provider<ReviewActions>(ReviewActions.new);

class ReviewActions {
  ReviewActions(this._ref);

  final Ref _ref;

  static const _tag = 'ReviewActions';

  ReviewsRepository get _reviews => _ref.read(reviewsRepositoryProvider);
  PostRepository get _posts => _ref.read(postRepositoryProvider);

  /// Saves the signed-in client's review of [bookingId] with [providerId].
  ///
  /// Photos: [keptPhotoUrls] are the review's existing photos still wanted
  /// (in order), [newPhotos] are uploaded and added after them, and anything
  /// in [originalPhotoUrls] not kept is deleted once the review is saved. If
  /// saving fails, the new uploads are removed again.
  Future<void> submit({
    required String bookingId,
    required String providerId,
    required int rating,
    required String body,
    List<String> originalPhotoUrls = const [],
    List<String> keptPhotoUrls = const [],
    List<File> newPhotos = const [],
  }) async {
    final String? userId;
    try {
      userId = (await _ref.read(userProfileProvider.future))?.rawUser.id;
    } catch (e) {
      throw ReviewFailure.from(e);
    }
    if (userId == null) throw const ReviewFailure(ReviewFailureCode.notAuthenticated);
    if (keptPhotoUrls.length + newPhotos.length > AppConfig.reviewMaxPhotos) {
      throw const ReviewFailure(ReviewFailureCode.tooManyPhotos);
    }
    final photosChanged = newPhotos.isNotEmpty || !listEquals(keptPhotoUrls, originalPhotoUrls);

    final uploaded = <String>[];
    try {
      for (final photo in newPhotos) {
        uploaded.add(await _posts.uploadPostMedia(userId, photo));
      }
    } catch (e, st) {
      AppLogger.e('Uploading review photos failed', tag: _tag, error: e, stackTrace: st);
      await _discardUploads(uploaded);
      throw ReviewFailure.from(e).code == ReviewFailureCode.offline
          ? const ReviewFailure(ReviewFailureCode.offline)
          : const ReviewFailure(ReviewFailureCode.photoUploadFailed);
    }

    try {
      final trimmed = body.trim();
      await _reviews.submit(
        bookingId: bookingId,
        rating: rating,
        body: trimmed.isEmpty ? null : trimmed,
        photoUrls: photosChanged ? [...keptPhotoUrls, ...uploaded] : null,
      );
    } catch (e) {
      await _discardUploads(uploaded);
      throw ReviewFailure.from(e);
    }

    final removed = originalPhotoUrls.where((url) => !keptPhotoUrls.contains(url)).toList();
    await _discardUploads(removed);
    _refresh(providerId: providerId, bookingId: bookingId, clientId: userId, photosChanged: photosChanged);
  }

  /// Deletes the signed-in client's [review] and its photos.
  Future<void> delete(Review review) async {
    final List<String> photos;
    try {
      photos = await _reviews.delete(review.id);
    } catch (e) {
      throw ReviewFailure.from(e);
    }
    await _discardUploads(photos);
    _refresh(
      providerId: review.providerId,
      bookingId: review.bookingId,
      clientId: review.clientId,
      photosChanged: photos.isNotEmpty,
    );
  }

  /// Sets the signed-in provider's reply to [review]; blank removes it.
  Future<void> reply(Review review, String text) async {
    final trimmed = text.trim();
    try {
      await _reviews.reply(review.id, trimmed.isEmpty ? null : trimmed);
    } catch (e) {
      throw ReviewFailure.from(e);
    }
    _refresh(providerId: review.providerId, bookingId: review.bookingId, clientId: review.clientId);
  }

  /// Best-effort removal of photo files nothing points at any more. A
  /// failure only leaves an orphaned file, so it's logged, not surfaced.
  Future<void> _discardUploads(List<String> urls) async {
    if (urls.isEmpty) return;
    try {
      await _posts.removeMedia(urls);
    } catch (e, st) {
      AppLogger.w('Removing ${urls.length} unused review photo(s) failed', tag: _tag, error: e, stackTrace: st);
    }
  }

  void _refresh({
    required String providerId,
    required String bookingId,
    required String clientId,
    bool photosChanged = false,
  }) {
    _ref
      ..invalidate(providerReviewSummaryProvider(providerId))
      ..invalidate(serviceReviewSummaryProvider)
      ..invalidate(reviewsPreviewProvider)
      ..invalidate(reviewListProvider)
      ..invalidate(bookingReviewProvider(bookingId))
      ..invalidate(bookingDetailsProvider(bookingId))
      ..invalidate(bookingListProvider);
    if (photosChanged) {
      _ref
        ..invalidate(discoveryFeedProvider)
        ..invalidate(servicePostsProvider)
        ..invalidate(userPostsProvider(clientId));
    }
  }
}
