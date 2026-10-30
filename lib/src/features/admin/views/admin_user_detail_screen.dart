import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../controllers/admin_controllers.dart';
import '../models/admin_models.dart';
import 'widgets/admin_widgets.dart';

/// One client or provider, as its own page (phones).
class AdminUserDetailScreen extends StatelessWidget {
  const AdminUserDetailScreen({super.key, required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Account')),
      body: AdminUserDetailView(userId: userId),
    );
  }
}

/// One client or provider: account, activity and settings. Used as a page on
/// phones and beside the people list on wide screens.
class AdminUserDetailView extends ConsumerWidget {
  const AdminUserDetailView({super.key, required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(adminUserProvider(userId));
    return switch (detail) {
      AsyncData(:final value) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(adminUserProvider(userId)),
          child: _Detail(user: value),
        ),
      AsyncError(:final error) => AdminErrorView(error: error, onRetry: () => ref.invalidate(adminUserProvider(userId))),
      _ => const Center(child: CircularProgressIndicator()),
    };
  }
}

class _Detail extends StatelessWidget {
  const _Detail({required this.user});

  final AdminUserDetail user;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final settings = user.bookingSettings;
    final banned = user.bannedUntil != null && user.bannedUntil!.isAfter(DateTime.now());
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: scheme.primaryContainer,
              foregroundImage: user.avatarUrl == null ? null : CachedNetworkImageProvider(user.avatarUrl!),
              child: Icon(user.isProvider ? Icons.storefront_outlined : Icons.person_outline,
                  color: scheme.onPrimaryContainer, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user.title, style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: scheme.onSurface)),
                  if (user.isProvider && user.fullName != null)
                    Text(user.fullName!, style: TextStyle(color: scheme.onSurface.withValues(alpha: 0.65))),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      AdminChip(
                        label: user.isProvider ? 'Provider' : 'Client',
                        color: user.isProvider ? scheme.secondary : AppTheme.success,
                      ),
                      if (banned) const AdminChip(label: 'Sign-in blocked', color: AppTheme.destructive),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        AdminSection(
          title: 'Account',
          children: [
            AdminInfoRow(label: 'Email', value: user.email ?? '—'),
            AdminInfoRow(
              label: 'Email confirmed',
              value: user.emailConfirmedAt == null ? 'No' : adminDate(user.emailConfirmedAt!),
            ),
            AdminInfoRow(label: 'Phone', value: user.phone ?? '—'),
            if (user.isProvider) AdminInfoRow(label: 'Address', value: user.address ?? '—'),
            AdminInfoRow(label: 'Joined', value: adminDate(user.createdAt)),
            AdminInfoRow(label: 'Last sign-in', value: user.lastSignIn == null ? 'Never' : adminDateTime(user.lastSignIn!)),
            AdminInfoRow(label: 'Account id', value: user.userId),
          ],
        ),
        AdminSection(
          title: 'Bookings',
          children: [
            AdminInfoRow(label: 'Total', value: '${user.bookings.total}'),
            AdminInfoRow(label: 'Upcoming', value: '${user.bookings.upcoming}'),
            AdminInfoRow(label: 'Completed', value: '${user.bookings.completed}'),
            AdminInfoRow(label: 'Cancelled', value: '${user.bookings.cancelled}'),
            AdminInfoRow(label: 'No-shows', value: '${user.bookings.noShow}'),
            AdminInfoRow(label: 'Declined / expired', value: '${user.bookings.declined}'),
          ],
        ),
        if (settings != null)
          AdminSection(
            title: 'Booking settings',
            children: [
              AdminInfoRow(label: 'Taking bookings', value: settings['accepts_bookings'] == true ? 'Yes' : 'Paused'),
              AdminInfoRow(label: 'Approves requests', value: settings['requires_approval'] == true ? 'Yes' : 'No'),
              AdminInfoRow(
                label: 'Free cancellation',
                value: 'Until ${settings['cancellation_window_hours']} h before',
              ),
              AdminInfoRow(label: 'Late fee', value: '${settings['cancellation_fee_percent']}%'),
              AdminInfoRow(
                label: 'Works at',
                value: [
                  if (settings['offers_studio'] == true) 'Studio',
                  if (settings['offers_mobile'] == true) 'Mobile',
                ].join(' + '),
              ),
            ],
          ),
        AdminSection(
          title: 'Recent bookings',
          children: user.recentBookings.isEmpty
              ? [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text('No bookings yet.', style: TextStyle(color: scheme.onSurface.withValues(alpha: 0.6))),
                  ),
                ]
              : [
                  for (final booking in user.recentBookings)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: Text('${booking.reference} · ${booking.otherParty ?? '—'}'),
                      subtitle: Text('${adminDateTime(booking.startsAt)} · ${booking.status.replaceAll('_', ' ')}'),
                      trailing: Text(
                        Formatters.audCents(booking.totalCents),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                ],
        ),
        OutlinedButton.icon(
          onPressed: () => context.pushNamed(
            AppRoute.adminAuditLog.name,
            queryParameters: {'target_type': 'user', 'target_id': user.userId},
          ),
          icon: const Icon(Icons.history),
          label: const Text('Admin history for this account'),
        ),
      ],
    );
  }
}
