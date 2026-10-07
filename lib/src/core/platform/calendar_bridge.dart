import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../utils/app_logger.dart';

/// An event to add to the device's calendar.
class CalendarEvent {
  const CalendarEvent({
    required this.title,
    required this.start,
    required this.end,
    this.location,
    this.notes,
    this.timeZone,
  });

  final String title;

  /// Instants; the calendar shows them in the device's time zone.
  final DateTime start;
  final DateTime end;
  final String? location;
  final String? notes;

  /// IANA zone the event belongs to, e.g. `Australia/Brisbane`.
  final String? timeZone;
}

/// What happened when the calendar sheet was shown.
enum CalendarAddResult {
  /// The user saved the event (iOS reports this).
  saved,

  /// The calendar app opened with the event filled in (Android can't report
  /// whether it was saved).
  opened,

  cancelled,

  /// Calendar access was refused (iOS 16 and earlier).
  denied,

  /// No calendar is available on this device.
  unavailable,
}

/// Adds events through the platform's own "new event" screen, so the user
/// reviews and saves it themselves. No package: see `MainActivity.kt` and
/// `AppDelegate.swift`.
abstract interface class CalendarBridge {
  Future<CalendarAddResult> addEvent(CalendarEvent event);
}

final calendarBridgeProvider = Provider<CalendarBridge>((ref) => const MethodChannelCalendarBridge());

class MethodChannelCalendarBridge implements CalendarBridge {
  const MethodChannelCalendarBridge();

  static const MethodChannel _channel = MethodChannel('app.myglo/calendar');

  @override
  Future<CalendarAddResult> addEvent(CalendarEvent event) async {
    try {
      final result = await _channel.invokeMethod<String>('addEvent', {
        'title': event.title,
        'startMillis': event.start.millisecondsSinceEpoch,
        'endMillis': event.end.millisecondsSinceEpoch,
        'location': event.location,
        'notes': event.notes,
        'timeZone': event.timeZone,
      });
      return switch (result) {
        'saved' => CalendarAddResult.saved,
        'opened' => CalendarAddResult.opened,
        'denied' => CalendarAddResult.denied,
        'cancelled' => CalendarAddResult.cancelled,
        _ => CalendarAddResult.unavailable,
      };
    } on PlatformException catch (e, st) {
      if (e.code == 'unavailable') return CalendarAddResult.unavailable;
      AppLogger.e('Adding to calendar failed', tag: 'CalendarBridge', error: e, stackTrace: st);
      return CalendarAddResult.unavailable;
    } on MissingPluginException {
      // Platforms without the bridge (tests, desktop).
      return CalendarAddResult.unavailable;
    }
  }
}
