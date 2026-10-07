import 'package:freezed_annotation/freezed_annotation.dart';

/// Where a booking is in its lifecycle. Mirrors `bookings.status`.
enum BookingStatus {
  /// Waiting for the provider to accept (providers who approve requests).
  @JsonValue('pending')
  pending,
  @JsonValue('confirmed')
  confirmed,
  @JsonValue('declined')
  declined,
  @JsonValue('cancelled')
  cancelled,
  @JsonValue('completed')
  completed,
  @JsonValue('no_show')
  noShow,

  /// A request nobody answered before its start time.
  @JsonValue('expired')
  expired;

  /// Still holds the provider's time.
  bool get isActive => this == pending || this == confirmed;

  String get label => switch (this) {
        pending => 'Pending approval',
        confirmed => 'Confirmed',
        declined => 'Declined',
        cancelled => 'Cancelled',
        completed => 'Completed',
        noShow => 'No-show',
        expired => 'Expired',
      };
}

/// Mirrors `bookings.payment_status`.
enum PaymentStatus {
  @JsonValue('pending')
  pending,
  @JsonValue('paid')
  paid,
  @JsonValue('refunded')
  refunded,

  /// Nothing is owed any more (cancelled, declined, expired…).
  @JsonValue('void')
  voided;
}

/// Mirrors `bookings.payment_method`. Only [cash] is live; the others are
/// shown as coming soon until card payments (Stripe) launch.
enum PaymentMethod {
  @JsonValue('cash')
  cash,
  @JsonValue('card')
  card,
  @JsonValue('apple_pay')
  applePay,
  @JsonValue('google_pay')
  googlePay,
  @JsonValue('afterpay')
  afterpay;

  String get wireName => switch (this) {
        cash => 'cash',
        card => 'card',
        applePay => 'apple_pay',
        googlePay => 'google_pay',
        afterpay => 'afterpay',
      };

  String get label => switch (this) {
        cash => 'Cash',
        card => 'Credit or debit card',
        applePay => 'Apple Pay',
        googlePay => 'Google Pay',
        afterpay => 'Afterpay',
      };

  /// Paid in person on the day. Cash bookings are always requests the
  /// provider accepts and never carry a fee (see [BookingTerms]).
  bool get isCash => this == cash;

  /// Can be chosen when booking. Card, wallets and Afterpay go live with
  /// Stripe; the server rejects them until then.
  bool get isAvailable => isCash;
}

/// Where the appointment happens. Mirrors `bookings.location_type`.
enum BookingLocationType {
  /// At the provider's salon or studio.
  @JsonValue('studio')
  studio,

  /// The provider travels to the client.
  @JsonValue('client')
  client;

  String get wireName => name;
}

/// Who cancelled a booking. Mirrors `bookings.cancelled_by`.
enum CancelledBy {
  @JsonValue('client')
  client,
  @JsonValue('provider')
  provider,
  @JsonValue('system')
  system,
}

/// Human label for a payment line, e.g. `Pending (Cash)`.
String paymentStatusLabel(PaymentMethod method, PaymentStatus status) {
  final via = method.label;
  return switch (status) {
    PaymentStatus.pending => 'Pending ($via)',
    PaymentStatus.paid => 'Paid ($via)',
    PaymentStatus.refunded => 'Refunded',
    PaymentStatus.voided => 'Nothing to pay',
  };
}
