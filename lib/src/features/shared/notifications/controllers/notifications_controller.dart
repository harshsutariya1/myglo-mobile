import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/realtime/postgres_changes.dart';
import '../../../../core/utils/app_logger.dart';
import '../../authentication/controllers/user_profile_provider.dart';
import '../models/app_notification.dart';
import '../models/notifications_repository.dart';

/// The inbox: newest first.
class NotificationsState {
  const NotificationsState(this.items);

  static const NotificationsState empty = NotificationsState([]);

  final List<AppNotification> items;

  int get unreadCount => items.where((n) => !n.isRead).length;
}

/// The signed-in user's notifications, kept live over realtime for as long
/// as the app runs (the in-app banner host keeps this alive).
final notificationsProvider =
    AsyncNotifierProvider<NotificationsController, NotificationsState>(NotificationsController.new);

/// The latest notification that arrived while the app was open and that the
/// user didn't cause themselves; shown as a banner.
final notificationArrivalProvider =
    NotifierProvider<NotificationArrivalController, AppNotification?>(NotificationArrivalController.new);

class NotificationArrivalController extends Notifier<AppNotification?> {
  @override
  AppNotification? build() => null;

  void announce(AppNotification notification) => state = notification;

  void clear() => state = null;
}

class NotificationsController extends AsyncNotifier<NotificationsState> {
  StreamSubscription<RealtimeChange>? _subscription;
  String? _userId;

  NotificationsRepository get _repository => ref.read(notificationsRepositoryProvider);

  @override
  Future<NotificationsState> build() async {
    final userId = ref.watch(userProfileProvider.select((p) => p.value?.rawUser.id));
    _userId = userId;
    await _subscription?.cancel();
    _subscription = null;
    ref.onDispose(() => _subscription?.cancel());
    if (userId == null) return NotificationsState.empty;

    _subscription = _repository.watch(userId).listen(_onChange);
    return NotificationsState(await _repository.fetchLatest(userId));
  }

  void _onChange(RealtimeChange change) {
    final userId = _userId;
    final current = state.value;
    if (userId == null || current == null) return;
    if (change.isResync) {
      unawaited(_refresh(userId));
      return;
    }
    final payload = change.payload!;
    switch (payload.eventType) {
      case PostgresChangeEvent.insert:
        final notification = _parse(payload.newRecord);
        if (notification == null || current.items.any((n) => n.id == notification.id)) return;
        state = AsyncData(NotificationsState([notification, ...current.items]));
        if (!notification.isRead && notification.actorId != userId) {
          ref.read(notificationArrivalProvider.notifier).announce(notification);
        }
      case PostgresChangeEvent.update:
        final notification = _parse(payload.newRecord);
        if (notification == null) return;
        state = AsyncData(NotificationsState([
          for (final n in current.items) n.id == notification.id ? notification : n,
        ]));
      case PostgresChangeEvent.delete:
        final id = payload.oldRecord['id'];
        state = AsyncData(NotificationsState([for (final n in current.items) if (n.id != id) n]));
      case PostgresChangeEvent.all:
        break;
    }
  }

  AppNotification? _parse(Map<String, dynamic> record) {
    try {
      return AppNotification.fromJson(record);
    } catch (e, st) {
      AppLogger.e('Unreadable realtime notification', tag: 'Notifications', error: e, stackTrace: st);
      return null;
    }
  }

  Future<void> _refresh(String userId) async {
    try {
      final items = await _repository.fetchLatest(userId);
      if (ref.mounted && _userId == userId) state = AsyncData(NotificationsState(items));
    } catch (_) {
      // Already reported; keep what's on screen until the next change.
    }
  }

  /// Pull to refresh.
  Future<void> refresh() async {
    final userId = _userId;
    if (userId != null) await _refresh(userId);
  }

  /// Marks one notification read (optimistically).
  Future<void> markRead(String id) async {
    final current = state.value;
    if (current == null || current.items.every((n) => n.id != id || n.isRead)) return;
    final now = DateTime.now().toUtc();
    state = AsyncData(NotificationsState([for (final n in current.items) n.id == id ? n.markedRead(now) : n]));
    try {
      await _repository.markRead(ids: [id]);
    } catch (_) {
      // The badge corrects itself on the next refresh; nothing to undo here.
    }
  }

  /// Marks everything read (optimistically).
  Future<void> markAllRead() async {
    final current = state.value;
    if (current == null || current.unreadCount == 0) return;
    final now = DateTime.now().toUtc();
    state = AsyncData(NotificationsState([for (final n in current.items) n.markedRead(now)]));
    try {
      await _repository.markRead();
    } catch (_) {
      if (ref.mounted) state = AsyncData(current);
      rethrow;
    }
  }

  /// Removes a notification; restores it if the delete fails.
  Future<void> remove(String id) async {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(NotificationsState([for (final n in current.items) if (n.id != id) n]));
    try {
      await _repository.delete(id);
    } catch (_) {
      if (ref.mounted) state = AsyncData(current);
      rethrow;
    }
  }
}
