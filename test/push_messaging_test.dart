import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myglo/src/features/shared/notifications/push/push_messaging.dart';

/// Scripted Firebase Messaging: the APNs token shows up after
/// [apnsTokenAfter] checks, like iOS handing it over just after launch.
class _FakeFirebaseMessaging extends Fake implements FirebaseMessaging {
  _FakeFirebaseMessaging({this.apnsTokenAfter = 0, this.status = AuthorizationStatus.notDetermined});

  /// Null: APNs never delivers a token.
  final int? apnsTokenAfter;
  AuthorizationStatus status;
  int apnsChecks = 0;
  int tokenRequests = 0;

  /// Throw `apns-token-not-set` from [getToken] this many times first.
  int tokenNotSetFailures = 0;
  Object? tokenError;
  final presentationOptions = <({bool alert, bool badge, bool sound})>[];

  @override
  Future<String?> getAPNSToken() async {
    apnsChecks++;
    final after = apnsTokenAfter;
    return after != null && apnsChecks > after ? 'apns-device-token' : null;
  }

  @override
  Future<String?> getToken({String? serviceWorkerScriptPath, String? vapidKey}) async {
    tokenRequests++;
    if (tokenNotSetFailures > 0) {
      tokenNotSetFailures--;
      throw FirebaseException(plugin: 'firebase_messaging', code: 'apns-token-not-set');
    }
    final error = tokenError;
    if (error != null) throw error;
    return 'fcm-token';
  }

  @override
  Future<NotificationSettings> getNotificationSettings() async => _settings(status);

  @override
  Future<NotificationSettings> requestPermission({
    bool alert = true,
    bool announcement = false,
    bool badge = true,
    bool carPlay = false,
    bool criticalAlert = false,
    bool provisional = false,
    bool sound = true,
    bool providesAppNotificationSettings = false,
  }) async =>
      _settings(status);

  @override
  Future<void> setForegroundNotificationPresentationOptions({
    bool alert = false,
    bool badge = false,
    bool sound = false,
  }) async =>
      presentationOptions.add((alert: alert, badge: badge, sound: sound));

  static NotificationSettings _settings(AuthorizationStatus status) => NotificationSettings(
        alert: AppleNotificationSetting.notSupported,
        announcement: AppleNotificationSetting.notSupported,
        authorizationStatus: status,
        badge: AppleNotificationSetting.notSupported,
        carPlay: AppleNotificationSetting.notSupported,
        lockScreen: AppleNotificationSetting.notSupported,
        notificationCenter: AppleNotificationSetting.notSupported,
        showPreviews: AppleShowPreviewSetting.notSupported,
        timeSensitive: AppleNotificationSetting.notSupported,
        criticalAlert: AppleNotificationSetting.notSupported,
        sound: AppleNotificationSetting.notSupported,
        providesAppNotificationSettings: AppleNotificationSetting.notSupported,
      );
}

const _noWait = [Duration.zero, Duration.zero, Duration.zero, Duration.zero, Duration.zero];

FirebasePushMessaging _messaging(_FakeFirebaseMessaging fcm, TargetPlatform platform, {bool isWeb = false}) =>
    FirebasePushMessaging(messaging: fcm, targetPlatform: platform, isWeb: isWeb, apnsRetryDelays: _noWait);

