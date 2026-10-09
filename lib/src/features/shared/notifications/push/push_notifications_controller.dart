import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/platform/system_bridge.dart';
import '../../../../core/services/app_preferences.dart';
import '../../../../core/utils/app_logger.dart';
import '../../authentication/controllers/user_profile_provider.dart';
import 'push_messaging.dart';
import 'push_token_repository.dart';

/// Where push notifications stand on this device for the signed-in user.
enum PushStatus {
  /// This platform doesn't receive pushes yet (iOS until APNs is set up).
  unsupported,

  /// Allowed, and this device is registered for booking updates.
  on,

  /// Not allowed yet; turning them on shows the system prompt.
  off,

  /// The system blocks them; only the system settings can change that.
  blocked,

  /// Allowed by the system, but the user switched Myglo's pushes off.
  paused,
}

final pushNotificationsProvider =
    AsyncNotifierProvider<PushNotificationsController, PushStatus>(PushNotificationsController.new);

/// Registers this install for booking pushes while someone is signed in and
/// lets them turn pushes on or off. Kept alive by `PushNotificationHost`.
class PushNotificationsController extends AsyncNotifier<PushStatus> {
  static const _tag = 'PushNotifications';
  static const _optOutKeyPrefix = 'push_opt_out';

  /// Set when asking showed no prompt (Android 12 and older with
  /// notifications switched off): only the system settings can help then.
  static const _promptUnavailableKey = 'push_prompt_unavailable';

  /// A permission answer this quick means no prompt was shown.
  static const Duration _instantAnswer = Duration(milliseconds: 350);

  StreamSubscription<String>? _tokenRefreshes;
  String? _userId;
  String? _registeredToken;
  String? _registeredFor;

  PushMessaging get _messaging => ref.read(pushMessagingProvider);

  String? get _optOutKey => _userId == null ? null : '$_optOutKeyPrefix.$_userId';

  @override
  Future<PushStatus> build() async {
    final messaging = ref.watch(pushMessagingProvider);
    if (!messaging.isSupported) return PushStatus.unsupported;

    _userId = ref.watch(userProfileProvider.select((p) => p.value?.rawUser.id));
    await _tokenRefreshes?.cancel();
    _tokenRefreshes = null;
    ref.onDispose(() => _tokenRefreshes?.cancel());
    if (_userId != null) {
      _tokenRefreshes = messaging.tokenRefreshes.listen((token) => unawaited(_register(token: token)));
    }
    return _resolve();
  }

  /// Re-reads the system setting (e.g. after the user comes back from the
  /// settings app) and registers if pushes are now allowed.
  Future<void> refresh() async {
    if (state.value == PushStatus.unsupported) return;
    try {
      final status = await _resolve();
      if (ref.mounted) state = AsyncData(status);
    } catch (e, st) {
      AppLogger.w('Refreshing push status failed', tag: _tag, error: e, stackTrace: st);
    }
  }

  /// Turns pushes on: asks for permission if it still can, or opens the
  /// system settings when it's been blocked.
  Future<void> enable() async {
    final current = state.value;
    if (current == null || current == PushStatus.unsupported || current == PushStatus.on) return;
    if (current == PushStatus.blocked) {
      await ref.read(systemBridgeProvider).openNotificationSettings();
      return;
    }
    try {
      final key = _optOutKey;
      if (key != null) await _prefs.remove(key);
      final asked = DateTime.now();
      final permission = await _messaging.requestPermission();
      if (permission == PushPermission.canAsk && DateTime.now().difference(asked) < _instantAnswer) {
        await _prefs.setBool(_promptUnavailableKey, true);
      }
    } catch (e, st) {
      AppLogger.e('Turning on push notifications failed', tag: _tag, error: e, stackTrace: st);
    }
    if (ref.mounted) state = AsyncData(await _resolve());
  }

  /// Stops Myglo pushes on this device for this account. The system
  /// permission stays as it is.
  Future<void> disable() async {
    final key = _optOutKey;
    if (key == null || state.value == PushStatus.unsupported) return;
    await _prefs.setBool(key, true);
    await _unregister();
    if (ref.mounted) state = AsyncData(await _resolve());
  }

  /// Unlinks this device before signing out, so the next person to use it
  /// doesn't get the previous account's notifications. Never throws.
  Future<void> unregisterForSignOut() async {
    if (!_messaging.isSupported) return;
    await _unregister();
    await _messaging.deleteToken();
  }

  SharedPreferences get _prefs => ref.read(sharedPreferencesProvider);

  Future<PushStatus> _resolve() async {
    final permission = await _messaging.permission();
    switch (permission) {
      case PushPermission.granted:
        // Allowed again (e.g. in system settings): forget the old refusal.
        await _prefs.remove(_promptUnavailableKey);
        final key = _optOutKey;
        if (key != null && (_prefs.getBool(key) ?? false)) return PushStatus.paused;
        if (_userId != null) unawaited(_register());
        return PushStatus.on;
      case PushPermission.blocked:
        return PushStatus.blocked;
      case PushPermission.canAsk:
        return (_prefs.getBool(_promptUnavailableKey) ?? false) ? PushStatus.blocked : PushStatus.off;
    }
  }

  Future<void> _register({String? token}) async {
    final userId = _userId;
    if (userId == null) return;
    final key = _optOutKey;
    if (key != null && (_prefs.getBool(key) ?? false)) return;
    final value = token ?? await _messaging.token();
    if (value == null || (value == _registeredToken && userId == _registeredFor)) return;
    try {
      await ref.read(pushTokenRepositoryProvider).register(value, platform: 'android');
      _registeredToken = value;
      _registeredFor = userId;
    } catch (_) {
      // Already reported; the next launch, resume or token refresh retries.
    }
  }

  Future<void> _unregister() async {
    final token = _registeredToken ?? await _messaging.token();
    _registeredToken = null;
    _registeredFor = null;
    if (token == null) return;
    try {
      await ref.read(pushTokenRepositoryProvider).unregister(token).timeout(const Duration(seconds: 5));
    } catch (e) {
      // Already reported. The server also drops tokens FCM says are dead,
      // and re-assigns this one when someone else signs in here.
      AppLogger.w('Push token not removed: $e', tag: _tag);
    }
  }
}
