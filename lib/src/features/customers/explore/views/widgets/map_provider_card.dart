import 'package:flutter/material.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/utils/formatters.dart';
import '../../../../shared/reviews/views/widgets/star_rating.dart' show starColor;
import '../../models/provider_listing.dart';
import 'listing_widgets.dart';

/// A provider in the carousel along the bottom of the map.
class MapProviderCard extends StatelessWidget {
  const MapProviderCard({
    super.key,
    required this.listing,
    required this.selected,
    required this.onTap,
    this.distanceKm,
  });

  static const double height = 128;

  final ProviderListing listing;
  final bool selected;
  final VoidCallback onTap;

  /// From the client, when we know where they are.
  final double? distanceKm;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final muted = scheme.onSurface.withValues(alpha: 0.58);
    final categories = listingCategoryLine(listing, max: 2);
    final distance = distanceKm;
    final rating = listing.reviewCount > 0 ? listing.ratingAverage : null;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      margin: EdgeInsets.symmetric(horizontal: 6, vertical: selected ? 0 : 6),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: selected ? scheme.primary.withValues(alpha: 0.55) : scheme.onSurface.withValues(alpha: 0.06),
          width: selected ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: selected ? 0.16 : 0.1),
            blurRadius: selected ? 24 : 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                ListingImage(listing: listing, size: 96, radius: 16),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        listing.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: scheme.onSurface),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(
                            Icons.star_rounded,
                            size: 15,
                            color: rating == null ? scheme.primary : starColor,
                          ),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              [
                                rating == null
                                    ? (categories == null ? 'New on Myglo' : 'New')
                                    : '${Formatters.rating(rating)} (${Formatters.compactCount(listing.reviewCount)})',
                                ?categories,
                              ].join(' · '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: scheme.secondary),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        [
                          if (distance != null) Formatters.distanceKm(distance),
                          listingLocationLine(listing),
                        ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12.5, color: muted),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          // The pills share whatever the arrow leaves and
                          // shorten their labels rather than overflow.
                          Expanded(
                            child: Row(
                              children: [
                                if (listing.minPrice case final price?)
                                  Flexible(
                                    child: ListingPill(label: 'From ${Formatters.aud(price)}', color: scheme.onSurface),
                                  ),
                                if (!listing.acceptsBookings) ...[
                                  if (listing.minPrice != null) const SizedBox(width: 6),
                                  const Flexible(
                                    child: ListingPill(label: 'Paused', icon: Icons.pause_rounded, color: AppTheme.warning),
                                  ),
                                ] else if (listing.offersMobile) ...[
                                  if (listing.minPrice != null) const SizedBox(width: 6),
                                  Flexible(
                                    child: ListingPill(
                                      label: listing.mobileOnly ? 'Mobile' : 'Also mobile',
                                      icon: Icons.directions_car_rounded,
                                      color: scheme.secondary,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(Icons.arrow_forward_rounded, size: 18, color: scheme.onSurface.withValues(alpha: 0.4)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
