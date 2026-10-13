import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/maps/external_maps.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/utils/formatters.dart';
import '../../../../../core/widgets/skeleton/skeletons.dart';
import '../../../../shared/authentication/models/profile_model.dart';
import '../../../../shared/bookings/controllers/booking_controllers.dart';
import '../../../../shared/bookings/models/booking_enums.dart';
import '../../../../shared/bookings/models/booking_time.dart';
import '../../../../shared/bookings/models/cancellation_policy.dart';
import '../../../../shared/bookings/models/working_hours.dart';
import '../../../../shared/reviews/controllers/reviews_controllers.dart';
import '../../../../shared/reviews/views/widgets/rating_summary.dart';
import '../../../../shared/reviews/views/widgets/review_card.dart';
import '../../../booking/views/widgets/location_preview.dart';
import 'provider_profile_header.dart' show providerDisplayName;
import 'section_states.dart';

const TextStyle _headingStyle = TextStyle(fontSize: 17, fontWeight: FontWeight.w800);
const TextStyle _bodyStyle = TextStyle(fontSize: 15, height: 1.45);

/// About / details tab of the public provider profile, as slivers.
///
/// Opening hours and the cancellation policy come live from the provider's
/// booking schedule and rules; reviews show the rating summary and the
/// newest few, with a link to the rest.
class ProviderAboutTab extends StatelessWidget {
  const ProviderAboutTab({
    super.key,
    required this.profile,
    required this.onRetry,
    this.onOpenReviews,
    this.distanceKm,
    this.mobileOnly = false,
  });

  final AsyncValue<ProfileModel?> profile;
  final VoidCallback onRetry;

  /// Opens every review of the provider.
  final ValueChanged<ProfileModel>? onOpenReviews;
  final double? distanceKm;

  /// Only visits clients, so their address and pin aren't shown.
  final bool mobileOnly;

  @override
  Widget build(BuildContext context) {
    return switch (profile) {
      AsyncData(:final value?) => SliverPadding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
        sliver: SliverList.list(children: _sections(context, value)),
      ),
      AsyncError(:final error) => SliverToBoxAdapter(
        child: SectionErrorView(
          title: "Details didn't load",
          message: describeLoadError(error, subject: "this provider's details"),
          onRetry: onRetry,
        ),
      ),
      // A missing provider is handled by the screen; anything else is loading.
      _ => const SliverToBoxAdapter(child: _AboutSkeleton()),
    };
  }

  List<Widget> _sections(BuildContext context, ProfileModel profile) {
    final muted = context.colorScheme.onSurface.withValues(alpha: 0.6);
    final bio = profile.bio?.trim() ?? '';
    final address = profile.addressText?.trim() ?? '';
    final distance = distanceKm;

    return [
      _Section(
        title: 'About',
        child: Text(
          bio.isNotEmpty ? bio : "This provider hasn't added a bio yet.",
          style: _bodyStyle.copyWith(
            color: bio.isNotEmpty ? context.colorScheme.onSurface.withValues(alpha: 0.85) : muted,
          ),
        ),
      ),
      _Section(
        title: 'Location',
        child: mobileOnly
            ? const _InfoCard(
                icon: Icons.directions_car_outlined,
                title: 'Mobile service',
                subtitle: 'They come to you. Add your address when you book to check they travel to your area.',
              )
            : _StudioLocation(profile: profile, address: address, distanceKm: distance),
      ),
      _Section(
        title: 'Opening hours',
        child: _OpeningHours(providerId: profile.id),
      ),
      _Section(
        title: 'Cancellation policy',
        child: _CancellationPolicy(providerId: profile.id),
      ),
      _Section(
        title: 'Reviews',
        child: _ReviewsPreview(
          profile: profile,
          onSeeAll: onOpenReviews == null ? null : () => onOpenReviews!(profile),
        ),
      ),
    ];
  }
}

/// Where the provider works: a map and the address, both opening the place
/// in Google Maps (the pin when there is one, otherwise the address).
class _StudioLocation extends ConsumerWidget {
  const _StudioLocation({required this.profile, required this.address, required this.distanceKm});

