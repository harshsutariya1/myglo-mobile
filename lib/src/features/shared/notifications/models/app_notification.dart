import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// What a notification is about. Mirrors `notifications.kind`.
enum NotificationKind {
  bookingRequest('booking_request', Icons.mark_email_unread_outlined),

  /// Provider reminder about a request they haven't answered yet.
  bookingRequestReminder('booking_request_reminder', Icons.pending_actions_rounded),
  bookingNew('booking_new', Icons.event_available_rounded),
  bookingRequested('booking_requested', Icons.outgoing_mail),
  bookingConfirmed('booking_confirmed', Icons.check_circle_outline_rounded),
  bookingDeclined('booking_declined', Icons.block_rounded),
  bookingCancelled('booking_cancelled', Icons.event_busy_rounded),
  bookingExpired('booking_expired', Icons.timer_off_outlined),
  bookingCompleted('booking_completed', Icons.favorite_border_rounded),
  bookingNoShow('booking_no_show', Icons.person_off_outlined),
  bookingReminder('booking_reminder', Icons.alarm_rounded),
  unknown('unknown', Icons.notifications_none_rounded);

  const NotificationKind(this.key, this.icon);

  final String key;
  final IconData icon;

  static NotificationKind fromKey(String? key) =>
      values.firstWhere((kind) => kind.key == key, orElse: () => unknown);

  Color color(ColorScheme scheme) => switch (this) {
        bookingNew || bookingConfirmed || bookingCompleted => AppTheme.success,
        bookingRequest || bookingRequestReminder || bookingRequested => AppTheme.warning,
        bookingDeclined || bookingCancelled || bookingNoShow => AppTheme.destructive,
        bookingReminder => scheme.primary,
        bookingExpired || unknown => scheme.onSurface.withValues(alpha: 0.55),
      };
}

/// One item in the in-app inbox (`notifications`).
class AppNotification {
  const AppNotification({
    required this.id,
    required this.recipientId,
    required this.kind,
    required this.title,
    required this.body,
    required this.createdAt,
    this.actorId,
    this.bookingId,
    this.readAt,
  });

  final String id;
  final String recipientId;

  /// Who caused it; null for the system (reminders, expiries).
  final String? actorId;
  final NotificationKind kind;
  final String title;
  final String body;
  final String? bookingId;
  final DateTime? readAt;
  final DateTime createdAt;

  bool get isRead => readAt != null;

  factory AppNotification.fromJson(Map<String, dynamic> json) => AppNotification(
        id: json['id'] as String,
        recipientId: json['recipient_id'] as String,
        actorId: json['actor_id'] as String?,
        kind: NotificationKind.fromKey(json['kind'] as String?),
        title: json['title'] as String? ?? '',
        body: json['body'] as String? ?? '',
        bookingId: json['booking_id'] as String?,
        readAt: json['read_at'] == null ? null : DateTime.parse(json['read_at'] as String),
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  AppNotification markedRead(DateTime at) => AppNotification(
        id: id,
        recipientId: recipientId,
        actorId: actorId,
        kind: kind,
        title: title,
        body: body,
        bookingId: bookingId,
        readAt: readAt ?? at,
        createdAt: createdAt,
      );
}
