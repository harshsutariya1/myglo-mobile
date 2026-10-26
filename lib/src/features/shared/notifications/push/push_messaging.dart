import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/app_logger.dart';

/// Platforms that receive pushes, named as `register_push_token` expects.
enum PushPlatform { android, ios }

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
  /// Where this install receives pushes, or null where it can't (web,
  /// desktop): nothing is registered there.
  PushPlatform? get platform;

  /// Whether [platform] is known: Android and iOS.
  bool get isSupported;

  Future<PushPermission> permission();

  /// Shows the system prompt where it still can (Android 13+, or iOS before
  /// the first answer); otherwise returns the current answer.
  Future<PushPermission> requestPermission();

  /// This install's FCM token, or null if it can't be had right now. Never
  /// throws.
  Future<String?> token();

  Stream<String> get tokenRefreshes;

  /// Invalidates this install's token (e.g. on sign-out).
  Future<void> deleteToken();

  /// The push that cold-started the app from the notification tray, if any.
  Future<PushMessage?> initialMessage();

  /// Pushes tapped while the app was in the background.
  Stream<PushMessage> get openedMessages;

  /// Pushes received while the app is open. The system shows nothing then
  /// (on iOS too); the in-app banner covers them.
  Stream<PushMessage> get foregroundMessages;
}

final pushMessagingProvider = Provider<PushMessaging>((ref) => FirebasePushMessaging());

class FirebasePushMessaging implements PushMessaging {
  /// [targetPlatform], [isWeb] and [apnsRetryDelays] are for tests; by
  /// default they come from the running app.
  FirebasePushMessaging({
    FirebaseMessaging? messaging,
    TargetPlatform? targetPlatform,
    bool isWeb = kIsWeb,
    List<Duration> apnsRetryDelays = defaultApnsRetryDelays,
  })  : _messaging = messaging,
        _targetPlatform = targetPlatform,
        _isWeb = isWeb,
        _apnsRetryDelays = apnsRetryDelays;

  final FirebaseMessaging? _messaging;
  final TargetPlatform? _targetPlatform;
  final bool _isWeb;
  final List<Duration> _apnsRetryDelays;

  FirebaseMessaging get _fcm => _messaging ?? FirebaseMessaging.instance;

  static const _tag = 'PushMessaging';

  /// How long to wait between checks for the APNs token, which iOS hands
  /// over a moment after launch (about 8 seconds in all). FCM can't issue a
  /// token before it arrives.
  static const List<Duration> defaultApnsRetryDelays = [
    Duration(milliseconds: 250),
    Duration(milliseconds: 500),
    Duration(seconds: 1),
    Duration(seconds: 2),
    Duration(seconds: 4),
  ];

  /// What FCM throws on iOS when asked for a token before APNs has one.
  static const _apnsTokenNotSet = 'apns-token-not-set';

  bool _apnsMissingReported = false;
  bool _foregroundConfigured = false;

  @override
  PushPlatform? get platform {
    if (_isWeb) return null;
    return switch (_targetPlatform ?? defaultTargetPlatform) {
      TargetPlatform.android => PushPlatform.android,
      TargetPlatform.iOS => PushPlatform.ios,
      _ => null,
    };
  }

  @override
  bool get isSupported => platform != null;

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
      if (platform != PushPlatform.ios) return await _fcm.getToken();
      final token = await _iosToken();
      if (token == null) _reportMissingApnsToken();
      return token;
    } catch (e, st) {
      // e.g. Google Play services missing or out of date, or no network.
      AppLogger.e('Getting the FCM token failed', tag: _tag, error: e, stackTrace: st);
      return null;
    }
  }

  /// Waits for the APNs token (with back-off), then asks FCM for its token.
  /// Null if APNs never delivered one.
  Future<String?> _iosToken() async {
    for (var attempt = 0;; attempt++) {
      try {
        if (await _fcm.getAPNSToken() != null) return await _fcm.getToken();
      } on FirebaseException catch (e) {
        if (e.code != _apnsTokenNotSet) rethrow;
      }
      if (attempt >= _apnsRetryDelays.length) return null;
      await Future<void>.delayed(_apnsRetryDelays[attempt]);
    }
  }

  /// No APNs token usually means the build lacks the Push Notifications
  /// entitlement or the device can't reach Apple. Reported once per run; the
  /// next resume or launch tries again.
  void _reportMissingApnsToken() {
    const message = 'No APNs token after retrying; push is not registered on this iPhone';
    if (_apnsMissingReported) {
      AppLogger.w(message, tag: _tag);
      return;
    }
    _apnsMissingReported = true;
    AppLogger.e(message, tag: _tag, error: StateError('APNs token unavailable'), stackTrace: StackTrace.current);
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
  Stream<PushMessage> get foregroundMessages {
    _keepSystemQuietInForeground();
    return FirebaseMessaging.onMessage.map((message) => PushMessage.fromData(message.data));
  }

  /// iOS would otherwise show a push that arrives with the app open if these
  /// options were ever turned on (they persist across launches), doubling up
  /// with the in-app banner. Android never shows one in the foreground.
  void _keepSystemQuietInForeground() {
    if (_foregroundConfigured || platform != PushPlatform.ios) return;
    _foregroundConfigured = true;
    unawaited(_fcm.setForegroundNotificationPresentationOptions(alert: false, badge: false, sound: false).catchError(
      (Object e, StackTrace st) =>
          AppLogger.e('Setting iOS foreground push options failed', tag: _tag, error: e, stackTrace: st),
    ));
  }

  /// iOS asks once: after a refusal only its settings can turn notifications
  /// on, and it reports that as plain `denied`. Android 13+ may ask again
  /// after `denied` and says `deniedPermanently` when it won't.
  PushPermission _map(AuthorizationStatus status) => switch (status) {
        AuthorizationStatus.authorized || AuthorizationStatus.provisional => PushPermission.granted,
        AuthorizationStatus.notDetermined => PushPermission.canAsk,
        AuthorizationStatus.denied => platform == PushPlatform.ios ? PushPermission.blocked : PushPermission.canAsk,
        AuthorizationStatus.deniedPermanently => PushPermission.blocked,
      };
}