  final ProfileModel profile;
  final String address;
  final double? distanceKm;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final point = profile.location;
    final distance = distanceKm;
    final VoidCallback? open = canOpenInMaps(point: point, address: address)
        ? () => openInMaps(context, ref, point: point, address: address)
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (point != null) ...[
          LocationPreview(
            label: address.isNotEmpty ? address : providerDisplayName(profile),
            point: point,
            height: 160,
            onTap: open,
          ),
          const SizedBox(height: 10),
        ],
        _InfoCard(
          icon: Icons.location_on_outlined,
          title: address.isNotEmpty ? address : 'Address not provided',
          subtitle: distance == null ? null : '${Formatters.distanceKm(distance)} away',
          onTap: open,
          tapHint: 'Opens in Maps',
        ),
      ],
    );
  }
}

/// The provider's rating summary and newest reviews.
class _ReviewsPreview extends ConsumerWidget {
  const _ReviewsPreview({required this.profile, required this.onSeeAll});

  final ProfileModel profile;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = context.colorScheme;
    final summaryAsync = ref.watch(providerReviewSummaryProvider(profile.id));
    final previewAsync = ref.watch(reviewsPreviewProvider((providerId: profile.id, serviceId: null)));
    final summary = summaryAsync.value;

    if (summaryAsync case AsyncError(:final error)) {
      return SectionErrorView(
        title: "Reviews didn't load",
        message: describeLoadError(error, subject: 'the reviews'),
        onRetry: () {
          ref.invalidate(providerReviewSummaryProvider(profile.id));
          ref.invalidate(reviewsPreviewProvider((providerId: profile.id, serviceId: null)));
        },
      );
    }
    if (summary == null) return const ReviewListSkeleton(count: 2);
    if (summary.isEmpty) {
      return const SectionEmptyView(
        icon: Icons.rate_review_outlined,
        title: 'No reviews yet',
        message: 'Reviews from clients will appear here after their appointments.',
      );
    }

    final reviews = previewAsync.value ?? const [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RatingSummaryCard(summary: summary),
        const SizedBox(height: 16),
        if (previewAsync.isLoading && reviews.isEmpty) const ReviewListSkeleton(count: 2),
        for (final (index, review) in reviews.indexed) ...[
          if (index > 0) Divider(height: 32, color: scheme.onSurface.withValues(alpha: 0.08)),
          ReviewCard(review: review, providerName: providerDisplayName(profile)),
        ],
        if (onSeeAll != null && summary.count > reviews.length) ...[
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: onSeeAll,
            style: OutlinedButton.styleFrom(
              foregroundColor: scheme.onSurface,
              minimumSize: const Size(0, 48),
              side: BorderSide(color: scheme.onSurface.withValues(alpha: 0.15)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              textStyle: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
            ),
            child: Text('See all ${summary.count} reviews'),
          ),
        ],
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(title, style: _headingStyle.copyWith(color: context.colorScheme.onSurface)),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

/// The provider's week, Monday first, in their own time zone with today
/// highlighted, so a client in another zone reads the hours correctly.
class _OpeningHours extends ConsumerWidget {
  const _OpeningHours({required this.providerId});

  final String providerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timeZone = ref.watch(bookingSettingsProvider(providerId)).value?.timeZone ?? BookingTime.defaultTimeZone;
    return switch (ref.watch(workingHoursProvider(providerId))) {
      AsyncData(:final value) when value.isEmpty => const _InfoCard(
        icon: Icons.schedule_outlined,
        title: 'Hours not listed yet',
        subtitle: 'Contact the provider to check their availability.',
      ),
      AsyncData(:final value) => _WeekCard(schedule: value, timeZone: timeZone),
      AsyncError(:final error) => SectionErrorView(
        title: "Opening hours didn't load",
        message: describeLoadError(error, subject: "this provider's opening hours"),
        onRetry: () => ref.invalidate(workingHoursProvider(providerId)),
      ),
      _ => const Shimmer(child: SkeletonBox(height: 220, borderRadius: 16)),
    };
  }
}

/// The provider's current free-cancellation window, and what applies after
/// it: never a fee for cash; their own fee for bookings paid in the app.
class _CancellationPolicy extends ConsumerWidget {
  const _CancellationPolicy({required this.providerId});

