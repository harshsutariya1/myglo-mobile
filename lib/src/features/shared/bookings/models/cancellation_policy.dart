import '../../../../core/utils/formatters.dart';

/// Plain-English wording of a provider's cancellation terms, shared by the
/// booking flow, booking details and settings so it always reads the same.
abstract final class CancellationPolicy {
  /// `24 hours`, `1 hour`, `2 days`.
  static String windowLabel(int hours) {
    if (hours % 24 == 0 && hours >= 48) return '${hours ~/ 24} days';
    return hours == 1 ? '1 hour' : '$hours hours';
  }

  /// One-line summary for settings and the booking flow.
  static String summary({required int windowHours, required int feePercent}) {
    if (windowHours <= 0) return 'Free cancellation any time before the appointment.';
    return '${headline(windowHours)}. ${lateTerms(feePercent)}';
  }

  /// `Free cancellation up to 24 hours before`, as a heading.
  static String headline(int windowHours) =>
      windowHours <= 0 ? 'Free cancellation any time' : 'Free cancellation up to ${windowLabel(windowHours)} before';

  /// What happens once free cancellation has ended.
  static String lateTerms(int feePercent) => feePercent > 0
      ? 'Later cancellations and no-shows are charged $feePercent% of the booking.'
      : 'Later cancellations are recorded as late.';

  /// What a provider's public profile says applies besides the free window.
  /// Cash bookings never have a fee. [inAppFeePercent] (the provider's
  /// late-cancellation / no-show fee) only applies to bookings paid in the
  /// app, so it's mentioned once [inAppPaymentsLive].
  static String profileTerms({
    required int windowHours,
    required int inAppFeePercent,
    required bool inAppPaymentsLive,
  }) {
    final cash = windowHours <= 0
        ? 'Cash bookings never have a cancellation fee.'
        : 'No fee on cash bookings; later cancellations are recorded as late.';
    if (!inAppPaymentsLive || inAppFeePercent <= 0) return cash;
    return '$cash Paid in the app: later cancellations and no-shows are charged $inAppFeePercent% of the booking.';
  }

  /// Terms for a specific booking, given when free cancellation ends
  /// (provider-local wall clock).
  static String forBooking({
    required DateTime freeUntilLocal,
    required int windowHours,
    required int feePercent,
    required int totalCents,
  }) {
    if (windowHours <= 0) return 'You can cancel for free any time before your appointment.';
    final fee = (totalCents * feePercent / 100).round();
    final late = feePercent > 0
        ? 'After that, a late-cancellation fee of ${Formatters.audCents(fee)} ($feePercent%) applies, '
            'payable to the provider.'
        : "After that, you can still cancel with no fee, but it's recorded as a late cancellation.";
    return 'Free cancellation until ${Formatters.dateTimeShort(freeUntilLocal)}. $late';
  }
}
