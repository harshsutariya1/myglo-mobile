import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../../core/maps/marker_icons.dart' show markerInitials;
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/utils/formatters.dart';
import '../../../../../core/widgets/skeleton/skeletons.dart';
import '../../../../shared/reviews/views/widgets/star_rating.dart' show starColor;
import '../../../explore/models/provider_listing.dart';
import '../../../explore/views/widgets/listing_widgets.dart';

/// Side of the photo on a nearby provider tile.
const double _tileImageSize = 96;

/// The words read out for a provider tile.
String _semanticLabel(ProviderListing listing, {required bool showDistance}) {
  final parts = <String>[
    listing.name,
    if ((listing.ratingAverage, listing.reviewCount) case (final rating?, final count) when count > 0)
      'rated ${Formatters.rating(rating)} from ${Formatters.reviewCount(count)}',
    ?listingCategoryLine(listing),
    listingLocationLine(listing),
    if (showDistance && listing.distanceKm != null) '${Formatters.distanceKm(listing.distanceKm!)} away',
    if (!listing.acceptsBookings) 'not taking bookings',
  ];
  return parts.join(', ');
}

/// A provider's cover (or profile photo), or a monogram on one of the brand
/// gradients when they haven't added a photo yet.
class ProviderArtwork extends StatelessWidget {
  const ProviderArtwork({super.key, required this.listing, required this.width, required this.height});

  final ProviderListing listing;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final url = listing.imageUrl;
    final fallback = _Monogram(listing: listing, size: Size(width, height));
    return SizedBox(
      width: width,
      height: height,
      child: url == null
          ? fallback
          : CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.cover,
              memCacheWidth: (width * MediaQuery.devicePixelRatioOf(context)).round(),
              fadeInDuration: const Duration(milliseconds: 220),
              placeholder: (_, _) => const Shimmer(child: SkeletonBox(borderRadius: 0)),
              errorWidget: (_, _, _) => fallback,
            ),
    );
  }
}

class _Monogram extends StatelessWidget {
  const _Monogram({required this.listing, required this.size});

  final ProviderListing listing;
  final Size size;

  /// Brand gradients, picked per provider so a list without photos still
  /// has some rhythm to it.
  static const _palettes = [
    [AppTheme.primaryPink, AppTheme.burntOrange],
    [AppTheme.peach, AppTheme.primaryPink],
    [AppTheme.burntOrange, Color(0xFF8E2C3F)],
    [AppTheme.lightPeach, AppTheme.burntOrange],
  ];

  @override
  Widget build(BuildContext context) {
    final seed = listing.id.codeUnits.fold<int>(0, (sum, unit) => (sum * 31 + unit) & 0x7fffffff);
    final colors = _palettes[seed % _palettes.length];
    final shortest = size.shortestSide;
    return ExcludeSemantics(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors),
        ),
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            Positioned(
              right: -shortest * 0.25,
              top: -shortest * 0.3,
              child: _Ring(diameter: shortest * 0.95),
            ),
            Positioned(
              left: -shortest * 0.2,
              bottom: -shortest * 0.35,
              child: _Ring(diameter: shortest * 0.7),
            ),
            Center(
              child: Text(
                markerInitials(listing.name),
                style: TextStyle(
                  fontSize: shortest * 0.32,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                  color: Colors.white,
                  shadows: [Shadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 12)],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Ring extends StatelessWidget {
  const _Ring({required this.diameter});

  final double diameter;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.1),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16), width: 1.2),
      ),
    );
  }
}

/// `★ 4.9 (23)` for a provider with at least one review.
class _RatingText extends StatelessWidget {
  const _RatingText({required this.rating, required this.reviewCount});

  final double rating;
  final int reviewCount;

  @override
  Widget build(BuildContext context) {
    final ink = context.colorScheme.onSurface;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.star_rounded, size: 15, color: starColor),
        const SizedBox(width: 3),
        Text(Formatters.rating(rating), style: TextStyle(fontWeight: FontWeight.w800, color: ink)),
        Text(
          ' (${Formatters.compactCount(reviewCount)})',
          style: TextStyle(fontWeight: FontWeight.w600, color: ink.withValues(alpha: 0.55)),
        ),
      ],
    );
  }
}

/// A provider in the home list: photo beside name, rating (once reviewed),
/// specialties and location.
class NearbyProviderTile extends StatelessWidget {
  const NearbyProviderTile({super.key, required this.listing, required this.showDistance, required this.onTap});

  final ProviderListing listing;
  final bool showDistance;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final muted = scheme.onSurface.withValues(alpha: 0.55);
    final categories = listingCategoryLine(listing);
    final distance = showDistance ? listing.distanceKm : null;

    return Semantics(
      button: true,
      label: _semanticLabel(listing, showDistance: showDistance),
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(color: AppTheme.darkRed.withValues(alpha: 0.05), blurRadius: 18, offset: const Offset(0, 6)),
          ],
        ),
        child: Material(
          color: scheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: BorderSide(color: scheme.onSurface.withValues(alpha: 0.07)),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: ProviderArtwork(listing: listing, width: _tileImageSize, height: _tileImageSize),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                listing.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 16,
                                  height: 1.25,
                                  fontWeight: FontWeight.w800,
                                  color: scheme.onSurface,
                                ),
                              ),
                            ),
                            if (distance != null) ...[
                              const SizedBox(width: 8),
                              ListingPill(label: Formatters.distanceKm(distance), icon: Icons.near_me_rounded),
                            ],
                          ],
                        ),
                        if ((listing.ratingAverage, listing.reviewCount) case (final rating?, final count)
                            when count > 0) ...[
                          const SizedBox(height: 4),
                          DefaultTextStyle.merge(
                            style: const TextStyle(fontSize: 13),
                            child: _RatingText(rating: rating, reviewCount: count),
                          ),
                        ],
                        if (categories != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            categories,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: scheme.secondary),
                          ),
                        ],
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              listing.mobileOnly ? Icons.directions_car_outlined : Icons.location_on_outlined,
                              size: 14,
                              color: muted,
                            ),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(
                                listingLocationLine(listing),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 13, color: muted),
                              ),
                            ),
                          ],
                        ),
                        if (!listing.acceptsBookings) ...[
                          const SizedBox(height: 8),
                          const FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: ListingPill(
                              label: 'Not taking bookings',
                              icon: Icons.pause_circle_outline_rounded,
                              color: AppTheme.warning,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Placeholder with the footprint of a [NearbyProviderTile].
class NearbyProviderTileSkeleton extends StatelessWidget {
  const NearbyProviderTileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: context.colorScheme.onSurface.withValues(alpha: 0.06)),
      ),
      child: const Row(
        children: [
          SkeletonBox(width: _tileImageSize, height: _tileImageSize, borderRadius: 18),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonText(style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800), widthFactor: 0.7),
                SizedBox(height: 6),
                SkeletonText(style: TextStyle(fontSize: 13), widthFactor: 0.5),
                SizedBox(height: 6),
                SkeletonText(style: TextStyle(fontSize: 13), widthFactor: 0.8),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
