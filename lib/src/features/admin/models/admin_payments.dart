/// Admin views of card payments. Shapes follow the `admin_*` payment RPCs
/// (supabase/migrations/20261101130000_payment_lifecycle.sql).
library;

DateTime? _date(Object? value) => value == null ? null : DateTime.tryParse('$value');

int _int(Object? value) => value is num ? value.toInt() : int.tryParse('$value') ?? 0;

/// One booking paid in the app, in the payments list.
class AdminPaymentSummary {
  const AdminPaymentSummary({
    required this.bookingId,
    required this.reference,
    required this.status,
    required this.paymentStatus,
    required this.totalCents,
    required this.startsAt,
    required this.clientName,
    required this.providerName,
    this.cardBrand,
    this.cardLast4,
    this.amountRefundedCents = 0,
    this.settlementStatus,
    this.holdReason,
    this.disputed = false,
  });

  factory AdminPaymentSummary.fromJson(Map<String, dynamic> json) => AdminPaymentSummary(
    bookingId: json['booking_id'] as String,
    reference: json['reference'] as String? ?? '',
    status: json['status'] as String? ?? '',
    paymentStatus: json['payment_status'] as String? ?? '',
    totalCents: _int(json['total_cents']),
    startsAt: _date(json['starts_at']) ?? DateTime.fromMillisecondsSinceEpoch(0),
    clientName: json['client_name'] as String? ?? 'Client',
    providerName: json['provider_name'] as String? ?? 'Provider',
    cardBrand: json['card_brand'] as String?,
    cardLast4: json['card_last4'] as String?,
    amountRefundedCents: _int(json['amount_refunded_cents']),
    settlementStatus: json['settlement_status'] as String?,
    holdReason: json['hold_reason'] as String?,
    disputed: json['disputed'] == true,
  );

  final String bookingId;
  final String reference;
  final String status;
  final String paymentStatus;
  final int totalCents;
  final DateTime startsAt;
  final String clientName;
  final String providerName;
  final String? cardBrand;
  final String? cardLast4;
  final int amountRefundedCents;
  final String? settlementStatus;
  final String? holdReason;
  final bool disputed;
}

/// A background job, as admins see it.
class AdminJob {
  const AdminJob({
    required this.id,
    required this.kind,
    required this.status,
    this.bookingId,
    this.attempts = 0,
    this.lastError,
    this.updatedAt,
  });

  factory AdminJob.fromJson(Map<String, dynamic> json) => AdminJob(
    id: json['id'] as String,
    kind: json['kind'] as String? ?? '',
    status: json['status'] as String? ?? 'failed',
    bookingId: json['booking_id'] as String?,
    attempts: _int(json['attempts']),
    lastError: json['last_error'] as String?,
    updatedAt: _date(json['updated_at']),
  );

  final String id;
  final String kind;
  final String status;
  final String? bookingId;
  final int attempts;
  final String? lastError;
  final DateTime? updatedAt;

  /// `Transfer to provider`, `Refund`…
  String get label => switch (kind) {
    'transfer' => 'Transfer to provider',
    'reverse_transfer' => 'Take back from provider',
    'refund_payment' => 'Refund',
    'capture_payment' => 'Capture card hold',
    'cancel_payment_intent' => 'Cancel payment',
    'admin_alert' => 'Admin email',
    _ => kind,
  };
}

class AdminDispute {
  const AdminDispute({
    required this.id,
    required this.amountCents,
    required this.status,
    this.bookingId,
    this.reference,
    this.reason,
    this.evidenceDueBy,
  });

  factory AdminDispute.fromJson(Map<String, dynamic> json) => AdminDispute(
    id: json['id'] as String,
    bookingId: json['booking_id'] as String?,
    reference: json['reference'] as String?,
    amountCents: _int(json['amount_cents']),
    reason: json['reason'] as String?,
    status: json['status'] as String? ?? '',
    evidenceDueBy: _date(json['evidence_due_by']),
  );

