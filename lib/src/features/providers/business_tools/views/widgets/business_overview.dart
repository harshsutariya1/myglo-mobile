import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/routing/app_router.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/utils/formatters.dart';
import '../../../../../core/widgets/skeleton/skeletons.dart';
import '../../../../customers/provider_profile/views/widgets/provider_profile_header.dart' show providerDisplayName;
import '../../../../customers/provider_profile/views/widgets/section_states.dart';
import '../../../../shared/authentication/controllers/user_profile_provider.dart';
import '../../../../shared/reviews/controllers/reviews_controllers.dart';
import '../../../../shared/reviews/views/reviews_screen.dart';
import '../../controllers/business_stats_controller.dart';
import '../../controllers/contacts_controllers.dart';
import '../../models/business_stats.dart';

const _valueStyle = TextStyle(fontSize: 24, fontWeight: FontWeight.bold);
const _heroStyle = TextStyle(fontSize: 34, fontWeight: FontWeight.w900, letterSpacing: -0.5);

/// Opens the signed-in provider's reviews, where they can reply.
void openOwnReviews(BuildContext context, WidgetRef ref) {
  final profile = ref.read(userProfileProvider).value;
  if (profile == null) return;
  Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute<void>(
      builder: (_) => ReviewsScreen(
        query: (providerId: profile.rawUser.id, serviceId: null),
        title: 'Your reviews',
        providerName: providerDisplayName(profile.profile),
        canReply: true,
      ),
    ),
  );
}

/// Small uppercase heading, matching the settings groups below it, with an
/// optional note on the right (e.g. the month).
class BusinessSectionLabel extends StatelessWidget {
  const BusinessSectionLabel({super.key, required this.title, this.trailing});

  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final muted = context.colorScheme.onSurface.withValues(alpha: 0.5);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 24, 4, 8),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                title.toUpperCase(),
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: muted),
              ),
            ),
          ),
          if (trailing != null)
            Text(trailing!, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: muted)),
        ],
      ),
    );
  }
}

/// This month at a glance: what the provider earned (with the split between
/// card and cash, last month's figure and money on its way), completed
/// bookings, the week ahead, their rating and their clients. Skeletons while
/// loading, an inline error with retry, and a refresh keeps the last numbers
/// on screen until new ones arrive.
class BusinessMonthOverview extends ConsumerWidget {
  const BusinessMonthOverview({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(businessStatsProvider);
    final stats = async.value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BusinessSectionLabel(
          title: 'This month',
          trailing: stats == null ? null : Formatters.monthYear(stats.periodStart),
        ),
        if (stats == null && async is AsyncError)
          SectionErrorView(
            title: "Your numbers didn't load",
            message: describeLoadError(async.error!, subject: "this month's numbers"),
            onRetry: () => ref.invalidate(businessStatsProvider),
          )
        else ...[
          _EarnedCard(stats: stats),
          const SizedBox(height: 12),
          _BookingStats(stats: stats),
        ],
        const SizedBox(height: 12),
        const _ClientStats(),
      ],
    );
  }
}

/// The month's earnings, which opens the full Earnings screen.
class _EarnedCard extends StatelessWidget {
  const _EarnedCard({required this.stats});

  /// Null while loading.
  final BusinessStats? stats;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final stats = this.stats;
    const ink = Colors.white;
    final muted = Colors.white.withValues(alpha: 0.85);
    final month = stats == null ? null : Formatters.monthLong(stats.periodStart);
    final lastMonth = stats == null ? null : Formatters.monthLong(stats.previousPeriodStart);

