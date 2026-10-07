import 'package:flutter_test/flutter_test.dart';
import 'package:myglo/src/features/customers/booking/models/empty_day_reason.dart';
import 'package:myglo/src/features/shared/bookings/models/booking_settings.dart';
import 'package:myglo/src/features/shared/bookings/models/working_hours.dart';

/// Wednesday 7 October 2026, provider-local midnight.
final _wednesday = DateTime.utc(2026, 10, 7);
final _thursday = DateTime.utc(2026, 10, 8);

/// Mon–Fri 9:00 am – 5:00 pm.
final _weekdays = WeeklySchedule([
  for (var day = 1; day <= 5; day++) WorkingHoursRange(weekday: day, opensMinutes: 9 * 60, closesMinutes: 17 * 60),
]);

const _settings = ProviderBookingSettings(providerId: 'prov-1', slotIntervalMinutes: 30, minNoticeMinutes: 120);

EmptyDayReason _explain({
  DateTime? day,
  required DateTime now,
  WeeklySchedule? hours,
  bool hoursLoaded = true,
  ProviderBookingSettings settings = _settings,
  int duration = 30,
}) => EmptyDayReason.explain(
  day: day ?? _wednesday,
  now: now,
  hours: hoursLoaded ? hours ?? _weekdays : null,
  settings: settings,
  durationMinutes: duration,
);

void main() {
  test('falls back to the general message while hours are loading', () {
    final reason = _explain(now: DateTime.utc(2026, 10, 7, 10), hoursLoaded: false);
    expect(reason.title, 'No times on Wednesday');
    expect(reason.message, 'This day is fully booked or the provider is closed.');
  });

  test('a weekday the provider never opens', () {
    final reason = _explain(day: DateTime.utc(2026, 10, 10), now: DateTime.utc(2026, 10, 7, 10));
    expect(reason.title, 'Closed on Saturdays');
    expect(reason.message, "This provider doesn't open on Saturdays.");
  });

  test('services longer than any opening range', () {
    final reason = _explain(now: DateTime.utc(2026, 10, 7, 8), duration: 9 * 60);
    expect(reason.title, 'Not enough time on Wednesday');
    expect(reason.message, contains('too short for 9 hr of services'));
  });

  test('after closing time today, with the provider clock', () {
    final reason = _explain(now: DateTime.utc(2026, 10, 7, 18, 56));
    expect(reason.title, 'Closed for the rest of today');
    expect(reason.message, "It's 6:56 pm Gold Coast time (AEST), after today's closing time of 5:00 pm.");
  });

  test('before closing, but the remaining times fall inside the notice period', () {
    // The last 30 min start is 4:30 pm; with 2 hr notice it closed at 2:30 pm.
    final reason = _explain(now: DateTime.utc(2026, 10, 7, 14, 31));
    expect(reason.title, 'Too late to book today');
    expect(
      reason.message,
      'This provider needs at least 2 hr notice. The latest start that fits your services today is 4:30 pm, '
      "and it's 2:31 pm Gold Coast time (AEST) now.",
    );
  });

  test('the latest start follows the slot interval, not just closing minus duration', () {
    // 45 min from 9:00 in 30 min steps: 4:00 pm is the last start, not 4:15.
    final reason = _explain(
      now: DateTime.utc(2026, 10, 7, 16, 5),
      settings: _settings.copyWith(minNoticeMinutes: 0),
      duration: 45,
    );
    expect(reason.title, 'Too late to book today');
    expect(
      reason.message,
      "The latest start that fits your services today is 4:00 pm, and it's 4:05 pm Gold Coast time (AEST) now.",
    );
  });

  test('a long notice period can rule out a future day too', () {
    final reason = _explain(
      day: _thursday,
      now: DateTime.utc(2026, 10, 7, 12),
      settings: _settings.copyWith(minNoticeMinutes: 48 * 60),
    );
    expect(reason.title, 'Too soon to book Thursday');
    expect(reason.message, startsWith('This provider needs at least 48 hr notice. '));
    expect(reason.message, contains('on Thursday is 4:30 pm'));
  });

  test('a day that is open and outside the notice period is fully booked', () {
    final today = _explain(now: DateTime.utc(2026, 10, 7, 10));
    expect(today.title, 'Fully booked on Wednesday');
    expect(_explain(day: _thursday, now: DateTime.utc(2026, 10, 7, 18, 56)).title, 'Fully booked on Thursday');
  });

  test('uses the latest range on a split day', () {
    final split = WeeklySchedule(const [
      WorkingHoursRange(weekday: 3, opensMinutes: 9 * 60, closesMinutes: 12 * 60),
      WorkingHoursRange(weekday: 3, opensMinutes: 13 * 60, closesMinutes: 15 * 60),
    ]);
    // 12:45 pm, in the lunch gap: 2 hr notice passes the 2:30 pm last start.
    final reason = _explain(now: DateTime.utc(2026, 10, 7, 12, 45), hours: split);
    expect(reason.title, 'Too late to book today');
    expect(reason.message, contains('today is 2:30 pm'));
  });
}
