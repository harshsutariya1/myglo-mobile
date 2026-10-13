import 'package:flutter/foundation.dart';

/// Totals for a set of reviews (a provider's, or one service's).
@immutable
class ReviewSummary {
  const ReviewSummary({required this.count, required this.average, required this.starCounts});

  /// Nothing reviewed yet.
  static const empty = ReviewSummary(count: 0, average: null, starCounts: [0, 0, 0, 0, 0]);

  final int count;

  /// Null when there are no reviews.
  final double? average;

  /// How many reviews gave 1, 2, 3, 4 and 5 stars (in that order).
  final List<int> starCounts;

  bool get isEmpty => count == 0 || average == null;

  /// Reviews that gave [stars] (1–5).
  int countFor(int stars) => starCounts[stars - 1];

  /// A `provider_review_stats` row or `get_service_review_summary` row.
  factory ReviewSummary.fromJson(Map<String, dynamic> json) {
    final count = (json['review_count'] as num? ?? 0).toInt();
    final average = (json['rating_average'] as num?)?.toDouble();
    return ReviewSummary(
      count: count,
      average: count > 0 ? average : null,
      starCounts: [for (var stars = 1; stars <= 5; stars++) (json['stars_$stars'] as num? ?? 0).toInt()],
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ReviewSummary &&
      other.count == count &&
      other.average == average &&
      listEquals(other.starCounts, starCounts);

  @override
  int get hashCode => Object.hash(count, average, Object.hashAll(starCounts));
}
