import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../../core/maps/marker_icons.dart' show markerInitials;
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/utils/formatters.dart';
import '../../../../../core/widgets/skeleton/skeletons.dart';
import '../../models/provider_listing.dart';

/// [text] split into spans with every occurrence of any of [words]
/// (case-insensitive) in [highlight].
List<TextSpan> highlightMatches(String text, Iterable<String> words, {required TextStyle highlight}) {
  final needles = {for (final word in words) if (word.trim().isNotEmpty) word.trim().toLowerCase()};
  if (needles.isEmpty || text.isEmpty) return [TextSpan(text: text)];

  final lower = text.toLowerCase();
  final marked = List<bool>.filled(text.length, false);
  for (final needle in needles) {
    var from = 0;
    while (true) {
      final index = lower.indexOf(needle, from);
      if (index < 0) break;
      for (var i = index; i < index + needle.length && i < text.length; i++) {
        marked[i] = true;
      }
      from = index + needle.length;
    }
  }

  final spans = <TextSpan>[];
  var start = 0;
  for (var i = 1; i <= text.length; i++) {
    if (i == text.length || marked[i] != marked[start]) {
      final chunk = text.substring(start, i);
      spans.add(marked[start] ? TextSpan(text: chunk, style: highlight) : TextSpan(text: chunk));
      start = i;
    }
  }
  return spans;
}

/// Square-ish photo for a provider: their cover or profile photo, or their
/// initials on the brand gradient.
class ListingImage extends StatelessWidget {
  const ListingImage({super.key, required this.listing, required this.size, this.radius = 16});

  final ProviderListing listing;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final url = listing.imageUrl;
    final fallback = DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.primaryPink, AppTheme.burntOrange],
        ),
      ),
      child: Center(
        child: Text(
          markerInitials(listing.name),
          style: TextStyle(fontSize: size * 0.3, fontWeight: FontWeight.w800, color: Colors.white),
        ),
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox.square(
        dimension: size,
        child: url == null
            ? fallback
            : CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                memCacheWidth: (size * MediaQuery.devicePixelRatioOf(context)).round(),
                placeholder: (_, _) => const Shimmer(child: SkeletonBox(borderRadius: 0)),
                errorWidget: (_, _, _) => fallback,
              ),
      ),
    );
  }
}

/// Small rounded label, e.g. "2.4 km" or "Not taking bookings".
class ListingPill extends StatelessWidget {
  const ListingPill({super.key, required this.label, this.icon, this.color, this.filled = false});

  final String label;
  final IconData? icon;
  final Color? color;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? context.colorScheme.onSurface;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: filled ? tint : tint.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12.5, color: filled ? Colors.white : tint),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: filled ? Colors.white : Color.lerp(tint, Colors.black, 0.2),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Studio · Surfers Paradise QLD" style line under a provider's name.
String listingLocationLine(ProviderListing listing) {
  if (listing.mobileOnly) return 'Comes to you';
  final address = listing.addressText;
  if (address == null) return listing.offersMobile ? 'Studio and home visits' : 'Address on profile';
  return address;
}

/// "Hair · Nails · Lashes" from a provider's categories.
String? listingCategoryLine(ProviderListing listing, {int max = 3}) {
  if (listing.categories.isEmpty) return null;
  final shown = listing.categories.take(max).join(' · ');
  final more = listing.categories.length - max;
  return more > 0 ? '$shown +$more' : shown;
}

/// One search result.
class ProviderResultCard extends StatelessWidget {
  const ProviderResultCard({super.key, required this.listing, required this.query, required this.onTap});

  final ProviderListing listing;
  final String query;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final muted = scheme.onSurface.withValues(alpha: 0.58);
    final words = query.split(' ');
    final highlight = TextStyle(color: scheme.secondary, fontWeight: FontWeight.w900);
    final categories = listingCategoryLine(listing);
    final distance = listing.distanceKm;

    return Semantics(
      button: true,
      label: '${listing.name}, ${listingLocationLine(listing)}'
          '${distance == null ? '' : ', ${Formatters.distanceKm(distance)} away'}',
      child: Material(
        color: scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: scheme.onSurface.withValues(alpha: 0.08)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ListingImage(listing: listing, size: 76),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text.rich(
                                  TextSpan(children: highlightMatches(listing.name, words, highlight: highlight)),
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
                          if (categories != null) ...[
                            const SizedBox(height: 3),
                            Text(
                              categories,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: scheme.secondary),
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
                                child: Text.rich(
                                  TextSpan(
                                    children: highlightMatches(
                                      listingLocationLine(listing),
                                      words,
                                      highlight: highlight.copyWith(fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 13, color: muted),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              if (listing.minPrice case final price?)
                                ListingPill(label: 'From ${Formatters.aud(price)}', color: scheme.onSurface),
                              if (!listing.acceptsBookings)
                                const ListingPill(
                                  label: 'Not taking bookings',
                                  icon: Icons.pause_circle_outline_rounded,
                                  color: AppTheme.warning,
                                ),
                              if (listing.serviceCount == 0)
                                ListingPill(label: 'No services yet', color: scheme.onSurface),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (listing.matchedServices.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Divider(height: 1, color: scheme.onSurface.withValues(alpha: 0.06)),
                  const SizedBox(height: 8),
                  for (final service in listing.matchedServices)
                    _MatchedServiceRow(service: service, words: words, highlight: highlight),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MatchedServiceRow extends StatelessWidget {
  const _MatchedServiceRow({required this.service, required this.words, required this.highlight});

  final MatchedService service;
  final List<String> words;
  final TextStyle highlight;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final details = [
      if (service.durationMinutes case final minutes? when minutes > 0) Formatters.duration(minutes),
      if (service.price case final price?) Formatters.aud(price),
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(Icons.content_cut_rounded, size: 14, color: scheme.secondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text.rich(
              TextSpan(children: highlightMatches(service.name, words, highlight: highlight)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: scheme.onSurface),
            ),
          ),
          if (details.isNotEmpty) ...[
            const SizedBox(width: 8),
            Text(
              details,
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: scheme.onSurface.withValues(alpha: 0.55)),
            ),
          ],
        ],
      ),
    );
  }
}

/// Placeholder rows matching [ProviderResultCard] while a search runs.
class ProviderResultSkeleton extends StatelessWidget {
  const ProviderResultSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: context.colorScheme.onSurface.withValues(alpha: 0.06)),
        ),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SkeletonBox(width: 76, height: 76, borderRadius: 16),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonText(style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800), widthFactor: 0.7),
                  SizedBox(height: 6),
                  SkeletonText(style: TextStyle(fontSize: 13), widthFactor: 0.45),
                  SizedBox(height: 6),
                  SkeletonText(style: TextStyle(fontSize: 13), widthFactor: 0.8),
                  SizedBox(height: 10),
                  SkeletonBox(width: 80, height: 22, borderRadius: 999),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
