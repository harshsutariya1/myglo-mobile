import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/routing/app_router.dart';
import '../../authentication/controllers/user_profile_provider.dart';
import '../controllers/notifications_controller.dart';
import '../models/app_notification.dart';

/// Keeps the notification inbox live for the whole session and drops a
/// banner from the top whenever something new arrives while the app is open
/// (a new booking for a provider, a request accepted for a client…).
///
/// Sits above the router (in `MaterialApp.builder`), so it navigates through
/// the router directly.
class InAppNotificationHost extends ConsumerStatefulWidget {
  const InAppNotificationHost({super.key, required this.child});

  final Widget child;

  static const Duration visibleFor = Duration(seconds: 5);

  @override
  ConsumerState<InAppNotificationHost> createState() => _InAppNotificationHostState();
}

class _InAppNotificationHostState extends ConsumerState<InAppNotificationHost> {
  AppNotification? _showing;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _show(AppNotification notification) {
    HapticFeedback.lightImpact();
    _timer?.cancel();
    setState(() => _showing = notification);
    _timer = Timer(InAppNotificationHost.visibleFor, _hide);
  }

  void _hide() {
    _timer?.cancel();
    if (mounted && _showing != null) setState(() => _showing = null);
  }

  void _open(AppNotification notification) {
    _hide();
    ref.read(notificationsProvider.notifier).markRead(notification.id);
    final bookingId = notification.bookingId;
    if (bookingId == null) return;
    final isProvider = ref.read(userProfileProvider).value?.isProvider ?? false;
    ref.read(routerProvider).pushNamed(
          isProvider ? AppRoute.providerBookingDetail.name : AppRoute.clientBookingDetail.name,
          pathParameters: {'bookingId': bookingId},
        );
  }

  @override
  Widget build(BuildContext context) {
    // Keeps the inbox (and its realtime subscription) alive app-wide.
    ref.listen(notificationsProvider, (_, _) {});
    ref.listen(notificationArrivalProvider, (_, next) {
      if (next == null) return;
      ref.read(notificationArrivalProvider.notifier).clear();
      _show(next);
    });

    final notification = _showing;
    return Stack(
      children: [
        widget.child,
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          child: SafeArea(
            bottom: false,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 280),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) => SlideTransition(
                position: Tween(begin: const Offset(0, -1.2), end: Offset.zero).animate(animation),
                child: FadeTransition(opacity: animation, child: child),
              ),
              child: notification == null
                  ? const SizedBox.shrink(key: ValueKey('none'))
                  : _Banner(
                      key: ValueKey(notification.id),
                      notification: notification,
                      onTap: () => _open(notification),
                      onDismiss: _hide,
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({super.key, required this.notification, required this.onTap, required this.onDismiss});

  final AppNotification notification;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = notification.kind.color(scheme);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Dismissible(
        key: ValueKey('banner-${notification.id}'),
        direction: DismissDirection.up,
        onDismissed: (_) => onDismiss(),
        child: Semantics(
          liveRegion: true,
          button: true,
          label: '${notification.title}. ${notification.body}',
          excludeSemantics: true,
          child: Material(
            color: scheme.onSurface,
            elevation: 10,
            shadowColor: Colors.black45,
            borderRadius: BorderRadius.circular(20),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(color: color.withValues(alpha: 0.25), shape: BoxShape.circle),
                      child: Icon(notification.kind.icon, size: 20, color: Color.lerp(color, Colors.white, 0.35)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            notification.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: scheme.surface),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            notification.body,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 13, height: 1.35, color: scheme.surface.withValues(alpha: 0.75)),
                          ),
                        ],
                      ),
                    ),
                    if (notification.bookingId != null) ...[
                      const SizedBox(width: 8),
                      Icon(Icons.chevron_right_rounded, color: scheme.surface.withValues(alpha: 0.6)),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
