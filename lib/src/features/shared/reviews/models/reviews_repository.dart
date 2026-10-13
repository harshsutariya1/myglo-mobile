import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/utils/app_logger.dart';
import '../../authentication/models/auth_repository.dart';
import 'review.dart';
import 'review_failure.dart';
import 'review_summary.dart';

final reviewsRepositoryProvider = Provider<ReviewsRepository>((ref) {
  return ReviewsRepository(ref.watch(supabaseClientProvider));
});

/// Reviews of completed bookings. Reads are open to every signed-in user;
/// every write goes through an RPC that checks who may make it (see the
/// reviews migration).
class ReviewsRepository {
  ReviewsRepository(this._client);

  final SupabaseClient _client;

  static const _tag = 'ReviewsRepository';

  /// One page of reviews, newest first, for a provider, a service or one
  /// booking (pass at least one). Pass the last review shown as [before] for
  /// the next page.
  Future<List<Review>> list({
    String? providerId,
    String? serviceId,
    String? bookingId,
    Review? before,
    required int limit,
  }) async {
    assert(providerId != null || serviceId != null || bookingId != null, 'A review filter is required');
    final sw = Stopwatch()..start();
    try {
      final rows = await _client.rpc('list_reviews', params: {
        'p_provider_id': providerId,
        'p_service_id': serviceId,
        'p_booking_id': bookingId,
        'p_before': before?.createdAt.toUtc().toIso8601String(),
        'p_before_id': before?.id,
        'p_limit': limit,
      }) as List<dynamic>;
      sw.stop();
      AppLogger.api('rpc.list_reviews', count: rows.length, duration: sw.elapsed);
      return [for (final row in rows) Review.fromJson(Map<String, dynamic>.from(row as Map))];
    } catch (e, st) {
      AppLogger.e('Failed to load reviews', tag: _tag, error: e, stackTrace: st);
      rethrow;
    }
  }

  /// A provider's totals (empty when nobody has reviewed them yet).
  Future<ReviewSummary> providerSummary(String providerId) async {
    final sw = Stopwatch()..start();
    try {
      final row = await _client.from('provider_review_stats').select().eq('provider_id', providerId).maybeSingle();
      sw.stop();
      AppLogger.api('provider_review_stats.select', endpoint: 'provider=$providerId', duration: sw.elapsed);
      return row == null ? ReviewSummary.empty : ReviewSummary.fromJson(row);
    } catch (e, st) {
      AppLogger.e('Failed to load review totals for provider $providerId', tag: _tag, error: e, stackTrace: st);
      rethrow;
    }
  }

  /// One service's totals.
  Future<ReviewSummary> serviceSummary(String serviceId) async {
    final sw = Stopwatch()..start();
    try {
      final rows = await _client.rpc('get_service_review_summary', params: {'p_service_id': serviceId}) as List<dynamic>;
      sw.stop();
      AppLogger.api('rpc.get_service_review_summary', endpoint: 'service=$serviceId', duration: sw.elapsed);
      return rows.isEmpty ? ReviewSummary.empty : ReviewSummary.fromJson(Map<String, dynamic>.from(rows.first as Map));
    } catch (e, st) {
      AppLogger.e('Failed to load review totals for service $serviceId', tag: _tag, error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Creates or updates the signed-in client's review of [bookingId] and
  /// returns its id. [photoUrls]: null keeps the current photos, empty
  /// removes them, otherwise the full new list (already uploaded).
  /// Throws a [ReviewFailure].
  Future<String> submit({
    required String bookingId,
    required int rating,
    String? body,
    List<String>? photoUrls,
  }) async {
    final sw = Stopwatch()..start();
    try {
      final row = await _client.rpc('submit_review', params: {
        'p_booking_id': bookingId,
        'p_rating': rating,
        'p_body': body,
        'p_photo_urls': photoUrls,
      }) as Map<String, dynamic>;
      sw.stop();
      AppLogger.api('rpc.submit_review', endpoint: 'booking=$bookingId', duration: sw.elapsed);
      return row['id'] as String;
    } catch (e, st) {
      throwReviewError(e, st, action: 'Submitting a review');
    }
  }

  /// Deletes the signed-in client's review (and its photo post). Returns the
  /// photo URLs that were on it. Throws a [ReviewFailure].
  Future<List<String>> delete(String reviewId) async {
    final sw = Stopwatch()..start();
    try {
      final urls = await _client.rpc('delete_review', params: {'p_review_id': reviewId}) as List<dynamic>?;
      sw.stop();
      AppLogger.api('rpc.delete_review', endpoint: 'review=$reviewId', duration: sw.elapsed);
      return [for (final url in urls ?? const []) url as String];
    } catch (e, st) {
      throwReviewError(e, st, action: 'Deleting a review');
    }
  }

  /// Sets the signed-in provider's public reply to [reviewId], or removes it
  /// when [reply] is blank. Throws a [ReviewFailure].
  Future<void> reply(String reviewId, String? reply) async {
    final sw = Stopwatch()..start();
    try {
      await _client.rpc('reply_to_review', params: {'p_review_id': reviewId, 'p_reply': reply});
      sw.stop();
      AppLogger.api('rpc.reply_to_review', endpoint: 'review=$reviewId', duration: sw.elapsed);
    } catch (e, st) {
      throwReviewError(e, st, action: 'Replying to a review');
    }
  }
}
