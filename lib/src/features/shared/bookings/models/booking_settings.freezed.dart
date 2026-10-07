// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'booking_settings.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ProviderBookingSettings {

@JsonKey(name: 'provider_id') String get providerId;@JsonKey(name: 'time_zone') String get timeZone;@JsonKey(name: 'accepts_bookings') bool get acceptsBookings;/// Requests wait for the provider to accept instead of confirming
/// instantly.
@JsonKey(name: 'requires_approval') bool get requiresApproval;@JsonKey(name: 'slot_interval_minutes') int get slotIntervalMinutes;@JsonKey(name: 'buffer_minutes') int get bufferMinutes;@JsonKey(name: 'min_notice_minutes') int get minNoticeMinutes;@JsonKey(name: 'max_advance_days') int get maxAdvanceDays;@JsonKey(name: 'cancellation_window_hours') int get cancellationWindowHours;@JsonKey(name: 'cancellation_fee_percent') int get cancellationFeePercent;@JsonKey(name: 'offers_studio') bool get offersStudio;@JsonKey(name: 'offers_mobile') bool get offersMobile;/// How far a mobile provider travels; null means no limit.
@JsonKey(name: 'travel_radius_km') double? get travelRadiusKm;/// Moves whenever availability may have changed (see the migration).
@JsonKey(name: 'availability_version') int get availabilityVersion;
/// Create a copy of ProviderBookingSettings
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProviderBookingSettingsCopyWith<ProviderBookingSettings> get copyWith => _$ProviderBookingSettingsCopyWithImpl<ProviderBookingSettings>(this as ProviderBookingSettings, _$identity);

  /// Serializes this ProviderBookingSettings to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProviderBookingSettings&&(identical(other.providerId, providerId) || other.providerId == providerId)&&(identical(other.timeZone, timeZone) || other.timeZone == timeZone)&&(identical(other.acceptsBookings, acceptsBookings) || other.acceptsBookings == acceptsBookings)&&(identical(other.requiresApproval, requiresApproval) || other.requiresApproval == requiresApproval)&&(identical(other.slotIntervalMinutes, slotIntervalMinutes) || other.slotIntervalMinutes == slotIntervalMinutes)&&(identical(other.bufferMinutes, bufferMinutes) || other.bufferMinutes == bufferMinutes)&&(identical(other.minNoticeMinutes, minNoticeMinutes) || other.minNoticeMinutes == minNoticeMinutes)&&(identical(other.maxAdvanceDays, maxAdvanceDays) || other.maxAdvanceDays == maxAdvanceDays)&&(identical(other.cancellationWindowHours, cancellationWindowHours) || other.cancellationWindowHours == cancellationWindowHours)&&(identical(other.cancellationFeePercent, cancellationFeePercent) || other.cancellationFeePercent == cancellationFeePercent)&&(identical(other.offersStudio, offersStudio) || other.offersStudio == offersStudio)&&(identical(other.offersMobile, offersMobile) || other.offersMobile == offersMobile)&&(identical(other.travelRadiusKm, travelRadiusKm) || other.travelRadiusKm == travelRadiusKm)&&(identical(other.availabilityVersion, availabilityVersion) || other.availabilityVersion == availabilityVersion));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,providerId,timeZone,acceptsBookings,requiresApproval,slotIntervalMinutes,bufferMinutes,minNoticeMinutes,maxAdvanceDays,cancellationWindowHours,cancellationFeePercent,offersStudio,offersMobile,travelRadiusKm,availabilityVersion);

@override
String toString() {
  return 'ProviderBookingSettings(providerId: $providerId, timeZone: $timeZone, acceptsBookings: $acceptsBookings, requiresApproval: $requiresApproval, slotIntervalMinutes: $slotIntervalMinutes, bufferMinutes: $bufferMinutes, minNoticeMinutes: $minNoticeMinutes, maxAdvanceDays: $maxAdvanceDays, cancellationWindowHours: $cancellationWindowHours, cancellationFeePercent: $cancellationFeePercent, offersStudio: $offersStudio, offersMobile: $offersMobile, travelRadiusKm: $travelRadiusKm, availabilityVersion: $availabilityVersion)';
}


}

