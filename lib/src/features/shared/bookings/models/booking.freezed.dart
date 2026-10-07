// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'booking.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$BookingItem {

@JsonKey(name: 'service_id') String? get serviceId; String get name; String? get category;@JsonKey(name: 'duration_minutes') int get durationMinutes;@JsonKey(name: 'price_cents') int get priceCents;
/// Create a copy of BookingItem
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BookingItemCopyWith<BookingItem> get copyWith => _$BookingItemCopyWithImpl<BookingItem>(this as BookingItem, _$identity);

  /// Serializes this BookingItem to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BookingItem&&(identical(other.serviceId, serviceId) || other.serviceId == serviceId)&&(identical(other.name, name) || other.name == name)&&(identical(other.category, category) || other.category == category)&&(identical(other.durationMinutes, durationMinutes) || other.durationMinutes == durationMinutes)&&(identical(other.priceCents, priceCents) || other.priceCents == priceCents));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,serviceId,name,category,durationMinutes,priceCents);

@override
String toString() {
  return 'BookingItem(serviceId: $serviceId, name: $name, category: $category, durationMinutes: $durationMinutes, priceCents: $priceCents)';
}


}

/// @nodoc
abstract mixin class $BookingItemCopyWith<$Res>  {
  factory $BookingItemCopyWith(BookingItem value, $Res Function(BookingItem) _then) = _$BookingItemCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'service_id') String? serviceId, String name, String? category,@JsonKey(name: 'duration_minutes') int durationMinutes,@JsonKey(name: 'price_cents') int priceCents
});




}
/// @nodoc
class _$BookingItemCopyWithImpl<$Res>
    implements $BookingItemCopyWith<$Res> {
  _$BookingItemCopyWithImpl(this._self, this._then);

  final BookingItem _self;
  final $Res Function(BookingItem) _then;

/// Create a copy of BookingItem
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? serviceId = freezed,Object? name = null,Object? category = freezed,Object? durationMinutes = null,Object? priceCents = null,}) {
  return _then(_self.copyWith(
serviceId: freezed == serviceId ? _self.serviceId : serviceId // ignore: cast_nullable_to_non_nullable
as String?,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,category: freezed == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as String?,durationMinutes: null == durationMinutes ? _self.durationMinutes : durationMinutes // ignore: cast_nullable_to_non_nullable
as int,priceCents: null == priceCents ? _self.priceCents : priceCents // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [BookingItem].
extension BookingItemPatterns on BookingItem {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _BookingItem value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _BookingItem() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _BookingItem value)  $default,){
final _that = this;
switch (_that) {
case _BookingItem():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _BookingItem value)?  $default,){
final _that = this;
switch (_that) {
case _BookingItem() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'service_id')  String? serviceId,  String name,  String? category, @JsonKey(name: 'duration_minutes')  int durationMinutes, @JsonKey(name: 'price_cents')  int priceCents)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _BookingItem() when $default != null:
return $default(_that.serviceId,_that.name,_that.category,_that.durationMinutes,_that.priceCents);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'service_id')  String? serviceId,  String name,  String? category, @JsonKey(name: 'duration_minutes')  int durationMinutes, @JsonKey(name: 'price_cents')  int priceCents)  $default,) {final _that = this;
switch (_that) {
case _BookingItem():
return $default(_that.serviceId,_that.name,_that.category,_that.durationMinutes,_that.priceCents);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'service_id')  String? serviceId,  String name,  String? category, @JsonKey(name: 'duration_minutes')  int durationMinutes, @JsonKey(name: 'price_cents')  int priceCents)?  $default,) {final _that = this;
switch (_that) {
case _BookingItem() when $default != null:
return $default(_that.serviceId,_that.name,_that.category,_that.durationMinutes,_that.priceCents);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _BookingItem implements BookingItem {
  const _BookingItem({@JsonKey(name: 'service_id') this.serviceId, required this.name, this.category, @JsonKey(name: 'duration_minutes') required this.durationMinutes, @JsonKey(name: 'price_cents') required this.priceCents});
  factory _BookingItem.fromJson(Map<String, dynamic> json) => _$BookingItemFromJson(json);

@override@JsonKey(name: 'service_id') final  String? serviceId;
@override final  String name;
@override final  String? category;
@override@JsonKey(name: 'duration_minutes') final  int durationMinutes;
@override@JsonKey(name: 'price_cents') final  int priceCents;

/// Create a copy of BookingItem
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BookingItemCopyWith<_BookingItem> get copyWith => __$BookingItemCopyWithImpl<_BookingItem>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$BookingItemToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _BookingItem&&(identical(other.serviceId, serviceId) || other.serviceId == serviceId)&&(identical(other.name, name) || other.name == name)&&(identical(other.category, category) || other.category == category)&&(identical(other.durationMinutes, durationMinutes) || other.durationMinutes == durationMinutes)&&(identical(other.priceCents, priceCents) || other.priceCents == priceCents));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,serviceId,name,category,durationMinutes,priceCents);

@override
String toString() {
  return 'BookingItem(serviceId: $serviceId, name: $name, category: $category, durationMinutes: $durationMinutes, priceCents: $priceCents)';
}


}

