// GENERATED CODE - DO NOT MODIFY BY HAND

// ignore_for_file: type=lint

part of 'account_deletion_status.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_AccountDeletionBlocker _$AccountDeletionBlockerFromJson(
  Map<String, dynamic> json,
) => _AccountDeletionBlocker(
  code: $enumDecode(
    _$AccountDeletionBlockerCodeEnumMap,
    json['code'],
    unknownValue: AccountDeletionBlockerCode.unknown,
  ),
  count: (json['count'] as num?)?.toInt() ?? 1,
  amountCents: (json['amount_cents'] as num?)?.toInt(),
);

Map<String, dynamic> _$AccountDeletionBlockerToJson(
  _AccountDeletionBlocker instance,
) => <String, dynamic>{
  'code': _$AccountDeletionBlockerCodeEnumMap[instance.code]!,
  'count': instance.count,
  'amount_cents': instance.amountCents,
};

const _$AccountDeletionBlockerCodeEnumMap = {
  AccountDeletionBlockerCode.providerDeletionDisabled:
      'provider_deletion_disabled',
  AccountDeletionBlockerCode.adminAccount: 'admin_account',
  AccountDeletionBlockerCode.accountSuspended: 'account_suspended',
  AccountDeletionBlockerCode.upcomingBookings: 'upcoming_bookings',
  AccountDeletionBlockerCode.payoutsPending: 'payouts_pending',
  AccountDeletionBlockerCode.openDisputes: 'open_disputes',
  AccountDeletionBlockerCode.stripeBalance: 'stripe_balance',
  AccountDeletionBlockerCode.unknown: 'unknown',
};

_AccountDeletionStatus _$AccountDeletionStatusFromJson(
  Map<String, dynamic> json,
) => _AccountDeletionStatus(
  role: json['role'] as String?,
  blockers:
      (json['blockers'] as List<dynamic>?)
          ?.map(
            (e) => AccountDeletionBlocker.fromJson(e as Map<String, dynamic>),
          )
          .toList() ??
      const [],
  hasPayoutAccount: json['has_payout_account'] as bool? ?? false,
);

Map<String, dynamic> _$AccountDeletionStatusToJson(
  _AccountDeletionStatus instance,
) => <String, dynamic>{
  'role': instance.role,
  'blockers': instance.blockers.map((e) => e.toJson()).toList(),
  'has_payout_account': instance.hasPayoutAccount,
};