  final String providerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return switch (ref.watch(bookingSettingsProvider(providerId))) {
      AsyncData(value: final settings?) => _InfoCard(
        icon: Icons.event_busy_outlined,
        title: CancellationPolicy.headline(settings.cancellationWindowHours),
        subtitle: CancellationPolicy.profileTerms(
          windowHours: settings.cancellationWindowHours,
          inAppFeePercent: settings.cancellationFeePercent,
          inAppPaymentsLive: PaymentMethod.values.any((method) => method.isAvailable && !method.isCash),
        ),
      ),
      AsyncData() => const _InfoCard(
        icon: Icons.event_busy_outlined,
        title: 'No policy published',
        subtitle: 'Confirm cancellation terms with the provider before you book.',
      ),
      AsyncError(:final error) => SectionErrorView(
        title: "Cancellation policy didn't load",
        message: describeLoadError(error, subject: "this provider's cancellation policy"),
        onRetry: () => ref.invalidate(bookingSettingsProvider(providerId)),
      ),
      _ => const Shimmer(child: SkeletonBox(height: 72, borderRadius: 16)),
    };
  }
}

class _WeekCard extends StatelessWidget {
  const _WeekCard({required this.schedule, required this.timeZone});

  final WeeklySchedule schedule;
  final String timeZone;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final today = BookingTime.todayIn(timeZone).weekday;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.onSurface.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var weekday = 1; weekday <= 7; weekday++)
            _DayRow(weekday: weekday, ranges: schedule.on(weekday), isToday: weekday == today),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.public_rounded, size: 15, color: scheme.onSurface.withValues(alpha: 0.5)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Times in ${BookingTime.label(timeZone)}',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface.withValues(alpha: 0.55),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DayRow extends StatelessWidget {
  const _DayRow({required this.weekday, required this.ranges, required this.isToday});

  final int weekday;
  final List<WorkingHoursRange> ranges;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final closed = ranges.isEmpty;
    final style = TextStyle(
      fontSize: 14.5,
      height: 1.4,
      fontWeight: isToday ? FontWeight.w800 : FontWeight.w500,
      color: closed && !isToday ? scheme.onSurface.withValues(alpha: 0.5) : scheme.onSurface,
    );
    final day = Formatters.weekdayLong(DateTime.utc(2024, 1, weekday));
    final hours = closed ? 'Closed' : ranges.map((range) => range.label).join('\n');
    return Semantics(
      label: '$day${isToday ? ', today' : ''}: ${hours.replaceAll('\n', ', ')}',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 108,
              child: Row(
                children: [
                  Flexible(child: Text(day, style: style)),
                  if (isToday) ...[
                    const SizedBox(width: 6),
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(color: scheme.secondary, shape: BoxShape.circle),
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: Text(hours, textAlign: TextAlign.end, style: style),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.icon, required this.title, this.subtitle, this.onTap, this.tapHint});

  final IconData icon;
  final String title;
  final String? subtitle;

  /// Makes the card a button, with [tapHint] read out by screen readers.
  final VoidCallback? onTap;
  final String? tapHint;

  @override
  Widget build(BuildContext context) {
    final subtitle = this.subtitle;
    final onTap = this.onTap;
    final radius = BorderRadius.circular(16);
    final content = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(color: context.colorScheme.onSurface.withValues(alpha: 0.1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: context.colorScheme.secondary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: context.colorScheme.onSurface,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      color: context.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(width: 8),
            Icon(Icons.open_in_new_rounded, size: 18, color: context.colorScheme.onSurface.withValues(alpha: 0.45)),
          ],
        ],
      ),
    );
    if (onTap == null) return content;
    return Semantics(
      button: true,
      hint: tapHint,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(onTap: onTap, borderRadius: radius, child: content),
      ),
    );
  }
}

class _AboutSkeleton extends StatelessWidget {
  const _AboutSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Shimmer(
      child: Padding(
        padding: EdgeInsets.fromLTRB(24, 28, 24, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SkeletonText(style: _headingStyle, widthFactor: 0.3),
            SizedBox(height: 10),
            SkeletonText(style: _bodyStyle),
            SkeletonText(style: _bodyStyle),
            SkeletonText(style: _bodyStyle, widthFactor: 0.6),
            SizedBox(height: 20),
            SkeletonText(style: _headingStyle, widthFactor: 0.35),
            SizedBox(height: 10),
            SkeletonBox(height: 72, borderRadius: 16),
            SizedBox(height: 20),
            SkeletonText(style: _headingStyle, widthFactor: 0.3),
            SizedBox(height: 10),
            ReviewCardSkeleton(),
          ],
        ),
      ),
    );
  }
}
