import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/utils/formatters.dart';

/// Colour of filled stars everywhere ratings appear.
const Color starColor = AppTheme.warning;

/// Five read-only stars for [rating] (whole and half stars).
class StarRating extends StatelessWidget {
  const StarRating({super.key, required this.rating, this.size = 16});

  /// 0–5.
  final double rating;
  final double size;

  @override
  Widget build(BuildContext context) {
    final empty = context.colorScheme.onSurface.withValues(alpha: 0.2);
    final value = rating.clamp(0, 5).toDouble();
    return Semantics(
      label: value == 0 ? 'Not rated yet' : 'Rated ${Formatters.rating(value)} out of 5',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 1; i <= 5; i++)
            Icon(
              value >= i
                  ? Icons.star_rounded
                  : value >= i - 0.5
                      ? Icons.star_half_rounded
                      : Icons.star_outline_rounded,
              size: size,
              color: value >= i - 0.5 ? starColor : empty,
            ),
        ],
      ),
    );
  }
}

/// Five tappable stars for choosing 1–5. [value] 0 means none chosen yet.
class StarRatingInput extends StatelessWidget {
  const StarRatingInput({super.key, required this.value, required this.onChanged, this.size = 40});

  final int value;
  final ValueChanged<int>? onChanged;
  final double size;

  static const labels = ['Poor', 'Fair', 'Good', 'Great', 'Excellent'];

  @override
  Widget build(BuildContext context) {
    final empty = context.colorScheme.onSurface.withValues(alpha: 0.25);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var stars = 1; stars <= 5; stars++)
          Semantics(
            button: true,
            selected: stars == value,
            label: '$stars ${stars == 1 ? 'star' : 'stars'}, ${labels[stars - 1]}',
            excludeSemantics: true,
            child: InkResponse(
              onTap: onChanged == null
                  ? null
                  : () {
                      HapticFeedback.selectionClick();
                      onChanged!(stars);
                    },
              radius: size * 0.7,
              child: Padding(
                padding: EdgeInsets.all(size * 0.12),
                child: AnimatedScale(
                  scale: stars <= value ? 1.08 : 1,
                  duration: const Duration(milliseconds: 150),
                  child: Icon(
                    stars <= value ? Icons.star_rounded : Icons.star_outline_rounded,
                    size: size,
                    color: stars <= value ? starColor : empty,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
