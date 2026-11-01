import 'package:freezed_annotation/freezed_annotation.dart';

/// Where a booking is in its lifecycle. Mirrors `bookings.status`.
enum BookingStatus {
  /// A booking paid in the app, waiting for the client to finish paying. It
  /// holds the time for a few minutes; only the client can see it.
  @JsonValue('awaiting_payment')
  awaitingPayment,

  /// A booking paid in the app whose payment was never finished (abandoned,
  /// or the hold on the time ran out). Only the client can see it.
  @JsonValue('checkout_expired')
  checkoutExpired,

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

  /// Still in checkout: not a booking the provider knows about yet.
  bool get isCheckout => this == awaitingPayment || this == checkoutExpired;

  String get label => switch (this) {
        awaitingPayment => 'Awaiting payment',
        checkoutExpired => 'Payment not completed',
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
  /// Cash: to be paid at the appointment.
  @JsonValue('pending')
  pending,

  /// Paid in the app: the client hasn't finished paying yet.
  @JsonValue('requires_payment')
  requiresPayment,

  /// Paid in the app: the amount is held on the client's card until the
  /// provider accepts the request.
  @JsonValue('authorized')
  authorized,
  @JsonValue('paid')
  paid,
  @JsonValue('partially_refunded')
  partiallyRefunded,
  @JsonValue('refunded')
  refunded,

  /// Nothing is owed any more (cancelled, declined, expired…).
  @JsonValue('void')
  voided,

  /// The payment couldn't be completed (Myglo follows it up).
  @JsonValue('failed')
  failed,

  /// A status this version of the app doesn't know yet.
  unknown;
}

/// Mirrors `bookings.payment_method`. Bookings are paid in [cash] or in the
/// app as [card] (Apple Pay and Google Pay are card payments, recorded as
/// [card] with the wallet on the payment). The wallet and Afterpay values
/// exist on the server but aren't offered.
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

  /// Can be chosen when booking (if the provider takes it). Afterpay comes
  /// later; wallets are offered inside the card payment sheet.
  bool get isOffered => this == cash || this == card;
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

/// Human label for a payment line, e.g. `Pending (Cash)` or `Card held`.
String paymentStatusLabel(PaymentMethod method, PaymentStatus status) {
  final via = method.isCash ? 'Cash' : 'Card';
  return switch (status) {
    PaymentStatus.pending => 'Pending ($via)',
    PaymentStatus.requiresPayment => 'Awaiting payment',
    PaymentStatus.authorized => 'Card held',
    PaymentStatus.paid => 'Paid ($via)',
    PaymentStatus.partiallyRefunded => 'Partly refunded',
    PaymentStatus.refunded => 'Refunded',
    PaymentStatus.voided => 'Nothing to pay',
    PaymentStatus.failed => 'Payment failed',
    PaymentStatus.unknown => 'Payment ($via)',
  };
}