/// @nodoc
abstract mixin class _$BookingItemCopyWith<$Res> implements $BookingItemCopyWith<$Res> {
  factory _$BookingItemCopyWith(_BookingItem value, $Res Function(_BookingItem) _then) = __$BookingItemCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'service_id') String? serviceId, String name, String? category,@JsonKey(name: 'duration_minutes') int durationMinutes,@JsonKey(name: 'price_cents') int priceCents
});




}
/// @nodoc
class __$BookingItemCopyWithImpl<$Res>
    implements _$BookingItemCopyWith<$Res> {
  __$BookingItemCopyWithImpl(this._self, this._then);

  final _BookingItem _self;
  final $Res Function(_BookingItem) _then;

/// Create a copy of BookingItem
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? serviceId = freezed,Object? name = null,Object? category = freezed,Object? durationMinutes = null,Object? priceCents = null,}) {
  return _then(_BookingItem(
serviceId: freezed == serviceId ? _self.serviceId : serviceId // ignore: cast_nullable_to_non_nullable
as String?,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,category: freezed == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as String?,durationMinutes: null == durationMinutes ? _self.durationMinutes : durationMinutes // ignore: cast_nullable_to_non_nullable
as int,priceCents: null == priceCents ? _self.priceCents : priceCents // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$Booking {

 String get id; String get reference;@JsonKey(name: 'client_id') String? get clientId;@JsonKey(name: 'provider_id') String? get providerId; BookingStatus get status;@JsonKey(name: 'starts_at') DateTime get startsAt;@JsonKey(name: 'ends_at') DateTime get endsAt;@JsonKey(name: 'time_zone') String get timeZone;@WallClockConverter()@JsonKey(name: 'starts_at_local') DateTime get startsAtLocal;@WallClockConverter()@JsonKey(name: 'ends_at_local') DateTime get endsAtLocal;@JsonKey(name: 'duration_minutes') int get durationMinutes;@JsonKey(name: 'location_type') BookingLocationType get locationType;@JsonKey(name: 'address_text') String get addressText; ClientAddress? get address;@JsonKey(name: 'access_notes') String? get accessNotes; double? get latitude; double? get longitude;@JsonKey(name: 'distance_km') double? get distanceKm;@JsonKey(name: 'provider_name') String get providerName;@JsonKey(name: 'provider_avatar_url') String? get providerAvatarUrl;@JsonKey(name: 'client_name') String get clientName;@JsonKey(name: 'client_avatar_url') String? get clientAvatarUrl;@JsonKey(name: 'client_phone') String get clientPhone;@JsonKey(name: 'client_notes') String? get clientNotes;@JsonKey(name: 'subtotal_cents') int get subtotalCents;@JsonKey(name: 'total_cents') int get totalCents; String get currency;@JsonKey(name: 'payment_method') PaymentMethod get paymentMethod;@JsonKey(name: 'payment_status') PaymentStatus get paymentStatus;@JsonKey(name: 'requires_approval') bool get requiresApproval;@JsonKey(name: 'cancellation_window_hours') int get cancellationWindowHours;@JsonKey(name: 'cancellation_fee_percent') int get cancellationFeePercent;@JsonKey(name: 'free_cancellation_until') DateTime get freeCancellationUntil;@JsonKey(name: 'decline_reason') String? get declineReason;@JsonKey(name: 'responded_at') DateTime? get respondedAt;@JsonKey(name: 'cancelled_by') CancelledBy? get cancelledBy;@JsonKey(name: 'cancellation_reason') String? get cancellationReason;@JsonKey(name: 'cancelled_at') DateTime? get cancelledAt;@JsonKey(name: 'late_cancellation') bool get lateCancellation;@JsonKey(name: 'cancellation_fee_cents') int get cancellationFeeCents;@JsonKey(name: 'completed_at') DateTime? get completedAt;@JsonKey(name: 'created_at') DateTime get createdAt;@JsonKey(name: 'updated_at') DateTime get updatedAt; List<BookingItem> get items;/// Myglo's commission on this booking. Only the provider can see it
/// (null for the client, who pays no booking fee).
@JsonKey(name: 'platform_fee_cents') int? get platformFeeCents;
/// Create a copy of Booking
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BookingCopyWith<Booking> get copyWith => _$BookingCopyWithImpl<Booking>(this as Booking, _$identity);

  /// Serializes this Booking to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Booking&&(identical(other.id, id) || other.id == id)&&(identical(other.reference, reference) || other.reference == reference)&&(identical(other.clientId, clientId) || other.clientId == clientId)&&(identical(other.providerId, providerId) || other.providerId == providerId)&&(identical(other.status, status) || other.status == status)&&(identical(other.startsAt, startsAt) || other.startsAt == startsAt)&&(identical(other.endsAt, endsAt) || other.endsAt == endsAt)&&(identical(other.timeZone, timeZone) || other.timeZone == timeZone)&&(identical(other.startsAtLocal, startsAtLocal) || other.startsAtLocal == startsAtLocal)&&(identical(other.endsAtLocal, endsAtLocal) || other.endsAtLocal == endsAtLocal)&&(identical(other.durationMinutes, durationMinutes) || other.durationMinutes == durationMinutes)&&(identical(other.locationType, locationType) || other.locationType == locationType)&&(identical(other.addressText, addressText) || other.addressText == addressText)&&(identical(other.address, address) || other.address == address)&&(identical(other.accessNotes, accessNotes) || other.accessNotes == accessNotes)&&(identical(other.latitude, latitude) || other.latitude == latitude)&&(identical(other.longitude, longitude) || other.longitude == longitude)&&(identical(other.distanceKm, distanceKm) || other.distanceKm == distanceKm)&&(identical(other.providerName, providerName) || other.providerName == providerName)&&(identical(other.providerAvatarUrl, providerAvatarUrl) || other.providerAvatarUrl == providerAvatarUrl)&&(identical(other.clientName, clientName) || other.clientName == clientName)&&(identical(other.clientAvatarUrl, clientAvatarUrl) || other.clientAvatarUrl == clientAvatarUrl)&&(identical(other.clientPhone, clientPhone) || other.clientPhone == clientPhone)&&(identical(other.clientNotes, clientNotes) || other.clientNotes == clientNotes)&&(identical(other.subtotalCents, subtotalCents) || other.subtotalCents == subtotalCents)&&(identical(other.totalCents, totalCents) || other.totalCents == totalCents)&&(identical(other.currency, currency) || other.currency == currency)&&(identical(other.paymentMethod, paymentMethod) || other.paymentMethod == paymentMethod)&&(identical(other.paymentStatus, paymentStatus) || other.paymentStatus == paymentStatus)&&(identical(other.requiresApproval, requiresApproval) || other.requiresApproval == requiresApproval)&&(identical(other.cancellationWindowHours, cancellationWindowHours) || other.cancellationWindowHours == cancellationWindowHours)&&(identical(other.cancellationFeePercent, cancellationFeePercent) || other.cancellationFeePercent == cancellationFeePercent)&&(identical(other.freeCancellationUntil, freeCancellationUntil) || other.freeCancellationUntil == freeCancellationUntil)&&(identical(other.declineReason, declineReason) || other.declineReason == declineReason)&&(identical(other.respondedAt, respondedAt) || other.respondedAt == respondedAt)&&(identical(other.cancelledBy, cancelledBy) || other.cancelledBy == cancelledBy)&&(identical(other.cancellationReason, cancellationReason) || other.cancellationReason == cancellationReason)&&(identical(other.cancelledAt, cancelledAt) || other.cancelledAt == cancelledAt)&&(identical(other.lateCancellation, lateCancellation) || other.lateCancellation == lateCancellation)&&(identical(other.cancellationFeeCents, cancellationFeeCents) || other.cancellationFeeCents == cancellationFeeCents)&&(identical(other.completedAt, completedAt) || other.completedAt == completedAt)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&const DeepCollectionEquality().equals(other.items, items)&&(identical(other.platformFeeCents, platformFeeCents) || other.platformFeeCents == platformFeeCents));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,reference,clientId,providerId,status,startsAt,endsAt,timeZone,startsAtLocal,endsAtLocal,durationMinutes,locationType,addressText,address,accessNotes,latitude,longitude,distanceKm,providerName,providerAvatarUrl,clientName,clientAvatarUrl,clientPhone,clientNotes,subtotalCents,totalCents,currency,paymentMethod,paymentStatus,requiresApproval,cancellationWindowHours,cancellationFeePercent,freeCancellationUntil,declineReason,respondedAt,cancelledBy,cancellationReason,cancelledAt,lateCancellation,cancellationFeeCents,completedAt,createdAt,updatedAt,const DeepCollectionEquality().hash(items),platformFeeCents]);

@override
String toString() {
  return 'Booking(id: $id, reference: $reference, clientId: $clientId, providerId: $providerId, status: $status, startsAt: $startsAt, endsAt: $endsAt, timeZone: $timeZone, startsAtLocal: $startsAtLocal, endsAtLocal: $endsAtLocal, durationMinutes: $durationMinutes, locationType: $locationType, addressText: $addressText, address: $address, accessNotes: $accessNotes, latitude: $latitude, longitude: $longitude, distanceKm: $distanceKm, providerName: $providerName, providerAvatarUrl: $providerAvatarUrl, clientName: $clientName, clientAvatarUrl: $clientAvatarUrl, clientPhone: $clientPhone, clientNotes: $clientNotes, subtotalCents: $subtotalCents, totalCents: $totalCents, currency: $currency, paymentMethod: $paymentMethod, paymentStatus: $paymentStatus, requiresApproval: $requiresApproval, cancellationWindowHours: $cancellationWindowHours, cancellationFeePercent: $cancellationFeePercent, freeCancellationUntil: $freeCancellationUntil, declineReason: $declineReason, respondedAt: $respondedAt, cancelledBy: $cancelledBy, cancellationReason: $cancellationReason, cancelledAt: $cancelledAt, lateCancellation: $lateCancellation, cancellationFeeCents: $cancellationFeeCents, completedAt: $completedAt, createdAt: $createdAt, updatedAt: $updatedAt, items: $items, platformFeeCents: $platformFeeCents)';
}


}

/// @nodoc
abstract mixin class $BookingCopyWith<$Res>  {
  factory $BookingCopyWith(Booking value, $Res Function(Booking) _then) = _$BookingCopyWithImpl;
@useResult
$Res call({
 String id, String reference,@JsonKey(name: 'client_id') String? clientId,@JsonKey(name: 'provider_id') String? providerId, BookingStatus status,@JsonKey(name: 'starts_at') DateTime startsAt,@JsonKey(name: 'ends_at') DateTime endsAt,@JsonKey(name: 'time_zone') String timeZone,@WallClockConverter()@JsonKey(name: 'starts_at_local') DateTime startsAtLocal,@WallClockConverter()@JsonKey(name: 'ends_at_local') DateTime endsAtLocal,@JsonKey(name: 'duration_minutes') int durationMinutes,@JsonKey(name: 'location_type') BookingLocationType locationType,@JsonKey(name: 'address_text') String addressText, ClientAddress? address,@JsonKey(name: 'access_notes') String? accessNotes, double? latitude, double? longitude,@JsonKey(name: 'distance_km') double? distanceKm,@JsonKey(name: 'provider_name') String providerName,@JsonKey(name: 'provider_avatar_url') String? providerAvatarUrl,@JsonKey(name: 'client_name') String clientName,@JsonKey(name: 'client_avatar_url') String? clientAvatarUrl,@JsonKey(name: 'client_phone') String clientPhone,@JsonKey(name: 'client_notes') String? clientNotes,@JsonKey(name: 'subtotal_cents') int subtotalCents,@JsonKey(name: 'total_cents') int totalCents, String currency,@JsonKey(name: 'payment_method') PaymentMethod paymentMethod,@JsonKey(name: 'payment_status') PaymentStatus paymentStatus,@JsonKey(name: 'requires_approval') bool requiresApproval,@JsonKey(name: 'cancellation_window_hours') int cancellationWindowHours,@JsonKey(name: 'cancellation_fee_percent') int cancellationFeePercent,@JsonKey(name: 'free_cancellation_until') DateTime freeCancellationUntil,@JsonKey(name: 'decline_reason') String? declineReason,@JsonKey(name: 'responded_at') DateTime? respondedAt,@JsonKey(name: 'cancelled_by') CancelledBy? cancelledBy,@JsonKey(name: 'cancellation_reason') String? cancellationReason,@JsonKey(name: 'cancelled_at') DateTime? cancelledAt,@JsonKey(name: 'late_cancellation') bool lateCancellation,@JsonKey(name: 'cancellation_fee_cents') int cancellationFeeCents,@JsonKey(name: 'completed_at') DateTime? completedAt,@JsonKey(name: 'created_at') DateTime createdAt,@JsonKey(name: 'updated_at') DateTime updatedAt, List<BookingItem> items,@JsonKey(name: 'platform_fee_cents') int? platformFeeCents
});




}
/// @nodoc
class _$BookingCopyWithImpl<$Res>
    implements $BookingCopyWith<$Res> {
  _$BookingCopyWithImpl(this._self, this._then);

  final Booking _self;
  final $Res Function(Booking) _then;

/// Create a copy of Booking
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? reference = null,Object? clientId = freezed,Object? providerId = freezed,Object? status = null,Object? startsAt = null,Object? endsAt = null,Object? timeZone = null,Object? startsAtLocal = null,Object? endsAtLocal = null,Object? durationMinutes = null,Object? locationType = null,Object? addressText = null,Object? address = freezed,Object? accessNotes = freezed,Object? latitude = freezed,Object? longitude = freezed,Object? distanceKm = freezed,Object? providerName = null,Object? providerAvatarUrl = freezed,Object? clientName = null,Object? clientAvatarUrl = freezed,Object? clientPhone = null,Object? clientNotes = freezed,Object? subtotalCents = null,Object? totalCents = null,Object? currency = null,Object? paymentMethod = null,Object? paymentStatus = null,Object? requiresApproval = null,Object? cancellationWindowHours = null,Object? cancellationFeePercent = null,Object? freeCancellationUntil = null,Object? declineReason = freezed,Object? respondedAt = freezed,Object? cancelledBy = freezed,Object? cancellationReason = freezed,Object? cancelledAt = freezed,Object? lateCancellation = null,Object? cancellationFeeCents = null,Object? completedAt = freezed,Object? createdAt = null,Object? updatedAt = null,Object? items = null,Object? platformFeeCents = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,reference: null == reference ? _self.reference : reference // ignore: cast_nullable_to_non_nullable
as String,clientId: freezed == clientId ? _self.clientId : clientId // ignore: cast_nullable_to_non_nullable
as String?,providerId: freezed == providerId ? _self.providerId : providerId // ignore: cast_nullable_to_non_nullable
as String?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as BookingStatus,startsAt: null == startsAt ? _self.startsAt : startsAt // ignore: cast_nullable_to_non_nullable
as DateTime,endsAt: null == endsAt ? _self.endsAt : endsAt // ignore: cast_nullable_to_non_nullable
as DateTime,timeZone: null == timeZone ? _self.timeZone : timeZone // ignore: cast_nullable_to_non_nullable
as String,startsAtLocal: null == startsAtLocal ? _self.startsAtLocal : startsAtLocal // ignore: cast_nullable_to_non_nullable
as DateTime,endsAtLocal: null == endsAtLocal ? _self.endsAtLocal : endsAtLocal // ignore: cast_nullable_to_non_nullable
as DateTime,durationMinutes: null == durationMinutes ? _self.durationMinutes : durationMinutes // ignore: cast_nullable_to_non_nullable
as int,locationType: null == locationType ? _self.locationType : locationType // ignore: cast_nullable_to_non_nullable
as BookingLocationType,addressText: null == addressText ? _self.addressText : addressText // ignore: cast_nullable_to_non_nullable
as String,address: freezed == address ? _self.address : address // ignore: cast_nullable_to_non_nullable
as ClientAddress?,accessNotes: freezed == accessNotes ? _self.accessNotes : accessNotes // ignore: cast_nullable_to_non_nullable
as String?,latitude: freezed == latitude ? _self.latitude : latitude // ignore: cast_nullable_to_non_nullable
as double?,longitude: freezed == longitude ? _self.longitude : longitude // ignore: cast_nullable_to_non_nullable
as double?,distanceKm: freezed == distanceKm ? _self.distanceKm : distanceKm // ignore: cast_nullable_to_non_nullable
as double?,providerName: null == providerName ? _self.providerName : providerName // ignore: cast_nullable_to_non_nullable
as String,providerAvatarUrl: freezed == providerAvatarUrl ? _self.providerAvatarUrl : providerAvatarUrl // ignore: cast_nullable_to_non_nullable
as String?,clientName: null == clientName ? _self.clientName : clientName // ignore: cast_nullable_to_non_nullable
as String,clientAvatarUrl: freezed == clientAvatarUrl ? _self.clientAvatarUrl : clientAvatarUrl // ignore: cast_nullable_to_non_nullable
as String?,clientPhone: null == clientPhone ? _self.clientPhone : clientPhone // ignore: cast_nullable_to_non_nullable
as String,clientNotes: freezed == clientNotes ? _self.clientNotes : clientNotes // ignore: cast_nullable_to_non_nullable
as String?,subtotalCents: null == subtotalCents ? _self.subtotalCents : subtotalCents // ignore: cast_nullable_to_non_nullable
as int,totalCents: null == totalCents ? _self.totalCents : totalCents // ignore: cast_nullable_to_non_nullable
as int,currency: null == currency ? _self.currency : currency // ignore: cast_nullable_to_non_nullable
as String,paymentMethod: null == paymentMethod ? _self.paymentMethod : paymentMethod // ignore: cast_nullable_to_non_nullable
as PaymentMethod,paymentStatus: null == paymentStatus ? _self.paymentStatus : paymentStatus // ignore: cast_nullable_to_non_nullable
as PaymentStatus,requiresApproval: null == requiresApproval ? _self.requiresApproval : requiresApproval // ignore: cast_nullable_to_non_nullable
as bool,cancellationWindowHours: null == cancellationWindowHours ? _self.cancellationWindowHours : cancellationWindowHours // ignore: cast_nullable_to_non_nullable
as int,cancellationFeePercent: null == cancellationFeePercent ? _self.cancellationFeePercent : cancellationFeePercent // ignore: cast_nullable_to_non_nullable
as int,freeCancellationUntil: null == freeCancellationUntil ? _self.freeCancellationUntil : freeCancellationUntil // ignore: cast_nullable_to_non_nullable
as DateTime,declineReason: freezed == declineReason ? _self.declineReason : declineReason // ignore: cast_nullable_to_non_nullable
as String?,respondedAt: freezed == respondedAt ? _self.respondedAt : respondedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,cancelledBy: freezed == cancelledBy ? _self.cancelledBy : cancelledBy // ignore: cast_nullable_to_non_nullable
as CancelledBy?,cancellationReason: freezed == cancellationReason ? _self.cancellationReason : cancellationReason // ignore: cast_nullable_to_non_nullable
as String?,cancelledAt: freezed == cancelledAt ? _self.cancelledAt : cancelledAt // ignore: cast_nullable_to_non_nullable
as DateTime?,lateCancellation: null == lateCancellation ? _self.lateCancellation : lateCancellation // ignore: cast_nullable_to_non_nullable
as bool,cancellationFeeCents: null == cancellationFeeCents ? _self.cancellationFeeCents : cancellationFeeCents // ignore: cast_nullable_to_non_nullable
as int,completedAt: freezed == completedAt ? _self.completedAt : completedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,items: null == items ? _self.items : items // ignore: cast_nullable_to_non_nullable
as List<BookingItem>,platformFeeCents: freezed == platformFeeCents ? _self.platformFeeCents : platformFeeCents // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}


/// Adds pattern-matching-related methods to [Booking].
extension BookingPatterns on Booking {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Booking value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Booking() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Booking value)  $default,){
final _that = this;
switch (_that) {
case _Booking():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Booking value)?  $default,){
final _that = this;
switch (_that) {
case _Booking() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String reference, @JsonKey(name: 'client_id')  String? clientId, @JsonKey(name: 'provider_id')  String? providerId,  BookingStatus status, @JsonKey(name: 'starts_at')  DateTime startsAt, @JsonKey(name: 'ends_at')  DateTime endsAt, @JsonKey(name: 'time_zone')  String timeZone, @WallClockConverter()@JsonKey(name: 'starts_at_local')  DateTime startsAtLocal, @WallClockConverter()@JsonKey(name: 'ends_at_local')  DateTime endsAtLocal, @JsonKey(name: 'duration_minutes')  int durationMinutes, @JsonKey(name: 'location_type')  BookingLocationType locationType, @JsonKey(name: 'address_text')  String addressText,  ClientAddress? address, @JsonKey(name: 'access_notes')  String? accessNotes,  double? latitude,  double? longitude, @JsonKey(name: 'distance_km')  double? distanceKm, @JsonKey(name: 'provider_name')  String providerName, @JsonKey(name: 'provider_avatar_url')  String? providerAvatarUrl, @JsonKey(name: 'client_name')  String clientName, @JsonKey(name: 'client_avatar_url')  String? clientAvatarUrl, @JsonKey(name: 'client_phone')  String clientPhone, @JsonKey(name: 'client_notes')  String? clientNotes, @JsonKey(name: 'subtotal_cents')  int subtotalCents, @JsonKey(name: 'total_cents')  int totalCents,  String currency, @JsonKey(name: 'payment_method')  PaymentMethod paymentMethod, @JsonKey(name: 'payment_status')  PaymentStatus paymentStatus, @JsonKey(name: 'requires_approval')  bool requiresApproval, @JsonKey(name: 'cancellation_window_hours')  int cancellationWindowHours, @JsonKey(name: 'cancellation_fee_percent')  int cancellationFeePercent, @JsonKey(name: 'free_cancellation_until')  DateTime freeCancellationUntil, @JsonKey(name: 'decline_reason')  String? declineReason, @JsonKey(name: 'responded_at')  DateTime? respondedAt, @JsonKey(name: 'cancelled_by')  CancelledBy? cancelledBy, @JsonKey(name: 'cancellation_reason')  String? cancellationReason, @JsonKey(name: 'cancelled_at')  DateTime? cancelledAt, @JsonKey(name: 'late_cancellation')  bool lateCancellation, @JsonKey(name: 'cancellation_fee_cents')  int cancellationFeeCents, @JsonKey(name: 'completed_at')  DateTime? completedAt, @JsonKey(name: 'created_at')  DateTime createdAt, @JsonKey(name: 'updated_at')  DateTime updatedAt,  List<BookingItem> items, @JsonKey(name: 'platform_fee_cents')  int? platformFeeCents)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Booking() when $default != null:
return $default(_that.id,_that.reference,_that.clientId,_that.providerId,_that.status,_that.startsAt,_that.endsAt,_that.timeZone,_that.startsAtLocal,_that.endsAtLocal,_that.durationMinutes,_that.locationType,_that.addressText,_that.address,_that.accessNotes,_that.latitude,_that.longitude,_that.distanceKm,_that.providerName,_that.providerAvatarUrl,_that.clientName,_that.clientAvatarUrl,_that.clientPhone,_that.clientNotes,_that.subtotalCents,_that.totalCents,_that.currency,_that.paymentMethod,_that.paymentStatus,_that.requiresApproval,_that.cancellationWindowHours,_that.cancellationFeePercent,_that.freeCancellationUntil,_that.declineReason,_that.respondedAt,_that.cancelledBy,_that.cancellationReason,_that.cancelledAt,_that.lateCancellation,_that.cancellationFeeCents,_that.completedAt,_that.createdAt,_that.updatedAt,_that.items,_that.platformFeeCents);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String reference, @JsonKey(name: 'client_id')  String? clientId, @JsonKey(name: 'provider_id')  String? providerId,  BookingStatus status, @JsonKey(name: 'starts_at')  DateTime startsAt, @JsonKey(name: 'ends_at')  DateTime endsAt, @JsonKey(name: 'time_zone')  String timeZone, @WallClockConverter()@JsonKey(name: 'starts_at_local')  DateTime startsAtLocal, @WallClockConverter()@JsonKey(name: 'ends_at_local')  DateTime endsAtLocal, @JsonKey(name: 'duration_minutes')  int durationMinutes, @JsonKey(name: 'location_type')  BookingLocationType locationType, @JsonKey(name: 'address_text')  String addressText,  ClientAddress? address, @JsonKey(name: 'access_notes')  String? accessNotes,  double? latitude,  double? longitude, @JsonKey(name: 'distance_km')  double? distanceKm, @JsonKey(name: 'provider_name')  String providerName, @JsonKey(name: 'provider_avatar_url')  String? providerAvatarUrl, @JsonKey(name: 'client_name')  String clientName, @JsonKey(name: 'client_avatar_url')  String? clientAvatarUrl, @JsonKey(name: 'client_phone')  String clientPhone, @JsonKey(name: 'client_notes')  String? clientNotes, @JsonKey(name: 'subtotal_cents')  int subtotalCents, @JsonKey(name: 'total_cents')  int totalCents,  String currency, @JsonKey(name: 'payment_method')  PaymentMethod paymentMethod, @JsonKey(name: 'payment_status')  PaymentStatus paymentStatus, @JsonKey(name: 'requires_approval')  bool requiresApproval, @JsonKey(name: 'cancellation_window_hours')  int cancellationWindowHours, @JsonKey(name: 'cancellation_fee_percent')  int cancellationFeePercent, @JsonKey(name: 'free_cancellation_until')  DateTime freeCancellationUntil, @JsonKey(name: 'decline_reason')  String? declineReason, @JsonKey(name: 'responded_at')  DateTime? respondedAt, @JsonKey(name: 'cancelled_by')  CancelledBy? cancelledBy, @JsonKey(name: 'cancellation_reason')  String? cancellationReason, @JsonKey(name: 'cancelled_at')  DateTime? cancelledAt, @JsonKey(name: 'late_cancellation')  bool lateCancellation, @JsonKey(name: 'cancellation_fee_cents')  int cancellationFeeCents, @JsonKey(name: 'completed_at')  DateTime? completedAt, @JsonKey(name: 'created_at')  DateTime createdAt, @JsonKey(name: 'updated_at')  DateTime updatedAt,  List<BookingItem> items, @JsonKey(name: 'platform_fee_cents')  int? platformFeeCents)  $default,) {final _that = this;
switch (_that) {
case _Booking():
return $default(_that.id,_that.reference,_that.clientId,_that.providerId,_that.status,_that.startsAt,_that.endsAt,_that.timeZone,_that.startsAtLocal,_that.endsAtLocal,_that.durationMinutes,_that.locationType,_that.addressText,_that.address,_that.accessNotes,_that.latitude,_that.longitude,_that.distanceKm,_that.providerName,_that.providerAvatarUrl,_that.clientName,_that.clientAvatarUrl,_that.clientPhone,_that.clientNotes,_that.subtotalCents,_that.totalCents,_that.currency,_that.paymentMethod,_that.paymentStatus,_that.requiresApproval,_that.cancellationWindowHours,_that.cancellationFeePercent,_that.freeCancellationUntil,_that.declineReason,_that.respondedAt,_that.cancelledBy,_that.cancellationReason,_that.cancelledAt,_that.lateCancellation,_that.cancellationFeeCents,_that.completedAt,_that.createdAt,_that.updatedAt,_that.items,_that.platformFeeCents);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String reference, @JsonKey(name: 'client_id')  String? clientId, @JsonKey(name: 'provider_id')  String? providerId,  BookingStatus status, @JsonKey(name: 'starts_at')  DateTime startsAt, @JsonKey(name: 'ends_at')  DateTime endsAt, @JsonKey(name: 'time_zone')  String timeZone, @WallClockConverter()@JsonKey(name: 'starts_at_local')  DateTime startsAtLocal, @WallClockConverter()@JsonKey(name: 'ends_at_local')  DateTime endsAtLocal, @JsonKey(name: 'duration_minutes')  int durationMinutes, @JsonKey(name: 'location_type')  BookingLocationType locationType, @JsonKey(name: 'address_text')  String addressText,  ClientAddress? address, @JsonKey(name: 'access_notes')  String? accessNotes,  double? latitude,  double? longitude, @JsonKey(name: 'distance_km')  double? distanceKm, @JsonKey(name: 'provider_name')  String providerName, @JsonKey(name: 'provider_avatar_url')  String? providerAvatarUrl, @JsonKey(name: 'client_name')  String clientName, @JsonKey(name: 'client_avatar_url')  String? clientAvatarUrl, @JsonKey(name: 'client_phone')  String clientPhone, @JsonKey(name: 'client_notes')  String? clientNotes, @JsonKey(name: 'subtotal_cents')  int subtotalCents, @JsonKey(name: 'total_cents')  int totalCents,  String currency, @JsonKey(name: 'payment_method')  PaymentMethod paymentMethod, @JsonKey(name: 'payment_status')  PaymentStatus paymentStatus, @JsonKey(name: 'requires_approval')  bool requiresApproval, @JsonKey(name: 'cancellation_window_hours')  int cancellationWindowHours, @JsonKey(name: 'cancellation_fee_percent')  int cancellationFeePercent, @JsonKey(name: 'free_cancellation_until')  DateTime freeCancellationUntil, @JsonKey(name: 'decline_reason')  String? declineReason, @JsonKey(name: 'responded_at')  DateTime? respondedAt, @JsonKey(name: 'cancelled_by')  CancelledBy? cancelledBy, @JsonKey(name: 'cancellation_reason')  String? cancellationReason, @JsonKey(name: 'cancelled_at')  DateTime? cancelledAt, @JsonKey(name: 'late_cancellation')  bool lateCancellation, @JsonKey(name: 'cancellation_fee_cents')  int cancellationFeeCents, @JsonKey(name: 'completed_at')  DateTime? completedAt, @JsonKey(name: 'created_at')  DateTime createdAt, @JsonKey(name: 'updated_at')  DateTime updatedAt,  List<BookingItem> items, @JsonKey(name: 'platform_fee_cents')  int? platformFeeCents)?  $default,) {final _that = this;
switch (_that) {
case _Booking() when $default != null:
return $default(_that.id,_that.reference,_that.clientId,_that.providerId,_that.status,_that.startsAt,_that.endsAt,_that.timeZone,_that.startsAtLocal,_that.endsAtLocal,_that.durationMinutes,_that.locationType,_that.addressText,_that.address,_that.accessNotes,_that.latitude,_that.longitude,_that.distanceKm,_that.providerName,_that.providerAvatarUrl,_that.clientName,_that.clientAvatarUrl,_that.clientPhone,_that.clientNotes,_that.subtotalCents,_that.totalCents,_that.currency,_that.paymentMethod,_that.paymentStatus,_that.requiresApproval,_that.cancellationWindowHours,_that.cancellationFeePercent,_that.freeCancellationUntil,_that.declineReason,_that.respondedAt,_that.cancelledBy,_that.cancellationReason,_that.cancelledAt,_that.lateCancellation,_that.cancellationFeeCents,_that.completedAt,_that.createdAt,_that.updatedAt,_that.items,_that.platformFeeCents);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Booking extends Booking {
  const _Booking({required this.id, required this.reference, @JsonKey(name: 'client_id') this.clientId, @JsonKey(name: 'provider_id') this.providerId, required this.status, @JsonKey(name: 'starts_at') required this.startsAt, @JsonKey(name: 'ends_at') required this.endsAt, @JsonKey(name: 'time_zone') required this.timeZone, @WallClockConverter()@JsonKey(name: 'starts_at_local') required this.startsAtLocal, @WallClockConverter()@JsonKey(name: 'ends_at_local') required this.endsAtLocal, @JsonKey(name: 'duration_minutes') required this.durationMinutes, @JsonKey(name: 'location_type') required this.locationType, @JsonKey(name: 'address_text') required this.addressText, this.address, @JsonKey(name: 'access_notes') this.accessNotes, this.latitude, this.longitude, @JsonKey(name: 'distance_km') this.distanceKm, @JsonKey(name: 'provider_name') required this.providerName, @JsonKey(name: 'provider_avatar_url') this.providerAvatarUrl, @JsonKey(name: 'client_name') required this.clientName, @JsonKey(name: 'client_avatar_url') this.clientAvatarUrl, @JsonKey(name: 'client_phone') required this.clientPhone, @JsonKey(name: 'client_notes') this.clientNotes, @JsonKey(name: 'subtotal_cents') required this.subtotalCents, @JsonKey(name: 'total_cents') required this.totalCents, this.currency = 'AUD', @JsonKey(name: 'payment_method') required this.paymentMethod, @JsonKey(name: 'payment_status') required this.paymentStatus, @JsonKey(name: 'requires_approval') required this.requiresApproval, @JsonKey(name: 'cancellation_window_hours') required this.cancellationWindowHours, @JsonKey(name: 'cancellation_fee_percent') required this.cancellationFeePercent, @JsonKey(name: 'free_cancellation_until') required this.freeCancellationUntil, @JsonKey(name: 'decline_reason') this.declineReason, @JsonKey(name: 'responded_at') this.respondedAt, @JsonKey(name: 'cancelled_by') this.cancelledBy, @JsonKey(name: 'cancellation_reason') this.cancellationReason, @JsonKey(name: 'cancelled_at') this.cancelledAt, @JsonKey(name: 'late_cancellation') this.lateCancellation = false, @JsonKey(name: 'cancellation_fee_cents') this.cancellationFeeCents = 0, @JsonKey(name: 'completed_at') this.completedAt, @JsonKey(name: 'created_at') required this.createdAt, @JsonKey(name: 'updated_at') required this.updatedAt, final  List<BookingItem> items = const <BookingItem>[], @JsonKey(name: 'platform_fee_cents') this.platformFeeCents}): _items = items,super._();
  factory _Booking.fromJson(Map<String, dynamic> json) => _$BookingFromJson(json);

@override final  String id;
@override final  String reference;
@override@JsonKey(name: 'client_id') final  String? clientId;
@override@JsonKey(name: 'provider_id') final  String? providerId;
@override final  BookingStatus status;
@override@JsonKey(name: 'starts_at') final  DateTime startsAt;
@override@JsonKey(name: 'ends_at') final  DateTime endsAt;
@override@JsonKey(name: 'time_zone') final  String timeZone;
@override@WallClockConverter()@JsonKey(name: 'starts_at_local') final  DateTime startsAtLocal;
@override@WallClockConverter()@JsonKey(name: 'ends_at_local') final  DateTime endsAtLocal;
@override@JsonKey(name: 'duration_minutes') final  int durationMinutes;
@override@JsonKey(name: 'location_type') final  BookingLocationType locationType;
@override@JsonKey(name: 'address_text') final  String addressText;
@override final  ClientAddress? address;
@override@JsonKey(name: 'access_notes') final  String? accessNotes;
@override final  double? latitude;
@override final  double? longitude;
@override@JsonKey(name: 'distance_km') final  double? distanceKm;
@override@JsonKey(name: 'provider_name') final  String providerName;
@override@JsonKey(name: 'provider_avatar_url') final  String? providerAvatarUrl;
@override@JsonKey(name: 'client_name') final  String clientName;
@override@JsonKey(name: 'client_avatar_url') final  String? clientAvatarUrl;
@override@JsonKey(name: 'client_phone') final  String clientPhone;
@override@JsonKey(name: 'client_notes') final  String? clientNotes;
@override@JsonKey(name: 'subtotal_cents') final  int subtotalCents;
@override@JsonKey(name: 'total_cents') final  int totalCents;
@override@JsonKey() final  String currency;
@override@JsonKey(name: 'payment_method') final  PaymentMethod paymentMethod;
@override@JsonKey(name: 'payment_status') final  PaymentStatus paymentStatus;
@override@JsonKey(name: 'requires_approval') final  bool requiresApproval;
@override@JsonKey(name: 'cancellation_window_hours') final  int cancellationWindowHours;
@override@JsonKey(name: 'cancellation_fee_percent') final  int cancellationFeePercent;
@override@JsonKey(name: 'free_cancellation_until') final  DateTime freeCancellationUntil;
@override@JsonKey(name: 'decline_reason') final  String? declineReason;
@override@JsonKey(name: 'responded_at') final  DateTime? respondedAt;
@override@JsonKey(name: 'cancelled_by') final  CancelledBy? cancelledBy;
@override@JsonKey(name: 'cancellation_reason') final  String? cancellationReason;
@override@JsonKey(name: 'cancelled_at') final  DateTime? cancelledAt;
@override@JsonKey(name: 'late_cancellation') final  bool lateCancellation;
@override@JsonKey(name: 'cancellation_fee_cents') final  int cancellationFeeCents;
@override@JsonKey(name: 'completed_at') final  DateTime? completedAt;
@override@JsonKey(name: 'created_at') final  DateTime createdAt;
@override@JsonKey(name: 'updated_at') final  DateTime updatedAt;
 final  List<BookingItem> _items;
@override@JsonKey() List<BookingItem> get items {
  if (_items is EqualUnmodifiableListView) return _items;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_items);
}

/// Myglo's commission on this booking. Only the provider can see it
/// (null for the client, who pays no booking fee).
@override@JsonKey(name: 'platform_fee_cents') final  int? platformFeeCents;

/// Create a copy of Booking
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BookingCopyWith<_Booking> get copyWith => __$BookingCopyWithImpl<_Booking>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$BookingToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Booking&&(identical(other.id, id) || other.id == id)&&(identical(other.reference, reference) || other.reference == reference)&&(identical(other.clientId, clientId) || other.clientId == clientId)&&(identical(other.providerId, providerId) || other.providerId == providerId)&&(identical(other.status, status) || other.status == status)&&(identical(other.startsAt, startsAt) || other.startsAt == startsAt)&&(identical(other.endsAt, endsAt) || other.endsAt == endsAt)&&(identical(other.timeZone, timeZone) || other.timeZone == timeZone)&&(identical(other.startsAtLocal, startsAtLocal) || other.startsAtLocal == startsAtLocal)&&(identical(other.endsAtLocal, endsAtLocal) || other.endsAtLocal == endsAtLocal)&&(identical(other.durationMinutes, durationMinutes) || other.durationMinutes == durationMinutes)&&(identical(other.locationType, locationType) || other.locationType == locationType)&&(identical(other.addressText, addressText) || other.addressText == addressText)&&(identical(other.address, address) || other.address == address)&&(identical(other.accessNotes, accessNotes) || other.accessNotes == accessNotes)&&(identical(other.latitude, latitude) || other.latitude == latitude)&&(identical(other.longitude, longitude) || other.longitude == longitude)&&(identical(other.distanceKm, distanceKm) || other.distanceKm == distanceKm)&&(identical(other.providerName, providerName) || other.providerName == providerName)&&(identical(other.providerAvatarUrl, providerAvatarUrl) || other.providerAvatarUrl == providerAvatarUrl)&&(identical(other.clientName, clientName) || other.clientName == clientName)&&(identical(other.clientAvatarUrl, clientAvatarUrl) || other.clientAvatarUrl == clientAvatarUrl)&&(identical(other.clientPhone, clientPhone) || other.clientPhone == clientPhone)&&(identical(other.clientNotes, clientNotes) || other.clientNotes == clientNotes)&&(identical(other.subtotalCents, subtotalCents) || other.subtotalCents == subtotalCents)&&(identical(other.totalCents, totalCents) || other.totalCents == totalCents)&&(identical(other.currency, currency) || other.currency == currency)&&(identical(other.paymentMethod, paymentMethod) || other.paymentMethod == paymentMethod)&&(identical(other.paymentStatus, paymentStatus) || other.paymentStatus == paymentStatus)&&(identical(other.requiresApproval, requiresApproval) || other.requiresApproval == requiresApproval)&&(identical(other.cancellationWindowHours, cancellationWindowHours) || other.cancellationWindowHours == cancellationWindowHours)&&(identical(other.cancellationFeePercent, cancellationFeePercent) || other.cancellationFeePercent == cancellationFeePercent)&&(identical(other.freeCancellationUntil, freeCancellationUntil) || other.freeCancellationUntil == freeCancellationUntil)&&(identical(other.declineReason, declineReason) || other.declineReason == declineReason)&&(identical(other.respondedAt, respondedAt) || other.respondedAt == respondedAt)&&(identical(other.cancelledBy, cancelledBy) || other.cancelledBy == cancelledBy)&&(identical(other.cancellationReason, cancellationReason) || other.cancellationReason == cancellationReason)&&(identical(other.cancelledAt, cancelledAt) || other.cancelledAt == cancelledAt)&&(identical(other.lateCancellation, lateCancellation) || other.lateCancellation == lateCancellation)&&(identical(other.cancellationFeeCents, cancellationFeeCents) || other.cancellationFeeCents == cancellationFeeCents)&&(identical(other.completedAt, completedAt) || other.completedAt == completedAt)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&const DeepCollectionEquality().equals(other._items, _items)&&(identical(other.platformFeeCents, platformFeeCents) || other.platformFeeCents == platformFeeCents));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,reference,clientId,providerId,status,startsAt,endsAt,timeZone,startsAtLocal,endsAtLocal,durationMinutes,locationType,addressText,address,accessNotes,latitude,longitude,distanceKm,providerName,providerAvatarUrl,clientName,clientAvatarUrl,clientPhone,clientNotes,subtotalCents,totalCents,currency,paymentMethod,paymentStatus,requiresApproval,cancellationWindowHours,cancellationFeePercent,freeCancellationUntil,declineReason,respondedAt,cancelledBy,cancellationReason,cancelledAt,lateCancellation,cancellationFeeCents,completedAt,createdAt,updatedAt,const DeepCollectionEquality().hash(_items),platformFeeCents]);

