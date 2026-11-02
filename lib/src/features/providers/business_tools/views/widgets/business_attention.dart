import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/routing/app_router.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/utils/formatters.dart';
import '../../../../shared/bookings/models/booking_settings.dart';
import '../../../../shared/bookings/models/booking_time.dart';
import '../../../home/views/provider_home_screen.dart' show ProviderHomeTab;
import '../../../home/views/widgets/booking_setup_card.dart';
import '../../../payments/controllers/payments_controllers.dart';
import '../../../payments/models/payments_setup.dart';
import '../../../provider_profiles/views/widgets/settings_widgets.dart';
import '../../../schedule/controllers/provider_schedule_controller.dart';
import '../../controllers/business_stats_controller.dart';
import 'business_overview.dart' show openOwnReviews;

/// What the provider should deal with now, most urgent first: unfinished
/// set-up, paused bookings, requests waiting for an answer, card payments
/// that need them, and reviews without a reply. Each row opens the place to
/// sort it out. Hidden when there's nothing to do, and rows wait for their
/// data rather than flashing in and out.
class BusinessAttention extends ConsumerWidget {
  const BusinessAttention({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(businessStatsProvider).value;
    final setup = ref.watch(paymentsSetupProvider).value;
    final settings = ref.watch(ownBookingSettingsProvider).value;
    final progress = ref.watch(bookingSetupProgressProvider);
    void home({ProviderHomeTab tab = ProviderHomeTab.upcoming}) => context.goNamed(
          AppRoute.providerHome.name,
          queryParameters: tab == ProviderHomeTab.upcoming ? const {} : {'tab': tab.query},
        );

    final payments = paymentsAttention(setup, settings);
    final items = [
      if (progress != null && !progress.isComplete)
        SettingsTile(
          icon: Icons.checklist_rounded,
          iconColor: AppTheme.warning,
          title: 'Finish setting up',
          subtitle: '${progress.done} of ${BookingSetupProgress.total} done. Clients can book once your services, '
              'hours and location are set',
          onTap: home,
        ),
      if (settings?.acceptsBookings == false)
        SettingsTile(
          icon: Icons.pause_circle_outline_rounded,
          iconColor: AppTheme.warning,
          title: 'New bookings are paused',
          subtitle: "Clients can't book you until you resume",
          onTap: home,
        ),
      if (stats != null && stats.pendingRequests > 0)
        SettingsTile(
          icon: Icons.hourglass_top_rounded,
          iconColor: AppTheme.warning,
          title: stats.pendingRequests == 1 ? '1 request waiting' : '${stats.pendingRequests} requests waiting',
          subtitle: switch (stats.nextReplyByLocal) {
            final replyBy? => 'Reply by ${Formatters.dateTimeShort(replyBy)}, or it expires',
            null => 'Reply soon, or it expires',
          },
          onTap: () => home(tab: ProviderHomeTab.requests),
        ),
      if (payments != null)
        SettingsTile(
          icon: Icons.credit_card_rounded,
          iconColor: payments.color,
          title: payments.title,
          subtitle: payments.subtitle,
          onTap: () => context.pushNamed(AppRoute.providerPayments.name),
        ),
      if (stats != null && stats.reviewsAwaitingReply > 0)
        SettingsTile(
          icon: Icons.rate_review_outlined,
          title: stats.reviewsAwaitingReply == 1
              ? '1 review to reply to'
              : '${stats.reviewsAwaitingReply} reviews to reply to',
          subtitle: 'Your replies show on your profile for everyone to see',
          onTap: () => openOwnReviews(context, ref),
        ),
    ];

    if (items.isEmpty) return const SizedBox.shrink();
    return SettingsSection(title: 'Needs your attention', children: items);
  }
}

/// The card-payments row for [setup], or null when there's nothing for the
/// provider to do. A provider who turned card payments off isn't asked to
/// set them up.
({String title, String subtitle, Color? color})? paymentsAttention(
  PaymentsSetup? setup,
  ProviderBookingSettings? settings,
) {
  if (setup == null) return null;
  final deadline = switch (setup.requirementsDeadline) {
    final due? => Formatters.dateShort(BookingTime.wallClockOf(due, settings?.timeZone ?? BookingTime.defaultTimeZone)),
    null => null,
  };
  return switch (setup.status) {
    PaymentsSetupStatus.notStarted when settings?.acceptsCard ?? true => (
        title: 'Take card payments',
        subtitle: 'Set up payouts with Stripe so clients can pay in the app',
        color: null,
      ),
    PaymentsSetupStatus.onboarding => (
        title: 'Finish setting up card payments',
        subtitle: 'Stripe still needs a few details from you',
        color: AppTheme.warning,
      ),
    PaymentsSetupStatus.actionNeeded => (
        title: 'Stripe needs more details',
        subtitle: deadline == null
            ? 'Send them soon to keep taking card payments'
            : 'Send them by $deadline to keep taking card payments',
        color: AppTheme.warning,
      ),
    PaymentsSetupStatus.restricted => (
        title: 'Card payments are paused',
        subtitle: 'Stripe needs details from you before clients can pay by card again',
        color: AppTheme.destructive,
      ),
    _ => null,
  };
}
