import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/snackbar_utils.dart';
import '../controllers/admin_actions.dart';
import '../controllers/admin_controllers.dart';
import '../models/admin_models.dart';
import '../models/admin_moderation.dart';
import '../models/admin_repository.dart';
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
        _ModerationSection(user: user),
        AdminSection(
          title: 'Account',
          children: [
            AdminInfoRow(label: 'Email', value: user.email ?? '—'),
            AdminInfoRow(
              label: 'Email confirmed',
              value: user.emailConfirmedAt == null ? 'No' : adminDate(user.emailConfirmedAt!),
            ),
            AdminInfoRow(label: 'Phone', value: user.phone ?? '—'),
            if (user.isProvider)
              AdminInfoRow(
                label: 'Phone verified',
                value: user.phoneVerifiedAt == null ? 'No' : adminDate(user.phoneVerifiedAt!),
                valueColor: user.phoneVerifiedAt == null ? AppTheme.warning : null,
              ),
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
              AdminInfoRow(
                label: 'Marketplace',
                value: settings['hidden_from_marketplace'] == true ? 'Hidden by the provider' : 'Listed',
                valueColor: settings['hidden_from_marketplace'] == true ? AppTheme.warning : null,
              ),
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
        if (user.isProvider) _PayoutAccountSection(userId: user.userId),
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

/// Suspension and (for providers) booking blocks, with the reports that
/// concern the account.
class _ModerationSection extends ConsumerWidget {
  const _ModerationSection({required this.user});

  final AdminUserDetail user;

  void _refresh(WidgetRef ref) {
    ref.invalidate(adminModerationStateProvider(user.userId));
    ref.invalidate(adminUserProvider(user.userId));
  }

  Future<void> _suspend(BuildContext context, WidgetRef ref, AdminModerationState state) async {
    final reason = await askAdminReason(
      context,
      title: 'Suspend ${user.title}',
      summary: "They're signed out and can't sign in, book, post or change anything until the suspension is lifted."
          '${user.isProvider ? ' They also drop out of search and the map.' : ''}',
    );
    if (reason == null || !context.mounted) return;
    var cancelUpcoming = false;
    if (state.upcomingBookings > 0) {
      final choice = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text('${state.upcomingBookings} upcoming ${state.upcomingBookings == 1 ? 'booking' : 'bookings'}'),
          content: const Text(
            'Cancel them on Myglo\'s behalf? Clients paid in the app are refunded in full and both sides are told. '
            'Kept bookings stay as they are.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Back')),
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Keep them')),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: FilledButton.styleFrom(backgroundColor: AppTheme.destructive),
              child: const Text('Cancel & refund'),
            ),
          ],
        ),
      );
      if (choice == null || !context.mounted) return;
      cancelUpcoming = choice;
    }
    final cancelled = await runAdminAction(
      context,
      ref,
      sensitive: true,
      action: () => ref
          .read(adminRepositoryProvider)
          .setSuspension(user.userId, suspended: true, reason: reason, cancelUpcoming: cancelUpcoming),
    );
    if (cancelled != null && context.mounted) {
      context.showAppSnackBar(
        cancelled > 0 ? 'Account suspended · $cancelled ${cancelled == 1 ? 'booking' : 'bookings'} cancelled' : 'Account suspended',
      );
    }
    _refresh(ref);
  }

  Future<void> _unsuspend(BuildContext context, WidgetRef ref) async {
    final reason = await askAdminReason(
      context,
      title: 'Lift the suspension',
      summary: '${user.title} can sign in and use Myglo again. Cancelled bookings stay cancelled.',
    );
    if (reason == null || !context.mounted) return;
    await runAdminAction(
      context,
      ref,
      sensitive: true,
      action: () => ref.read(adminRepositoryProvider).setSuspension(user.userId, suspended: false, reason: reason),
      successMessage: 'Suspension lifted',
    );
    _refresh(ref);
  }

  Future<void> _setBlocked(BuildContext context, WidgetRef ref, {required bool blocked}) async {
    final reason = await askAdminReason(
      context,
      title: blocked ? 'Stop new bookings' : 'Allow bookings again',
      summary: blocked
          ? 'Clients can no longer book ${user.title}, and they drop out of search and the map. '
              'Existing bookings go ahead, and they can still use the app.'
          : 'Clients can find and book ${user.title} again.',
    );
    if (reason == null || !context.mounted) return;
    await runAdminAction(
      context,
      ref,
      sensitive: true,
      action: () => ref.read(adminRepositoryProvider).setBookingsBlocked(user.userId, blocked: blocked, reason: reason),
      successMessage: blocked ? 'New bookings stopped' : 'Bookings allowed again',
    );
    _refresh(ref);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = context.colorScheme;
    final async = ref.watch(adminModerationStateProvider(user.userId));
    return AdminSection(
      title: 'Moderation',
      children: switch (async) {
        AsyncData(value: final state) => [
            if (state.isSuspended) ...[
              AdminInfoRow(
                label: 'Suspended',
                value: 'Since ${adminDateTime(state.suspendedAt!)}',
                valueColor: AppTheme.destructive,
              ),
              AdminInfoRow(label: 'Reason', value: state.suspendedReason ?? '—'),
            ] else
              const AdminInfoRow(label: 'Account', value: 'Active', valueColor: AppTheme.success),
            if (user.isProvider)
              state.bookingsBlocked
                  ? AdminInfoRow(
                      label: 'New bookings',
                      value: 'Stopped ${adminDate(state.bookingsBlockedAt!)} · ${state.bookingsBlockedReason ?? ''}',
                      valueColor: AppTheme.warning,
                    )
                  : const AdminInfoRow(label: 'New bookings', value: 'Allowed'),
            AdminInfoRow(label: 'Open reports about them', value: '${state.openReportsAbout}'),
            AdminInfoRow(label: 'Reports they sent', value: '${state.reportsMade}'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (state.isSuspended)
                  OutlinedButton.icon(
                    onPressed: () => _unsuspend(context, ref),
                    icon: const Icon(Icons.lock_open_rounded),
                    label: const Text('Lift suspension'),
                  )
                else
                  OutlinedButton.icon(
                    onPressed: () => _suspend(context, ref, state),
                    style: OutlinedButton.styleFrom(foregroundColor: AppTheme.destructive),
                    icon: const Icon(Icons.block_rounded),
                    label: const Text('Suspend account'),
                  ),
                if (user.isProvider && !state.isSuspended)
                  OutlinedButton.icon(
                    onPressed: () => _setBlocked(context, ref, blocked: !state.bookingsBlocked),
                    icon: Icon(state.bookingsBlocked ? Icons.event_available_outlined : Icons.event_busy_outlined),
                    label: Text(state.bookingsBlocked ? 'Allow bookings' : 'Stop new bookings'),
                  ),
              ],
            ),
          ],
        AsyncError() => [
            Text("Couldn't load moderation details.", style: TextStyle(color: scheme.onSurface.withValues(alpha: 0.6))),
            TextButton(
              onPressed: () => ref.invalidate(adminModerationStateProvider(user.userId)),
              child: const Text('Try again'),
            ),
          ],
        _ => [const Padding(padding: EdgeInsets.all(8), child: LinearProgressIndicator())],
      },
    );
  }
}