  final String id;
  final String? bookingId;
  final String? reference;
  final int amountCents;
  final String? reason;
  final String status;
  final DateTime? evidenceDueBy;
}

/// What needs a person, and the last week's money.
class AdminPaymentsOverview {
  const AdminPaymentsOverview({
    this.paid7dCents = 0,
    this.fees7dCents = 0,
    this.heldSettlements = 0,
    this.failedSettlements = 0,
    this.openDisputes = 0,
    this.pendingRefunds = 0,
    this.failedJobs = const [],
    this.disputes = const [],
  });

  factory AdminPaymentsOverview.fromJson(Map<String, dynamic> json) => AdminPaymentsOverview(
    paid7dCents: _int(json['paid_7d_cents']),
    fees7dCents: _int(json['fees_7d_cents']),
    heldSettlements: _int(json['held_settlements']),
    failedSettlements: _int(json['failed_settlements']),
    openDisputes: _int(json['open_disputes']),
    pendingRefunds: _int(json['pending_refunds']),
    failedJobs: [
      for (final job in (json['failed_jobs'] as List? ?? const []))
        AdminJob.fromJson(Map<String, dynamic>.from(job as Map)),
    ],
    disputes: [
      for (final d in (json['disputes'] as List? ?? const []))
        AdminDispute.fromJson(Map<String, dynamic>.from(d as Map)),
    ],
  );

  final int paid7dCents;
  final int fees7dCents;
  final int heldSettlements;
  final int failedSettlements;
  final int openDisputes;
  final int pendingRefunds;
  final List<AdminJob> failedJobs;
  final List<AdminDispute> disputes;
}

/// Everything about one booking's money (`admin_get_booking_payment`).
class AdminBookingPayment {
  const AdminBookingPayment({
    required this.booking,
    this.payment,
    this.refunds = const [],
    this.settlement,
    this.disputes = const [],
    this.jobs = const [],
    this.events = const [],
  });

  factory AdminBookingPayment.fromJson(Map<String, dynamic> json) {
    List<Map<String, dynamic>> list(String key) => [
      for (final row in (json[key] as List? ?? const [])) Map<String, dynamic>.from(row as Map),
    ];
    Map<String, dynamic>? map(String key) => json[key] is Map ? Map<String, dynamic>.from(json[key] as Map) : null;
    return AdminBookingPayment(
      booking: map('booking') ?? const {},
      payment: map('payment'),
      refunds: list('refunds'),
      settlement: map('settlement'),
      disputes: [for (final d in list('disputes')) AdminDispute.fromJson(d)],
      jobs: [for (final j in list('jobs')) AdminJob.fromJson(j)],
      events: list('events'),
    );
  }

  final Map<String, dynamic> booking;
  final Map<String, dynamic>? payment;
  final List<Map<String, dynamic>> refunds;
  final Map<String, dynamic>? settlement;
  final List<AdminDispute> disputes;
  final List<AdminJob> jobs;
  final List<Map<String, dynamic>> events;

  String get bookingId => booking['id'] as String;
  String get reference => booking['reference'] as String? ?? '';
  String get status => booking['status'] as String? ?? '';
  String get paymentMethod => booking['payment_method'] as String? ?? 'cash';
  int get totalCents => _int(booking['total_cents']);
  int get refundableCents => _int(booking['refundable_cents']);
  String? get settlementStatus => settlement?['status'] as String?;

  bool get canCancel => status == 'pending' || status == 'confirmed';
  bool get canRefund => paymentMethod != 'cash' && refundableCents > 0;
  bool get canHold =>
      const {'scheduled', 'failed'}.contains(settlementStatus) ||
      (settlementStatus == 'held' && settlement?['hold_reason'] != 'admin');
  bool get canRelease => settlementStatus == 'failed' || settlementStatus == 'held';
}
