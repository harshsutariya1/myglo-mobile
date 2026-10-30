// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'payments_setup.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$PaymentsSetup {

@JsonKey(unknownEnumValue: PaymentsSetupStatus.unknown) PaymentsSetupStatus get status;@JsonKey(name: 'payouts_enabled') bool get payoutsEnabled;/// What Stripe needs from the provider, in Stripe's words.
@JsonKey(name: 'requirements_due') List<String> get requirementsDue;@JsonKey(name: 'requirements_deadline') DateTime? get requirementsDeadline;@JsonKey(name: 'first_enabled_at') DateTime? get firstEnabledAt;/// Myglo's commission on bookings paid in the app.
@JsonKey(name: 'fee_percent') double get feePercent;@JsonKey(name: 'fee_free_days') int get feeFreeDays;/// End of this provider's fee-free period (null until card payments start).
@JsonKey(name: 'fee_free_until') DateTime? get feeFreeUntil;
/// Create a copy of PaymentsSetup
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PaymentsSetupCopyWith<PaymentsSetup> get copyWith => _$PaymentsSetupCopyWithImpl<PaymentsSetup>(this as PaymentsSetup, _$identity);

  /// Serializes this PaymentsSetup to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PaymentsSetup&&(identical(other.status, status) || other.status == status)&&(identical(other.payoutsEnabled, payoutsEnabled) || other.payoutsEnabled == payoutsEnabled)&&const DeepCollectionEquality().equals(other.requirementsDue, requirementsDue)&&(identical(other.requirementsDeadline, requirementsDeadline) || other.requirementsDeadline == requirementsDeadline)&&(identical(other.firstEnabledAt, firstEnabledAt) || other.firstEnabledAt == firstEnabledAt)&&(identical(other.feePercent, feePercent) || other.feePercent == feePercent)&&(identical(other.feeFreeDays, feeFreeDays) || other.feeFreeDays == feeFreeDays)&&(identical(other.feeFreeUntil, feeFreeUntil) || other.feeFreeUntil == feeFreeUntil));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,status,payoutsEnabled,const DeepCollectionEquality().hash(requirementsDue),requirementsDeadline,firstEnabledAt,feePercent,feeFreeDays,feeFreeUntil);

@override
String toString() {
  return 'PaymentsSetup(status: $status, payoutsEnabled: $payoutsEnabled, requirementsDue: $requirementsDue, requirementsDeadline: $requirementsDeadline, firstEnabledAt: $firstEnabledAt, feePercent: $feePercent, feeFreeDays: $feeFreeDays, feeFreeUntil: $feeFreeUntil)';
}


}