/// The provider's Stripe payout account as Myglo last saw it.
class _PayoutAccountSection extends ConsumerWidget {
  const _PayoutAccountSection({required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = context.colorScheme;
    final account = ref.watch(adminPayoutAccountProvider(userId));
    return AdminSection(
      title: 'Card payments',
      children: switch (account) {
        AsyncData(value: null) => [const AdminInfoRow(label: 'Stripe account', value: 'Not set up')],
        AsyncData(:final value?) => [
            AdminInfoRow(
              label: 'Transfers',
              value: '${value['transfers_status']}',
              valueColor: value['transfers_status'] == 'active' ? AppTheme.success : AppTheme.warning,
            ),
            AdminInfoRow(label: 'Payouts', value: value['payouts_enabled'] == true ? 'Enabled' : 'Not enabled'),
            AdminInfoRow(
              label: 'Takes',
              value: [
                if (value['accepts_card'] == true && value['card_ready'] == true) 'Card',
                if (value['accepts_cash'] == true || value['card_ready'] != true) 'Cash',
              ].join(' + '),
            ),
            if ((value['requirements_due'] as List?)?.isNotEmpty ?? false)
              AdminInfoRow(label: 'Stripe needs', value: (value['requirements_due'] as List).join('\n')),
            if (value['disabled_reason'] != null) AdminInfoRow(label: 'Reason', value: '${value['disabled_reason']}'),
            if (value['first_enabled_at'] != null)
              AdminInfoRow(label: 'Enabled since', value: adminDate(DateTime.parse('${value['first_enabled_at']}'))),
            AdminInfoRow(label: 'Stripe account', value: '${value['stripe_account_id']}'),
          ],
        AsyncError() => [
            Text("Couldn't load the payout account.", style: TextStyle(color: scheme.onSurface.withValues(alpha: 0.6))),
          ],
        _ => [const Padding(padding: EdgeInsets.all(8), child: LinearProgressIndicator())],
      },
    );
  }
}
