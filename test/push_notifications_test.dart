import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:myglo/src/core/platform/system_bridge.dart';
import 'package:myglo/src/core/services/app_preferences.dart';
import 'package:myglo/src/features/shared/authentication/controllers/session_actions.dart';
import 'package:myglo/src/features/shared/authentication/controllers/user_profile_provider.dart';
import 'package:myglo/src/features/shared/authentication/models/auth_repository.dart';
import 'package:myglo/src/features/shared/authentication/models/profile_model.dart';
import 'package:myglo/src/features/shared/authentication/models/user_role.dart';
import 'package:myglo/src/features/shared/notifications/push/push_messaging.dart';
import 'package:myglo/src/features/shared/notifications/push/push_notifications_controller.dart';
import 'package:myglo/src/features/shared/notifications/push/push_settings.dart';
import 'package:myglo/src/features/shared/notifications/push/push_token_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'support/fake_push_messaging.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

class _FakeTokens implements PushTokenRepository {
  final registered = <String>[];
  final unregistered = <String>[];

  @override
  Future<void> register(String token, {required String platform}) async {
    expect(platform, 'android');
    registered.add(token);
  }

  @override
  Future<void> unregister(String token) async => unregistered.add(token);
}

class _FakeSystem implements SystemBridge {
  int settingsOpened = 0;

  @override
  Future<bool> mapsAvailable() async => true;

  @override
  Future<bool> notificationsEnabled() async => false;

  @override
  Future<bool> openNotificationSettings() async {
    settingsOpened++;
    return true;
  }
}

AppUserProfile _user(String id) => AppUserProfile(
      rawUser: User(
        id: id,
        appMetadata: const {},
        userMetadata: const {},
        aud: 'authenticated',
        createdAt: DateTime.utc(2026, 1, 1).toIso8601String(),
      ),
      role: UserRole.provider,
      profile: ProfileModel(id: id, role: UserRole.provider, firstName: 'Mia', lastName: 'Nguyen'),
    );

Future<ProviderContainer> _container({
  required FakePushMessaging push,
  _FakeTokens? tokens,
  _FakeSystem? system,
  AuthRepository? auth,
  Map<String, Object> preferences = const {},
}) async {
  SharedPreferences.setMockInitialValues(preferences);
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    retry: (_, _) => null,
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      userProfileProvider.overrideWith((ref) async => _user('prov-1')),
      pushMessagingProvider.overrideWithValue(push),
      pushTokenRepositoryProvider.overrideWithValue(tokens ?? _FakeTokens()),
      systemBridgeProvider.overrideWithValue(system ?? _FakeSystem()),
      if (auth != null) authRepositoryProvider.overrideWithValue(auth),
    ],
  );
  addTearDown(container.dispose);
  // Keep the controller alive like PushNotificationHost does.
  container.listen(pushNotificationsProvider, (_, _) {});
  await container.read(userProfileProvider.future);
  return container;
}

Future<PushStatus> _status(ProviderContainer container) async {
  final status = await container.read(pushNotificationsProvider.future);
  // Let fire-and-forget registration finish.
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
  return status;
}