/// @nodoc
abstract mixin class $PaymentsSetupCopyWith<$Res>  {
  factory $PaymentsSetupCopyWith(PaymentsSetup value, $Res Function(PaymentsSetup) _then) = _$PaymentsSetupCopyWithImpl;
@useResult
$Res call({
@JsonKey(unknownEnumValue: PaymentsSetupStatus.unknown) PaymentsSetupStatus status,@JsonKey(name: 'payouts_enabled') bool payoutsEnabled,@JsonKey(name: 'requirements_due') List<String> requirementsDue,@JsonKey(name: 'requirements_deadline') DateTime? requirementsDeadline,@JsonKey(name: 'first_enabled_at') DateTime? firstEnabledAt,@JsonKey(name: 'fee_percent') double feePercent,@JsonKey(name: 'fee_free_days') int feeFreeDays,@JsonKey(name: 'fee_free_until') DateTime? feeFreeUntil
});




}
/// @nodoc
class _$PaymentsSetupCopyWithImpl<$Res>
    implements $PaymentsSetupCopyWith<$Res> {
  _$PaymentsSetupCopyWithImpl(this._self, this._then);

  final PaymentsSetup _self;
  final $Res Function(PaymentsSetup) _then;

/// Create a copy of PaymentsSetup
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? status = null,Object? payoutsEnabled = null,Object? requirementsDue = null,Object? requirementsDeadline = freezed,Object? firstEnabledAt = freezed,Object? feePercent = null,Object? feeFreeDays = null,Object? feeFreeUntil = freezed,}) {
  return _then(_self.copyWith(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as PaymentsSetupStatus,payoutsEnabled: null == payoutsEnabled ? _self.payoutsEnabled : payoutsEnabled // ignore: cast_nullable_to_non_nullable
as bool,requirementsDue: null == requirementsDue ? _self.requirementsDue : requirementsDue // ignore: cast_nullable_to_non_nullable
as List<String>,requirementsDeadline: freezed == requirementsDeadline ? _self.requirementsDeadline : requirementsDeadline // ignore: cast_nullable_to_non_nullable
as DateTime?,firstEnabledAt: freezed == firstEnabledAt ? _self.firstEnabledAt : firstEnabledAt // ignore: cast_nullable_to_non_nullable
as DateTime?,feePercent: null == feePercent ? _self.feePercent : feePercent // ignore: cast_nullable_to_non_nullable
as double,feeFreeDays: null == feeFreeDays ? _self.feeFreeDays : feeFreeDays // ignore: cast_nullable_to_non_nullable
as int,feeFreeUntil: freezed == feeFreeUntil ? _self.feeFreeUntil : feeFreeUntil // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [PaymentsSetup].
extension PaymentsSetupPatterns on PaymentsSetup {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PaymentsSetup value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PaymentsSetup() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PaymentsSetup value)  $default,){
final _that = this;
switch (_that) {
case _PaymentsSetup():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PaymentsSetup value)?  $default,){
final _that = this;
switch (_that) {
case _PaymentsSetup() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(unknownEnumValue: PaymentsSetupStatus.unknown)  PaymentsSetupStatus status, @JsonKey(name: 'payouts_enabled')  bool payoutsEnabled, @JsonKey(name: 'requirements_due')  List<String> requirementsDue, @JsonKey(name: 'requirements_deadline')  DateTime? requirementsDeadline, @JsonKey(name: 'first_enabled_at')  DateTime? firstEnabledAt, @JsonKey(name: 'fee_percent')  double feePercent, @JsonKey(name: 'fee_free_days')  int feeFreeDays, @JsonKey(name: 'fee_free_until')  DateTime? feeFreeUntil)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PaymentsSetup() when $default != null:
return $default(_that.status,_that.payoutsEnabled,_that.requirementsDue,_that.requirementsDeadline,_that.firstEnabledAt,_that.feePercent,_that.feeFreeDays,_that.feeFreeUntil);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(unknownEnumValue: PaymentsSetupStatus.unknown)  PaymentsSetupStatus status, @JsonKey(name: 'payouts_enabled')  bool payoutsEnabled, @JsonKey(name: 'requirements_due')  List<String> requirementsDue, @JsonKey(name: 'requirements_deadline')  DateTime? requirementsDeadline, @JsonKey(name: 'first_enabled_at')  DateTime? firstEnabledAt, @JsonKey(name: 'fee_percent')  double feePercent, @JsonKey(name: 'fee_free_days')  int feeFreeDays, @JsonKey(name: 'fee_free_until')  DateTime? feeFreeUntil)  $default,) {final _that = this;
switch (_that) {
case _PaymentsSetup():
return $default(_that.status,_that.payoutsEnabled,_that.requirementsDue,_that.requirementsDeadline,_that.firstEnabledAt,_that.feePercent,_that.feeFreeDays,_that.feeFreeUntil);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(unknownEnumValue: PaymentsSetupStatus.unknown)  PaymentsSetupStatus status, @JsonKey(name: 'payouts_enabled')  bool payoutsEnabled, @JsonKey(name: 'requirements_due')  List<String> requirementsDue, @JsonKey(name: 'requirements_deadline')  DateTime? requirementsDeadline, @JsonKey(name: 'first_enabled_at')  DateTime? firstEnabledAt, @JsonKey(name: 'fee_percent')  double feePercent, @JsonKey(name: 'fee_free_days')  int feeFreeDays, @JsonKey(name: 'fee_free_until')  DateTime? feeFreeUntil)?  $default,) {final _that = this;
switch (_that) {
case _PaymentsSetup() when $default != null:
return $default(_that.status,_that.payoutsEnabled,_that.requirementsDue,_that.requirementsDeadline,_that.firstEnabledAt,_that.feePercent,_that.feeFreeDays,_that.feeFreeUntil);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PaymentsSetup extends PaymentsSetup {
  const _PaymentsSetup({@JsonKey(unknownEnumValue: PaymentsSetupStatus.unknown) this.status = PaymentsSetupStatus.notStarted, @JsonKey(name: 'payouts_enabled') this.payoutsEnabled = false, @JsonKey(name: 'requirements_due') final  List<String> requirementsDue = const [], @JsonKey(name: 'requirements_deadline') this.requirementsDeadline, @JsonKey(name: 'first_enabled_at') this.firstEnabledAt, @JsonKey(name: 'fee_percent') this.feePercent = 0, @JsonKey(name: 'fee_free_days') this.feeFreeDays = 0, @JsonKey(name: 'fee_free_until') this.feeFreeUntil}): _requirementsDue = requirementsDue,super._();
  factory _PaymentsSetup.fromJson(Map<String, dynamic> json) => _$PaymentsSetupFromJson(json);

@override@JsonKey(unknownEnumValue: PaymentsSetupStatus.unknown) final  PaymentsSetupStatus status;
@override@JsonKey(name: 'payouts_enabled') final  bool payoutsEnabled;
/// What Stripe needs from the provider, in Stripe's words.
 final  List<String> _requirementsDue;
/// What Stripe needs from the provider, in Stripe's words.
@override@JsonKey(name: 'requirements_due') List<String> get requirementsDue {
  if (_requirementsDue is EqualUnmodifiableListView) return _requirementsDue;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_requirementsDue);
}

@override@JsonKey(name: 'requirements_deadline') final  DateTime? requirementsDeadline;
@override@JsonKey(name: 'first_enabled_at') final  DateTime? firstEnabledAt;
/// Myglo's commission on bookings paid in the app.
@override@JsonKey(name: 'fee_percent') final  double feePercent;
@override@JsonKey(name: 'fee_free_days') final  int feeFreeDays;
/// End of this provider's fee-free period (null until card payments start).
@override@JsonKey(name: 'fee_free_until') final  DateTime? feeFreeUntil;

/// Create a copy of PaymentsSetup
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PaymentsSetupCopyWith<_PaymentsSetup> get copyWith => __$PaymentsSetupCopyWithImpl<_PaymentsSetup>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PaymentsSetupToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PaymentsSetup&&(identical(other.status, status) || other.status == status)&&(identical(other.payoutsEnabled, payoutsEnabled) || other.payoutsEnabled == payoutsEnabled)&&const DeepCollectionEquality().equals(other._requirementsDue, _requirementsDue)&&(identical(other.requirementsDeadline, requirementsDeadline) || other.requirementsDeadline == requirementsDeadline)&&(identical(other.firstEnabledAt, firstEnabledAt) || other.firstEnabledAt == firstEnabledAt)&&(identical(other.feePercent, feePercent) || other.feePercent == feePercent)&&(identical(other.feeFreeDays, feeFreeDays) || other.feeFreeDays == feeFreeDays)&&(identical(other.feeFreeUntil, feeFreeUntil) || other.feeFreeUntil == feeFreeUntil));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,status,payoutsEnabled,const DeepCollectionEquality().hash(_requirementsDue),requirementsDeadline,firstEnabledAt,feePercent,feeFreeDays,feeFreeUntil);

@override
String toString() {
  return 'PaymentsSetup(status: $status, payoutsEnabled: $payoutsEnabled, requirementsDue: $requirementsDue, requirementsDeadline: $requirementsDeadline, firstEnabledAt: $firstEnabledAt, feePercent: $feePercent, feeFreeDays: $feeFreeDays, feeFreeUntil: $feeFreeUntil)';
}


}