    final card = Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [scheme.primary, Color.lerp(scheme.primary, scheme.secondary, 0.6)!],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(color: scheme.primary.withValues(alpha: 0.25), blurRadius: 20, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.payments_outlined, color: ink, size: 20),
              ),
              const Spacer(),
              Icon(Icons.arrow_outward_rounded, size: 18, color: Colors.white.withValues(alpha: 0.8)),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 42,
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: stats == null
                  ? const Shimmer(child: SkeletonText(style: _heroStyle, widthFactor: 0.4))
                  : FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(Formatters.audCents(stats.earnedCents), maxLines: 1, style: _heroStyle.copyWith(color: ink)),
                    ),
            ),
          ),
          Text(
            month == null ? 'Earned this month' : 'Earned in $month',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: muted),
          ),
          if (stats != null) ...[
            const SizedBox(height: 14),
            Container(height: 1, color: Colors.white.withValues(alpha: 0.25)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _Figure(label: 'In the app', value: Formatters.audCents(stats.cardEarnedCents))),
                Expanded(child: _Figure(label: 'Cash', value: Formatters.audCents(stats.cashCollectedCents))),
                Expanded(child: _Figure(label: lastMonth!, value: Formatters.audCents(stats.previousEarnedCents))),
              ],
            ),
            if (stats.onItsWayCents > 0) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.schedule_send_outlined, size: 16, color: muted),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${Formatters.audCents(stats.onItsWayCents)} on its way to your Stripe balance',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: muted),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ],
      ),
    );

    void open() => context.pushNamed(AppRoute.providerEarnings.name);
    return Semantics(
      button: true,
      label: stats == null
          ? 'Earned this month: loading'
          : 'Earned in $month: ${Formatters.audCents(stats.earnedCents)}. '
              'In the app ${Formatters.audCents(stats.cardEarnedCents)}, cash ${Formatters.audCents(stats.cashCollectedCents)}. '
              '$lastMonth: ${Formatters.audCents(stats.previousEarnedCents)}.'
              '${stats.onItsWayCents > 0 ? ' ${Formatters.audCents(stats.onItsWayCents)} on its way.' : ''}',
      onTap: open,
      excludeSemantics: true,
      child: InkWell(onTap: open, borderRadius: BorderRadius.circular(22), child: card),
    );
  }
}

/// A small label over a figure, on the earnings card.
class _Figure extends StatelessWidget {
  const _Figure({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.75)),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerStart,
          child: Text(value, maxLines: 1, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
        ),
      ],
    );
  }
}

/// Completed bookings this month (with last month's count) beside the
/// confirmed appointments coming up in the next seven days.
class _BookingStats extends StatelessWidget {
  const _BookingStats({required this.stats});

  /// Null while loading.
  final BusinessStats? stats;

  static const _placeholder = Shimmer(child: SkeletonText(style: _valueStyle, widthFactor: 0.4));

  @override
  Widget build(BuildContext context) {
    final stats = this.stats;
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            title: 'Completed bookings',
            icon: Icons.task_alt_rounded,
            value: stats == null ? _placeholder : _StatValue('${stats.completedBookings}'),
            caption: stats == null
                ? ''
                : '${Formatters.monthLong(stats.previousPeriodStart)}: ${stats.previousCompletedBookings}',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            title: 'Coming up',
            icon: Icons.event_available_outlined,
            value: stats == null ? _placeholder : _StatValue('${stats.upcomingWeekBookings}'),
            caption: 'Next 7 days',
            semanticsLabel: stats == null
                ? null
                : 'Coming up in the next 7 days: ${stats.upcomingWeekBookings} confirmed '
                    '${stats.upcomingWeekBookings == 1 ? 'appointment' : 'appointments'}',
            onTap: () => context.goNamed(AppRoute.providerHome.name),
          ),
        ),
      ],
    );
  }
}

/// The provider's rating and review count (all time) in one card, which
/// opens their reviews (where they can reply), beside their client count,
/// which opens their contacts.
class _ClientStats extends ConsumerWidget {
  const _ClientStats();

  static const _placeholder = Shimmer(child: SkeletonText(style: _valueStyle, widthFactor: 0.5));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final providerId = ref.watch(userProfileProvider.select((p) => p.value?.rawUser.id));
    if (providerId == null) return const SizedBox.shrink();
    final reviews = ref.watch(providerReviewSummaryProvider(providerId));
    final contacts = ref.watch(providerContactCountProvider);

