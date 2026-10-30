import 'package:freezed_annotation/freezed_annotation.dart';

part 'payments_setup.freezed.dart';
part 'payments_setup.g.dart';

/// Where a provider's Stripe payout account is (`get_my_payments_setup`).
enum PaymentsSetupStatus {
  /// No Stripe account yet.
  @JsonValue('not_started')
  notStarted,

  /// Account created; Stripe still needs details from the provider.
  @JsonValue('onboarding')
  onboarding,

  /// Details sent; Stripe is checking them.
  @JsonValue('verifying')
  verifying,

  /// Card payments and payouts work.
  @JsonValue('active')
  active,

  /// Working, but Stripe needs more details soon.
  @JsonValue('action_needed')
  actionNeeded,

  /// Was working; paused until the provider gives Stripe what it needs.
  @JsonValue('restricted')
  restricted,

  /// Stripe can't support this account.
  @JsonValue('rejected')
  rejected,

  @JsonValue('closed')
  closed,
  unknown;

  /// The provider can take card payments right now.
  bool get canTakeCards => this == active || this == actionNeeded;

  /// The provider has something to do in Stripe.
  bool get needsProvider => this == notStarted || this == onboarding || this == actionNeeded || this == restricted;
}

@freezed
abstract class PaymentsSetup with _$PaymentsSetup {
  const PaymentsSetup._();

  const factory PaymentsSetup({
    @JsonKey(unknownEnumValue: PaymentsSetupStatus.unknown) @Default(PaymentsSetupStatus.notStarted)
    PaymentsSetupStatus status,
    @JsonKey(name: 'payouts_enabled') @Default(false) bool payoutsEnabled,

    /// What Stripe needs from the provider, in Stripe's words.
    @JsonKey(name: 'requirements_due') @Default([]) List<String> requirementsDue,
    @JsonKey(name: 'requirements_deadline') DateTime? requirementsDeadline,
    @JsonKey(name: 'first_enabled_at') DateTime? firstEnabledAt,

    /// Myglo's commission on bookings paid in the app.
    @JsonKey(name: 'fee_percent') @Default(0) double feePercent,
    @JsonKey(name: 'fee_free_days') @Default(0) int feeFreeDays,

    /// End of this provider's fee-free period (null until card payments start).
    @JsonKey(name: 'fee_free_until') DateTime? feeFreeUntil,
  }) = _PaymentsSetup;

  factory PaymentsSetup.fromJson(Map<String, dynamic> json) => _$PaymentsSetupFromJson(json);

  /// Whether no fee is charged on a card booking made at [now].
  bool isFeeFree(DateTime now) => feePercent == 0 || (feeFreeUntil != null && now.isBefore(feeFreeUntil!));
}
