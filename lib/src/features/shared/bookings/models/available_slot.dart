import 'booking_time.dart';

/// Part of the day a slot falls in, for grouping the time grid.
enum SlotPeriod {
  morning('Morning'),
  afternoon('Afternoon'),
  evening('Evening');

  const SlotPeriod(this.label);

  final String label;

  static SlotPeriod of(DateTime wallClock) {
    if (wallClock.hour < 12) return morning;
    if (wallClock.hour < 17) return afternoon;
    return evening;
  }
}

/// A bookable start time, from `get_available_slots`.
class AvailableSlot {
  const AvailableSlot({required this.startsAt, required this.local});

  /// The instant (UTC) to book.
  final DateTime startsAt;

  /// The same moment on the provider's wall clock.
  final DateTime local;

  factory AvailableSlot.fromJson(Map<String, dynamic> json) => AvailableSlot(
        startsAt: DateTime.parse(json['starts_at'] as String).toUtc(),
        local: BookingTime.wallClockFrom(json['local_date'] as String, json['local_time'] as String),
      );

  /// Provider-local day of the slot (midnight).
  DateTime get day => BookingTime.dateOf(local);

  SlotPeriod get period => SlotPeriod.of(local);

  /// Wall-clock end for an appointment of [minutes].
  DateTime localEnd(int minutes) => local.add(Duration(minutes: minutes));

  Duration get utcOffset => BookingTime.offsetBetween(startsAt, local);

  @override
  bool operator ==(Object other) => other is AvailableSlot && other.startsAt == startsAt;

  @override
  int get hashCode => startsAt.hashCode;

  @override
  String toString() => 'AvailableSlot($local)';
}

/// Available slots indexed by provider-local day.
class SlotCalendar {
  SlotCalendar._(this._byDay);

  factory SlotCalendar(Iterable<AvailableSlot> slots) {
    final byDay = <DateTime, List<AvailableSlot>>{};
    for (final slot in slots) {
      byDay.putIfAbsent(slot.day, () => []).add(slot);
    }
    for (final day in byDay.values) {
      day.sort((a, b) => a.startsAt.compareTo(b.startsAt));
    }
    return SlotCalendar._(byDay);
  }

  static final SlotCalendar empty = SlotCalendar._(const {});

  final Map<DateTime, List<AvailableSlot>> _byDay;

  bool get isEmpty => _byDay.isEmpty;

  /// Days with at least one slot, earliest first.
  List<DateTime> get days => _byDay.keys.toList()..sort();

  List<AvailableSlot> on(DateTime day) => _byDay[BookingTime.dateOf(day)] ?? const [];

  bool hasSlotsOn(DateTime day) => _byDay.containsKey(BookingTime.dateOf(day));

  /// Whether [slot] is still offered.
  bool contains(AvailableSlot slot) => on(slot.day).contains(slot);

  /// The first day on or after [from] that has slots.
  DateTime? firstDayFrom(DateTime from) {
    final start = BookingTime.dateOf(from);
    for (final day in days) {
      if (!day.isBefore(start)) return day;
    }
    return null;
  }

  /// [slots] of one day grouped by part of the day, in order.
  static Map<SlotPeriod, List<AvailableSlot>> byPeriod(List<AvailableSlot> slots) {
    final grouped = <SlotPeriod, List<AvailableSlot>>{};
    for (final slot in slots) {
      grouped.putIfAbsent(slot.period, () => []).add(slot);
    }
    return {for (final period in SlotPeriod.values) period: ?grouped[period]};
  }
}
