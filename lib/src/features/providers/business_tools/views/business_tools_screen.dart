import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/skeleton/skeletons.dart';
import '../../../../core/widgets/snackbar_utils.dart';
import '../../../../core/widgets/soon_badge.dart';
import '../../../customers/provider_profile/views/widgets/section_states.dart';
import '../../../shared/notifications/views/notification_bell.dart';
import '../controllers/business_stats_controller.dart';

/// The provider's business overview: this month's real numbers (cash
/// collected, completed bookings), placeholders for metrics that have no
/// data yet, and shortcuts to the tools that manage the business.
class BusinessToolsScreen extends ConsumerWidget {
  const BusinessToolsScreen({super.key});

  static const _valueStyle = TextStyle(fontSize: 24, fontWeight: FontWeight.bold);

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(businessStatsProvider);
    try {
      await ref.read(businessStatsProvider.future);
    } catch (_) {
      // Shown inline by the overview.
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(businessStatsProvider.select((s) => s.value?.periodStart));

    return Scaffold(
      backgroundColor: context.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: context.colorScheme.surface,
        elevation: 0,
        title: Text(
          'Business Tools',
          style: TextStyle(
            color: context.colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: const [NotificationBell(size: 24)],
      ),
      body: RefreshIndicator(
        color: context.colorScheme.primary,
        onRefresh: () => _refresh(ref),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Expanded(
                    child: Text(
                      'Overview',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: context.colorScheme.onSurface,
                      ),
                    ),
                  ),
                  if (period != null)
                    Text(
                      Formatters.monthYear(period),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade600,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              const _MonthStats(),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      title: 'Profile views',
                      icon: Icons.visibility,
                      value: const SoonBadge(),
                      onTap: () => context.showComingSoon('Profile views'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _StatCard(
                      title: 'Rating',
                      icon: Icons.star,
                      value: const SoonBadge(),
                      onTap: () => context.showComingSoon('Ratings'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Text(
                'Quick Actions',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: context.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 16),
              _ActionItem(
                title: 'Manage Schedule',
                subtitle: 'Update your availability and working hours',
                icon: Icons.schedule,
                onTap: () => context.pushNamed(AppRoute.workingHours.name),
              ),
              const SizedBox(height: 16),
              _ActionItem(
                title: 'Services & Pricing',
                subtitle: 'Add or modify your service offerings',
                icon: Icons.design_services,
                // The profile tab opens on its Services list, where services
                // are added, edited and priced.
                onTap: () => context.goNamed(AppRoute.providerProfile.name),
              ),
              const SizedBox(height: 16),
              _ActionItem(
                title: 'Financials',
                subtitle: 'View payout history and manage bank details',
                icon: Icons.account_balance_wallet,
                soon: true,
                onTap: () => context.showComingSoon('Financials'),
              ),
              const SizedBox(height: 100), // Bottom navigation bar padding
            ],
          ),
        ),
      ),
    );
  }
}

/// This month's cash collected and completed bookings: skeletons while
/// loading, an inline error with retry, then the numbers. A refresh keeps
/// the last numbers on screen until new ones arrive.
class _MonthStats extends ConsumerWidget {
  const _MonthStats();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(businessStatsProvider);
    final stats = async.value;

    if (stats == null) {
      if (async case AsyncError(:final error)) {
        return SectionErrorView(
          title: "Your numbers didn't load",
          message: describeLoadError(error, subject: "this month's numbers"),
          onRetry: () => ref.invalidate(businessStatsProvider),
        );
      }
      const placeholder = Shimmer(
        child: SkeletonText(style: BusinessToolsScreen._valueStyle, widthFactor: 0.6),
      );
      return const Row(
        children: [
          Expanded(
            child: _StatCard(title: 'Cash collected', icon: Icons.attach_money, value: placeholder, highlight: true),
          ),
          SizedBox(width: 16),
          Expanded(child: _StatCard(title: 'Completed bookings', icon: Icons.calendar_month, value: placeholder)),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: _StatCard(
            title: 'Cash collected',
            icon: Icons.attach_money,
            highlight: true,
            value: _StatValue(Formatters.audCents(stats.cashCollectedCents), highlight: true),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _StatCard(
            title: 'Completed bookings',
            icon: Icons.calendar_month,
            value: _StatValue('${stats.completedBookings}'),
          ),
        ),
      ],
    );
  }
}

class _StatValue extends StatelessWidget {
  const _StatValue(this.text, {this.highlight = false});

  final String text;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: AlignmentDirectional.centerStart,
      child: Text(
        text,
        maxLines: 1,
        style: BusinessToolsScreen._valueStyle.copyWith(
          color: highlight ? Colors.white : context.colorScheme.onSurface,
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.icon,
    required this.value,
    this.highlight = false,
    this.onTap,
  });

  final String title;
  final IconData icon;

  /// The figure, or a skeleton / "Soon" badge in its place.
  final Widget value;
  final bool highlight;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: highlight ? context.colorScheme.primary : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: highlight ? null : Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: (highlight ? context.colorScheme.primary : Colors.black).withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: highlight ? Colors.white.withValues(alpha: 0.2) : const Color(0xFFFFF5F5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: highlight ? Colors.white : context.colorScheme.secondary,
              size: 20,
            ),
          ),
          const SizedBox(height: 16),
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
            style: TextStyle(
              fontSize: 14,
              color: highlight ? Colors.white.withValues(alpha: 0.9) : Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return card;
    return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(20), child: card);
  }
}

class _ActionItem extends StatelessWidget {
  const _ActionItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.soon = false,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  /// Not live yet: shows a "Soon" badge instead of the chevron.
  final bool soon;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
          border: Border.all(
            color: Colors.grey.shade100,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF5F5),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: context.colorScheme.secondary, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: context.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (soon) const SoonBadge() else Icon(Icons.chevron_right, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }
}