@override
String toString() {
  return 'Booking(id: $id, reference: $reference, clientId: $clientId, providerId: $providerId, status: $status, startsAt: $startsAt, endsAt: $endsAt, timeZone: $timeZone, startsAtLocal: $startsAtLocal, endsAtLocal: $endsAtLocal, durationMinutes: $durationMinutes, locationType: $locationType, addressText: $addressText, address: $address, accessNotes: $accessNotes, latitude: $latitude, longitude: $longitude, distanceKm: $distanceKm, providerName: $providerName, providerAvatarUrl: $providerAvatarUrl, clientName: $clientName, clientAvatarUrl: $clientAvatarUrl, clientPhone: $clientPhone, clientNotes: $clientNotes, subtotalCents: $subtotalCents, totalCents: $totalCents, currency: $currency, paymentMethod: $paymentMethod, paymentStatus: $paymentStatus, requiresApproval: $requiresApproval, cancellationWindowHours: $cancellationWindowHours, cancellationFeePercent: $cancellationFeePercent, freeCancellationUntil: $freeCancellationUntil, declineReason: $declineReason, respondedAt: $respondedAt, cancelledBy: $cancelledBy, cancellationReason: $cancellationReason, cancelledAt: $cancelledAt, lateCancellation: $lateCancellation, cancellationFeeCents: $cancellationFeeCents, completedAt: $completedAt, createdAt: $createdAt, updatedAt: $updatedAt, items: $items, platformFeeCents: $platformFeeCents)';
}


}