void main() {
  group('platform', () {
    test('Android and iOS receive pushes', () {
      final fcm = _FakeFirebaseMessaging();
      expect(_messaging(fcm, TargetPlatform.android).platform, PushPlatform.android);
      expect(_messaging(fcm, TargetPlatform.iOS).platform, PushPlatform.ios);
      expect(_messaging(fcm, TargetPlatform.iOS).isSupported, isTrue);
    });

    test('web and desktop do not', () {
      final fcm = _FakeFirebaseMessaging();
      expect(_messaging(fcm, TargetPlatform.android, isWeb: true).isSupported, isFalse);
      expect(_messaging(fcm, TargetPlatform.iOS, isWeb: true).isSupported, isFalse);
      expect(_messaging(fcm, TargetPlatform.macOS).platform, isNull);
      expect(_messaging(fcm, TargetPlatform.windows).isSupported, isFalse);
    });

    test('names match what register_push_token accepts', () {
      expect(PushPlatform.values.map((p) => p.name), ['android', 'ios']);
    });
  });

  group('token on iOS', () {
    test('waits for the APNs token, then fetches the FCM token', () async {
      final fcm = _FakeFirebaseMessaging(apnsTokenAfter: 3);

      expect(await _messaging(fcm, TargetPlatform.iOS).token(), 'fcm-token');
      expect(fcm.apnsChecks, 4);
      expect(fcm.tokenRequests, 1);
    });

    test('retries when FCM still says the APNs token is not set', () async {
      final fcm = _FakeFirebaseMessaging()..tokenNotSetFailures = 2;

      expect(await _messaging(fcm, TargetPlatform.iOS).token(), 'fcm-token');
      expect(fcm.tokenRequests, 3);
    });

    test('gives up after the last retry without asking FCM', () async {
      final fcm = _FakeFirebaseMessaging(apnsTokenAfter: null);

      expect(await _messaging(fcm, TargetPlatform.iOS).token(), isNull);
      expect(fcm.apnsChecks, _noWait.length + 1);
      expect(fcm.tokenRequests, 0);
    });

    test('other errors return null instead of throwing', () async {
      final fcm = _FakeFirebaseMessaging()..tokenError = FirebaseException(plugin: 'firebase_messaging', code: 'unknown');

      expect(await _messaging(fcm, TargetPlatform.iOS).token(), isNull);
      expect(fcm.tokenRequests, 1);
    });
  });

  group('token on Android', () {
    test('asks FCM straight away', () async {
      final fcm = _FakeFirebaseMessaging(apnsTokenAfter: null);

      expect(await _messaging(fcm, TargetPlatform.android).token(), 'fcm-token');
      expect(fcm.apnsChecks, 0);
    });

    test('errors return null', () async {
      final fcm = _FakeFirebaseMessaging()..tokenError = Exception('no Play services');

      expect(await _messaging(fcm, TargetPlatform.android).token(), isNull);
    });
  });

  group('permission', () {
    Future<PushPermission> on(TargetPlatform platform, AuthorizationStatus status) =>
        _messaging(_FakeFirebaseMessaging(status: status), platform).permission();

    test('iOS: a refusal is final, so it is blocked', () async {
      expect(await on(TargetPlatform.iOS, AuthorizationStatus.notDetermined), PushPermission.canAsk);
      expect(await on(TargetPlatform.iOS, AuthorizationStatus.denied), PushPermission.blocked);
      expect(await on(TargetPlatform.iOS, AuthorizationStatus.authorized), PushPermission.granted);
      expect(await on(TargetPlatform.iOS, AuthorizationStatus.provisional), PushPermission.granted);
    });

    test('Android: denied can still ask; denied permanently is blocked', () async {
      expect(await on(TargetPlatform.android, AuthorizationStatus.denied), PushPermission.canAsk);
      expect(await on(TargetPlatform.android, AuthorizationStatus.deniedPermanently), PushPermission.blocked);
      expect(await on(TargetPlatform.android, AuthorizationStatus.authorized), PushPermission.granted);
    });

    test('requesting maps the answer the same way', () async {
      final fcm = _FakeFirebaseMessaging(status: AuthorizationStatus.denied);
      expect(await _messaging(fcm, TargetPlatform.iOS).requestPermission(), PushPermission.blocked);
    });
  });

  group('foreground on iOS', () {
    test('keeps the system banner off once, so only the in-app banner shows', () {
      final fcm = _FakeFirebaseMessaging();
      final messaging = _messaging(fcm, TargetPlatform.iOS);

      messaging.foregroundMessages;
      messaging.foregroundMessages;

      expect(fcm.presentationOptions, [(alert: false, badge: false, sound: false)]);
    });

    test('leaves Android alone', () {
      final fcm = _FakeFirebaseMessaging();

      _messaging(fcm, TargetPlatform.android).foregroundMessages;

      expect(fcm.presentationOptions, isEmpty);
    });
  });
}
