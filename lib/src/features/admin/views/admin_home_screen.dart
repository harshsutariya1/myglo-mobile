import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/adaptive/adaptive_list_detail.dart';
import '../controllers/admin_controllers.dart';
import 'widgets/admin_widgets.dart';

/// Admin home: headline numbers and anything that needs attention.
class AdminHomeScreen extends ConsumerWidget {
  const AdminHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = context.colorScheme;
    final status = ref.watch(adminStatusProvider).value;
    final dashboard = ref.watch(adminDashboardProvider);

    Future<void> refresh() async {
      ref.invalidate(adminDashboardProvider);
      try {
        await ref.read(adminDashboardProvider.future);
      } catch (_) {
        // The screen shows the error with a retry.
      }
    }

    return Scaffold(
      appBar: AppBar(title: Text(status?.displayName == null ? 'Admin' : 'Hi, ${status!.displayName}')),
      body: switch (dashboard) {
        AsyncData(:final value) => RefreshIndicator(
            onRefresh: refresh,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                if (value.failedJobs > 0)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Material(
                      color: AppTheme.destructive.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(16),
                      child: ListTile(
                        leading: const Icon(Icons.error_outline, color: AppTheme.destructive),
                        title: Text('${value.failedJobs} background ${value.failedJobs == 1 ? 'job' : 'jobs'} failed'),
                        subtitle: const Text('In the last 30 days. Admins were emailed about each one.'),
                      ),
                    ),
                  ),
                GridView.count(
                  crossAxisCount: isWideLayout(context) ? 4 : 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.35,
                  children: [
                    AdminStatTile(
                      label: 'Providers',
                      value: value.providers,
                      icon: Icons.storefront_outlined,
                      onTap: () => context.goNamed(AppRoute.adminPeople.name, queryParameters: {'role': 'provider'}),
                    ),
                    AdminStatTile(
                      label: 'Clients',
                      value: value.clients,
                      icon: Icons.person_outline,
                      onTap: () => context.goNamed(AppRoute.adminPeople.name, queryParameters: {'role': 'customer'}),
                    ),
                    AdminStatTile(label: 'New accounts (7 days)', value: value.newUsers7d, icon: Icons.person_add_alt),
                    AdminStatTile(label: 'Upcoming bookings', value: value.bookingsUpcoming, icon: Icons.event_outlined),
                    AdminStatTile(label: 'Requests awaiting reply', value: value.bookingsPending, icon: Icons.hourglass_top),
                    AdminStatTile(label: 'Bookings made (7 days)', value: value.bookings7d, icon: Icons.trending_up),
                    AdminStatTile(
                      label: 'Failed jobs (30 days)',
                      value: value.failedJobs,
                      icon: Icons.sync_problem_outlined,
                      alert: true,
                    ),
                  ],
                ),
                if (status?.sessionExpiresAt != null) ...[
                  const SizedBox(height: 20),
                  Text(
                    'Signed in with two-factor. Your admin session ends ${adminDateTime(status!.sessionExpiresAt!)}.',
                    style: TextStyle(fontSize: 12.5, color: scheme.onSurface.withValues(alpha: 0.55)),
                  ),
                ],
              ],
            ),
          ),
        AsyncError(:final error) => AdminErrorView(error: error, onRetry: () => ref.invalidate(adminDashboardProvider)),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}
