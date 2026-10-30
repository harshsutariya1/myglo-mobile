// GENERATED CODE - DO NOT MODIFY BY HAND

// ignore_for_file: type=lint

part of 'payments_setup.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_PaymentsSetup _$PaymentsSetupFromJson(Map<String, dynamic> json) =>
    _PaymentsSetup(
      status:
          $enumDecodeNullable(
            _$PaymentsSetupStatusEnumMap,
            json['status'],
            unknownValue: PaymentsSetupStatus.unknown,
          ) ??
          PaymentsSetupStatus.notStarted,
      payoutsEnabled: json['payouts_enabled'] as bool? ?? false,
      requirementsDue:
          (json['requirements_due'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      requirementsDeadline: json['requirements_deadline'] == null
          ? null
          : DateTime.parse(json['requirements_deadline'] as String),
      firstEnabledAt: json['first_enabled_at'] == null
          ? null
          : DateTime.parse(json['first_enabled_at'] as String),
      feePercent: (json['fee_percent'] as num?)?.toDouble() ?? 0,
      feeFreeDays: (json['fee_free_days'] as num?)?.toInt() ?? 0,
      feeFreeUntil: json['fee_free_until'] == null
          ? null
          : DateTime.parse(json['fee_free_until'] as String),
    );

Map<String, dynamic> _$PaymentsSetupToJson(_PaymentsSetup instance) =>
    <String, dynamic>{
      'status': _$PaymentsSetupStatusEnumMap[instance.status]!,
      'payouts_enabled': instance.payoutsEnabled,
      'requirements_due': instance.requirementsDue,
      'requirements_deadline': instance.requirementsDeadline?.toIso8601String(),
      'first_enabled_at': instance.firstEnabledAt?.toIso8601String(),
      'fee_percent': instance.feePercent,
      'fee_free_days': instance.feeFreeDays,
      'fee_free_until': instance.feeFreeUntil?.toIso8601String(),
    };

const _$PaymentsSetupStatusEnumMap = {
  PaymentsSetupStatus.notStarted: 'not_started',
  PaymentsSetupStatus.onboarding: 'onboarding',
  PaymentsSetupStatus.verifying: 'verifying',
  PaymentsSetupStatus.active: 'active',
  PaymentsSetupStatus.actionNeeded: 'action_needed',
  PaymentsSetupStatus.restricted: 'restricted',
  PaymentsSetupStatus.rejected: 'rejected',
  PaymentsSetupStatus.closed: 'closed',
  PaymentsSetupStatus.unknown: 'unknown',
};
