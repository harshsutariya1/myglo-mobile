import 'dart:math' as math;

/// Display formatting shared across features.
///
/// Kept dependency-free (no `intl`) and deterministic so it can be unit
/// tested without a locale setup.
class Formatters {
  Formatters._();

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  static const _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  static const _weekdayNames = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday',
  ];

  /// Formats an AUD amount the Australian way: `$45`, `$45.50`, `$1,250`.
  ///
  /// Whole-dollar amounts drop the cents; everything else shows two decimals.
  static String aud(num amount) {
    final cents = (amount * 100).round();
    final negative = cents < 0;
    final absCents = cents.abs();
    final dollars = absCents ~/ 100;
    final remainder = absCents % 100;

    final digits = dollars.toString();
    final grouped = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) grouped.write(',');
      grouped.write(digits[i]);
    }

    final centsPart = remainder == 0 ? '' : '.${remainder.toString().padLeft(2, '0')}';
    return '${negative ? '-' : ''}\$$grouped$centsPart';
  }

  /// Formats a service length: `45 min`, `1 hr`, `1 hr 30 min`.
  static String duration(int minutes) {
    if (minutes <= 0) return '0 min';
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (hours == 0) return '$mins min';
    return mins == 0 ? '$hours hr' : '$hours hr $mins min';
  }

  /// Formats [time] relative to [now]: `Just now`, `5m ago`, `3h ago`,
  /// `2d ago`, then a date such as `12 Sep` (or `12 Sep 2025` in another year).
  ///
  /// Both instants are compared as absolute moments, and the calendar date is
  /// rendered in the device's local time zone.
  static String relativeTime(DateTime time, {DateTime? now}) {
    final reference = now ?? DateTime.now();
    final diff = reference.difference(time);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';

    final local = time.toLocal();
    final label = '${local.day} ${_months[local.month - 1]}';
    return local.year == reference.toLocal().year ? label : '$label ${local.year}';
  }

  /// Formats an engagement count compactly: `7`, `999`, `1.2k`, `12k`, `3.4M`.
  ///
  /// Values are truncated rather than rounded so a count never reads higher
  /// than it is (1,999 shows as `1.9k`, not `2k`).
  static String compactCount(int count) {
    if (count < 1000) return '${math.max(0, count)}';
    String scaled(int unit, String suffix) {
      final tenths = count * 10 ~/ unit;
      final whole = tenths ~/ 10;
      final decimal = tenths % 10;
      return whole >= 10 || decimal == 0 ? '$whole$suffix' : '$whole.$decimal$suffix';
    }

    return count < 1000000 ? scaled(1000, 'k') : scaled(1000000, 'M');
  }

  /// Formats a distance in kilometres: `850 m`, `4.2 km`, `18 km`.
  static String distanceKm(double km) {
    if (km < 1) return '${math.max(1, (km * 1000).round())} m';
    if (km < 10) return '${km.toStringAsFixed(1)} km';
    return '${km.round()} km';
  }

  /// Formats an AUD amount held in whole cents, like [aud].
  static String audCents(int cents) => aud(cents / 100);

  // The calendar helpers below read only the date/time *fields* of the value
  // they're given and never convert time zones. Booking times are passed in
  // as provider-local wall-clock values (see `BookingTime`), so they print the
  // same on every device regardless of its time zone.

  /// Time of day the Australian way: `9:30 am`, `12:05 pm`.
  static String time(DateTime wallClock) {
    final hour12 = wallClock.hour % 12 == 0 ? 12 : wallClock.hour % 12;
    final minutes = wallClock.minute.toString().padLeft(2, '0');
    return '$hour12:$minutes ${wallClock.hour < 12 ? 'am' : 'pm'}';
  }

  /// `9:30 am – 11:00 am`.
  static String timeRange(DateTime start, DateTime end) => '${time(start)} – ${time(end)}';

  /// `Tue`.
  static String weekdayShort(DateTime date) => _weekdays[date.weekday - 1];

  /// `Tuesday`.
  static String weekdayLong(DateTime date) => _weekdayNames[date.weekday - 1];

  /// `Oct`.
  static String monthShort(DateTime date) => _months[date.month - 1];

  /// `October 2026`.
  static String monthYear(DateTime date) => '${_monthNames[date.month - 1]} ${date.year}';

  /// `Tue 7 Oct`.
  static String dateShort(DateTime date) => '${weekdayShort(date)} ${date.day} ${monthShort(date)}';

  /// `Tuesday 7 October`, with the year appended when it differs from
  /// [currentYear] (or always, when [withYear] is set).
  static String dateLong(DateTime date, {int? currentYear, bool withYear = false}) {
    final label = '${weekdayLong(date)} ${date.day} ${_monthNames[date.month - 1]}';
    final showYear = withYear || (currentYear != null && currentYear != date.year);
    return showYear ? '$label ${date.year}' : label;
  }

  /// `Tue 7 Oct, 9:30 am`.
  static String dateTimeShort(DateTime wallClock) => '${dateShort(wallClock)}, ${time(wallClock)}';
}
