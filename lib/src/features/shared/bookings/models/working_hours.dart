import '../../../../core/utils/formatters.dart';

/// One opening range on a weekday, in the provider's local time.
class WorkingHoursRange {
  const WorkingHoursRange({required this.weekday, required this.opensMinutes, required this.closesMinutes});

  /// ISO weekday: 1 = Monday … 7 = Sunday.
  final int weekday;

  /// Minutes after midnight. [closesMinutes] may be 1440 (midnight).
  final int opensMinutes;
  final int closesMinutes;

  factory WorkingHoursRange.fromJson(Map<String, dynamic> json) => WorkingHoursRange(
        weekday: (json['weekday'] as num).toInt(),
        opensMinutes: _parseTime(json['opens_at'] as String),
        closesMinutes: _parseTime(json['closes_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'weekday': weekday,
        'opens_at': formatTime24(opensMinutes),
        'closes_at': formatTime24(closesMinutes),
      };

  bool get isValid => opensMinutes >= 0 && closesMinutes <= 1440 && closesMinutes > opensMinutes;

  bool overlaps(WorkingHoursRange other) =>
      other.weekday == weekday && opensMinutes < other.closesMinutes && other.opensMinutes < closesMinutes;

  /// `9:00 am – 5:00 pm`.
  String get label => '${formatMinutes(opensMinutes)} – ${formatMinutes(closesMinutes)}';

  WorkingHoursRange copyWith({int? opensMinutes, int? closesMinutes}) => WorkingHoursRange(
        weekday: weekday,
        opensMinutes: opensMinutes ?? this.opensMinutes,
        closesMinutes: closesMinutes ?? this.closesMinutes,
      );

  static int _parseTime(String value) {
    final parts = value.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }

  /// `09:00`, or `24:00` for midnight at the end of the day.
  static String formatTime24(int minutes) =>
      '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';

  /// `9:00 am`, with `12:00 am` for midnight.
  static String formatMinutes(int minutes) =>
      Formatters.time(DateTime.utc(2000, 1, 1).add(Duration(minutes: minutes % 1440)));

  @override
  bool operator ==(Object other) =>
      other is WorkingHoursRange &&
      other.weekday == weekday &&
      other.opensMinutes == opensMinutes &&
      other.closesMinutes == closesMinutes;

  @override
  int get hashCode => Object.hash(weekday, opensMinutes, closesMinutes);
}

/// A provider's whole week of opening hours.
class WeeklySchedule {
  WeeklySchedule(Iterable<WorkingHoursRange> ranges)
      : ranges = List.unmodifiable(
          [...ranges]..sort((a, b) => a.weekday != b.weekday ? a.weekday - b.weekday : a.opensMinutes - b.opensMinutes),
        );

  final List<WorkingHoursRange> ranges;

  static const int maxRangesPerDay = 3;

  bool get isEmpty => ranges.isEmpty;

  List<WorkingHoursRange> on(int weekday) => [for (final range in ranges) if (range.weekday == weekday) range];

  bool isOpenOn(int weekday) => ranges.any((range) => range.weekday == weekday);

  /// Why the schedule can't be saved, or null when it's valid.
  String? get validationError {
    for (var weekday = 1; weekday <= 7; weekday++) {
      final day = on(weekday);
      if (day.length > maxRangesPerDay) return 'Use at most $maxRangesPerDay time ranges per day.';
      for (var i = 0; i < day.length; i++) {
        if (!day[i].isValid) return '${_weekdayName(weekday)}: each range must end after it starts.';
        for (var j = i + 1; j < day.length; j++) {
          if (day[i].overlaps(day[j])) return '${_weekdayName(weekday)}: two time ranges overlap.';
        }
      }
    }
    return null;
  }

  List<Map<String, dynamic>> toJson() => [for (final range in ranges) range.toJson()];

  /// One line for settings: `Mon–Fri · 9:00 am – 5:00 pm`, or just the days
  /// (`Mon–Wed, Sat`) when hours differ between them. Null when closed all
  /// week.
  String? get summary {
    final openDays = [for (var day = 1; day <= 7; day++) if (isOpenOn(day)) day];
    if (openDays.isEmpty) return null;
    final days = openDays.length == 7 ? 'Every day' : _dayRuns(openDays);
    final first = on(openDays.first);
    final sameHours = openDays.every((day) {
      final ranges = on(day);
      if (ranges.length != first.length) return false;
      for (var i = 0; i < ranges.length; i++) {
        if (ranges[i].opensMinutes != first[i].opensMinutes || ranges[i].closesMinutes != first[i].closesMinutes) {
          return false;
        }
      }
      return true;
    });
    if (!sameHours) return days;
    return '$days · ${first.map((range) => range.label).join(', ')}';
  }

  /// `Mon–Fri`, `Mon, Wed, Fri`, `Mon–Wed, Sat, Sun` (two-day runs are listed).
  static String _dayRuns(List<int> weekdays) {
    String short(int weekday) => Formatters.weekdayShort(DateTime.utc(2024, 1, weekday));
    final runs = <String>[];
    var start = weekdays.first;
    var previous = start;
    void close() => runs.add(
          start == previous
              ? short(start)
              : previous == start + 1
                  ? '${short(start)}, ${short(previous)}'
                  : '${short(start)}–${short(previous)}',
        );
    for (final day in weekdays.skip(1)) {
      if (day == previous + 1) {
        previous = day;
        continue;
      }
      close();
      start = previous = day;
    }
    close();
    return runs.join(', ');
  }

  static String _weekdayName(int weekday) => Formatters.weekdayLong(DateTime.utc(2024, 1, weekday));
}
