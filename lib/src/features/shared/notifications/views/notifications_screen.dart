import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/skeleton/skeletons.dart';
import '../../../../core/widgets/snackbar_utils.dart';
import '../../../customers/provider_profile/views/widgets/section_states.dart';
import '../controllers/notifications_controller.dart';
import '../models/app_notification.dart';
import 'notification_bell.dart';

/// Every booking update for the signed-in user, newest first, live.
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  Future<void> _markAllRead(BuildContext context, WidgetRef ref) async {
    HapticFeedback.selectionClick();
    try {
      await ref.read(notificationsProvider.notifier).markAllRead();
    } catch (_) {
      if (context.mounted) context.showAppSnackBar("Couldn't update your notifications. Please try again.", isError: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = context.colorScheme;
    final async = ref.watch(notificationsProvider);
    final state = async.value;
    final unread = state?.unreadCount ?? 0;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        title: const Text('Notifications'),
        actions: [
          if (unread > 0)
            TextButton(
              onPressed: () => _markAllRead(context, ref),
              style: TextButton.styleFrom(
                foregroundColor: scheme.secondary,
                textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
              child: const Text('Mark all read'),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: switch (state) {
        null when async.hasError => Center(
            child: SingleChildScrollView(
              child: SectionErrorView(
                title: "Notifications didn't load",
                message: describeLoadError(async.error!, subject: 'your notifications'),
                onRetry: () => ref.invalidate(notificationsProvider),
              ),
            ),
          ),
        null => Shimmer(
            child: ListView.builder(
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 6,
              itemBuilder: (_, _) => const ListTileSkeleton(),
            ),
          ),
        final state when state.items.isEmpty => RefreshIndicator(
            color: scheme.primary,
            onRefresh: () => ref.read(notificationsProvider.notifier).refresh(),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 80),
                SectionEmptyView(
                  icon: Icons.notifications_none_rounded,
                  title: "You're all caught up",
                  message: 'Booking confirmations, changes and reminders will appear here.',
                ),
              ],
            ),
          ),
        final state => RefreshIndicator(
            color: scheme.primary,
            onRefresh: () => ref.read(notificationsProvider.notifier).refresh(),
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(0, 4, 0, 24 + MediaQuery.paddingOf(context).bottom),
              itemCount: state.items.length,
              separatorBuilder: (_, _) => Divider(
                height: 1,
                thickness: 1,
                indent: 76,
                color: scheme.onSurface.withValues(alpha: 0.06),
              ),
              itemBuilder: (context, index) {
                final notification = state.items[index];
                return _NotificationTile(
                  key: ValueKey(notification.id),
                  notification: notification,
                  onTap: () {
                    ref.read(notificationsProvider.notifier).markRead(notification.id);
                    openNotificationTarget(context, ref, notification);
                  },
                  onDismissed: () async {
                    try {
                      await ref.read(notificationsProvider.notifier).remove(notification.id);
                    } catch (_) {
                      if (context.mounted) {
                        context.showAppSnackBar("Couldn't remove that notification.", isError: true);
                      }
                    }
                  },
                );
              },
            ),
          ),
      },
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({super.key, required this.notification, required this.onTap, required this.onDismissed});

  final AppNotification notification;
  final VoidCallback onTap;
  final VoidCallback onDismissed;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final color = notification.kind.color(scheme);
    final unread = !notification.isRead;

    return Dismissible(
      key: ValueKey('dismiss-${notification.id}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDismissed(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        color: AppTheme.destructive.withValues(alpha: 0.12),
        child: const Icon(Icons.delete_outline_rounded, color: AppTheme.destructive),
      ),
      child: Semantics(
        button: true,
        label: '${unread ? 'Unread. ' : ''}${notification.title}. ${notification.body}. '
            '${Formatters.relativeTime(notification.createdAt)}',
        excludeSemantics: true,
        child: InkWell(
          onTap: onTap,
          child: Container(
            color: unread ? scheme.primary.withValues(alpha: 0.04) : null,
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
                  child: Icon(notification.kind.icon, size: 21, color: Color.lerp(color, Colors.black, 0.2)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              notification.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: unread ? FontWeight.w800 : FontWeight.w700,
                                color: scheme.onSurface,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            Formatters.relativeTime(notification.createdAt),
                            style: TextStyle(fontSize: 12, color: scheme.onSurface.withValues(alpha: 0.45)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        notification.body,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13.5,
                          height: 1.4,
                          color: scheme.onSurface.withValues(alpha: unread ? 0.75 : 0.55),
                        ),
                      ),
                    ],
                  ),
                ),
                if (unread) ...[
                  const SizedBox(width: 10),
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(color: scheme.primary, shape: BoxShape.circle),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
