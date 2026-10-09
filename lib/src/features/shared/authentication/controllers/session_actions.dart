import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/app_logger.dart';
import '../../notifications/push/push_notifications_controller.dart';
import '../models/auth_repository.dart';

final sessionActionsProvider = Provider<SessionActions>(SessionActions.new);

/// Session-wide actions that touch more than authentication.
class SessionActions {
  SessionActions(this._ref);

  final Ref _ref;

  static const Duration _unlinkTimeout = Duration(seconds: 6);

  /// Unlinks this device from push notifications (while still signed in, so
  /// the server accepts it), then signs out. A failed unlink never blocks
  /// signing out.
  Future<void> signOut() async {
    try {
      await _ref.read(pushNotificationsProvider.notifier).unregisterForSignOut().timeout(_unlinkTimeout);
    } catch (e, st) {
      AppLogger.w('Push unlink before sign-out did not finish', tag: 'Session', error: e, stackTrace: st);
    }
    await _ref.read(authRepositoryProvider).signOut();
  }
}
