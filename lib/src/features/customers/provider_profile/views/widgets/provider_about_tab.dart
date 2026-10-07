import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/utils/formatters.dart';
import '../../../../../core/widgets/skeleton/skeletons.dart';
import '../../../../shared/authentication/models/profile_model.dart';
import '../../../../shared/bookings/controllers/booking_controllers.dart';
import '../../../../shared/bookings/models/booking_enums.dart';
import '../../../../shared/bookings/models/booking_time.dart';
import '../../../../shared/bookings/models/cancellation_policy.dart';
import '../../../../shared/bookings/models/working_hours.dart';
import 'section_states.dart';

const TextStyle _headingStyle = TextStyle(fontSize: 17, fontWeight: FontWeight.w800);
const TextStyle _bodyStyle = TextStyle(fontSize: 15, height: 1.45);

/// About / details tab of the public provider profile, as slivers.
///
/// Opening hours and the cancellation policy come live from the provider's
/// booking schedule and rules. Reviews are not stored yet, so that section
/// explains that instead of staying blank.
class ProviderAboutTab extends StatelessWidget {
  const ProviderAboutTab({
    super.key,
    required this.profile,
    required this.onRetry,
    this.distanceKm,
  });

  final AsyncValue<ProfileModel?> profile;
  final VoidCallback onRetry;
  final double? distanceKm;

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
        child: _InfoCard(
          icon: Icons.location_on_outlined,
          title: address.isNotEmpty ? address : 'Address not provided',
          subtitle: distance == null ? null : '${Formatters.distanceKm(distance)} away',
        ),
      ),
      _Section(
        title: 'Opening hours',
        child: _OpeningHours(providerId: profile.id),
      ),
      _Section(
        title: 'Cancellation policy',
        child: _CancellationPolicy(providerId: profile.id),
      ),
      const _Section(
        title: 'Reviews',
        child: SectionEmptyView(
          icon: Icons.rate_review_outlined,
          title: 'No reviews yet',
          message: 'Reviews from clients will appear here after their appointments.',
        ),
      ),
    ];
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
  const _InfoCard({required this.icon, required this.title, this.subtitle});

  final IconData icon;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final subtitle = this.subtitle;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
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
        ],
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
