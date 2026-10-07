/// Booking times are always shown in the provider's time zone (Gold Coast for
/// every provider at launch), never the device's: a client planning from
/// Sydney during daylight saving, or a developer testing from India, must see
/// the same 9:30 am the provider sees.
///
/// The server sends every booking and slot time twice: as an instant
/// (`starts_at`, UTC) and as the provider-local wall clock (`starts_at_local`,
/// or `local_date` + `local_time` for slots). Wall-clock values are held as
/// UTC [DateTime]s purely so no device time zone is ever applied to them:
/// read their date/time fields, never convert them.
abstract final class BookingTime {
  /// Every provider's zone at launch: AEST, UTC+10 all year (Queensland has
  /// no daylight saving).
  static const String defaultTimeZone = 'Australia/Brisbane';

  /// UTC offsets of zones that never observe daylight saving, so "now" in the
  /// provider's zone can be worked out without a time zone database.
  static const Map<String, Duration> _fixedOffsets = {
    'Australia/Brisbane': Duration(hours: 10),
    'Australia/Lindeman': Duration(hours: 10),
    'Australia/Darwin': Duration(hours: 9, minutes: 30),
    'Australia/Perth': Duration(hours: 8),
  };

  /// Parses a Postgres `timestamp without time zone`, e.g.
  /// `2026-10-08T09:30:00`, as a wall-clock value.
  static DateTime parseWallClock(String value) {
    final parsed = DateTime.parse(value.endsWith('Z') ? value : '${value}Z');
    return DateTime.utc(parsed.year, parsed.month, parsed.day, parsed.hour, parsed.minute, parsed.second);
  }

  /// Combines a `date` (`2026-10-08`) and `time` (`09:30:00`) column pair.
  static DateTime wallClockFrom(String date, String time) => parseWallClock('${date}T$time');

  /// Midnight of [wallClock]'s day.
  static DateTime dateOf(DateTime wallClock) => DateTime.utc(wallClock.year, wallClock.month, wallClock.day);

  /// `YYYY-MM-DD`, as Postgres `date` parameters expect.
  static String isoDate(DateTime wallDate) =>
      '${wallDate.year.toString().padLeft(4, '0')}-${wallDate.month.toString().padLeft(2, '0')}'
      '-${wallDate.day.toString().padLeft(2, '0')}';

  /// The wall clock in [timeZone] right now.
  ///
  /// Exact for zones without daylight saving (all launch providers). For any
  /// other zone it falls back to the device's own wall clock; the server still
  /// enforces the real rules (minimum notice, booking window) either way.
  static DateTime nowIn(String timeZone, {DateTime? now}) {
    final instant = (now ?? DateTime.now()).toUtc();
    final offset = _fixedOffsets[timeZone];
    final local = offset == null ? instant.toLocal() : instant.add(offset);
    return DateTime.utc(local.year, local.month, local.day, local.hour, local.minute, local.second);
  }

  /// Today's date in [timeZone].
  static DateTime todayIn(String timeZone, {DateTime? now}) => dateOf(nowIn(timeZone, now: now));

  /// The wall clock in [timeZone] at [instant] (same caveat as [nowIn]).
  static DateTime wallClockOf(DateTime instant, String timeZone) => nowIn(timeZone, now: instant);

  /// The instant a [wallClock] in [timeZone] refers to: exact for zones
  /// without daylight saving, otherwise the device's zone stands in.
  static DateTime instantOf(DateTime wallClock, String timeZone) {
    final offset = _fixedOffsets[timeZone];
    if (offset == null) {
      return DateTime(wallClock.year, wallClock.month, wallClock.day, wallClock.hour, wallClock.minute).toUtc();
    }
    return DateTime.utc(wallClock.year, wallClock.month, wallClock.day, wallClock.hour, wallClock.minute)
        .subtract(offset);
  }

  /// How far [wallClock] is ahead of the UTC [instant] it represents.
  static Duration offsetBetween(DateTime instant, DateTime wallClock) => wallClock.difference(instant.toUtc());

  /// Short name for an Australian zone at [offset] (`AEST`, `AEDT`, `ACST`…),
  /// or `UTC+10:00` style elsewhere.
  static String abbreviation(String timeZone, Duration offset) {
    if (timeZone.startsWith('Australia/')) {
      switch (offset.inMinutes) {
        case 600:
          return 'AEST';
        case 660:
          return 'AEDT';
        case 570:
          return 'ACST';
        case 630:
          return 'ACDT';
        case 480:
          return 'AWST';
      }
    }
    final sign = offset.isNegative ? '-' : '+';
    final minutes = offset.inMinutes.abs();
    return 'UTC$sign${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';
  }

  /// Plain-English zone name for captions: `Gold Coast time (AEST)`.
  static String label(String timeZone, {Duration? offset}) {
    final known = offset ?? _fixedOffsets[timeZone];
    final abbrev = known == null ? null : abbreviation(timeZone, known);
    final place = switch (timeZone) {
      'Australia/Brisbane' => 'Gold Coast',
      _ => timeZone.split('/').last.replaceAll('_', ' '),
    };
    return abbrev == null ? '$place time' : '$place time ($abbrev)';
  }
}
