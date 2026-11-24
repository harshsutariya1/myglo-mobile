import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/utils/formatters.dart';

part 'account_deletion_status.freezed.dart';
part 'account_deletion_status.g.dart';

/// Why an account can't be deleted yet (`account_deletion_blockers`, plus
/// `stripe_balance` from the delete-account function).
enum AccountDeletionBlockerCode {
  /// Providers hide their business instead (a platform setting).
  @JsonValue('provider_deletion_disabled')
  providerDeletionDisabled,
  @JsonValue('admin_account')
  adminAccount,
  @JsonValue('account_suspended')
  accountSuspended,
  @JsonValue('upcoming_bookings')
  upcomingBookings,
  @JsonValue('payouts_pending')
  payoutsPending,
  @JsonValue('open_disputes')
  openDisputes,
  @JsonValue('stripe_balance')
  stripeBalance,
  unknown,
}

@freezed
abstract class AccountDeletionBlocker with _$AccountDeletionBlocker {
  const AccountDeletionBlocker._();

  const factory AccountDeletionBlocker({
    @JsonKey(unknownEnumValue: AccountDeletionBlockerCode.unknown) required AccountDeletionBlockerCode code,
    @Default(1) int count,

    /// Money still in the provider's Stripe balance (stripe_balance only).
    @JsonKey(name: 'amount_cents') int? amountCents,
  }) = _AccountDeletionBlocker;

  factory AccountDeletionBlocker.fromJson(Map<String, dynamic> json) => _$AccountDeletionBlockerFromJson(json);

  String get title => switch (code) {
        AccountDeletionBlockerCode.providerDeletionDisabled => "Business accounts aren't deleted in the app",
        AccountDeletionBlockerCode.adminAccount => 'Admin account',
        AccountDeletionBlockerCode.accountSuspended => 'Account suspended',
        AccountDeletionBlockerCode.upcomingBookings =>
          count == 1 ? '1 upcoming booking' : '$count upcoming bookings',
        AccountDeletionBlockerCode.payoutsPending => 'Payouts on the way',
        AccountDeletionBlockerCode.openDisputes => 'Payment dispute open',
        AccountDeletionBlockerCode.stripeBalance => 'Money in your Stripe balance',
        AccountDeletionBlockerCode.unknown => 'Something needs sorting first',
      };

  String get message => switch (code) {
        AccountDeletionBlockerCode.providerDeletionDisabled =>
          'Hide your business from the marketplace in Settings to stop appearing and taking bookings. '
              'To close the account for good, email ${AppConfig.supportEmail}.',
        AccountDeletionBlockerCode.adminAccount =>
          "Admin accounts can't be deleted in the app. Another admin can remove it.",
        AccountDeletionBlockerCode.accountSuspended =>
          'To delete a suspended account, email ${AppConfig.supportEmail}.',
        AccountDeletionBlockerCode.upcomingBookings =>
          'Cancel or finish your upcoming and unanswered bookings first.',
        AccountDeletionBlockerCode.payoutsPending => count == 1
            ? "A completed booking is still being paid out to you. You can delete your account once it's arrived."
            : "$count completed bookings are still being paid out to you. You can delete your account once they've arrived.",
        AccountDeletionBlockerCode.openDisputes =>
          "A client disputed a card payment. You can delete your account once it's resolved.",
        AccountDeletionBlockerCode.stripeBalance =>
          '${amountCents == null ? 'Money is' : '${Formatters.audCents(amountCents!)} is'} waiting to be paid out '
              'to your bank. Payouts go every Monday; try again once it arrives.',
        AccountDeletionBlockerCode.unknown => "Email ${AppConfig.supportEmail} and we'll help.",
      };
}

/// What the delete-account screen needs (`get_my_account_deletion_status`).
@freezed
abstract class AccountDeletionStatus with _$AccountDeletionStatus {
  const AccountDeletionStatus._();

  const factory AccountDeletionStatus({
    String? role,
    @Default([]) List<AccountDeletionBlocker> blockers,

    /// A Stripe payout account that will be closed with the Myglo account.
    @JsonKey(name: 'has_payout_account') @Default(false) bool hasPayoutAccount,
  }) = _AccountDeletionStatus;

  factory AccountDeletionStatus.fromJson(Map<String, dynamic> json) => _$AccountDeletionStatusFromJson(json);

  bool get isProvider => role == 'provider';
  bool get canDelete => blockers.isEmpty;
}
