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

  /// Formats a distance in kilometres: `850 m`, `4.2 km`, `18 km`.
  static String distanceKm(double km) {
    if (km < 1) return '${math.max(1, (km * 1000).round())} m';
    if (km < 10) return '${km.toStringAsFixed(1)} km';
    return '${km.round()} km';
  }
}
