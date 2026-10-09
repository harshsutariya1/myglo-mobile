import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/app_logger.dart';

/// Whether the system lets the app show notifications.
enum PushPermission {
  granted,

  /// Not allowed, but asking again shows the system prompt.
  canAsk,

  /// Not allowed, and the system won't prompt again: only its settings can
  /// change it.
  blocked,
}

/// A push the user tapped (or that arrived while the app was open), reduced
/// to what the app needs to route it.
@immutable
class PushMessage {
  const PushMessage({this.notificationId, this.bookingId, this.kind});

  /// Reads the data the send-notifications Edge Function attaches.
  factory PushMessage.fromData(Map<String, dynamic> data) {
    String? text(String key) {
      final value = data[key];
      return value is String && value.trim().isNotEmpty ? value.trim() : null;
    }

    return PushMessage(notificationId: text('notification_id'), bookingId: text('booking_id'), kind: text('kind'));
  }

  final String? notificationId;
  final String? bookingId;
  final String? kind;
}

/// The app's seam over Firebase Cloud Messaging, so push logic can be
/// tested without Firebase.
abstract interface class PushMessaging {
  /// Push is live on Android. iOS needs an APNs key in Firebase plus the Push
  /// Notifications capability first; until then nothing is registered there.
  bool get isSupported;

  Future<PushPermission> permission();

  /// Shows the system prompt where it still can (Android 13+); otherwise
  /// returns the current answer.
  Future<PushPermission> requestPermission();

  /// This install's FCM token, or null if it can't be had right now.
  Future<String?> token();

  Stream<String> get tokenRefreshes;

  /// Invalidates this install's token (e.g. on sign-out).
  Future<void> deleteToken();

  /// The push that cold-started the app from the notification tray, if any.
  Future<PushMessage?> initialMessage();

  /// Pushes tapped while the app was in the background.
  Stream<PushMessage> get openedMessages;

  /// Pushes received while the app is open (the system shows nothing then).
  Stream<PushMessage> get foregroundMessages;
}

final pushMessagingProvider = Provider<PushMessaging>((ref) => FirebasePushMessaging());

class FirebasePushMessaging implements PushMessaging {
  FirebasePushMessaging({FirebaseMessaging? messaging}) : _messaging = messaging;

  final FirebaseMessaging? _messaging;

  FirebaseMessaging get _fcm => _messaging ?? FirebaseMessaging.instance;

  static const _tag = 'PushMessaging';

  @override
  bool get isSupported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  Future<PushPermission> permission() async {
    final settings = await _fcm.getNotificationSettings();
    return _map(settings.authorizationStatus);
  }

  @override
  Future<PushPermission> requestPermission() async {
    final settings = await _fcm.requestPermission();
    return _map(settings.authorizationStatus);
  }

  @override
  Future<String?> token() async {
    try {
      return await _fcm.getToken();
    } catch (e, st) {
      // e.g. Google Play services missing or out of date.
      AppLogger.e('Getting the FCM token failed', tag: _tag, error: e, stackTrace: st);
      return null;
    }
  }

  @override
  Stream<String> get tokenRefreshes => _fcm.onTokenRefresh;

  @override
  Future<void> deleteToken() async {
    try {
      await _fcm.deleteToken();
    } catch (e, st) {
      AppLogger.w('Deleting the FCM token failed', tag: _tag, error: e, stackTrace: st);
    }
  }

  @override
  Future<PushMessage?> initialMessage() async {
    final message = await _fcm.getInitialMessage();
    return message == null ? null : PushMessage.fromData(message.data);
  }

  @override
  Stream<PushMessage> get openedMessages =>
      FirebaseMessaging.onMessageOpenedApp.map((message) => PushMessage.fromData(message.data));

  @override
  Stream<PushMessage> get foregroundMessages =>
      FirebaseMessaging.onMessage.map((message) => PushMessage.fromData(message.data));

  static PushPermission _map(AuthorizationStatus status) => switch (status) {
        AuthorizationStatus.authorized || AuthorizationStatus.provisional => PushPermission.granted,
        AuthorizationStatus.denied || AuthorizationStatus.notDetermined => PushPermission.canAsk,
        AuthorizationStatus.deniedPermanently => PushPermission.blocked,
      };
}
