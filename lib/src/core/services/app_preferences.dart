import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/app_logger.dart';

/// Device-local preferences, loaded once before the app starts (see
/// `initializeApp`) so they can be read synchronously, e.g. by the router.
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('sharedPreferencesProvider must be overridden with a loaded instance');
});

/// Whether this device has already been through the intro slides. Once true
/// the slides are never shown again: signed-out users go straight to sign-in.
final introSeenProvider = NotifierProvider<IntroSeenController, bool>(IntroSeenController.new);

class IntroSeenController extends Notifier<bool> {
  static const storageKey = 'intro_seen';

  @override
  bool build() => ref.watch(sharedPreferencesProvider).getBool(storageKey) ?? false;

  /// Remembers that the intro has been seen. Safe to call repeatedly.
  Future<void> markSeen() async {
    if (state) return;
    state = true;
    try {
      await ref.read(sharedPreferencesProvider).setBool(storageKey, true);
    } catch (e, st) {
      // The flag still holds for this session; worst case the slides show
      // once more after a restart.
      AppLogger.e('Failed to save the intro-seen flag', tag: 'AppPreferences', error: e, stackTrace: st);
    }
  }
}