    final Widget rating;
    final String reviewsLabel;
    if (reviews.value case final summary?) {
      rating = summary.isEmpty
          ? const _StatValue('New')
          : _RatingValue(average: summary.average!, count: summary.count);
      reviewsLabel = summary.isEmpty
          ? 'Rating & reviews: no reviews yet'
          : 'Rating ${Formatters.rating(summary.average!)} from ${Formatters.reviewCount(summary.count)}';
    } else if (reviews.hasError) {
      // Already reported; tapping through retries.
      rating = const _StatValue('–');
      reviewsLabel = "Rating & reviews: didn't load";
    } else {
      rating = _placeholder;
      reviewsLabel = 'Rating & reviews: loading';
    }

    final Widget clients;
    if (contacts.value case final count?) {
      clients = _StatValue(Formatters.compactCount(count));
    } else if (contacts.hasError) {
      // Already reported; the contacts screen shows the details and a retry.
      clients = const _StatValue('–');
    } else {
      clients = _placeholder;
    }

    return Row(
      children: [
        Expanded(
          child: _StatCard(
            title: 'Rating & reviews',
            icon: Icons.star_rounded,
            value: rating,
            semanticsLabel: reviewsLabel,
            onTap: () => openOwnReviews(context, ref),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            title: 'Contacts',
            icon: Icons.people_alt_outlined,
            value: clients,
            semanticsLabel: switch (contacts.value) {
              final count? => 'Contacts: ${count == 1 ? '1 client' : '$count clients'}',
              null => 'Contacts',
            },
            onTap: () => context.pushNamed(AppRoute.providerContacts.name),
          ),
        ),
      ],
    );
  }
}

/// `4.8 ★ (12)`: the average with the review count beside it.
class _RatingValue extends StatelessWidget {
  const _RatingValue({required this.average, required this.count});

  final double average;
  final int count;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: AlignmentDirectional.centerStart,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(Formatters.rating(average), maxLines: 1, style: _valueStyle.copyWith(color: context.colorScheme.onSurface)),
          const SizedBox(width: 3),
          const Icon(Icons.star_rounded, size: 22, color: AppTheme.warning),
          const SizedBox(width: 6),
          Text(
            '(${Formatters.compactCount(count)})',
            maxLines: 1,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: context.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatValue extends StatelessWidget {
  const _StatValue(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: AlignmentDirectional.centerStart,
      child: Text(text, maxLines: 1, style: _valueStyle.copyWith(color: context.colorScheme.onSurface)),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.icon,
    required this.value,
    this.caption,
    this.onTap,
    this.semanticsLabel,
  });

  final String title;
  final IconData icon;

  /// The figure, or a skeleton in its place.
  final Widget value;

  /// A line under the title (e.g. last month's figure). Pass '' while
  /// loading so the card keeps its height.
  final String? caption;
  final VoidCallback? onTap;

  /// Read out instead of the card's contents (for tappable cards).
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final card = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.onSurface.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(color: scheme.onSurface.withValues(alpha: 0.04), blurRadius: 15, offset: const Offset(0, 5)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: scheme.secondary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: scheme.secondary, size: 20),
              ),
              const Spacer(),
              // Marks the cards that open something.
              if (onTap != null)
                Icon(Icons.arrow_outward_rounded, size: 18, color: scheme.onSurface.withValues(alpha: 0.3)),
            ],
          ),
          const SizedBox(height: 14),
          // Same height whatever stands in for the figure, so cards in a row
          // line up and nothing jumps when numbers arrive.
          SizedBox(
            height: 32,
            child: Align(alignment: AlignmentDirectional.centerStart, child: value),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: scheme.onSurface.withValues(alpha: 0.7)),
          ),
          if (caption != null)
            Text(
              caption!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12.5, color: scheme.onSurface.withValues(alpha: 0.5)),
            ),
        ],
      ),
    );

    if (onTap == null) return card;
    final tappable = InkWell(onTap: onTap, borderRadius: BorderRadius.circular(20), child: card);
    if (semanticsLabel == null) return tappable;
    return Semantics(button: true, label: semanticsLabel, onTap: onTap, excludeSemantics: true, child: tappable);
  }
}
