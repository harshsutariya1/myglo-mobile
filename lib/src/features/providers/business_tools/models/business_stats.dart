import '../../../shared/bookings/models/booking_time.dart';

/// The signed-in provider's business overview, as computed by the
/// `get_provider_business_stats` RPC.
///
/// "This month" and "last month" are the provider's calendar months in their
/// own time zone, and a booking belongs to the month its appointment starts
/// in.
class BusinessStats {
  const BusinessStats({
    required this.periodStart,
    required this.timeZone,
    required this.completedBookings,
    required this.cashCollectedCents,
    this.cardEarnedCents = 0,
    this.previousCompletedBookings = 0,
    this.previousEarnedCents = 0,
    this.upcomingWeekBookings = 0,
    this.pendingRequests = 0,
    this.nextReplyBy,
    this.reviewsAwaitingReply = 0,
    this.onItsWayCents = 0,
  });

  /// First day of the month, as a provider-local wall-clock date (see
  /// [BookingTime]): read its fields, never convert it.
  final DateTime periodStart;

  final String timeZone;

  /// Appointments this month marked completed.
  final int completedBookings;

  /// Cash recorded as paid for this month's appointments, in AUD cents.
  final int cashCollectedCents;

  /// This month's card bookings after Myglo's fee, in AUD cents, counted as
  /// on the Financials screen (paid out or still on its way).
  final int cardEarnedCents;

  /// Last month's completed appointments.
  final int previousCompletedBookings;

  /// Last month's earnings (cash plus card after Myglo's fee), in AUD cents.
  final int previousEarnedCents;

  /// Confirmed appointments starting in the next seven days.
  final int upcomingWeekBookings;

  /// Requests waiting for the provider's answer.
  final int pendingRequests;

  /// The earliest reply deadline among [pendingRequests] (an instant), or
  /// null when nothing is waiting.
  final DateTime? nextReplyBy;

  /// Reviews of the provider without a public reply.
  final int reviewsAwaitingReply;

  /// Card shares not yet transferred to the provider's Stripe balance, in
  /// AUD cents (including any on hold).
  final int onItsWayCents;

  /// Everything earned this month: cash plus card after Myglo's fee.
  int get earnedCents => cashCollectedCents + cardEarnedCents;

  /// The first day of last month, as a provider-local wall-clock date.
  DateTime get previousPeriodStart => DateTime.utc(periodStart.year, periodStart.month - 1);

  /// [nextReplyBy] on the provider's wall clock.
  DateTime? get nextReplyByLocal => nextReplyBy == null ? null : BookingTime.wallClockOf(nextReplyBy!, timeZone);

  static int _int(Object? value) => (value as num? ?? 0).toInt();

  factory BusinessStats.fromJson(Map<String, dynamic> json) => BusinessStats(
        periodStart: BookingTime.parseWallClock('${json['period_start'] as String}T00:00:00'),
        timeZone: json['time_zone'] as String? ?? BookingTime.defaultTimeZone,
        completedBookings: _int(json['completed_bookings']),
        cashCollectedCents: _int(json['cash_collected_cents']),
        cardEarnedCents: _int(json['card_earned_cents']),
        previousCompletedBookings: _int(json['previous_completed_bookings']),
        previousEarnedCents: _int(json['previous_earned_cents']),
        upcomingWeekBookings: _int(json['upcoming_week_bookings']),
        pendingRequests: _int(json['pending_requests']),
        nextReplyBy: switch (json['next_reply_by']) {
          final String value => DateTime.parse(value).toUtc(),
          _ => null,
        },
        reviewsAwaitingReply: _int(json['reviews_awaiting_reply']),
        onItsWayCents: _int(json['on_its_way_cents']),
      );
}
