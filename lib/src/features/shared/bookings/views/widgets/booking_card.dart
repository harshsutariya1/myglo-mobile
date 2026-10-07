import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/utils/formatters.dart';
import '../../../../../core/widgets/skeleton/skeletons.dart';
import '../../models/booking.dart';
import '../../models/booking_enums.dart';
import 'booking_pills.dart';

/// Round photo with initials as the fallback.
class PersonAvatar extends StatelessWidget {
  const PersonAvatar({super.key, required this.name, this.url, this.size = 40});

  final String name;
  final String? url;
  final double size;

  String get _initials => name
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .take(2)
      .map((part) => part[0].toUpperCase())
      .join();

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final fallback = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [scheme.primary, scheme.secondary],
        ),
      ),
      child: Text(
        _initials,
        style: TextStyle(fontSize: size * 0.36, fontWeight: FontWeight.w800, color: scheme.onPrimary),
      ),
    );
    final link = url?.trim() ?? '';
    return ExcludeSemantics(
      child: ClipOval(
        child: SizedBox.square(
          dimension: size,
          child: link.isEmpty
              ? fallback
              : CachedNetworkImage(
                  imageUrl: link,
                  fit: BoxFit.cover,
                  placeholder: (_, _) => Shimmer(child: SkeletonBox.circle(size: size)),
                  errorWidget: (_, _, _) => fallback,
                ),
        ),
      ),
    );
  }
}

/// Calendar-page style date: `TUE / 7 / OCT`.
class BookingDateTile extends StatelessWidget {
  const BookingDateTile({super.key, required this.date, this.muted = false, this.size = 64});

  /// Provider-local wall-clock date.
  final DateTime date;
  final bool muted;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final accent = muted ? scheme.onSurface.withValues(alpha: 0.45) : scheme.secondary;
    return Container(
      width: size,
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: muted ? scheme.onSurface.withValues(alpha: 0.04) : scheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            Formatters.weekdayShort(date).toUpperCase(),
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: accent),
          ),
          const SizedBox(height: 2),
          Text(
            '${date.day}',
            style: TextStyle(
              fontSize: 24,
              height: 1.1,
              fontWeight: FontWeight.w900,
              color: muted ? scheme.onSurface.withValues(alpha: 0.55) : scheme.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            Formatters.monthShort(date).toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: scheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}

/// A booking in a list. [showClient] flips it to the provider's point of
/// view (the client's name and photo instead of the provider's).
class BookingCard extends StatelessWidget {
  const BookingCard({
    super.key,
    required this.booking,
    required this.onTap,
    this.showClient = false,
    this.muted = false,
    this.footer,
  });

  final Booking booking;
  final VoidCallback onTap;
  final bool showClient;

  /// Past bookings are drawn quieter.
  final bool muted;

  /// Optional actions under the card (e.g. accept / decline a request).
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final muteColor = scheme.onSurface.withValues(alpha: 0.55);
    final name = showClient ? booking.clientName : booking.providerName;
    final avatar = showClient ? booking.clientAvatarUrl : booking.providerAvatarUrl;
    final time = Formatters.timeRange(booking.startsAtLocal, booking.endsAtLocal);
    final where = booking.isMobile
        ? (booking.distanceKm == null ? 'Mobile visit' : 'Mobile · ${Formatters.distanceKm(booking.distanceKm!)}')
        : 'At the studio';

    return Semantics(
      button: true,
      label: '${booking.servicesSummary} with $name, ${Formatters.dateShort(booking.startsAtLocal)}, $time, '
          '${booking.status.label}',
      excludeSemantics: true,
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
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    BookingDateTile(date: booking.startsAtLocal, muted: muted),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              PersonAvatar(name: name, url: avatar, size: 22),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: muteColor),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            booking.servicesSummary,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 16,
                              height: 1.25,
                              fontWeight: FontWeight.w800,
                              color: scheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(Icons.schedule_rounded, size: 14, color: muteColor),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  time,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: muteColor),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                booking.isMobile ? Icons.home_outlined : Icons.storefront_outlined,
                                size: 14,
                                color: muteColor,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  where,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 13, color: muteColor),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    BookingStatusPill(status: booking.status, dense: true),
                    if (booking.status.isActive || booking.paymentStatus == PaymentStatus.paid)
                      PaymentStatusPill(method: booking.paymentMethod, status: booking.paymentStatus, dense: true),
                    BookingPill(
                      label: Formatters.audCents(booking.totalCents),
                      color: scheme.onSurface.withValues(alpha: 0.6),
                      dense: true,
                    ),
                  ],
                ),
                if (footer != null) ...[
                  const SizedBox(height: 12),
                  footer!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Placeholder with the footprint of a [BookingCard]. Place under a [Shimmer].
class BookingCardSkeleton extends StatelessWidget {
  const BookingCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.colorScheme.onSurface.withValues(alpha: 0.08)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SkeletonBox(width: 64, height: 78, borderRadius: 16),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonText(style: TextStyle(fontSize: 13), widthFactor: 0.45),
                    SizedBox(height: 6),
                    SkeletonText(style: TextStyle(fontSize: 16, height: 1.25), widthFactor: 0.8),
                    SizedBox(height: 6),
                    SkeletonText(style: TextStyle(fontSize: 13), widthFactor: 0.55),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Row(
            children: [
              SkeletonBox(width: 90, height: 22, borderRadius: 11),
              SizedBox(width: 8),
              SkeletonBox(width: 110, height: 22, borderRadius: 11),
            ],
          ),
        ],
      ),
    );
  }
}
