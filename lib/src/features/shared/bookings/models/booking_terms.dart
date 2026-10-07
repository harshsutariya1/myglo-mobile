import 'booking_enums.dart';
import 'booking_settings.dart';

/// The rules a new booking is made under, which depend on how the client
/// pays. Mirrors `public.create_booking`, which applies (and snapshots) the
/// same rules on the server:
///
/// * Cash bookings are always requests the provider has to accept, and never
///   carry a late-cancellation or no-show fee.
/// * Bookings paid in the app follow the provider's own settings: instant or
///   approved, with their late-cancellation fee.
///
/// The free-cancellation window applies either way. Clients never pay a
/// Myglo fee; Myglo's commission is charged to providers on bookings paid in
/// the app only.
class BookingTerms {
  const BookingTerms._({
    required this.requiresApproval,
    required this.cancellationWindowHours,
    required this.cancellationFeePercent,
  });

  factory BookingTerms.of(ProviderBookingSettings settings, PaymentMethod method) => BookingTerms._(
    requiresApproval: method.isCash || settings.requiresApproval,
    cancellationWindowHours: settings.cancellationWindowHours,
    cancellationFeePercent: method.isCash ? 0 : settings.cancellationFeePercent,
  );

  /// The booking is sent as a request and confirmed once the provider
  /// accepts it.
  final bool requiresApproval;

  /// Clients can cancel for free until this many hours before the start.
  final int cancellationWindowHours;

  /// Share of the booking owed for a late cancellation or no-show.
  final int cancellationFeePercent;
}
