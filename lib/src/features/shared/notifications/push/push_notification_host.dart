import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../core/utils/app_logger.dart';
import '../../authentication/controllers/user_profile_provider.dart';
import '../controllers/notifications_controller.dart';
import 'push_messaging.dart';
import 'push_notifications_controller.dart';

/// Wires push notifications into the running app:
///
/// * keeps this device registered while someone is signed in, re-checking
///   the system setting whenever the app comes back to the foreground;
/// * opens the right booking when a notification is tapped, including one
///   that launched the app, once the user is signed in and past the splash;
/// * refreshes the inbox when a push arrives with the app open (the system
///   shows nothing then; the in-app banner covers it).
///
/// Sits above the router (in `MaterialApp.builder`), like
/// `InAppNotificationHost`.
class PushNotificationHost extends ConsumerStatefulWidget {
  const PushNotificationHost({super.key, required this.child});

  final Widget child;

  /// Locations where the app isn't ready to show a booking yet.
  static const Set<String> notReadyPaths = {'/', '/intro', '/auth', '/confirm_email', '/role', '/onboarding_details', '/error'};

  @override
  ConsumerState<PushNotificationHost> createState() => _PushNotificationHostState();
}

class _PushNotificationHostState extends ConsumerState<PushNotificationHost> with WidgetsBindingObserver {
  final List<StreamSubscription<PushMessage>> _subscriptions = [];
  PushMessage? _pending;
  GoRouter? _router;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final messaging = ref.read(pushMessagingProvider);
    if (!messaging.isSupported) return;

    final router = ref.read(routerProvider);
    router.routerDelegate.addListener(_tryOpenPending);
    _router = router;
    _subscriptions
      ..add(messaging.openedMessages.listen(_queue))
      ..add(messaging.foregroundMessages.listen((_) => ref.read(notificationsProvider.notifier).refresh()));
    unawaited(messaging.initialMessage().then((message) {
      if (message != null && mounted) _queue(message);
    }).catchError((Object e, StackTrace st) {
      AppLogger.e('Reading the launch notification failed', tag: 'PushHost', error: e, stackTrace: st);
    }));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _router?.routerDelegate.removeListener(_tryOpenPending);
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(ref.read(pushNotificationsProvider.notifier).refresh());
    }
  }

  void _queue(PushMessage message) {
    _pending = message;
    _tryOpenPending();
  }

  /// Opens the pending notification as soon as the app can show it.
  void _tryOpenPending() {
    final message = _pending;
    final router = _router;
    if (message == null || router == null || !mounted) return;
    final user = ref.read(userProfileProvider).value;
    final path = router.routerDelegate.currentConfiguration.uri.path;
    if (user == null || PushNotificationHost.notReadyPaths.contains(path)) return;

    _pending = null;
    final notificationId = message.notificationId;
    if (notificationId != null) unawaited(ref.read(notificationsProvider.notifier).markRead(notificationId));
    final bookingId = message.bookingId;
    if (bookingId == null) {
      router.pushNamed(AppRoute.notifications.name);
      return;
    }
    router.pushNamed(
      user.isProvider ? AppRoute.providerBookingDetail.name : AppRoute.clientBookingDetail.name,
      pathParameters: {'bookingId': bookingId},
    );
  }

  @override
  Widget build(BuildContext context) {
    // Keeps registration alive for the whole session.
    ref.listen(pushNotificationsProvider, (_, _) {});
    ref.listen(userProfileProvider, (_, _) => _tryOpenPending());
    return widget.child;
  }
}
