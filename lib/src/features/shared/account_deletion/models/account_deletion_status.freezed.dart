// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'account_deletion_status.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$AccountDeletionBlocker {

@JsonKey(unknownEnumValue: AccountDeletionBlockerCode.unknown) AccountDeletionBlockerCode get code; int get count;/// Money still in the provider's Stripe balance (stripe_balance only).
@JsonKey(name: 'amount_cents') int? get amountCents;
/// Create a copy of AccountDeletionBlocker
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AccountDeletionBlockerCopyWith<AccountDeletionBlocker> get copyWith => _$AccountDeletionBlockerCopyWithImpl<AccountDeletionBlocker>(this as AccountDeletionBlocker, _$identity);

  /// Serializes this AccountDeletionBlocker to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AccountDeletionBlocker&&(identical(other.code, code) || other.code == code)&&(identical(other.count, count) || other.count == count)&&(identical(other.amountCents, amountCents) || other.amountCents == amountCents));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,code,count,amountCents);

@override
String toString() {
  return 'AccountDeletionBlocker(code: $code, count: $count, amountCents: $amountCents)';
}


}

/// @nodoc
abstract mixin class $AccountDeletionBlockerCopyWith<$Res>  {
  factory $AccountDeletionBlockerCopyWith(AccountDeletionBlocker value, $Res Function(AccountDeletionBlocker) _then) = _$AccountDeletionBlockerCopyWithImpl;
@useResult
$Res call({
@JsonKey(unknownEnumValue: AccountDeletionBlockerCode.unknown) AccountDeletionBlockerCode code, int count,@JsonKey(name: 'amount_cents') int? amountCents
});




}
/// @nodoc
class _$AccountDeletionBlockerCopyWithImpl<$Res>
    implements $AccountDeletionBlockerCopyWith<$Res> {
  _$AccountDeletionBlockerCopyWithImpl(this._self, this._then);

  final AccountDeletionBlocker _self;
  final $Res Function(AccountDeletionBlocker) _then;

/// Create a copy of AccountDeletionBlocker
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? code = null,Object? count = null,Object? amountCents = freezed,}) {
  return _then(_self.copyWith(
code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as AccountDeletionBlockerCode,count: null == count ? _self.count : count // ignore: cast_nullable_to_non_nullable
as int,amountCents: freezed == amountCents ? _self.amountCents : amountCents // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}


/// Adds pattern-matching-related methods to [AccountDeletionBlocker].
extension AccountDeletionBlockerPatterns on AccountDeletionBlocker {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AccountDeletionBlocker value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AccountDeletionBlocker() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AccountDeletionBlocker value)  $default,){
final _that = this;
switch (_that) {
case _AccountDeletionBlocker():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AccountDeletionBlocker value)?  $default,){
final _that = this;
switch (_that) {
case _AccountDeletionBlocker() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(unknownEnumValue: AccountDeletionBlockerCode.unknown)  AccountDeletionBlockerCode code,  int count, @JsonKey(name: 'amount_cents')  int? amountCents)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AccountDeletionBlocker() when $default != null:
return $default(_that.code,_that.count,_that.amountCents);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(unknownEnumValue: AccountDeletionBlockerCode.unknown)  AccountDeletionBlockerCode code,  int count, @JsonKey(name: 'amount_cents')  int? amountCents)  $default,) {final _that = this;
switch (_that) {
case _AccountDeletionBlocker():
return $default(_that.code,_that.count,_that.amountCents);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(unknownEnumValue: AccountDeletionBlockerCode.unknown)  AccountDeletionBlockerCode code,  int count, @JsonKey(name: 'amount_cents')  int? amountCents)?  $default,) {final _that = this;
switch (_that) {
case _AccountDeletionBlocker() when $default != null:
return $default(_that.code,_that.count,_that.amountCents);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AccountDeletionBlocker extends AccountDeletionBlocker {
  const _AccountDeletionBlocker({@JsonKey(unknownEnumValue: AccountDeletionBlockerCode.unknown) required this.code, this.count = 1, @JsonKey(name: 'amount_cents') this.amountCents}): super._();
  factory _AccountDeletionBlocker.fromJson(Map<String, dynamic> json) => _$AccountDeletionBlockerFromJson(json);

@override@JsonKey(unknownEnumValue: AccountDeletionBlockerCode.unknown) final  AccountDeletionBlockerCode code;
@override@JsonKey() final  int count;
/// Money still in the provider's Stripe balance (stripe_balance only).
@override@JsonKey(name: 'amount_cents') final  int? amountCents;

/// Create a copy of AccountDeletionBlocker
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AccountDeletionBlockerCopyWith<_AccountDeletionBlocker> get copyWith => __$AccountDeletionBlockerCopyWithImpl<_AccountDeletionBlocker>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AccountDeletionBlockerToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AccountDeletionBlocker&&(identical(other.code, code) || other.code == code)&&(identical(other.count, count) || other.count == count)&&(identical(other.amountCents, amountCents) || other.amountCents == amountCents));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,code,count,amountCents);

@override
String toString() {
  return 'AccountDeletionBlocker(code: $code, count: $count, amountCents: $amountCents)';
}


}

/// @nodoc
abstract mixin class _$AccountDeletionBlockerCopyWith<$Res> implements $AccountDeletionBlockerCopyWith<$Res> {
  factory _$AccountDeletionBlockerCopyWith(_AccountDeletionBlocker value, $Res Function(_AccountDeletionBlocker) _then) = __$AccountDeletionBlockerCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(unknownEnumValue: AccountDeletionBlockerCode.unknown) AccountDeletionBlockerCode code, int count,@JsonKey(name: 'amount_cents') int? amountCents
});




}
/// @nodoc
class __$AccountDeletionBlockerCopyWithImpl<$Res>
    implements _$AccountDeletionBlockerCopyWith<$Res> {
  __$AccountDeletionBlockerCopyWithImpl(this._self, this._then);

  final _AccountDeletionBlocker _self;
  final $Res Function(_AccountDeletionBlocker) _then;

/// Create a copy of AccountDeletionBlocker
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? code = null,Object? count = null,Object? amountCents = freezed,}) {
  return _then(_AccountDeletionBlocker(
code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as AccountDeletionBlockerCode,count: null == count ? _self.count : count // ignore: cast_nullable_to_non_nullable
as int,amountCents: freezed == amountCents ? _self.amountCents : amountCents // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}


/// @nodoc
mixin _$AccountDeletionStatus {

 String? get role; List<AccountDeletionBlocker> get blockers;/// A Stripe payout account that will be closed with the Myglo account.
@JsonKey(name: 'has_payout_account') bool get hasPayoutAccount;
/// Create a copy of AccountDeletionStatus
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AccountDeletionStatusCopyWith<AccountDeletionStatus> get copyWith => _$AccountDeletionStatusCopyWithImpl<AccountDeletionStatus>(this as AccountDeletionStatus, _$identity);

  /// Serializes this AccountDeletionStatus to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AccountDeletionStatus&&(identical(other.role, role) || other.role == role)&&const DeepCollectionEquality().equals(other.blockers, blockers)&&(identical(other.hasPayoutAccount, hasPayoutAccount) || other.hasPayoutAccount == hasPayoutAccount));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,role,const DeepCollectionEquality().hash(blockers),hasPayoutAccount);

@override
String toString() {
  return 'AccountDeletionStatus(role: $role, blockers: $blockers, hasPayoutAccount: $hasPayoutAccount)';
}


}

/// @nodoc
abstract mixin class $AccountDeletionStatusCopyWith<$Res>  {
  factory $AccountDeletionStatusCopyWith(AccountDeletionStatus value, $Res Function(AccountDeletionStatus) _then) = _$AccountDeletionStatusCopyWithImpl;
@useResult
$Res call({
 String? role, List<AccountDeletionBlocker> blockers,@JsonKey(name: 'has_payout_account') bool hasPayoutAccount
});




}
/// @nodoc
class _$AccountDeletionStatusCopyWithImpl<$Res>
    implements $AccountDeletionStatusCopyWith<$Res> {
  _$AccountDeletionStatusCopyWithImpl(this._self, this._then);

  final AccountDeletionStatus _self;
  final $Res Function(AccountDeletionStatus) _then;

/// Create a copy of AccountDeletionStatus
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? role = freezed,Object? blockers = null,Object? hasPayoutAccount = null,}) {
  return _then(_self.copyWith(
role: freezed == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as String?,blockers: null == blockers ? _self.blockers : blockers // ignore: cast_nullable_to_non_nullable
as List<AccountDeletionBlocker>,hasPayoutAccount: null == hasPayoutAccount ? _self.hasPayoutAccount : hasPayoutAccount // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [AccountDeletionStatus].
extension AccountDeletionStatusPatterns on AccountDeletionStatus {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AccountDeletionStatus value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AccountDeletionStatus() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AccountDeletionStatus value)  $default,){
final _that = this;
switch (_that) {
case _AccountDeletionStatus():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AccountDeletionStatus value)?  $default,){
final _that = this;
switch (_that) {
case _AccountDeletionStatus() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String? role,  List<AccountDeletionBlocker> blockers, @JsonKey(name: 'has_payout_account')  bool hasPayoutAccount)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AccountDeletionStatus() when $default != null:
return $default(_that.role,_that.blockers,_that.hasPayoutAccount);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String? role,  List<AccountDeletionBlocker> blockers, @JsonKey(name: 'has_payout_account')  bool hasPayoutAccount)  $default,) {final _that = this;
switch (_that) {
case _AccountDeletionStatus():
return $default(_that.role,_that.blockers,_that.hasPayoutAccount);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String? role,  List<AccountDeletionBlocker> blockers, @JsonKey(name: 'has_payout_account')  bool hasPayoutAccount)?  $default,) {final _that = this;
switch (_that) {
case _AccountDeletionStatus() when $default != null:
return $default(_that.role,_that.blockers,_that.hasPayoutAccount);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AccountDeletionStatus extends AccountDeletionStatus {
  const _AccountDeletionStatus({this.role, final  List<AccountDeletionBlocker> blockers = const [], @JsonKey(name: 'has_payout_account') this.hasPayoutAccount = false}): _blockers = blockers,super._();
  factory _AccountDeletionStatus.fromJson(Map<String, dynamic> json) => _$AccountDeletionStatusFromJson(json);

@override final  String? role;
 final  List<AccountDeletionBlocker> _blockers;
@override@JsonKey() List<AccountDeletionBlocker> get blockers {
  if (_blockers is EqualUnmodifiableListView) return _blockers;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_blockers);
}

/// A Stripe payout account that will be closed with the Myglo account.
@override@JsonKey(name: 'has_payout_account') final  bool hasPayoutAccount;

/// Create a copy of AccountDeletionStatus
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AccountDeletionStatusCopyWith<_AccountDeletionStatus> get copyWith => __$AccountDeletionStatusCopyWithImpl<_AccountDeletionStatus>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AccountDeletionStatusToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AccountDeletionStatus&&(identical(other.role, role) || other.role == role)&&const DeepCollectionEquality().equals(other._blockers, _blockers)&&(identical(other.hasPayoutAccount, hasPayoutAccount) || other.hasPayoutAccount == hasPayoutAccount));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,role,const DeepCollectionEquality().hash(_blockers),hasPayoutAccount);

@override
String toString() {
  return 'AccountDeletionStatus(role: $role, blockers: $blockers, hasPayoutAccount: $hasPayoutAccount)';
}


}

/// @nodoc
abstract mixin class _$AccountDeletionStatusCopyWith<$Res> implements $AccountDeletionStatusCopyWith<$Res> {
  factory _$AccountDeletionStatusCopyWith(_AccountDeletionStatus value, $Res Function(_AccountDeletionStatus) _then) = __$AccountDeletionStatusCopyWithImpl;
@override @useResult
$Res call({
 String? role, List<AccountDeletionBlocker> blockers,@JsonKey(name: 'has_payout_account') bool hasPayoutAccount
});




}
/// @nodoc
class __$AccountDeletionStatusCopyWithImpl<$Res>
    implements _$AccountDeletionStatusCopyWith<$Res> {
  __$AccountDeletionStatusCopyWithImpl(this._self, this._then);

  final _AccountDeletionStatus _self;
  final $Res Function(_AccountDeletionStatus) _then;

/// Create a copy of AccountDeletionStatus
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? role = freezed,Object? blockers = null,Object? hasPayoutAccount = null,}) {
  return _then(_AccountDeletionStatus(
role: freezed == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as String?,blockers: null == blockers ? _self._blockers : blockers // ignore: cast_nullable_to_non_nullable
as List<AccountDeletionBlocker>,hasPayoutAccount: null == hasPayoutAccount ? _self.hasPayoutAccount : hasPayoutAccount // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
