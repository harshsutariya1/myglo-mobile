// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'booking_draft.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$BookingDraft {

/// Idempotency key for `create_booking`. Renewed whenever the booking
/// changes, so a retry of the same booking can never become a different
/// one.
 String get attemptId; AvailableSlot? get slot; BookingLocationType? get locationType; ClientAddress? get address;/// Where [address] was located, once it passed the travel-area check.
 GeoPoint? get verifiedPoint; double? get distanceKm; String get accessNotes;/// Contact number for this booking; null until the client edits it (the
/// profile's number is used until then).
 String? get phone; String get notes; PaymentMethod get paymentMethod;
/// Create a copy of BookingDraft
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BookingDraftCopyWith<BookingDraft> get copyWith => _$BookingDraftCopyWithImpl<BookingDraft>(this as BookingDraft, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BookingDraft&&(identical(other.attemptId, attemptId) || other.attemptId == attemptId)&&(identical(other.slot, slot) || other.slot == slot)&&(identical(other.locationType, locationType) || other.locationType == locationType)&&(identical(other.address, address) || other.address == address)&&(identical(other.verifiedPoint, verifiedPoint) || other.verifiedPoint == verifiedPoint)&&(identical(other.distanceKm, distanceKm) || other.distanceKm == distanceKm)&&(identical(other.accessNotes, accessNotes) || other.accessNotes == accessNotes)&&(identical(other.phone, phone) || other.phone == phone)&&(identical(other.notes, notes) || other.notes == notes)&&(identical(other.paymentMethod, paymentMethod) || other.paymentMethod == paymentMethod));
}


@override
int get hashCode => Object.hash(runtimeType,attemptId,slot,locationType,address,verifiedPoint,distanceKm,accessNotes,phone,notes,paymentMethod);

@override
String toString() {
  return 'BookingDraft(attemptId: $attemptId, slot: $slot, locationType: $locationType, address: $address, verifiedPoint: $verifiedPoint, distanceKm: $distanceKm, accessNotes: $accessNotes, phone: $phone, notes: $notes, paymentMethod: $paymentMethod)';
}


}

/// @nodoc
abstract mixin class $BookingDraftCopyWith<$Res>  {
  factory $BookingDraftCopyWith(BookingDraft value, $Res Function(BookingDraft) _then) = _$BookingDraftCopyWithImpl;
@useResult
$Res call({
 String attemptId, AvailableSlot? slot, BookingLocationType? locationType, ClientAddress? address, GeoPoint? verifiedPoint, double? distanceKm, String accessNotes, String? phone, String notes, PaymentMethod paymentMethod
});




}
/// @nodoc
class _$BookingDraftCopyWithImpl<$Res>
    implements $BookingDraftCopyWith<$Res> {
  _$BookingDraftCopyWithImpl(this._self, this._then);

  final BookingDraft _self;
  final $Res Function(BookingDraft) _then;

/// Create a copy of BookingDraft
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? attemptId = null,Object? slot = freezed,Object? locationType = freezed,Object? address = freezed,Object? verifiedPoint = freezed,Object? distanceKm = freezed,Object? accessNotes = null,Object? phone = freezed,Object? notes = null,Object? paymentMethod = null,}) {
  return _then(_self.copyWith(
attemptId: null == attemptId ? _self.attemptId : attemptId // ignore: cast_nullable_to_non_nullable
as String,slot: freezed == slot ? _self.slot : slot // ignore: cast_nullable_to_non_nullable
as AvailableSlot?,locationType: freezed == locationType ? _self.locationType : locationType // ignore: cast_nullable_to_non_nullable
as BookingLocationType?,address: freezed == address ? _self.address : address // ignore: cast_nullable_to_non_nullable
as ClientAddress?,verifiedPoint: freezed == verifiedPoint ? _self.verifiedPoint : verifiedPoint // ignore: cast_nullable_to_non_nullable
as GeoPoint?,distanceKm: freezed == distanceKm ? _self.distanceKm : distanceKm // ignore: cast_nullable_to_non_nullable
as double?,accessNotes: null == accessNotes ? _self.accessNotes : accessNotes // ignore: cast_nullable_to_non_nullable
as String,phone: freezed == phone ? _self.phone : phone // ignore: cast_nullable_to_non_nullable
as String?,notes: null == notes ? _self.notes : notes // ignore: cast_nullable_to_non_nullable
as String,paymentMethod: null == paymentMethod ? _self.paymentMethod : paymentMethod // ignore: cast_nullable_to_non_nullable
as PaymentMethod,
  ));
}

}


/// Adds pattern-matching-related methods to [BookingDraft].
extension BookingDraftPatterns on BookingDraft {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _BookingDraft value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _BookingDraft() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _BookingDraft value)  $default,){
final _that = this;
switch (_that) {
case _BookingDraft():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _BookingDraft value)?  $default,){
final _that = this;
switch (_that) {
case _BookingDraft() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String attemptId,  AvailableSlot? slot,  BookingLocationType? locationType,  ClientAddress? address,  GeoPoint? verifiedPoint,  double? distanceKm,  String accessNotes,  String? phone,  String notes,  PaymentMethod paymentMethod)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _BookingDraft() when $default != null:
return $default(_that.attemptId,_that.slot,_that.locationType,_that.address,_that.verifiedPoint,_that.distanceKm,_that.accessNotes,_that.phone,_that.notes,_that.paymentMethod);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String attemptId,  AvailableSlot? slot,  BookingLocationType? locationType,  ClientAddress? address,  GeoPoint? verifiedPoint,  double? distanceKm,  String accessNotes,  String? phone,  String notes,  PaymentMethod paymentMethod)  $default,) {final _that = this;
switch (_that) {
case _BookingDraft():
return $default(_that.attemptId,_that.slot,_that.locationType,_that.address,_that.verifiedPoint,_that.distanceKm,_that.accessNotes,_that.phone,_that.notes,_that.paymentMethod);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String attemptId,  AvailableSlot? slot,  BookingLocationType? locationType,  ClientAddress? address,  GeoPoint? verifiedPoint,  double? distanceKm,  String accessNotes,  String? phone,  String notes,  PaymentMethod paymentMethod)?  $default,) {final _that = this;
switch (_that) {
case _BookingDraft() when $default != null:
return $default(_that.attemptId,_that.slot,_that.locationType,_that.address,_that.verifiedPoint,_that.distanceKm,_that.accessNotes,_that.phone,_that.notes,_that.paymentMethod);case _:
  return null;

}
}

}

