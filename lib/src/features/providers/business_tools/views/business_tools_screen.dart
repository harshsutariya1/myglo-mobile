import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../shared/authentication/controllers/user_profile_provider.dart';
import '../../../shared/notifications/views/notification_bell.dart';
import '../../../shared/reviews/controllers/reviews_controllers.dart';
import '../../payments/controllers/payments_controllers.dart';
import '../../provider_profiles/controllers/provider_services_controller.dart';
import '../../schedule/controllers/provider_schedule_controller.dart';
import '../controllers/business_stats_controller.dart';
import '../controllers/contacts_controllers.dart';
import 'widgets/business_attention.dart';
import 'widgets/business_manage.dart';
import 'widgets/business_overview.dart';

/// The provider's business hub: what needs their attention, this month's
/// numbers (earnings, completed bookings, the week ahead, rating, clients)
/// and the tools that run the business, each showing where it stands.
class BusinessToolsScreen extends ConsumerWidget {
  const BusinessToolsScreen({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(businessStatsProvider);
    final providerId = ref.read(userProfileProvider).value?.rawUser.id;
    if (providerId != null) {
      ref.invalidate(providerReviewSummaryProvider(providerId));
      ref.invalidate(providerServicesProvider(providerId));
    }
    ref.invalidate(providerContactCountProvider);
    ref.invalidate(paymentsSetupProvider);
    ref.invalidate(ownWorkingHoursProvider);
    ref.invalidate(ownTimeOffProvider);
    try {
      await ref.read(businessStatsProvider.future);
    } catch (_) {
      // Shown inline by the overview.
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = context.colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: scheme.primary,
          onRefresh: () => _refresh(ref),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            // Room at the bottom for the floating tab bar.
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
            children: const [
              _Header(),
              BusinessAttention(),
              BusinessMonthOverview(),
              BusinessManageSections(),
            ],
          ),
        ),
      ),
    );
  }
}

/// Large title with the brand underline, as on the other tabs.
class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    'My business',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: scheme.onSurface,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                Transform.translate(
                  offset: const Offset(0, -4),
                  child: Image.asset(AppAssets.underlineGraphic, width: 160, fit: BoxFit.contain),
                ),
              ],
            ),
          ),
        ),
        const NotificationBell(),
      ],
    );
  }
}
