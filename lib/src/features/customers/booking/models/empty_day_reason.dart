import 'dart:math' as math;

import '../../../../core/utils/formatters.dart';
import '../../../shared/bookings/models/booking_settings.dart';
import '../../../shared/bookings/models/booking_time.dart';
import '../../../shared/bookings/models/working_hours.dart';

/// Why a day the client picked has no bookable times, worked out from the
/// provider's hours and rules so the empty state can say more than "fully
/// booked or closed".
///
/// The server stays the source of truth for which times exist; this only
/// explains an empty day it already returned, mirroring how it generates
/// candidate starts (aligned to the slot interval from each opening time,
/// then filtered by minimum notice).
class EmptyDayReason {
  const EmptyDayReason({required this.title, required this.message});

  final String title;
  final String message;

  /// Explains why [day] (provider-local midnight) has no times for
  /// [durationMinutes] of services. [now] is the provider's wall clock
  /// (see [BookingTime.nowIn]); [hours] is null while still loading.
  factory EmptyDayReason.explain({
    required DateTime day,
    required DateTime now,
    required WeeklySchedule? hours,
    required ProviderBookingSettings settings,
    required int durationMinutes,
  }) {
    final weekday = Formatters.weekdayLong(day);
    final ranges = hours?.on(day.weekday);
    if (ranges == null) {
      return EmptyDayReason(
        title: 'No times on $weekday',
        message: 'This day is fully booked or the provider is closed.',
      );
    }
    if (ranges.isEmpty) {
      return EmptyDayReason(title: 'Closed on ${weekday}s', message: "This provider doesn't open on ${weekday}s.");
    }

    final interval = math.max(1, settings.slotIntervalMinutes);
    int? lastStart;
    for (final range in ranges) {
      final room = range.closesMinutes - range.opensMinutes - durationMinutes;
      if (room < 0) continue;
      lastStart = math.max(lastStart ?? 0, range.opensMinutes + room ~/ interval * interval);
    }
    if (lastStart == null) {
      return EmptyDayReason(
        title: 'Not enough time on $weekday',
        message:
            "This provider's opening hours on ${weekday}s are too short for "
            '${Formatters.duration(durationMinutes)} of services. Try fewer services or another day.',
      );
    }

    final isToday = day == BookingTime.dateOf(now);
    final clock = '${Formatters.time(now)} ${BookingTime.label(settings.timeZone)}';
    final lastClose = ranges.map((range) => range.closesMinutes).reduce(math.max);
    if (isToday && now.hour * 60 + now.minute >= lastClose) {
      return EmptyDayReason(
        title: 'Closed for the rest of today',
        message: "It's $clock, after today's closing time of ${WorkingHoursRange.formatMinutes(lastClose)}.",
      );
    }

    final lastStartLabel = WorkingHoursRange.formatMinutes(lastStart);
    final earliest = now.add(Duration(minutes: settings.minNoticeMinutes));
    if (day.add(Duration(minutes: lastStart)).isBefore(earliest)) {
      final when = isToday ? 'today' : 'on $weekday';
      final latest = 'The latest start that fits your services $when is $lastStartLabel';
      return EmptyDayReason(
        title: isToday ? 'Too late to book today' : 'Too soon to book $weekday',
        message: settings.minNoticeMinutes > 0
            ? 'This provider needs at least ${Formatters.duration(settings.minNoticeMinutes)} notice. '
                  "$latest, and it's $clock now."
            : "$latest, and it's $clock now.",
      );
    }

    return EmptyDayReason(
      title: 'Fully booked on $weekday',
      message: 'Every time that fits your services is booked or blocked out by the provider.',
    );
  }
}
