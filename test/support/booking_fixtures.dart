import 'package:myglo/src/features/shared/bookings/models/booking.dart';
import 'package:myglo/src/features/shared/bookings/models/booking_enums.dart';

/// A Gold Coast booking (AEST, UTC+10) for tests: Wed 8 Oct 2026,
/// 9:30–11:00 am local, a lash lift and tint paid in cash.
Booking sampleBooking({
  String id = 'booking-1',
  BookingStatus status = BookingStatus.confirmed,
  PaymentStatus paymentStatus = PaymentStatus.pending,
  BookingLocationType locationType = BookingLocationType.studio,
  DateTime? startsAt,
  int cancellationWindowHours = 24,
  int cancellationFeePercent = 0,
  int? platformFeeCents,
  String? clientNotes,
  CancelledBy? cancelledBy,
  bool lateCancellation = false,
  int cancellationFeeCents = 0,
}) {
  final start = startsAt ?? DateTime.utc(2026, 10, 7, 23, 30);
  final end = start.add(const Duration(minutes: 90));
  const offset = Duration(hours: 10);
  return Booking(
    id: id,
    reference: 'MG-7K3QX9',
    clientId: 'client-1',
    providerId: 'prov-1',
    status: status,
    startsAt: start,
    endsAt: end,
    timeZone: 'Australia/Brisbane',
    startsAtLocal: start.add(offset),
    endsAtLocal: end.add(offset),
    durationMinutes: 90,
    locationType: locationType,
    addressText: locationType == BookingLocationType.studio
        ? '1 Cavill Ave, Surfers Paradise QLD 4217'
        : '12 Smith St, Southport QLD 4215',
    distanceKm: locationType == BookingLocationType.client ? 6.4 : null,
    providerName: 'Glow Studio',
    clientName: 'Michelle Zhang',
    clientPhone: '0412 345 678',
    clientNotes: clientNotes,
    subtotalCents: 11500,
    totalCents: 11500,
    paymentMethod: PaymentMethod.cash,
    paymentStatus: paymentStatus,
    requiresApproval: status == BookingStatus.pending,
    cancellationWindowHours: cancellationWindowHours,
    cancellationFeePercent: cancellationFeePercent,
    freeCancellationUntil: start.subtract(Duration(hours: cancellationWindowHours)),
    cancelledBy: cancelledBy,
    lateCancellation: lateCancellation,
    cancellationFeeCents: cancellationFeeCents,
    createdAt: DateTime.utc(2026, 10, 5),
    updatedAt: DateTime.utc(2026, 10, 5),
    platformFeeCents: platformFeeCents,
    items: const [
      BookingItem(serviceId: 'svc-1', name: 'Lash lift', durationMinutes: 70, priceCents: 8500),
      BookingItem(serviceId: 'svc-2', name: 'Lash tint', durationMinutes: 20, priceCents: 3000),
    ],
  );
}
