import '../../../shared/bookings/models/booking_time.dart';

/// The signed-in provider's numbers for the current month, as computed by
/// the `get_provider_business_stats` RPC.
///
/// "This month" is the provider's calendar month in their own time zone, and
/// a booking belongs to the month its appointment starts in.
class BusinessStats {
  const BusinessStats({
    required this.periodStart,
    required this.timeZone,
    required this.completedBookings,
    required this.cashCollectedCents,
  });

  /// First day of the month, as a provider-local wall-clock date (see
  /// [BookingTime]): read its fields, never convert it.
  final DateTime periodStart;

  final String timeZone;

  /// Appointments this month marked completed.
  final int completedBookings;

  /// Cash recorded as paid for this month's appointments, in AUD cents.
  final int cashCollectedCents;

  factory BusinessStats.fromJson(Map<String, dynamic> json) => BusinessStats(
        periodStart: BookingTime.parseWallClock('${json['period_start'] as String}T00:00:00'),
        timeZone: json['time_zone'] as String? ?? BookingTime.defaultTimeZone,
        completedBookings: (json['completed_bookings'] as num? ?? 0).toInt(),
        cashCollectedCents: (json['cash_collected_cents'] as num? ?? 0).toInt(),
      );
}