/// @nodoc


class _BookingDraft extends BookingDraft {
  const _BookingDraft({required this.attemptId, this.slot, this.locationType, this.address, this.verifiedPoint, this.distanceKm, this.accessNotes = '', this.phone, this.notes = '', this.paymentMethod = PaymentMethod.cash}): super._();
  

/// Idempotency key for `create_booking`. Renewed whenever the booking
/// changes, so a retry of the same booking can never become a different
/// one.
@override final  String attemptId;
@override final  AvailableSlot? slot;
@override final  BookingLocationType? locationType;
@override final  ClientAddress? address;
/// Where [address] was located, once it passed the travel-area check.
@override final  GeoPoint? verifiedPoint;
@override final  double? distanceKm;
@override@JsonKey() final  String accessNotes;
/// Contact number for this booking; null until the client edits it (the
/// profile's number is used until then).
@override final  String? phone;
@override@JsonKey() final  String notes;
@override@JsonKey() final  PaymentMethod paymentMethod;

/// Create a copy of BookingDraft
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BookingDraftCopyWith<_BookingDraft> get copyWith => __$BookingDraftCopyWithImpl<_BookingDraft>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _BookingDraft&&(identical(other.attemptId, attemptId) || other.attemptId == attemptId)&&(identical(other.slot, slot) || other.slot == slot)&&(identical(other.locationType, locationType) || other.locationType == locationType)&&(identical(other.address, address) || other.address == address)&&(identical(other.verifiedPoint, verifiedPoint) || other.verifiedPoint == verifiedPoint)&&(identical(other.distanceKm, distanceKm) || other.distanceKm == distanceKm)&&(identical(other.accessNotes, accessNotes) || other.accessNotes == accessNotes)&&(identical(other.phone, phone) || other.phone == phone)&&(identical(other.notes, notes) || other.notes == notes)&&(identical(other.paymentMethod, paymentMethod) || other.paymentMethod == paymentMethod));
}


@override
int get hashCode => Object.hash(runtimeType,attemptId,slot,locationType,address,verifiedPoint,distanceKm,accessNotes,phone,notes,paymentMethod);

@override
String toString() {
  return 'BookingDraft(attemptId: $attemptId, slot: $slot, locationType: $locationType, address: $address, verifiedPoint: $verifiedPoint, distanceKm: $distanceKm, accessNotes: $accessNotes, phone: $phone, notes: $notes, paymentMethod: $paymentMethod)';
}


}

/// @nodoc
abstract mixin class _$BookingDraftCopyWith<$Res> implements $BookingDraftCopyWith<$Res> {
  factory _$BookingDraftCopyWith(_BookingDraft value, $Res Function(_BookingDraft) _then) = __$BookingDraftCopyWithImpl;
@override @useResult
$Res call({
 String attemptId, AvailableSlot? slot, BookingLocationType? locationType, ClientAddress? address, GeoPoint? verifiedPoint, double? distanceKm, String accessNotes, String? phone, String notes, PaymentMethod paymentMethod
});




}
/// @nodoc
class __$BookingDraftCopyWithImpl<$Res>
    implements _$BookingDraftCopyWith<$Res> {
  __$BookingDraftCopyWithImpl(this._self, this._then);

  final _BookingDraft _self;
  final $Res Function(_BookingDraft) _then;

/// Create a copy of BookingDraft
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? attemptId = null,Object? slot = freezed,Object? locationType = freezed,Object? address = freezed,Object? verifiedPoint = freezed,Object? distanceKm = freezed,Object? accessNotes = null,Object? phone = freezed,Object? notes = null,Object? paymentMethod = null,}) {
  return _then(_BookingDraft(
attemptId: null == attemptId ? _self.attemptId : attemptId // ignore: cast_nullable_to_non_nullable
as String,slot: freezed == slot ? _self.slot : slot // ignore: cast_nullable_to_non_nullable
as AvailableSlot?,locationType: freezed == locationType ? _self.locationType : locationType // ignore: cast_nullable_to_non_nullable
as BookingLocationType?,address: freezed == address ? _self.address : address // ignore: cast_nullable_to_non_nullable
as ClientAddress?,verifiedPoint: freezed == verifiedPoint ? _self.verifiedPoint : verifiedPoint // ignore: cast_nullable_to_non_nullable
as GeoPoint?,distanceKm: freezed == distanceKm ? _self.distanceKm : distanceKm // ignore: cast_nullable_to_non_nullable
as double?,accessNotes: null == accessNotes ? _self.accessNotes : accessNotes // ignore: cast_nullable_to_non_nullable
as String,phone: freezed == phone ? _self.phone : phone // ignore: cast_nullable_to_non_nullable
as String?,notes: null == notes ? _self.notes : notes // ignore: cast_nullable_to_non_nullable
as String,paymentMethod: null == paymentMethod ? _self.paymentMethod : paymentMethod // ignore: cast_nullable_to_non_nullable
as PaymentMethod,
  ));
}


}

// dart format on