/// @nodoc
abstract mixin class _$BookingCopyWith<$Res> implements $BookingCopyWith<$Res> {
  factory _$BookingCopyWith(_Booking value, $Res Function(_Booking) _then) = __$BookingCopyWithImpl;
@override @useResult
$Res call({
 String id, String reference,@JsonKey(name: 'client_id') String? clientId,@JsonKey(name: 'provider_id') String? providerId, BookingStatus status,@JsonKey(name: 'starts_at') DateTime startsAt,@JsonKey(name: 'ends_at') DateTime endsAt,@JsonKey(name: 'time_zone') String timeZone,@WallClockConverter()@JsonKey(name: 'starts_at_local') DateTime startsAtLocal,@WallClockConverter()@JsonKey(name: 'ends_at_local') DateTime endsAtLocal,@JsonKey(name: 'duration_minutes') int durationMinutes,@JsonKey(name: 'location_type') BookingLocationType locationType,@JsonKey(name: 'address_text') String addressText, ClientAddress? address,@JsonKey(name: 'access_notes') String? accessNotes, double? latitude, double? longitude,@JsonKey(name: 'distance_km') double? distanceKm,@JsonKey(name: 'provider_name') String providerName,@JsonKey(name: 'provider_avatar_url') String? providerAvatarUrl,@JsonKey(name: 'client_name') String clientName,@JsonKey(name: 'client_avatar_url') String? clientAvatarUrl,@JsonKey(name: 'client_phone') String clientPhone,@JsonKey(name: 'client_notes') String? clientNotes,@JsonKey(name: 'subtotal_cents') int subtotalCents,@JsonKey(name: 'total_cents') int totalCents, String currency,@JsonKey(name: 'payment_method') PaymentMethod paymentMethod,@JsonKey(name: 'payment_status') PaymentStatus paymentStatus,@JsonKey(name: 'requires_approval') bool requiresApproval,@JsonKey(name: 'cancellation_window_hours') int cancellationWindowHours,@JsonKey(name: 'cancellation_fee_percent') int cancellationFeePercent,@JsonKey(name: 'free_cancellation_until') DateTime freeCancellationUntil,@JsonKey(name: 'decline_reason') String? declineReason,@JsonKey(name: 'responded_at') DateTime? respondedAt,@JsonKey(name: 'cancelled_by') CancelledBy? cancelledBy,@JsonKey(name: 'cancellation_reason') String? cancellationReason,@JsonKey(name: 'cancelled_at') DateTime? cancelledAt,@JsonKey(name: 'late_cancellation') bool lateCancellation,@JsonKey(name: 'cancellation_fee_cents') int cancellationFeeCents,@JsonKey(name: 'completed_at') DateTime? completedAt,@JsonKey(name: 'created_at') DateTime createdAt,@JsonKey(name: 'updated_at') DateTime updatedAt, List<BookingItem> items,@JsonKey(name: 'platform_fee_cents') int? platformFeeCents
});




}
/// @nodoc
class __$BookingCopyWithImpl<$Res>
    implements _$BookingCopyWith<$Res> {
  __$BookingCopyWithImpl(this._self, this._then);

  final _Booking _self;
  final $Res Function(_Booking) _then;

/// Create a copy of Booking
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? reference = null,Object? clientId = freezed,Object? providerId = freezed,Object? status = null,Object? startsAt = null,Object? endsAt = null,Object? timeZone = null,Object? startsAtLocal = null,Object? endsAtLocal = null,Object? durationMinutes = null,Object? locationType = null,Object? addressText = null,Object? address = freezed,Object? accessNotes = freezed,Object? latitude = freezed,Object? longitude = freezed,Object? distanceKm = freezed,Object? providerName = null,Object? providerAvatarUrl = freezed,Object? clientName = null,Object? clientAvatarUrl = freezed,Object? clientPhone = null,Object? clientNotes = freezed,Object? subtotalCents = null,Object? totalCents = null,Object? currency = null,Object? paymentMethod = null,Object? paymentStatus = null,Object? requiresApproval = null,Object? cancellationWindowHours = null,Object? cancellationFeePercent = null,Object? freeCancellationUntil = null,Object? declineReason = freezed,Object? respondedAt = freezed,Object? cancelledBy = freezed,Object? cancellationReason = freezed,Object? cancelledAt = freezed,Object? lateCancellation = null,Object? cancellationFeeCents = null,Object? completedAt = freezed,Object? createdAt = null,Object? updatedAt = null,Object? items = null,Object? platformFeeCents = freezed,}) {
  return _then(_Booking(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,reference: null == reference ? _self.reference : reference // ignore: cast_nullable_to_non_nullable
as String,clientId: freezed == clientId ? _self.clientId : clientId // ignore: cast_nullable_to_non_nullable
as String?,providerId: freezed == providerId ? _self.providerId : providerId // ignore: cast_nullable_to_non_nullable
as String?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as BookingStatus,startsAt: null == startsAt ? _self.startsAt : startsAt // ignore: cast_nullable_to_non_nullable
as DateTime,endsAt: null == endsAt ? _self.endsAt : endsAt // ignore: cast_nullable_to_non_nullable
as DateTime,timeZone: null == timeZone ? _self.timeZone : timeZone // ignore: cast_nullable_to_non_nullable
as String,startsAtLocal: null == startsAtLocal ? _self.startsAtLocal : startsAtLocal // ignore: cast_nullable_to_non_nullable
as DateTime,endsAtLocal: null == endsAtLocal ? _self.endsAtLocal : endsAtLocal // ignore: cast_nullable_to_non_nullable
as DateTime,durationMinutes: null == durationMinutes ? _self.durationMinutes : durationMinutes // ignore: cast_nullable_to_non_nullable
as int,locationType: null == locationType ? _self.locationType : locationType // ignore: cast_nullable_to_non_nullable
as BookingLocationType,addressText: null == addressText ? _self.addressText : addressText // ignore: cast_nullable_to_non_nullable
as String,address: freezed == address ? _self.address : address // ignore: cast_nullable_to_non_nullable
as ClientAddress?,accessNotes: freezed == accessNotes ? _self.accessNotes : accessNotes // ignore: cast_nullable_to_non_nullable
as String?,latitude: freezed == latitude ? _self.latitude : latitude // ignore: cast_nullable_to_non_nullable
as double?,longitude: freezed == longitude ? _self.longitude : longitude // ignore: cast_nullable_to_non_nullable
as double?,distanceKm: freezed == distanceKm ? _self.distanceKm : distanceKm // ignore: cast_nullable_to_non_nullable
as double?,providerName: null == providerName ? _self.providerName : providerName // ignore: cast_nullable_to_non_nullable
as String,providerAvatarUrl: freezed == providerAvatarUrl ? _self.providerAvatarUrl : providerAvatarUrl // ignore: cast_nullable_to_non_nullable
as String?,clientName: null == clientName ? _self.clientName : clientName // ignore: cast_nullable_to_non_nullable
as String,clientAvatarUrl: freezed == clientAvatarUrl ? _self.clientAvatarUrl : clientAvatarUrl // ignore: cast_nullable_to_non_nullable
as String?,clientPhone: null == clientPhone ? _self.clientPhone : clientPhone // ignore: cast_nullable_to_non_nullable
as String,clientNotes: freezed == clientNotes ? _self.clientNotes : clientNotes // ignore: cast_nullable_to_non_nullable
as String?,subtotalCents: null == subtotalCents ? _self.subtotalCents : subtotalCents // ignore: cast_nullable_to_non_nullable
as int,totalCents: null == totalCents ? _self.totalCents : totalCents // ignore: cast_nullable_to_non_nullable
as int,currency: null == currency ? _self.currency : currency // ignore: cast_nullable_to_non_nullable
as String,paymentMethod: null == paymentMethod ? _self.paymentMethod : paymentMethod // ignore: cast_nullable_to_non_nullable
as PaymentMethod,paymentStatus: null == paymentStatus ? _self.paymentStatus : paymentStatus // ignore: cast_nullable_to_non_nullable
as PaymentStatus,requiresApproval: null == requiresApproval ? _self.requiresApproval : requiresApproval // ignore: cast_nullable_to_non_nullable
as bool,cancellationWindowHours: null == cancellationWindowHours ? _self.cancellationWindowHours : cancellationWindowHours // ignore: cast_nullable_to_non_nullable
as int,cancellationFeePercent: null == cancellationFeePercent ? _self.cancellationFeePercent : cancellationFeePercent // ignore: cast_nullable_to_non_nullable
as int,freeCancellationUntil: null == freeCancellationUntil ? _self.freeCancellationUntil : freeCancellationUntil // ignore: cast_nullable_to_non_nullable
as DateTime,declineReason: freezed == declineReason ? _self.declineReason : declineReason // ignore: cast_nullable_to_non_nullable
as String?,respondedAt: freezed == respondedAt ? _self.respondedAt : respondedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,cancelledBy: freezed == cancelledBy ? _self.cancelledBy : cancelledBy // ignore: cast_nullable_to_non_nullable
as CancelledBy?,cancellationReason: freezed == cancellationReason ? _self.cancellationReason : cancellationReason // ignore: cast_nullable_to_non_nullable
as String?,cancelledAt: freezed == cancelledAt ? _self.cancelledAt : cancelledAt // ignore: cast_nullable_to_non_nullable
as DateTime?,lateCancellation: null == lateCancellation ? _self.lateCancellation : lateCancellation // ignore: cast_nullable_to_non_nullable
as bool,cancellationFeeCents: null == cancellationFeeCents ? _self.cancellationFeeCents : cancellationFeeCents // ignore: cast_nullable_to_non_nullable
as int,completedAt: freezed == completedAt ? _self.completedAt : completedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,items: null == items ? _self._items : items // ignore: cast_nullable_to_non_nullable
as List<BookingItem>,platformFeeCents: freezed == platformFeeCents ? _self.platformFeeCents : platformFeeCents // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}

// dart format on
