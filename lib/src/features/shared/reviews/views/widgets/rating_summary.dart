import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/utils/formatters.dart';
import '../../../../../core/widgets/skeleton/skeletons.dart';
import '../../controllers/reviews_controllers.dart';
import '../../models/review_summary.dart';
import 'star_rating.dart';

/// Text for a rating in one line: `4.8 (23 reviews)`, or `New · No reviews
/// yet` before the first review.
String ratingLineText(ReviewSummary summary) => summary.isEmpty
    ? 'New · No reviews yet'
    : '${Formatters.rating(summary.average!)} (${Formatters.reviewCount(summary.count)})';

/// A star and [ratingLineText], for headers and cards.
class RatingLine extends StatelessWidget {
  const RatingLine({super.key, required this.summary, this.style, this.iconSize = 16});

  final ReviewSummary summary;
  final TextStyle? style;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final muted = context.colorScheme.onSurface.withValues(alpha: 0.6);
    final base = (style ?? const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)).copyWith(color: style?.color ?? muted);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          summary.isEmpty ? Icons.star_outline_rounded : Icons.star_rounded,
          size: iconSize,
          color: summary.isEmpty ? context.colorScheme.secondary : starColor,
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text.rich(
            summary.isEmpty
                ? TextSpan(text: ratingLineText(summary))
                : TextSpan(children: [
                    TextSpan(
                      text: Formatters.rating(summary.average!),
                      style: TextStyle(fontWeight: FontWeight.w800, color: context.colorScheme.onSurface),
                    ),
                    TextSpan(text: ' (${Formatters.reviewCount(summary.count)})'),
                  ]),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: base,
          ),
        ),
      ],
    );
  }
}

/// [RatingLine] for a provider, loaded live. Keeps its height while loading;
/// a failure (already reported) falls back to the "new" line.
class ProviderRatingLine extends ConsumerWidget {
  const ProviderRatingLine({super.key, required this.providerId, this.style, this.iconSize = 16});

  final String providerId;
  final TextStyle? style;
  final double iconSize;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(providerReviewSummaryProvider(providerId));
    return switch (async) {
      AsyncData(:final value) => RatingLine(summary: value, style: style, iconSize: iconSize),
      AsyncError() => RatingLine(summary: ReviewSummary.empty, style: style, iconSize: iconSize),
      _ => Shimmer(child: SkeletonBox(width: 110, height: iconSize, borderRadius: 6)),
    };
  }
}

/// The average, its stars, the count, and a bar per star level.
class RatingSummaryCard extends StatelessWidget {
  const RatingSummaryCard({super.key, required this.summary});

  final ReviewSummary summary;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final muted = scheme.onSurface.withValues(alpha: 0.6);
    final average = summary.average;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.onSurface.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 104,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  average == null ? '–' : Formatters.rating(average),
                  style: TextStyle(fontSize: 36, height: 1.1, fontWeight: FontWeight.w900, color: scheme.onSurface),
                ),
                const SizedBox(height: 4),
                StarRating(rating: average ?? 0, size: 15),
                const SizedBox(height: 6),
                Text(
                  summary.isEmpty ? 'No reviews yet' : Formatters.reviewCount(summary.count),
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var stars = 5; stars >= 1; stars--)
                  _StarBar(stars: stars, count: summary.countFor(stars), total: summary.count),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StarBar extends StatelessWidget {
  const _StarBar({required this.stars, required this.count, required this.total});

  final int stars;
  final int count;
  final int total;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final muted = scheme.onSurface.withValues(alpha: 0.6);
    return Semantics(
      label: '$stars ${stars == 1 ? 'star' : 'stars'}: $count',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2.5),
        child: Row(
          children: [
            SizedBox(
              width: 12,
              child: Text('$stars', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: muted)),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: total == 0 ? 0 : count / total,
                  minHeight: 7,
                  backgroundColor: scheme.onSurface.withValues(alpha: 0.07),
                  color: starColor,
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 24,
              child: Text(
                Formatters.compactCount(count),
                textAlign: TextAlign.end,
                style: TextStyle(fontSize: 12, color: muted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