void main() {
  group('PushMessage', () {
    test('reads the ids the Edge Function sends', () {
      final message = PushMessage.fromData({'notification_id': 'n1', 'booking_id': ' b1 ', 'kind': 'booking_request'});
      expect(message.notificationId, 'n1');
      expect(message.bookingId, 'b1');
      expect(message.kind, 'booking_request');
    });

    test('treats blank or missing values as absent', () {
      final message = PushMessage.fromData({'booking_id': '', 'notification_id': 3});
      expect(message.bookingId, isNull);
      expect(message.notificationId, isNull);
    });
  });

  group('PushNotificationsController', () {
    test('already allowed: turns on and registers this phone', () async {
      final push = FakePushMessaging(currentPermission: PushPermission.granted);
      final tokens = _FakeTokens();
      final container = await _container(push: push, tokens: tokens);

      expect(await _status(container), PushStatus.on);
      expect(tokens.registered, [push.currentToken]);
      expect(push.permissionRequests, 0);
    });

    test('not allowed yet: off until turned on, then asks and registers', () async {
      final push = FakePushMessaging();
      final tokens = _FakeTokens();
      final container = await _container(push: push, tokens: tokens);

      expect(await _status(container), PushStatus.off);
      expect(tokens.registered, isEmpty);

      await container.read(pushNotificationsProvider.notifier).enable();
      await Future<void>.delayed(Duration.zero);

      expect(push.permissionRequests, 1);
      expect(container.read(pushNotificationsProvider).value, PushStatus.on);
      expect(tokens.registered, [push.currentToken]);
    });

    test('a refusal with no prompt shown counts as blocked', () async {
      final push = FakePushMessaging(answer: PushPermission.canAsk);
      final container = await _container(push: push);
      await _status(container);

      await container.read(pushNotificationsProvider.notifier).enable();

      expect(container.read(pushNotificationsProvider).value, PushStatus.blocked);
    });

    test('blocked: turning on opens the system settings instead of asking', () async {
      final push = FakePushMessaging(currentPermission: PushPermission.blocked);
      final system = _FakeSystem();
      final container = await _container(push: push, system: system);

      expect(await _status(container), PushStatus.blocked);
      await container.read(pushNotificationsProvider.notifier).enable();

      expect(system.settingsOpened, 1);
      expect(push.permissionRequests, 0);
    });

    test('allowing in system settings is picked up on refresh', () async {
      final push = FakePushMessaging(currentPermission: PushPermission.blocked);
      final tokens = _FakeTokens();
      final container = await _container(push: push, tokens: tokens);
      expect(await _status(container), PushStatus.blocked);

      push.currentPermission = PushPermission.granted;
      await container.read(pushNotificationsProvider.notifier).refresh();
      await Future<void>.delayed(Duration.zero);

      expect(container.read(pushNotificationsProvider).value, PushStatus.on);
      expect(tokens.registered, [push.currentToken]);
    });

    test('turning off pauses this phone and unlinks it; turning on links it again', () async {
      final push = FakePushMessaging(currentPermission: PushPermission.granted);
      final tokens = _FakeTokens();
      final container = await _container(push: push, tokens: tokens);
      await _status(container);

      await container.read(pushNotificationsProvider.notifier).disable();
      expect(container.read(pushNotificationsProvider).value, PushStatus.paused);
      expect(tokens.unregistered, [push.currentToken]);

      // Stays paused across refreshes (e.g. coming back to the app).
      await container.read(pushNotificationsProvider.notifier).refresh();
      expect(container.read(pushNotificationsProvider).value, PushStatus.paused);

      await container.read(pushNotificationsProvider.notifier).enable();
      await Future<void>.delayed(Duration.zero);
      expect(container.read(pushNotificationsProvider).value, PushStatus.on);
      expect(tokens.registered.last, push.currentToken);
    });

    test('a refreshed token is registered', () async {
      final push = FakePushMessaging(currentPermission: PushPermission.granted);
      final tokens = _FakeTokens();
      final container = await _container(push: push, tokens: tokens);
      await _status(container);

      push.refreshes.add('rotated-token-0123456789abcdefghijklmnopqrstuvwxyz');
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(tokens.registered.last, 'rotated-token-0123456789abcdefghijklmnopqrstuvwxyz');
    });

    test('unsupported platforms do nothing', () async {
      final push = FakePushMessaging(isSupported: false, currentPermission: PushPermission.granted);
      final tokens = _FakeTokens();
      final container = await _container(push: push, tokens: tokens);

      expect(await _status(container), PushStatus.unsupported);
      await container.read(pushNotificationsProvider.notifier).enable();
      expect(push.permissionRequests, 0);
      expect(tokens.registered, isEmpty);
    });
  });

  group('signing out', () {
    test('unlinks this phone before signing out', () async {
      final push = FakePushMessaging(currentPermission: PushPermission.granted);
      final tokens = _FakeTokens();
      final auth = _MockAuthRepository();
      final token = push.currentToken;
      when(() => auth.signOut()).thenAnswer((_) async {
        // The device must already be unlinked while the session is valid.
        expect(tokens.unregistered, [token]);
      });
      final container = await _container(push: push, tokens: tokens, auth: auth);
      await _status(container);

      await container.read(sessionActionsProvider).signOut();

      verify(() => auth.signOut()).called(1);
      expect(push.tokenDeletions, 1);
    });
  });

  group('PushToggleModel', () {
    test('describes every status', () {
      expect(PushToggleModel.of(PushStatus.on).value, isTrue);
      expect(PushToggleModel.of(PushStatus.off).value, isFalse);
      expect(PushToggleModel.of(PushStatus.blocked).opensSettings, isTrue);
      expect(PushToggleModel.of(PushStatus.unsupported).enabled, isFalse);
      expect(PushToggleModel.of(null).enabled, isFalse);
    });
  });
}