/// @nodoc
abstract mixin class _$PaymentsSetupCopyWith<$Res> implements $PaymentsSetupCopyWith<$Res> {
  factory _$PaymentsSetupCopyWith(_PaymentsSetup value, $Res Function(_PaymentsSetup) _then) = __$PaymentsSetupCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(unknownEnumValue: PaymentsSetupStatus.unknown) PaymentsSetupStatus status,@JsonKey(name: 'payouts_enabled') bool payoutsEnabled,@JsonKey(name: 'requirements_due') List<String> requirementsDue,@JsonKey(name: 'requirements_deadline') DateTime? requirementsDeadline,@JsonKey(name: 'first_enabled_at') DateTime? firstEnabledAt,@JsonKey(name: 'fee_percent') double feePercent,@JsonKey(name: 'fee_free_days') int feeFreeDays,@JsonKey(name: 'fee_free_until') DateTime? feeFreeUntil
});




}
/// @nodoc
class __$PaymentsSetupCopyWithImpl<$Res>
    implements _$PaymentsSetupCopyWith<$Res> {
  __$PaymentsSetupCopyWithImpl(this._self, this._then);

  final _PaymentsSetup _self;
  final $Res Function(_PaymentsSetup) _then;

/// Create a copy of PaymentsSetup
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? status = null,Object? payoutsEnabled = null,Object? requirementsDue = null,Object? requirementsDeadline = freezed,Object? firstEnabledAt = freezed,Object? feePercent = null,Object? feeFreeDays = null,Object? feeFreeUntil = freezed,}) {
  return _then(_PaymentsSetup(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as PaymentsSetupStatus,payoutsEnabled: null == payoutsEnabled ? _self.payoutsEnabled : payoutsEnabled // ignore: cast_nullable_to_non_nullable
as bool,requirementsDue: null == requirementsDue ? _self._requirementsDue : requirementsDue // ignore: cast_nullable_to_non_nullable
as List<String>,requirementsDeadline: freezed == requirementsDeadline ? _self.requirementsDeadline : requirementsDeadline // ignore: cast_nullable_to_non_nullable
as DateTime?,firstEnabledAt: freezed == firstEnabledAt ? _self.firstEnabledAt : firstEnabledAt // ignore: cast_nullable_to_non_nullable
as DateTime?,feePercent: null == feePercent ? _self.feePercent : feePercent // ignore: cast_nullable_to_non_nullable
as double,feeFreeDays: null == feeFreeDays ? _self.feeFreeDays : feeFreeDays // ignore: cast_nullable_to_non_nullable
as int,feeFreeUntil: freezed == feeFreeUntil ? _self.feeFreeUntil : feeFreeUntil // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

// dart format on
