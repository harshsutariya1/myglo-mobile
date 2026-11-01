/// A provider's money over a period (`get_provider_financials`).
library;

int _int(Object? value) => value is num ? value.toInt() : int.tryParse('$value') ?? 0;

DateTime? _date(Object? value) => value == null ? null : DateTime.tryParse('$value');

/// The provider's share of one booking paid in the app.
class Settlement {
  const Settlement({
    required this.bookingId,
    required this.reference,
    required this.clientName,
    required this.startsAt,
    required this.keptCents,
    required this.feeCents,
    required this.transferCents,
    required this.status,
    this.reversedCents = 0,
    this.holdReason,
    this.transferredAt,
  });

  factory Settlement.fromJson(Map<String, dynamic> json) => Settlement(
        bookingId: json['booking_id'] as String,
        reference: json['reference'] as String? ?? '',
        clientName: json['client_name'] as String? ?? 'Client',
        startsAt: _date(json['starts_at']) ?? DateTime.fromMillisecondsSinceEpoch(0),
        keptCents: _int(json['kept_cents']),
        feeCents: _int(json['platform_fee_cents']),
        transferCents: _int(json['transfer_cents']),
        reversedCents: _int(json['reversed_cents']),
        status: json['status'] as String? ?? 'scheduled',
        holdReason: json['hold_reason'] as String?,
        transferredAt: _date(json['transferred_at']),
      );

  final String bookingId;
  final String reference;
  final String clientName;
  final DateTime startsAt;
  final int keptCents;
  final int feeCents;
  final int transferCents;
  final int reversedCents;
  final String status;
  final String? holdReason;
  final DateTime? transferredAt;

  /// What actually reaches the provider.
  int get netCents => transferCents - reversedCents;

  String get statusLabel => switch (status) {
        'scheduled' || 'processing' => 'On its way',
        'held' => switch (holdReason) {
            'payout_account' => 'Waiting for your payout details',
            'dispute' => 'On hold: disputed',
            _ => 'On hold',
          },
        'transferred' => reversedCents > 0 ? 'Paid, partly taken back' : 'Paid to your Stripe balance',
        'reversed' => 'Taken back',
        'failed' => 'Delayed: Myglo is on it',
        _ => 'Nothing to pay',
      };
}

/// A payout from the provider's Stripe balance to their bank.
class Payout {
  const Payout({required this.id, required this.amountCents, required this.status, this.arrivalDate, this.failureMessage});

  factory Payout.fromJson(Map<String, dynamic> json) => Payout(
        id: json['id'] as String,
        amountCents: _int(json['amount_cents']),
        status: json['status'] as String? ?? 'pending',
        arrivalDate: _date(json['arrival_date']),
        failureMessage: json['failure_message'] as String?,
      );

  final String id;
  final int amountCents;
  final String status;
  final DateTime? arrivalDate;
  final String? failureMessage;

  String get statusLabel => switch (status) {
        'paid' => 'Paid',
        'in_transit' => 'On its way',
        'failed' => 'Failed',
        'canceled' => 'Cancelled',
        _ => 'Pending',
      };
}

class ProviderFinancials {
  const ProviderFinancials({
    this.cardEarnedCents = 0,
    this.mygloFeeCents = 0,
    this.cashCollectedCents = 0,
    this.completedBookings = 0,
    this.onItsWayCents = 0,
    this.heldCents = 0,
    this.settlements = const [],
    this.payouts = const [],
  });

  factory ProviderFinancials.fromJson(Map<String, dynamic> json) => ProviderFinancials(
        cardEarnedCents: _int(json['card_earned_cents']),
        mygloFeeCents: _int(json['myglo_fee_cents']),
        cashCollectedCents: _int(json['cash_collected_cents']),
        completedBookings: _int(json['completed_bookings']),
        onItsWayCents: _int(json['on_its_way_cents']),
        heldCents: _int(json['held_cents']),
        settlements: [
          for (final row in (json['settlements'] as List? ?? const [])) Settlement.fromJson(Map<String, dynamic>.from(row as Map)),
        ],
        payouts: [for (final row in (json['payouts'] as List? ?? const [])) Payout.fromJson(Map<String, dynamic>.from(row as Map))],
      );

  /// Paid in the app, after Myglo's fee.
  final int cardEarnedCents;
  final int mygloFeeCents;
  final int cashCollectedCents;
  final int completedBookings;

  /// Shares not yet transferred (all time), and how much of that is on hold.
  final int onItsWayCents;
  final int heldCents;
  final List<Settlement> settlements;
  final List<Payout> payouts;

  /// Everything earned in the period, after Myglo's fee.
  int get totalEarnedCents => cardEarnedCents - mygloFeeCents + cashCollectedCents;
}