/// @nodoc
abstract mixin class $ProviderBookingSettingsCopyWith<$Res>  {
  factory $ProviderBookingSettingsCopyWith(ProviderBookingSettings value, $Res Function(ProviderBookingSettings) _then) = _$ProviderBookingSettingsCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'provider_id') String providerId,@JsonKey(name: 'time_zone') String timeZone,@JsonKey(name: 'accepts_bookings') bool acceptsBookings,@JsonKey(name: 'requires_approval') bool requiresApproval,@JsonKey(name: 'slot_interval_minutes') int slotIntervalMinutes,@JsonKey(name: 'buffer_minutes') int bufferMinutes,@JsonKey(name: 'min_notice_minutes') int minNoticeMinutes,@JsonKey(name: 'max_advance_days') int maxAdvanceDays,@JsonKey(name: 'cancellation_window_hours') int cancellationWindowHours,@JsonKey(name: 'cancellation_fee_percent') int cancellationFeePercent,@JsonKey(name: 'offers_studio') bool offersStudio,@JsonKey(name: 'offers_mobile') bool offersMobile,@JsonKey(name: 'travel_radius_km') double? travelRadiusKm,@JsonKey(name: 'availability_version') int availabilityVersion
});




}
/// @nodoc
class _$ProviderBookingSettingsCopyWithImpl<$Res>
    implements $ProviderBookingSettingsCopyWith<$Res> {
  _$ProviderBookingSettingsCopyWithImpl(this._self, this._then);

  final ProviderBookingSettings _self;
  final $Res Function(ProviderBookingSettings) _then;

/// Create a copy of ProviderBookingSettings
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? providerId = null,Object? timeZone = null,Object? acceptsBookings = null,Object? requiresApproval = null,Object? slotIntervalMinutes = null,Object? bufferMinutes = null,Object? minNoticeMinutes = null,Object? maxAdvanceDays = null,Object? cancellationWindowHours = null,Object? cancellationFeePercent = null,Object? offersStudio = null,Object? offersMobile = null,Object? travelRadiusKm = freezed,Object? availabilityVersion = null,}) {
  return _then(_self.copyWith(
providerId: null == providerId ? _self.providerId : providerId // ignore: cast_nullable_to_non_nullable
as String,timeZone: null == timeZone ? _self.timeZone : timeZone // ignore: cast_nullable_to_non_nullable
as String,acceptsBookings: null == acceptsBookings ? _self.acceptsBookings : acceptsBookings // ignore: cast_nullable_to_non_nullable
as bool,requiresApproval: null == requiresApproval ? _self.requiresApproval : requiresApproval // ignore: cast_nullable_to_non_nullable
as bool,slotIntervalMinutes: null == slotIntervalMinutes ? _self.slotIntervalMinutes : slotIntervalMinutes // ignore: cast_nullable_to_non_nullable
as int,bufferMinutes: null == bufferMinutes ? _self.bufferMinutes : bufferMinutes // ignore: cast_nullable_to_non_nullable
as int,minNoticeMinutes: null == minNoticeMinutes ? _self.minNoticeMinutes : minNoticeMinutes // ignore: cast_nullable_to_non_nullable
as int,maxAdvanceDays: null == maxAdvanceDays ? _self.maxAdvanceDays : maxAdvanceDays // ignore: cast_nullable_to_non_nullable
as int,cancellationWindowHours: null == cancellationWindowHours ? _self.cancellationWindowHours : cancellationWindowHours // ignore: cast_nullable_to_non_nullable
as int,cancellationFeePercent: null == cancellationFeePercent ? _self.cancellationFeePercent : cancellationFeePercent // ignore: cast_nullable_to_non_nullable
as int,offersStudio: null == offersStudio ? _self.offersStudio : offersStudio // ignore: cast_nullable_to_non_nullable
as bool,offersMobile: null == offersMobile ? _self.offersMobile : offersMobile // ignore: cast_nullable_to_non_nullable
as bool,travelRadiusKm: freezed == travelRadiusKm ? _self.travelRadiusKm : travelRadiusKm // ignore: cast_nullable_to_non_nullable
as double?,availabilityVersion: null == availabilityVersion ? _self.availabilityVersion : availabilityVersion // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [ProviderBookingSettings].
extension ProviderBookingSettingsPatterns on ProviderBookingSettings {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ProviderBookingSettings value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ProviderBookingSettings() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ProviderBookingSettings value)  $default,){
final _that = this;
switch (_that) {
case _ProviderBookingSettings():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ProviderBookingSettings value)?  $default,){
final _that = this;
switch (_that) {
case _ProviderBookingSettings() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'provider_id')  String providerId, @JsonKey(name: 'time_zone')  String timeZone, @JsonKey(name: 'accepts_bookings')  bool acceptsBookings, @JsonKey(name: 'requires_approval')  bool requiresApproval, @JsonKey(name: 'slot_interval_minutes')  int slotIntervalMinutes, @JsonKey(name: 'buffer_minutes')  int bufferMinutes, @JsonKey(name: 'min_notice_minutes')  int minNoticeMinutes, @JsonKey(name: 'max_advance_days')  int maxAdvanceDays, @JsonKey(name: 'cancellation_window_hours')  int cancellationWindowHours, @JsonKey(name: 'cancellation_fee_percent')  int cancellationFeePercent, @JsonKey(name: 'offers_studio')  bool offersStudio, @JsonKey(name: 'offers_mobile')  bool offersMobile, @JsonKey(name: 'travel_radius_km')  double? travelRadiusKm, @JsonKey(name: 'availability_version')  int availabilityVersion)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ProviderBookingSettings() when $default != null:
return $default(_that.providerId,_that.timeZone,_that.acceptsBookings,_that.requiresApproval,_that.slotIntervalMinutes,_that.bufferMinutes,_that.minNoticeMinutes,_that.maxAdvanceDays,_that.cancellationWindowHours,_that.cancellationFeePercent,_that.offersStudio,_that.offersMobile,_that.travelRadiusKm,_that.availabilityVersion);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'provider_id')  String providerId, @JsonKey(name: 'time_zone')  String timeZone, @JsonKey(name: 'accepts_bookings')  bool acceptsBookings, @JsonKey(name: 'requires_approval')  bool requiresApproval, @JsonKey(name: 'slot_interval_minutes')  int slotIntervalMinutes, @JsonKey(name: 'buffer_minutes')  int bufferMinutes, @JsonKey(name: 'min_notice_minutes')  int minNoticeMinutes, @JsonKey(name: 'max_advance_days')  int maxAdvanceDays, @JsonKey(name: 'cancellation_window_hours')  int cancellationWindowHours, @JsonKey(name: 'cancellation_fee_percent')  int cancellationFeePercent, @JsonKey(name: 'offers_studio')  bool offersStudio, @JsonKey(name: 'offers_mobile')  bool offersMobile, @JsonKey(name: 'travel_radius_km')  double? travelRadiusKm, @JsonKey(name: 'availability_version')  int availabilityVersion)  $default,) {final _that = this;
switch (_that) {
case _ProviderBookingSettings():
return $default(_that.providerId,_that.timeZone,_that.acceptsBookings,_that.requiresApproval,_that.slotIntervalMinutes,_that.bufferMinutes,_that.minNoticeMinutes,_that.maxAdvanceDays,_that.cancellationWindowHours,_that.cancellationFeePercent,_that.offersStudio,_that.offersMobile,_that.travelRadiusKm,_that.availabilityVersion);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'provider_id')  String providerId, @JsonKey(name: 'time_zone')  String timeZone, @JsonKey(name: 'accepts_bookings')  bool acceptsBookings, @JsonKey(name: 'requires_approval')  bool requiresApproval, @JsonKey(name: 'slot_interval_minutes')  int slotIntervalMinutes, @JsonKey(name: 'buffer_minutes')  int bufferMinutes, @JsonKey(name: 'min_notice_minutes')  int minNoticeMinutes, @JsonKey(name: 'max_advance_days')  int maxAdvanceDays, @JsonKey(name: 'cancellation_window_hours')  int cancellationWindowHours, @JsonKey(name: 'cancellation_fee_percent')  int cancellationFeePercent, @JsonKey(name: 'offers_studio')  bool offersStudio, @JsonKey(name: 'offers_mobile')  bool offersMobile, @JsonKey(name: 'travel_radius_km')  double? travelRadiusKm, @JsonKey(name: 'availability_version')  int availabilityVersion)?  $default,) {final _that = this;
switch (_that) {
case _ProviderBookingSettings() when $default != null:
return $default(_that.providerId,_that.timeZone,_that.acceptsBookings,_that.requiresApproval,_that.slotIntervalMinutes,_that.bufferMinutes,_that.minNoticeMinutes,_that.maxAdvanceDays,_that.cancellationWindowHours,_that.cancellationFeePercent,_that.offersStudio,_that.offersMobile,_that.travelRadiusKm,_that.availabilityVersion);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ProviderBookingSettings extends ProviderBookingSettings {
  const _ProviderBookingSettings({@JsonKey(name: 'provider_id') required this.providerId, @JsonKey(name: 'time_zone') this.timeZone = BookingTime.defaultTimeZone, @JsonKey(name: 'accepts_bookings') this.acceptsBookings = true, @JsonKey(name: 'requires_approval') this.requiresApproval = false, @JsonKey(name: 'slot_interval_minutes') this.slotIntervalMinutes = 15, @JsonKey(name: 'buffer_minutes') this.bufferMinutes = 0, @JsonKey(name: 'min_notice_minutes') this.minNoticeMinutes = 120, @JsonKey(name: 'max_advance_days') this.maxAdvanceDays = 60, @JsonKey(name: 'cancellation_window_hours') this.cancellationWindowHours = 24, @JsonKey(name: 'cancellation_fee_percent') this.cancellationFeePercent = 0, @JsonKey(name: 'offers_studio') this.offersStudio = true, @JsonKey(name: 'offers_mobile') this.offersMobile = false, @JsonKey(name: 'travel_radius_km') this.travelRadiusKm, @JsonKey(name: 'availability_version') this.availabilityVersion = 0}): super._();
  factory _ProviderBookingSettings.fromJson(Map<String, dynamic> json) => _$ProviderBookingSettingsFromJson(json);

@override@JsonKey(name: 'provider_id') final  String providerId;
@override@JsonKey(name: 'time_zone') final  String timeZone;
@override@JsonKey(name: 'accepts_bookings') final  bool acceptsBookings;
/// Requests wait for the provider to accept instead of confirming
/// instantly.
@override@JsonKey(name: 'requires_approval') final  bool requiresApproval;
@override@JsonKey(name: 'slot_interval_minutes') final  int slotIntervalMinutes;
@override@JsonKey(name: 'buffer_minutes') final  int bufferMinutes;
@override@JsonKey(name: 'min_notice_minutes') final  int minNoticeMinutes;
@override@JsonKey(name: 'max_advance_days') final  int maxAdvanceDays;
@override@JsonKey(name: 'cancellation_window_hours') final  int cancellationWindowHours;
@override@JsonKey(name: 'cancellation_fee_percent') final  int cancellationFeePercent;
@override@JsonKey(name: 'offers_studio') final  bool offersStudio;
@override@JsonKey(name: 'offers_mobile') final  bool offersMobile;
/// How far a mobile provider travels; null means no limit.
@override@JsonKey(name: 'travel_radius_km') final  double? travelRadiusKm;
/// Moves whenever availability may have changed (see the migration).
@override@JsonKey(name: 'availability_version') final  int availabilityVersion;

/// Create a copy of ProviderBookingSettings
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ProviderBookingSettingsCopyWith<_ProviderBookingSettings> get copyWith => __$ProviderBookingSettingsCopyWithImpl<_ProviderBookingSettings>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ProviderBookingSettingsToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ProviderBookingSettings&&(identical(other.providerId, providerId) || other.providerId == providerId)&&(identical(other.timeZone, timeZone) || other.timeZone == timeZone)&&(identical(other.acceptsBookings, acceptsBookings) || other.acceptsBookings == acceptsBookings)&&(identical(other.requiresApproval, requiresApproval) || other.requiresApproval == requiresApproval)&&(identical(other.slotIntervalMinutes, slotIntervalMinutes) || other.slotIntervalMinutes == slotIntervalMinutes)&&(identical(other.bufferMinutes, bufferMinutes) || other.bufferMinutes == bufferMinutes)&&(identical(other.minNoticeMinutes, minNoticeMinutes) || other.minNoticeMinutes == minNoticeMinutes)&&(identical(other.maxAdvanceDays, maxAdvanceDays) || other.maxAdvanceDays == maxAdvanceDays)&&(identical(other.cancellationWindowHours, cancellationWindowHours) || other.cancellationWindowHours == cancellationWindowHours)&&(identical(other.cancellationFeePercent, cancellationFeePercent) || other.cancellationFeePercent == cancellationFeePercent)&&(identical(other.offersStudio, offersStudio) || other.offersStudio == offersStudio)&&(identical(other.offersMobile, offersMobile) || other.offersMobile == offersMobile)&&(identical(other.travelRadiusKm, travelRadiusKm) || other.travelRadiusKm == travelRadiusKm)&&(identical(other.availabilityVersion, availabilityVersion) || other.availabilityVersion == availabilityVersion));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,providerId,timeZone,acceptsBookings,requiresApproval,slotIntervalMinutes,bufferMinutes,minNoticeMinutes,maxAdvanceDays,cancellationWindowHours,cancellationFeePercent,offersStudio,offersMobile,travelRadiusKm,availabilityVersion);

@override
String toString() {
  return 'ProviderBookingSettings(providerId: $providerId, timeZone: $timeZone, acceptsBookings: $acceptsBookings, requiresApproval: $requiresApproval, slotIntervalMinutes: $slotIntervalMinutes, bufferMinutes: $bufferMinutes, minNoticeMinutes: $minNoticeMinutes, maxAdvanceDays: $maxAdvanceDays, cancellationWindowHours: $cancellationWindowHours, cancellationFeePercent: $cancellationFeePercent, offersStudio: $offersStudio, offersMobile: $offersMobile, travelRadiusKm: $travelRadiusKm, availabilityVersion: $availabilityVersion)';
}


}

