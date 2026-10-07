import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../authentication/controllers/user_profile_provider.dart';
import '../controllers/notifications_controller.dart';
import '../models/app_notification.dart';

/// Header bell with the unread count; opens the notifications screen.
class NotificationBell extends ConsumerWidget {
  const NotificationBell({super.key, this.size = 26});

  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = context.colorScheme;
    final unread = ref.watch(notificationsProvider.select((s) => s.value?.unreadCount ?? 0));
    return IconButton(
      tooltip: unread == 0 ? 'Notifications' : 'Notifications, $unread unread',
      onPressed: () => context.pushNamed(AppRoute.notifications.name),
      icon: Badge(
        isLabelVisible: unread > 0,
        backgroundColor: scheme.primary,
        textColor: scheme.onPrimary,
        label: Text(unread > 9 ? '9+' : '$unread'),
        child: Icon(unread > 0 ? Icons.notifications_rounded : Icons.notifications_outlined, size: size, color: scheme.onSurface),
      ),
    );
  }
}

/// Opens whatever [notification] is about, as the signed-in role sees it.
void openNotificationTarget(BuildContext context, WidgetRef ref, AppNotification notification) {
  final bookingId = notification.bookingId;
  if (bookingId == null) return;
  final isProvider = ref.read(userProfileProvider).value?.isProvider ?? false;
  context.pushNamed(
    isProvider ? AppRoute.providerBookingDetail.name : AppRoute.clientBookingDetail.name,
    pathParameters: {'bookingId': bookingId},
  );
}