/// @nodoc
abstract mixin class _$ProviderBookingSettingsCopyWith<$Res> implements $ProviderBookingSettingsCopyWith<$Res> {
  factory _$ProviderBookingSettingsCopyWith(_ProviderBookingSettings value, $Res Function(_ProviderBookingSettings) _then) = __$ProviderBookingSettingsCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'provider_id') String providerId,@JsonKey(name: 'time_zone') String timeZone,@JsonKey(name: 'accepts_bookings') bool acceptsBookings,@JsonKey(name: 'requires_approval') bool requiresApproval,@JsonKey(name: 'slot_interval_minutes') int slotIntervalMinutes,@JsonKey(name: 'buffer_minutes') int bufferMinutes,@JsonKey(name: 'min_notice_minutes') int minNoticeMinutes,@JsonKey(name: 'max_advance_days') int maxAdvanceDays,@JsonKey(name: 'cancellation_window_hours') int cancellationWindowHours,@JsonKey(name: 'cancellation_fee_percent') int cancellationFeePercent,@JsonKey(name: 'offers_studio') bool offersStudio,@JsonKey(name: 'offers_mobile') bool offersMobile,@JsonKey(name: 'travel_radius_km') double? travelRadiusKm,@JsonKey(name: 'availability_version') int availabilityVersion
});




}
/// @nodoc
class __$ProviderBookingSettingsCopyWithImpl<$Res>
    implements _$ProviderBookingSettingsCopyWith<$Res> {
  __$ProviderBookingSettingsCopyWithImpl(this._self, this._then);

  final _ProviderBookingSettings _self;
  final $Res Function(_ProviderBookingSettings) _then;

/// Create a copy of ProviderBookingSettings
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? providerId = null,Object? timeZone = null,Object? acceptsBookings = null,Object? requiresApproval = null,Object? slotIntervalMinutes = null,Object? bufferMinutes = null,Object? minNoticeMinutes = null,Object? maxAdvanceDays = null,Object? cancellationWindowHours = null,Object? cancellationFeePercent = null,Object? offersStudio = null,Object? offersMobile = null,Object? travelRadiusKm = freezed,Object? availabilityVersion = null,}) {
  return _then(_ProviderBookingSettings(
providerId: null == providerId ? _self.providerId : providerId // ignore: cast_nullable_to_non_nullable
as String,timeZone: null == timeZone ? _self.timeZone : timeZone // ignore: cast_nullable_to_non_nullable
as String,acceptsBookings: null == acceptsBookings ? _self.acceptsBookings : acceptsBookings // ignore: cast_nullable_to_non_nullable
as bool,requiresApproval: null == requiresApproval ? _self.requiresApproval : requiresApproval // ignore: cast_nullable_to_non_nullable
as bool,slotIntervalMinutes: null == slotIntervalMinutes ? _self.slotIntervalMinutes : slotIntervalMinutes // ignore: cast_nullable_to_non_nullable
as int,bufferMinutes: null == bufferMinutes ? _self.bufferMinutes : bufferMinutes // ignore: cast_nullable_to_non_nullable
as int,minNoticeMinutes: null == minNoticeMinutes ? _self.minNoticeMinutes : minNoticeMinutes // ignore: cast_nullable_to_non_nullable
as int,maxAdvanceDays: null == maxAdvanceDays ? _self.maxAdvanceDays : maxAdvanceDays // ignore: cast_nullable_to_non_nullable
as int,cancellationWindowHours: null == cancellationWindowHours ? _self.cancellationWindowHours : cancellationWindowHours // ignore: cast_nullable_to_non_nullable
as int,cancellationFeePercent: null == cancellationFeePercent ? _self.cancellationFeePercent : cancellationFeePercent // ignore: cast_nullable_to_non_nullable
as int,offersStudio: null == offersStudio ? _self.offersStudio : offersStudio // ignore: cast_nullable_to_non_nullable
as bool,offersMobile: null == offersMobile ? _self.offersMobile : offersMobile // ignore: cast_nullable_to_non_nullable
as bool,travelRadiusKm: freezed == travelRadiusKm ? _self.travelRadiusKm : travelRadiusKm // ignore: cast_nullable_to_non_nullable
as double?,availabilityVersion: null == availabilityVersion ? _self.availabilityVersion : availabilityVersion // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
