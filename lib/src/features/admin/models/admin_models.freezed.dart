// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'admin_models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$AdminStatus {

@JsonKey(name: 'is_admin') bool get isAdmin;@JsonKey(name: 'display_name') String? get displayName; String? get aal;@JsonKey(name: 'totp_verified_at') DateTime? get totpVerifiedAt;@JsonKey(name: 'session_expires_at') DateTime? get sessionExpiresAt;@JsonKey(name: 'reauth_seconds') int get reauthSeconds;
/// Create a copy of AdminStatus
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AdminStatusCopyWith<AdminStatus> get copyWith => _$AdminStatusCopyWithImpl<AdminStatus>(this as AdminStatus, _$identity);

  /// Serializes this AdminStatus to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AdminStatus&&(identical(other.isAdmin, isAdmin) || other.isAdmin == isAdmin)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.aal, aal) || other.aal == aal)&&(identical(other.totpVerifiedAt, totpVerifiedAt) || other.totpVerifiedAt == totpVerifiedAt)&&(identical(other.sessionExpiresAt, sessionExpiresAt) || other.sessionExpiresAt == sessionExpiresAt)&&(identical(other.reauthSeconds, reauthSeconds) || other.reauthSeconds == reauthSeconds));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,isAdmin,displayName,aal,totpVerifiedAt,sessionExpiresAt,reauthSeconds);

@override
String toString() {
  return 'AdminStatus(isAdmin: $isAdmin, displayName: $displayName, aal: $aal, totpVerifiedAt: $totpVerifiedAt, sessionExpiresAt: $sessionExpiresAt, reauthSeconds: $reauthSeconds)';
}


}

/// @nodoc
abstract mixin class $AdminStatusCopyWith<$Res>  {
  factory $AdminStatusCopyWith(AdminStatus value, $Res Function(AdminStatus) _then) = _$AdminStatusCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'is_admin') bool isAdmin,@JsonKey(name: 'display_name') String? displayName, String? aal,@JsonKey(name: 'totp_verified_at') DateTime? totpVerifiedAt,@JsonKey(name: 'session_expires_at') DateTime? sessionExpiresAt,@JsonKey(name: 'reauth_seconds') int reauthSeconds
});




}
/// @nodoc
class _$AdminStatusCopyWithImpl<$Res>
    implements $AdminStatusCopyWith<$Res> {
  _$AdminStatusCopyWithImpl(this._self, this._then);

  final AdminStatus _self;
  final $Res Function(AdminStatus) _then;

/// Create a copy of AdminStatus
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? isAdmin = null,Object? displayName = freezed,Object? aal = freezed,Object? totpVerifiedAt = freezed,Object? sessionExpiresAt = freezed,Object? reauthSeconds = null,}) {
  return _then(_self.copyWith(
isAdmin: null == isAdmin ? _self.isAdmin : isAdmin // ignore: cast_nullable_to_non_nullable
as bool,displayName: freezed == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String?,aal: freezed == aal ? _self.aal : aal // ignore: cast_nullable_to_non_nullable
as String?,totpVerifiedAt: freezed == totpVerifiedAt ? _self.totpVerifiedAt : totpVerifiedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,sessionExpiresAt: freezed == sessionExpiresAt ? _self.sessionExpiresAt : sessionExpiresAt // ignore: cast_nullable_to_non_nullable
as DateTime?,reauthSeconds: null == reauthSeconds ? _self.reauthSeconds : reauthSeconds // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [AdminStatus].
extension AdminStatusPatterns on AdminStatus {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AdminStatus value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AdminStatus() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AdminStatus value)  $default,){
final _that = this;
switch (_that) {
case _AdminStatus():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AdminStatus value)?  $default,){
final _that = this;
switch (_that) {
case _AdminStatus() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'is_admin')  bool isAdmin, @JsonKey(name: 'display_name')  String? displayName,  String? aal, @JsonKey(name: 'totp_verified_at')  DateTime? totpVerifiedAt, @JsonKey(name: 'session_expires_at')  DateTime? sessionExpiresAt, @JsonKey(name: 'reauth_seconds')  int reauthSeconds)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AdminStatus() when $default != null:
return $default(_that.isAdmin,_that.displayName,_that.aal,_that.totpVerifiedAt,_that.sessionExpiresAt,_that.reauthSeconds);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'is_admin')  bool isAdmin, @JsonKey(name: 'display_name')  String? displayName,  String? aal, @JsonKey(name: 'totp_verified_at')  DateTime? totpVerifiedAt, @JsonKey(name: 'session_expires_at')  DateTime? sessionExpiresAt, @JsonKey(name: 'reauth_seconds')  int reauthSeconds)  $default,) {final _that = this;
switch (_that) {
case _AdminStatus():
return $default(_that.isAdmin,_that.displayName,_that.aal,_that.totpVerifiedAt,_that.sessionExpiresAt,_that.reauthSeconds);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'is_admin')  bool isAdmin, @JsonKey(name: 'display_name')  String? displayName,  String? aal, @JsonKey(name: 'totp_verified_at')  DateTime? totpVerifiedAt, @JsonKey(name: 'session_expires_at')  DateTime? sessionExpiresAt, @JsonKey(name: 'reauth_seconds')  int reauthSeconds)?  $default,) {final _that = this;
switch (_that) {
case _AdminStatus() when $default != null:
return $default(_that.isAdmin,_that.displayName,_that.aal,_that.totpVerifiedAt,_that.sessionExpiresAt,_that.reauthSeconds);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AdminStatus extends AdminStatus {
  const _AdminStatus({@JsonKey(name: 'is_admin') this.isAdmin = false, @JsonKey(name: 'display_name') this.displayName, this.aal, @JsonKey(name: 'totp_verified_at') this.totpVerifiedAt, @JsonKey(name: 'session_expires_at') this.sessionExpiresAt, @JsonKey(name: 'reauth_seconds') this.reauthSeconds = 300}): super._();
  factory _AdminStatus.fromJson(Map<String, dynamic> json) => _$AdminStatusFromJson(json);

@override@JsonKey(name: 'is_admin') final  bool isAdmin;
@override@JsonKey(name: 'display_name') final  String? displayName;
@override final  String? aal;
@override@JsonKey(name: 'totp_verified_at') final  DateTime? totpVerifiedAt;
@override@JsonKey(name: 'session_expires_at') final  DateTime? sessionExpiresAt;
@override@JsonKey(name: 'reauth_seconds') final  int reauthSeconds;

/// Create a copy of AdminStatus
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AdminStatusCopyWith<_AdminStatus> get copyWith => __$AdminStatusCopyWithImpl<_AdminStatus>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AdminStatusToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AdminStatus&&(identical(other.isAdmin, isAdmin) || other.isAdmin == isAdmin)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.aal, aal) || other.aal == aal)&&(identical(other.totpVerifiedAt, totpVerifiedAt) || other.totpVerifiedAt == totpVerifiedAt)&&(identical(other.sessionExpiresAt, sessionExpiresAt) || other.sessionExpiresAt == sessionExpiresAt)&&(identical(other.reauthSeconds, reauthSeconds) || other.reauthSeconds == reauthSeconds));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,isAdmin,displayName,aal,totpVerifiedAt,sessionExpiresAt,reauthSeconds);

@override
String toString() {
  return 'AdminStatus(isAdmin: $isAdmin, displayName: $displayName, aal: $aal, totpVerifiedAt: $totpVerifiedAt, sessionExpiresAt: $sessionExpiresAt, reauthSeconds: $reauthSeconds)';
}


}

/// @nodoc
abstract mixin class _$AdminStatusCopyWith<$Res> implements $AdminStatusCopyWith<$Res> {
  factory _$AdminStatusCopyWith(_AdminStatus value, $Res Function(_AdminStatus) _then) = __$AdminStatusCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'is_admin') bool isAdmin,@JsonKey(name: 'display_name') String? displayName, String? aal,@JsonKey(name: 'totp_verified_at') DateTime? totpVerifiedAt,@JsonKey(name: 'session_expires_at') DateTime? sessionExpiresAt,@JsonKey(name: 'reauth_seconds') int reauthSeconds
});




}
/// @nodoc
class __$AdminStatusCopyWithImpl<$Res>
    implements _$AdminStatusCopyWith<$Res> {
  __$AdminStatusCopyWithImpl(this._self, this._then);

  final _AdminStatus _self;
  final $Res Function(_AdminStatus) _then;

/// Create a copy of AdminStatus
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? isAdmin = null,Object? displayName = freezed,Object? aal = freezed,Object? totpVerifiedAt = freezed,Object? sessionExpiresAt = freezed,Object? reauthSeconds = null,}) {
  return _then(_AdminStatus(
isAdmin: null == isAdmin ? _self.isAdmin : isAdmin // ignore: cast_nullable_to_non_nullable
as bool,displayName: freezed == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String?,aal: freezed == aal ? _self.aal : aal // ignore: cast_nullable_to_non_nullable
as String?,totpVerifiedAt: freezed == totpVerifiedAt ? _self.totpVerifiedAt : totpVerifiedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,sessionExpiresAt: freezed == sessionExpiresAt ? _self.sessionExpiresAt : sessionExpiresAt // ignore: cast_nullable_to_non_nullable
as DateTime?,reauthSeconds: null == reauthSeconds ? _self.reauthSeconds : reauthSeconds // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$AdminDashboard {

 int get providers; int get clients;@JsonKey(name: 'new_users_7d') int get newUsers7d;@JsonKey(name: 'bookings_upcoming') int get bookingsUpcoming;@JsonKey(name: 'bookings_pending') int get bookingsPending;@JsonKey(name: 'bookings_7d') int get bookings7d;@JsonKey(name: 'failed_jobs') int get failedJobs;@JsonKey(name: 'generated_at') DateTime? get generatedAt;
/// Create a copy of AdminDashboard
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AdminDashboardCopyWith<AdminDashboard> get copyWith => _$AdminDashboardCopyWithImpl<AdminDashboard>(this as AdminDashboard, _$identity);

  /// Serializes this AdminDashboard to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AdminDashboard&&(identical(other.providers, providers) || other.providers == providers)&&(identical(other.clients, clients) || other.clients == clients)&&(identical(other.newUsers7d, newUsers7d) || other.newUsers7d == newUsers7d)&&(identical(other.bookingsUpcoming, bookingsUpcoming) || other.bookingsUpcoming == bookingsUpcoming)&&(identical(other.bookingsPending, bookingsPending) || other.bookingsPending == bookingsPending)&&(identical(other.bookings7d, bookings7d) || other.bookings7d == bookings7d)&&(identical(other.failedJobs, failedJobs) || other.failedJobs == failedJobs)&&(identical(other.generatedAt, generatedAt) || other.generatedAt == generatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,providers,clients,newUsers7d,bookingsUpcoming,bookingsPending,bookings7d,failedJobs,generatedAt);

@override
String toString() {
  return 'AdminDashboard(providers: $providers, clients: $clients, newUsers7d: $newUsers7d, bookingsUpcoming: $bookingsUpcoming, bookingsPending: $bookingsPending, bookings7d: $bookings7d, failedJobs: $failedJobs, generatedAt: $generatedAt)';
}


}

/// @nodoc
abstract mixin class $AdminDashboardCopyWith<$Res>  {
  factory $AdminDashboardCopyWith(AdminDashboard value, $Res Function(AdminDashboard) _then) = _$AdminDashboardCopyWithImpl;
@useResult
$Res call({
 int providers, int clients,@JsonKey(name: 'new_users_7d') int newUsers7d,@JsonKey(name: 'bookings_upcoming') int bookingsUpcoming,@JsonKey(name: 'bookings_pending') int bookingsPending,@JsonKey(name: 'bookings_7d') int bookings7d,@JsonKey(name: 'failed_jobs') int failedJobs,@JsonKey(name: 'generated_at') DateTime? generatedAt
});




}
/// @nodoc
class _$AdminDashboardCopyWithImpl<$Res>
    implements $AdminDashboardCopyWith<$Res> {
  _$AdminDashboardCopyWithImpl(this._self, this._then);

  final AdminDashboard _self;
  final $Res Function(AdminDashboard) _then;

/// Create a copy of AdminDashboard
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? providers = null,Object? clients = null,Object? newUsers7d = null,Object? bookingsUpcoming = null,Object? bookingsPending = null,Object? bookings7d = null,Object? failedJobs = null,Object? generatedAt = freezed,}) {
  return _then(_self.copyWith(
providers: null == providers ? _self.providers : providers // ignore: cast_nullable_to_non_nullable
as int,clients: null == clients ? _self.clients : clients // ignore: cast_nullable_to_non_nullable
as int,newUsers7d: null == newUsers7d ? _self.newUsers7d : newUsers7d // ignore: cast_nullable_to_non_nullable
as int,bookingsUpcoming: null == bookingsUpcoming ? _self.bookingsUpcoming : bookingsUpcoming // ignore: cast_nullable_to_non_nullable
as int,bookingsPending: null == bookingsPending ? _self.bookingsPending : bookingsPending // ignore: cast_nullable_to_non_nullable
as int,bookings7d: null == bookings7d ? _self.bookings7d : bookings7d // ignore: cast_nullable_to_non_nullable
as int,failedJobs: null == failedJobs ? _self.failedJobs : failedJobs // ignore: cast_nullable_to_non_nullable
as int,generatedAt: freezed == generatedAt ? _self.generatedAt : generatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [AdminDashboard].
extension AdminDashboardPatterns on AdminDashboard {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AdminDashboard value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AdminDashboard() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AdminDashboard value)  $default,){
final _that = this;
switch (_that) {
case _AdminDashboard():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AdminDashboard value)?  $default,){
final _that = this;
switch (_that) {
case _AdminDashboard() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int providers,  int clients, @JsonKey(name: 'new_users_7d')  int newUsers7d, @JsonKey(name: 'bookings_upcoming')  int bookingsUpcoming, @JsonKey(name: 'bookings_pending')  int bookingsPending, @JsonKey(name: 'bookings_7d')  int bookings7d, @JsonKey(name: 'failed_jobs')  int failedJobs, @JsonKey(name: 'generated_at')  DateTime? generatedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AdminDashboard() when $default != null:
return $default(_that.providers,_that.clients,_that.newUsers7d,_that.bookingsUpcoming,_that.bookingsPending,_that.bookings7d,_that.failedJobs,_that.generatedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int providers,  int clients, @JsonKey(name: 'new_users_7d')  int newUsers7d, @JsonKey(name: 'bookings_upcoming')  int bookingsUpcoming, @JsonKey(name: 'bookings_pending')  int bookingsPending, @JsonKey(name: 'bookings_7d')  int bookings7d, @JsonKey(name: 'failed_jobs')  int failedJobs, @JsonKey(name: 'generated_at')  DateTime? generatedAt)  $default,) {final _that = this;
switch (_that) {
case _AdminDashboard():
return $default(_that.providers,_that.clients,_that.newUsers7d,_that.bookingsUpcoming,_that.bookingsPending,_that.bookings7d,_that.failedJobs,_that.generatedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int providers,  int clients, @JsonKey(name: 'new_users_7d')  int newUsers7d, @JsonKey(name: 'bookings_upcoming')  int bookingsUpcoming, @JsonKey(name: 'bookings_pending')  int bookingsPending, @JsonKey(name: 'bookings_7d')  int bookings7d, @JsonKey(name: 'failed_jobs')  int failedJobs, @JsonKey(name: 'generated_at')  DateTime? generatedAt)?  $default,) {final _that = this;
switch (_that) {
case _AdminDashboard() when $default != null:
return $default(_that.providers,_that.clients,_that.newUsers7d,_that.bookingsUpcoming,_that.bookingsPending,_that.bookings7d,_that.failedJobs,_that.generatedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AdminDashboard implements AdminDashboard {
  const _AdminDashboard({this.providers = 0, this.clients = 0, @JsonKey(name: 'new_users_7d') this.newUsers7d = 0, @JsonKey(name: 'bookings_upcoming') this.bookingsUpcoming = 0, @JsonKey(name: 'bookings_pending') this.bookingsPending = 0, @JsonKey(name: 'bookings_7d') this.bookings7d = 0, @JsonKey(name: 'failed_jobs') this.failedJobs = 0, @JsonKey(name: 'generated_at') this.generatedAt});
  factory _AdminDashboard.fromJson(Map<String, dynamic> json) => _$AdminDashboardFromJson(json);

@override@JsonKey() final  int providers;
@override@JsonKey() final  int clients;
@override@JsonKey(name: 'new_users_7d') final  int newUsers7d;
@override@JsonKey(name: 'bookings_upcoming') final  int bookingsUpcoming;
@override@JsonKey(name: 'bookings_pending') final  int bookingsPending;
@override@JsonKey(name: 'bookings_7d') final  int bookings7d;
@override@JsonKey(name: 'failed_jobs') final  int failedJobs;
@override@JsonKey(name: 'generated_at') final  DateTime? generatedAt;

/// Create a copy of AdminDashboard
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AdminDashboardCopyWith<_AdminDashboard> get copyWith => __$AdminDashboardCopyWithImpl<_AdminDashboard>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AdminDashboardToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AdminDashboard&&(identical(other.providers, providers) || other.providers == providers)&&(identical(other.clients, clients) || other.clients == clients)&&(identical(other.newUsers7d, newUsers7d) || other.newUsers7d == newUsers7d)&&(identical(other.bookingsUpcoming, bookingsUpcoming) || other.bookingsUpcoming == bookingsUpcoming)&&(identical(other.bookingsPending, bookingsPending) || other.bookingsPending == bookingsPending)&&(identical(other.bookings7d, bookings7d) || other.bookings7d == bookings7d)&&(identical(other.failedJobs, failedJobs) || other.failedJobs == failedJobs)&&(identical(other.generatedAt, generatedAt) || other.generatedAt == generatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,providers,clients,newUsers7d,bookingsUpcoming,bookingsPending,bookings7d,failedJobs,generatedAt);

@override
String toString() {
  return 'AdminDashboard(providers: $providers, clients: $clients, newUsers7d: $newUsers7d, bookingsUpcoming: $bookingsUpcoming, bookingsPending: $bookingsPending, bookings7d: $bookings7d, failedJobs: $failedJobs, generatedAt: $generatedAt)';
}


}

/// @nodoc
abstract mixin class _$AdminDashboardCopyWith<$Res> implements $AdminDashboardCopyWith<$Res> {
  factory _$AdminDashboardCopyWith(_AdminDashboard value, $Res Function(_AdminDashboard) _then) = __$AdminDashboardCopyWithImpl;
@override @useResult
$Res call({
 int providers, int clients,@JsonKey(name: 'new_users_7d') int newUsers7d,@JsonKey(name: 'bookings_upcoming') int bookingsUpcoming,@JsonKey(name: 'bookings_pending') int bookingsPending,@JsonKey(name: 'bookings_7d') int bookings7d,@JsonKey(name: 'failed_jobs') int failedJobs,@JsonKey(name: 'generated_at') DateTime? generatedAt
});




}
/// @nodoc
class __$AdminDashboardCopyWithImpl<$Res>
    implements _$AdminDashboardCopyWith<$Res> {
  __$AdminDashboardCopyWithImpl(this._self, this._then);

  final _AdminDashboard _self;
  final $Res Function(_AdminDashboard) _then;

/// Create a copy of AdminDashboard
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? providers = null,Object? clients = null,Object? newUsers7d = null,Object? bookingsUpcoming = null,Object? bookingsPending = null,Object? bookings7d = null,Object? failedJobs = null,Object? generatedAt = freezed,}) {
  return _then(_AdminDashboard(
providers: null == providers ? _self.providers : providers // ignore: cast_nullable_to_non_nullable
as int,clients: null == clients ? _self.clients : clients // ignore: cast_nullable_to_non_nullable
as int,newUsers7d: null == newUsers7d ? _self.newUsers7d : newUsers7d // ignore: cast_nullable_to_non_nullable
as int,bookingsUpcoming: null == bookingsUpcoming ? _self.bookingsUpcoming : bookingsUpcoming // ignore: cast_nullable_to_non_nullable
as int,bookingsPending: null == bookingsPending ? _self.bookingsPending : bookingsPending // ignore: cast_nullable_to_non_nullable
as int,bookings7d: null == bookings7d ? _self.bookings7d : bookings7d // ignore: cast_nullable_to_non_nullable
as int,failedJobs: null == failedJobs ? _self.failedJobs : failedJobs // ignore: cast_nullable_to_non_nullable
as int,generatedAt: freezed == generatedAt ? _self.generatedAt : generatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}


/// @nodoc
mixin _$PlatformSettings {

/// Myglo's commission on bookings paid in the app, charged to providers.
@JsonKey(name: 'platform_fee_percent') double get platformFeePercent;/// Days without commission, from when a provider's card payments start.
@JsonKey(name: 'fee_free_days') int get feeFreeDays;@JsonKey(name: 'default_cancellation_window_hours') int get defaultCancellationWindowHours;@JsonKey(name: 'default_cancellation_fee_percent') int get defaultCancellationFeePercent;@JsonKey(name: 'map_provider') String get mapProvider;@JsonKey(name: 'checkout_hold_minutes') int get checkoutHoldMinutes;@JsonKey(name: 'card_request_response_hours') int get cardRequestResponseHours;@JsonKey(name: 'card_max_advance_days') int get cardMaxAdvanceDays;@JsonKey(name: 'auto_complete_after_hours') int get autoCompleteAfterHours;@JsonKey(name: 'report_window_hours') int get reportWindowHours;/// Whether providers may delete their own account in the app. Off:
/// they hide their business instead and ask support to close it.
@JsonKey(name: 'provider_self_deletion') bool get providerSelfDeletion;@JsonKey(name: 'updated_at') DateTime? get updatedAt;@JsonKey(name: 'updated_by') String? get updatedBy;
/// Create a copy of PlatformSettings
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PlatformSettingsCopyWith<PlatformSettings> get copyWith => _$PlatformSettingsCopyWithImpl<PlatformSettings>(this as PlatformSettings, _$identity);

  /// Serializes this PlatformSettings to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PlatformSettings&&(identical(other.platformFeePercent, platformFeePercent) || other.platformFeePercent == platformFeePercent)&&(identical(other.feeFreeDays, feeFreeDays) || other.feeFreeDays == feeFreeDays)&&(identical(other.defaultCancellationWindowHours, defaultCancellationWindowHours) || other.defaultCancellationWindowHours == defaultCancellationWindowHours)&&(identical(other.defaultCancellationFeePercent, defaultCancellationFeePercent) || other.defaultCancellationFeePercent == defaultCancellationFeePercent)&&(identical(other.mapProvider, mapProvider) || other.mapProvider == mapProvider)&&(identical(other.checkoutHoldMinutes, checkoutHoldMinutes) || other.checkoutHoldMinutes == checkoutHoldMinutes)&&(identical(other.cardRequestResponseHours, cardRequestResponseHours) || other.cardRequestResponseHours == cardRequestResponseHours)&&(identical(other.cardMaxAdvanceDays, cardMaxAdvanceDays) || other.cardMaxAdvanceDays == cardMaxAdvanceDays)&&(identical(other.autoCompleteAfterHours, autoCompleteAfterHours) || other.autoCompleteAfterHours == autoCompleteAfterHours)&&(identical(other.reportWindowHours, reportWindowHours) || other.reportWindowHours == reportWindowHours)&&(identical(other.providerSelfDeletion, providerSelfDeletion) || other.providerSelfDeletion == providerSelfDeletion)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.updatedBy, updatedBy) || other.updatedBy == updatedBy));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,platformFeePercent,feeFreeDays,defaultCancellationWindowHours,defaultCancellationFeePercent,mapProvider,checkoutHoldMinutes,cardRequestResponseHours,cardMaxAdvanceDays,autoCompleteAfterHours,reportWindowHours,providerSelfDeletion,updatedAt,updatedBy);

@override
String toString() {
  return 'PlatformSettings(platformFeePercent: $platformFeePercent, feeFreeDays: $feeFreeDays, defaultCancellationWindowHours: $defaultCancellationWindowHours, defaultCancellationFeePercent: $defaultCancellationFeePercent, mapProvider: $mapProvider, checkoutHoldMinutes: $checkoutHoldMinutes, cardRequestResponseHours: $cardRequestResponseHours, cardMaxAdvanceDays: $cardMaxAdvanceDays, autoCompleteAfterHours: $autoCompleteAfterHours, reportWindowHours: $reportWindowHours, providerSelfDeletion: $providerSelfDeletion, updatedAt: $updatedAt, updatedBy: $updatedBy)';
}


}

/// @nodoc
abstract mixin class $PlatformSettingsCopyWith<$Res>  {
  factory $PlatformSettingsCopyWith(PlatformSettings value, $Res Function(PlatformSettings) _then) = _$PlatformSettingsCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'platform_fee_percent') double platformFeePercent,@JsonKey(name: 'fee_free_days') int feeFreeDays,@JsonKey(name: 'default_cancellation_window_hours') int defaultCancellationWindowHours,@JsonKey(name: 'default_cancellation_fee_percent') int defaultCancellationFeePercent,@JsonKey(name: 'map_provider') String mapProvider,@JsonKey(name: 'checkout_hold_minutes') int checkoutHoldMinutes,@JsonKey(name: 'card_request_response_hours') int cardRequestResponseHours,@JsonKey(name: 'card_max_advance_days') int cardMaxAdvanceDays,@JsonKey(name: 'auto_complete_after_hours') int autoCompleteAfterHours,@JsonKey(name: 'report_window_hours') int reportWindowHours,@JsonKey(name: 'provider_self_deletion') bool providerSelfDeletion,@JsonKey(name: 'updated_at') DateTime? updatedAt,@JsonKey(name: 'updated_by') String? updatedBy
});




}
/// @nodoc
class _$PlatformSettingsCopyWithImpl<$Res>
    implements $PlatformSettingsCopyWith<$Res> {
  _$PlatformSettingsCopyWithImpl(this._self, this._then);

  final PlatformSettings _self;
  final $Res Function(PlatformSettings) _then;

/// Create a copy of PlatformSettings
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? platformFeePercent = null,Object? feeFreeDays = null,Object? defaultCancellationWindowHours = null,Object? defaultCancellationFeePercent = null,Object? mapProvider = null,Object? checkoutHoldMinutes = null,Object? cardRequestResponseHours = null,Object? cardMaxAdvanceDays = null,Object? autoCompleteAfterHours = null,Object? reportWindowHours = null,Object? providerSelfDeletion = null,Object? updatedAt = freezed,Object? updatedBy = freezed,}) {
  return _then(_self.copyWith(
platformFeePercent: null == platformFeePercent ? _self.platformFeePercent : platformFeePercent // ignore: cast_nullable_to_non_nullable
as double,feeFreeDays: null == feeFreeDays ? _self.feeFreeDays : feeFreeDays // ignore: cast_nullable_to_non_nullable
as int,defaultCancellationWindowHours: null == defaultCancellationWindowHours ? _self.defaultCancellationWindowHours : defaultCancellationWindowHours // ignore: cast_nullable_to_non_nullable
as int,defaultCancellationFeePercent: null == defaultCancellationFeePercent ? _self.defaultCancellationFeePercent : defaultCancellationFeePercent // ignore: cast_nullable_to_non_nullable
as int,mapProvider: null == mapProvider ? _self.mapProvider : mapProvider // ignore: cast_nullable_to_non_nullable
as String,checkoutHoldMinutes: null == checkoutHoldMinutes ? _self.checkoutHoldMinutes : checkoutHoldMinutes // ignore: cast_nullable_to_non_nullable
as int,cardRequestResponseHours: null == cardRequestResponseHours ? _self.cardRequestResponseHours : cardRequestResponseHours // ignore: cast_nullable_to_non_nullable
as int,cardMaxAdvanceDays: null == cardMaxAdvanceDays ? _self.cardMaxAdvanceDays : cardMaxAdvanceDays // ignore: cast_nullable_to_non_nullable
as int,autoCompleteAfterHours: null == autoCompleteAfterHours ? _self.autoCompleteAfterHours : autoCompleteAfterHours // ignore: cast_nullable_to_non_nullable
as int,reportWindowHours: null == reportWindowHours ? _self.reportWindowHours : reportWindowHours // ignore: cast_nullable_to_non_nullable
as int,providerSelfDeletion: null == providerSelfDeletion ? _self.providerSelfDeletion : providerSelfDeletion // ignore: cast_nullable_to_non_nullable
as bool,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,updatedBy: freezed == updatedBy ? _self.updatedBy : updatedBy // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [PlatformSettings].
extension PlatformSettingsPatterns on PlatformSettings {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PlatformSettings value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PlatformSettings() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PlatformSettings value)  $default,){
final _that = this;
switch (_that) {
case _PlatformSettings():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PlatformSettings value)?  $default,){
final _that = this;
switch (_that) {
case _PlatformSettings() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'platform_fee_percent')  double platformFeePercent, @JsonKey(name: 'fee_free_days')  int feeFreeDays, @JsonKey(name: 'default_cancellation_window_hours')  int defaultCancellationWindowHours, @JsonKey(name: 'default_cancellation_fee_percent')  int defaultCancellationFeePercent, @JsonKey(name: 'map_provider')  String mapProvider, @JsonKey(name: 'checkout_hold_minutes')  int checkoutHoldMinutes, @JsonKey(name: 'card_request_response_hours')  int cardRequestResponseHours, @JsonKey(name: 'card_max_advance_days')  int cardMaxAdvanceDays, @JsonKey(name: 'auto_complete_after_hours')  int autoCompleteAfterHours, @JsonKey(name: 'report_window_hours')  int reportWindowHours, @JsonKey(name: 'provider_self_deletion')  bool providerSelfDeletion, @JsonKey(name: 'updated_at')  DateTime? updatedAt, @JsonKey(name: 'updated_by')  String? updatedBy)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PlatformSettings() when $default != null:
return $default(_that.platformFeePercent,_that.feeFreeDays,_that.defaultCancellationWindowHours,_that.defaultCancellationFeePercent,_that.mapProvider,_that.checkoutHoldMinutes,_that.cardRequestResponseHours,_that.cardMaxAdvanceDays,_that.autoCompleteAfterHours,_that.reportWindowHours,_that.providerSelfDeletion,_that.updatedAt,_that.updatedBy);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'platform_fee_percent')  double platformFeePercent, @JsonKey(name: 'fee_free_days')  int feeFreeDays, @JsonKey(name: 'default_cancellation_window_hours')  int defaultCancellationWindowHours, @JsonKey(name: 'default_cancellation_fee_percent')  int defaultCancellationFeePercent, @JsonKey(name: 'map_provider')  String mapProvider, @JsonKey(name: 'checkout_hold_minutes')  int checkoutHoldMinutes, @JsonKey(name: 'card_request_response_hours')  int cardRequestResponseHours, @JsonKey(name: 'card_max_advance_days')  int cardMaxAdvanceDays, @JsonKey(name: 'auto_complete_after_hours')  int autoCompleteAfterHours, @JsonKey(name: 'report_window_hours')  int reportWindowHours, @JsonKey(name: 'provider_self_deletion')  bool providerSelfDeletion, @JsonKey(name: 'updated_at')  DateTime? updatedAt, @JsonKey(name: 'updated_by')  String? updatedBy)  $default,) {final _that = this;
switch (_that) {
case _PlatformSettings():
return $default(_that.platformFeePercent,_that.feeFreeDays,_that.defaultCancellationWindowHours,_that.defaultCancellationFeePercent,_that.mapProvider,_that.checkoutHoldMinutes,_that.cardRequestResponseHours,_that.cardMaxAdvanceDays,_that.autoCompleteAfterHours,_that.reportWindowHours,_that.providerSelfDeletion,_that.updatedAt,_that.updatedBy);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'platform_fee_percent')  double platformFeePercent, @JsonKey(name: 'fee_free_days')  int feeFreeDays, @JsonKey(name: 'default_cancellation_window_hours')  int defaultCancellationWindowHours, @JsonKey(name: 'default_cancellation_fee_percent')  int defaultCancellationFeePercent, @JsonKey(name: 'map_provider')  String mapProvider, @JsonKey(name: 'checkout_hold_minutes')  int checkoutHoldMinutes, @JsonKey(name: 'card_request_response_hours')  int cardRequestResponseHours, @JsonKey(name: 'card_max_advance_days')  int cardMaxAdvanceDays, @JsonKey(name: 'auto_complete_after_hours')  int autoCompleteAfterHours, @JsonKey(name: 'report_window_hours')  int reportWindowHours, @JsonKey(name: 'provider_self_deletion')  bool providerSelfDeletion, @JsonKey(name: 'updated_at')  DateTime? updatedAt, @JsonKey(name: 'updated_by')  String? updatedBy)?  $default,) {final _that = this;
switch (_that) {
case _PlatformSettings() when $default != null:
return $default(_that.platformFeePercent,_that.feeFreeDays,_that.defaultCancellationWindowHours,_that.defaultCancellationFeePercent,_that.mapProvider,_that.checkoutHoldMinutes,_that.cardRequestResponseHours,_that.cardMaxAdvanceDays,_that.autoCompleteAfterHours,_that.reportWindowHours,_that.providerSelfDeletion,_that.updatedAt,_that.updatedBy);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PlatformSettings extends PlatformSettings {
  const _PlatformSettings({@JsonKey(name: 'platform_fee_percent') this.platformFeePercent = 0, @JsonKey(name: 'fee_free_days') this.feeFreeDays = 0, @JsonKey(name: 'default_cancellation_window_hours') this.defaultCancellationWindowHours = 24, @JsonKey(name: 'default_cancellation_fee_percent') this.defaultCancellationFeePercent = 0, @JsonKey(name: 'map_provider') this.mapProvider = 'google', @JsonKey(name: 'checkout_hold_minutes') this.checkoutHoldMinutes = 15, @JsonKey(name: 'card_request_response_hours') this.cardRequestResponseHours = 144, @JsonKey(name: 'card_max_advance_days') this.cardMaxAdvanceDays = 60, @JsonKey(name: 'auto_complete_after_hours') this.autoCompleteAfterHours = 24, @JsonKey(name: 'report_window_hours') this.reportWindowHours = 24, @JsonKey(name: 'provider_self_deletion') this.providerSelfDeletion = false, @JsonKey(name: 'updated_at') this.updatedAt, @JsonKey(name: 'updated_by') this.updatedBy}): super._();
  factory _PlatformSettings.fromJson(Map<String, dynamic> json) => _$PlatformSettingsFromJson(json);

/// Myglo's commission on bookings paid in the app, charged to providers.
@override@JsonKey(name: 'platform_fee_percent') final  double platformFeePercent;
/// Days without commission, from when a provider's card payments start.
@override@JsonKey(name: 'fee_free_days') final  int feeFreeDays;
@override@JsonKey(name: 'default_cancellation_window_hours') final  int defaultCancellationWindowHours;
@override@JsonKey(name: 'default_cancellation_fee_percent') final  int defaultCancellationFeePercent;
@override@JsonKey(name: 'map_provider') final  String mapProvider;
@override@JsonKey(name: 'checkout_hold_minutes') final  int checkoutHoldMinutes;
@override@JsonKey(name: 'card_request_response_hours') final  int cardRequestResponseHours;
@override@JsonKey(name: 'card_max_advance_days') final  int cardMaxAdvanceDays;
@override@JsonKey(name: 'auto_complete_after_hours') final  int autoCompleteAfterHours;
@override@JsonKey(name: 'report_window_hours') final  int reportWindowHours;
/// Whether providers may delete their own account in the app. Off:
/// they hide their business instead and ask support to close it.
@override@JsonKey(name: 'provider_self_deletion') final  bool providerSelfDeletion;
@override@JsonKey(name: 'updated_at') final  DateTime? updatedAt;
@override@JsonKey(name: 'updated_by') final  String? updatedBy;

/// Create a copy of PlatformSettings
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PlatformSettingsCopyWith<_PlatformSettings> get copyWith => __$PlatformSettingsCopyWithImpl<_PlatformSettings>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PlatformSettingsToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PlatformSettings&&(identical(other.platformFeePercent, platformFeePercent) || other.platformFeePercent == platformFeePercent)&&(identical(other.feeFreeDays, feeFreeDays) || other.feeFreeDays == feeFreeDays)&&(identical(other.defaultCancellationWindowHours, defaultCancellationWindowHours) || other.defaultCancellationWindowHours == defaultCancellationWindowHours)&&(identical(other.defaultCancellationFeePercent, defaultCancellationFeePercent) || other.defaultCancellationFeePercent == defaultCancellationFeePercent)&&(identical(other.mapProvider, mapProvider) || other.mapProvider == mapProvider)&&(identical(other.checkoutHoldMinutes, checkoutHoldMinutes) || other.checkoutHoldMinutes == checkoutHoldMinutes)&&(identical(other.cardRequestResponseHours, cardRequestResponseHours) || other.cardRequestResponseHours == cardRequestResponseHours)&&(identical(other.cardMaxAdvanceDays, cardMaxAdvanceDays) || other.cardMaxAdvanceDays == cardMaxAdvanceDays)&&(identical(other.autoCompleteAfterHours, autoCompleteAfterHours) || other.autoCompleteAfterHours == autoCompleteAfterHours)&&(identical(other.reportWindowHours, reportWindowHours) || other.reportWindowHours == reportWindowHours)&&(identical(other.providerSelfDeletion, providerSelfDeletion) || other.providerSelfDeletion == providerSelfDeletion)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.updatedBy, updatedBy) || other.updatedBy == updatedBy));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,platformFeePercent,feeFreeDays,defaultCancellationWindowHours,defaultCancellationFeePercent,mapProvider,checkoutHoldMinutes,cardRequestResponseHours,cardMaxAdvanceDays,autoCompleteAfterHours,reportWindowHours,providerSelfDeletion,updatedAt,updatedBy);

@override
String toString() {
  return 'PlatformSettings(platformFeePercent: $platformFeePercent, feeFreeDays: $feeFreeDays, defaultCancellationWindowHours: $defaultCancellationWindowHours, defaultCancellationFeePercent: $defaultCancellationFeePercent, mapProvider: $mapProvider, checkoutHoldMinutes: $checkoutHoldMinutes, cardRequestResponseHours: $cardRequestResponseHours, cardMaxAdvanceDays: $cardMaxAdvanceDays, autoCompleteAfterHours: $autoCompleteAfterHours, reportWindowHours: $reportWindowHours, providerSelfDeletion: $providerSelfDeletion, updatedAt: $updatedAt, updatedBy: $updatedBy)';
}


}

/// @nodoc
abstract mixin class _$PlatformSettingsCopyWith<$Res> implements $PlatformSettingsCopyWith<$Res> {
  factory _$PlatformSettingsCopyWith(_PlatformSettings value, $Res Function(_PlatformSettings) _then) = __$PlatformSettingsCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'platform_fee_percent') double platformFeePercent,@JsonKey(name: 'fee_free_days') int feeFreeDays,@JsonKey(name: 'default_cancellation_window_hours') int defaultCancellationWindowHours,@JsonKey(name: 'default_cancellation_fee_percent') int defaultCancellationFeePercent,@JsonKey(name: 'map_provider') String mapProvider,@JsonKey(name: 'checkout_hold_minutes') int checkoutHoldMinutes,@JsonKey(name: 'card_request_response_hours') int cardRequestResponseHours,@JsonKey(name: 'card_max_advance_days') int cardMaxAdvanceDays,@JsonKey(name: 'auto_complete_after_hours') int autoCompleteAfterHours,@JsonKey(name: 'report_window_hours') int reportWindowHours,@JsonKey(name: 'provider_self_deletion') bool providerSelfDeletion,@JsonKey(name: 'updated_at') DateTime? updatedAt,@JsonKey(name: 'updated_by') String? updatedBy
});




}
/// @nodoc
class __$PlatformSettingsCopyWithImpl<$Res>
    implements _$PlatformSettingsCopyWith<$Res> {
  __$PlatformSettingsCopyWithImpl(this._self, this._then);

  final _PlatformSettings _self;
  final $Res Function(_PlatformSettings) _then;

/// Create a copy of PlatformSettings
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? platformFeePercent = null,Object? feeFreeDays = null,Object? defaultCancellationWindowHours = null,Object? defaultCancellationFeePercent = null,Object? mapProvider = null,Object? checkoutHoldMinutes = null,Object? cardRequestResponseHours = null,Object? cardMaxAdvanceDays = null,Object? autoCompleteAfterHours = null,Object? reportWindowHours = null,Object? providerSelfDeletion = null,Object? updatedAt = freezed,Object? updatedBy = freezed,}) {
  return _then(_PlatformSettings(
platformFeePercent: null == platformFeePercent ? _self.platformFeePercent : platformFeePercent // ignore: cast_nullable_to_non_nullable
as double,feeFreeDays: null == feeFreeDays ? _self.feeFreeDays : feeFreeDays // ignore: cast_nullable_to_non_nullable
as int,defaultCancellationWindowHours: null == defaultCancellationWindowHours ? _self.defaultCancellationWindowHours : defaultCancellationWindowHours // ignore: cast_nullable_to_non_nullable
as int,defaultCancellationFeePercent: null == defaultCancellationFeePercent ? _self.defaultCancellationFeePercent : defaultCancellationFeePercent // ignore: cast_nullable_to_non_nullable
as int,mapProvider: null == mapProvider ? _self.mapProvider : mapProvider // ignore: cast_nullable_to_non_nullable
as String,checkoutHoldMinutes: null == checkoutHoldMinutes ? _self.checkoutHoldMinutes : checkoutHoldMinutes // ignore: cast_nullable_to_non_nullable
as int,cardRequestResponseHours: null == cardRequestResponseHours ? _self.cardRequestResponseHours : cardRequestResponseHours // ignore: cast_nullable_to_non_nullable
as int,cardMaxAdvanceDays: null == cardMaxAdvanceDays ? _self.cardMaxAdvanceDays : cardMaxAdvanceDays // ignore: cast_nullable_to_non_nullable
as int,autoCompleteAfterHours: null == autoCompleteAfterHours ? _self.autoCompleteAfterHours : autoCompleteAfterHours // ignore: cast_nullable_to_non_nullable
as int,reportWindowHours: null == reportWindowHours ? _self.reportWindowHours : reportWindowHours // ignore: cast_nullable_to_non_nullable
as int,providerSelfDeletion: null == providerSelfDeletion ? _self.providerSelfDeletion : providerSelfDeletion // ignore: cast_nullable_to_non_nullable
as bool,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,updatedBy: freezed == updatedBy ? _self.updatedBy : updatedBy // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$AdminUserSummary {

@JsonKey(name: 'user_id') String get userId; String get role;@JsonKey(name: 'display_name') String? get displayName;@JsonKey(name: 'business_name') String? get businessName; String? get email; String? get phone;@JsonKey(name: 'avatar_url') String? get avatarUrl;@JsonKey(name: 'created_at') DateTime get createdAt;@JsonKey(name: 'last_sign_in') DateTime? get lastSignIn;
/// Create a copy of AdminUserSummary
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AdminUserSummaryCopyWith<AdminUserSummary> get copyWith => _$AdminUserSummaryCopyWithImpl<AdminUserSummary>(this as AdminUserSummary, _$identity);

  /// Serializes this AdminUserSummary to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AdminUserSummary&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.role, role) || other.role == role)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.businessName, businessName) || other.businessName == businessName)&&(identical(other.email, email) || other.email == email)&&(identical(other.phone, phone) || other.phone == phone)&&(identical(other.avatarUrl, avatarUrl) || other.avatarUrl == avatarUrl)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.lastSignIn, lastSignIn) || other.lastSignIn == lastSignIn));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,userId,role,displayName,businessName,email,phone,avatarUrl,createdAt,lastSignIn);

@override
String toString() {
  return 'AdminUserSummary(userId: $userId, role: $role, displayName: $displayName, businessName: $businessName, email: $email, phone: $phone, avatarUrl: $avatarUrl, createdAt: $createdAt, lastSignIn: $lastSignIn)';
}


}

/// @nodoc
abstract mixin class $AdminUserSummaryCopyWith<$Res>  {
  factory $AdminUserSummaryCopyWith(AdminUserSummary value, $Res Function(AdminUserSummary) _then) = _$AdminUserSummaryCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'user_id') String userId, String role,@JsonKey(name: 'display_name') String? displayName,@JsonKey(name: 'business_name') String? businessName, String? email, String? phone,@JsonKey(name: 'avatar_url') String? avatarUrl,@JsonKey(name: 'created_at') DateTime createdAt,@JsonKey(name: 'last_sign_in') DateTime? lastSignIn
});




}
/// @nodoc
class _$AdminUserSummaryCopyWithImpl<$Res>
    implements $AdminUserSummaryCopyWith<$Res> {
  _$AdminUserSummaryCopyWithImpl(this._self, this._then);

  final AdminUserSummary _self;
  final $Res Function(AdminUserSummary) _then;

/// Create a copy of AdminUserSummary
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? userId = null,Object? role = null,Object? displayName = freezed,Object? businessName = freezed,Object? email = freezed,Object? phone = freezed,Object? avatarUrl = freezed,Object? createdAt = null,Object? lastSignIn = freezed,}) {
  return _then(_self.copyWith(
userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as String,displayName: freezed == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String?,businessName: freezed == businessName ? _self.businessName : businessName // ignore: cast_nullable_to_non_nullable
as String?,email: freezed == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String?,phone: freezed == phone ? _self.phone : phone // ignore: cast_nullable_to_non_nullable
as String?,avatarUrl: freezed == avatarUrl ? _self.avatarUrl : avatarUrl // ignore: cast_nullable_to_non_nullable
as String?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,lastSignIn: freezed == lastSignIn ? _self.lastSignIn : lastSignIn // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [AdminUserSummary].
extension AdminUserSummaryPatterns on AdminUserSummary {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AdminUserSummary value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AdminUserSummary() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AdminUserSummary value)  $default,){
final _that = this;
switch (_that) {
case _AdminUserSummary():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AdminUserSummary value)?  $default,){
final _that = this;
switch (_that) {
case _AdminUserSummary() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'user_id')  String userId,  String role, @JsonKey(name: 'display_name')  String? displayName, @JsonKey(name: 'business_name')  String? businessName,  String? email,  String? phone, @JsonKey(name: 'avatar_url')  String? avatarUrl, @JsonKey(name: 'created_at')  DateTime createdAt, @JsonKey(name: 'last_sign_in')  DateTime? lastSignIn)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AdminUserSummary() when $default != null:
return $default(_that.userId,_that.role,_that.displayName,_that.businessName,_that.email,_that.phone,_that.avatarUrl,_that.createdAt,_that.lastSignIn);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'user_id')  String userId,  String role, @JsonKey(name: 'display_name')  String? displayName, @JsonKey(name: 'business_name')  String? businessName,  String? email,  String? phone, @JsonKey(name: 'avatar_url')  String? avatarUrl, @JsonKey(name: 'created_at')  DateTime createdAt, @JsonKey(name: 'last_sign_in')  DateTime? lastSignIn)  $default,) {final _that = this;
switch (_that) {
case _AdminUserSummary():
return $default(_that.userId,_that.role,_that.displayName,_that.businessName,_that.email,_that.phone,_that.avatarUrl,_that.createdAt,_that.lastSignIn);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'user_id')  String userId,  String role, @JsonKey(name: 'display_name')  String? displayName, @JsonKey(name: 'business_name')  String? businessName,  String? email,  String? phone, @JsonKey(name: 'avatar_url')  String? avatarUrl, @JsonKey(name: 'created_at')  DateTime createdAt, @JsonKey(name: 'last_sign_in')  DateTime? lastSignIn)?  $default,) {final _that = this;
switch (_that) {
case _AdminUserSummary() when $default != null:
return $default(_that.userId,_that.role,_that.displayName,_that.businessName,_that.email,_that.phone,_that.avatarUrl,_that.createdAt,_that.lastSignIn);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AdminUserSummary extends AdminUserSummary {
  const _AdminUserSummary({@JsonKey(name: 'user_id') required this.userId, required this.role, @JsonKey(name: 'display_name') this.displayName, @JsonKey(name: 'business_name') this.businessName, this.email, this.phone, @JsonKey(name: 'avatar_url') this.avatarUrl, @JsonKey(name: 'created_at') required this.createdAt, @JsonKey(name: 'last_sign_in') this.lastSignIn}): super._();
  factory _AdminUserSummary.fromJson(Map<String, dynamic> json) => _$AdminUserSummaryFromJson(json);

@override@JsonKey(name: 'user_id') final  String userId;
@override final  String role;
@override@JsonKey(name: 'display_name') final  String? displayName;
@override@JsonKey(name: 'business_name') final  String? businessName;
@override final  String? email;
@override final  String? phone;
@override@JsonKey(name: 'avatar_url') final  String? avatarUrl;
@override@JsonKey(name: 'created_at') final  DateTime createdAt;
@override@JsonKey(name: 'last_sign_in') final  DateTime? lastSignIn;

/// Create a copy of AdminUserSummary
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AdminUserSummaryCopyWith<_AdminUserSummary> get copyWith => __$AdminUserSummaryCopyWithImpl<_AdminUserSummary>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AdminUserSummaryToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AdminUserSummary&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.role, role) || other.role == role)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.businessName, businessName) || other.businessName == businessName)&&(identical(other.email, email) || other.email == email)&&(identical(other.phone, phone) || other.phone == phone)&&(identical(other.avatarUrl, avatarUrl) || other.avatarUrl == avatarUrl)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.lastSignIn, lastSignIn) || other.lastSignIn == lastSignIn));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,userId,role,displayName,businessName,email,phone,avatarUrl,createdAt,lastSignIn);

@override
String toString() {
  return 'AdminUserSummary(userId: $userId, role: $role, displayName: $displayName, businessName: $businessName, email: $email, phone: $phone, avatarUrl: $avatarUrl, createdAt: $createdAt, lastSignIn: $lastSignIn)';
}


}

/// @nodoc
abstract mixin class _$AdminUserSummaryCopyWith<$Res> implements $AdminUserSummaryCopyWith<$Res> {
  factory _$AdminUserSummaryCopyWith(_AdminUserSummary value, $Res Function(_AdminUserSummary) _then) = __$AdminUserSummaryCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'user_id') String userId, String role,@JsonKey(name: 'display_name') String? displayName,@JsonKey(name: 'business_name') String? businessName, String? email, String? phone,@JsonKey(name: 'avatar_url') String? avatarUrl,@JsonKey(name: 'created_at') DateTime createdAt,@JsonKey(name: 'last_sign_in') DateTime? lastSignIn
});




}
/// @nodoc
class __$AdminUserSummaryCopyWithImpl<$Res>
    implements _$AdminUserSummaryCopyWith<$Res> {
  __$AdminUserSummaryCopyWithImpl(this._self, this._then);

  final _AdminUserSummary _self;
  final $Res Function(_AdminUserSummary) _then;

/// Create a copy of AdminUserSummary
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? userId = null,Object? role = null,Object? displayName = freezed,Object? businessName = freezed,Object? email = freezed,Object? phone = freezed,Object? avatarUrl = freezed,Object? createdAt = null,Object? lastSignIn = freezed,}) {
  return _then(_AdminUserSummary(
userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as String,displayName: freezed == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String?,businessName: freezed == businessName ? _self.businessName : businessName // ignore: cast_nullable_to_non_nullable
as String?,email: freezed == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String?,phone: freezed == phone ? _self.phone : phone // ignore: cast_nullable_to_non_nullable
as String?,avatarUrl: freezed == avatarUrl ? _self.avatarUrl : avatarUrl // ignore: cast_nullable_to_non_nullable
as String?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,lastSignIn: freezed == lastSignIn ? _self.lastSignIn : lastSignIn // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}


/// @nodoc
mixin _$AdminBookingCounts {

 int get total; int get upcoming; int get completed; int get cancelled;@JsonKey(name: 'no_show') int get noShow; int get declined;
/// Create a copy of AdminBookingCounts
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AdminBookingCountsCopyWith<AdminBookingCounts> get copyWith => _$AdminBookingCountsCopyWithImpl<AdminBookingCounts>(this as AdminBookingCounts, _$identity);

  /// Serializes this AdminBookingCounts to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AdminBookingCounts&&(identical(other.total, total) || other.total == total)&&(identical(other.upcoming, upcoming) || other.upcoming == upcoming)&&(identical(other.completed, completed) || other.completed == completed)&&(identical(other.cancelled, cancelled) || other.cancelled == cancelled)&&(identical(other.noShow, noShow) || other.noShow == noShow)&&(identical(other.declined, declined) || other.declined == declined));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,total,upcoming,completed,cancelled,noShow,declined);

@override
String toString() {
  return 'AdminBookingCounts(total: $total, upcoming: $upcoming, completed: $completed, cancelled: $cancelled, noShow: $noShow, declined: $declined)';
}


}

/// @nodoc
abstract mixin class $AdminBookingCountsCopyWith<$Res>  {
  factory $AdminBookingCountsCopyWith(AdminBookingCounts value, $Res Function(AdminBookingCounts) _then) = _$AdminBookingCountsCopyWithImpl;
@useResult
$Res call({
 int total, int upcoming, int completed, int cancelled,@JsonKey(name: 'no_show') int noShow, int declined
});




}
/// @nodoc
class _$AdminBookingCountsCopyWithImpl<$Res>
    implements $AdminBookingCountsCopyWith<$Res> {
  _$AdminBookingCountsCopyWithImpl(this._self, this._then);

  final AdminBookingCounts _self;
  final $Res Function(AdminBookingCounts) _then;

/// Create a copy of AdminBookingCounts
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? total = null,Object? upcoming = null,Object? completed = null,Object? cancelled = null,Object? noShow = null,Object? declined = null,}) {
  return _then(_self.copyWith(
total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as int,upcoming: null == upcoming ? _self.upcoming : upcoming // ignore: cast_nullable_to_non_nullable
as int,completed: null == completed ? _self.completed : completed // ignore: cast_nullable_to_non_nullable
as int,cancelled: null == cancelled ? _self.cancelled : cancelled // ignore: cast_nullable_to_non_nullable
as int,noShow: null == noShow ? _self.noShow : noShow // ignore: cast_nullable_to_non_nullable
as int,declined: null == declined ? _self.declined : declined // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [AdminBookingCounts].
extension AdminBookingCountsPatterns on AdminBookingCounts {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AdminBookingCounts value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AdminBookingCounts() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AdminBookingCounts value)  $default,){
final _that = this;
switch (_that) {
case _AdminBookingCounts():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AdminBookingCounts value)?  $default,){
final _that = this;
switch (_that) {
case _AdminBookingCounts() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int total,  int upcoming,  int completed,  int cancelled, @JsonKey(name: 'no_show')  int noShow,  int declined)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AdminBookingCounts() when $default != null:
return $default(_that.total,_that.upcoming,_that.completed,_that.cancelled,_that.noShow,_that.declined);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int total,  int upcoming,  int completed,  int cancelled, @JsonKey(name: 'no_show')  int noShow,  int declined)  $default,) {final _that = this;
switch (_that) {
case _AdminBookingCounts():
return $default(_that.total,_that.upcoming,_that.completed,_that.cancelled,_that.noShow,_that.declined);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int total,  int upcoming,  int completed,  int cancelled, @JsonKey(name: 'no_show')  int noShow,  int declined)?  $default,) {final _that = this;
switch (_that) {
case _AdminBookingCounts() when $default != null:
return $default(_that.total,_that.upcoming,_that.completed,_that.cancelled,_that.noShow,_that.declined);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AdminBookingCounts implements AdminBookingCounts {
  const _AdminBookingCounts({this.total = 0, this.upcoming = 0, this.completed = 0, this.cancelled = 0, @JsonKey(name: 'no_show') this.noShow = 0, this.declined = 0});
  factory _AdminBookingCounts.fromJson(Map<String, dynamic> json) => _$AdminBookingCountsFromJson(json);

@override@JsonKey() final  int total;
@override@JsonKey() final  int upcoming;
@override@JsonKey() final  int completed;
@override@JsonKey() final  int cancelled;
@override@JsonKey(name: 'no_show') final  int noShow;
@override@JsonKey() final  int declined;

/// Create a copy of AdminBookingCounts
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AdminBookingCountsCopyWith<_AdminBookingCounts> get copyWith => __$AdminBookingCountsCopyWithImpl<_AdminBookingCounts>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AdminBookingCountsToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AdminBookingCounts&&(identical(other.total, total) || other.total == total)&&(identical(other.upcoming, upcoming) || other.upcoming == upcoming)&&(identical(other.completed, completed) || other.completed == completed)&&(identical(other.cancelled, cancelled) || other.cancelled == cancelled)&&(identical(other.noShow, noShow) || other.noShow == noShow)&&(identical(other.declined, declined) || other.declined == declined));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,total,upcoming,completed,cancelled,noShow,declined);

@override
String toString() {
  return 'AdminBookingCounts(total: $total, upcoming: $upcoming, completed: $completed, cancelled: $cancelled, noShow: $noShow, declined: $declined)';
}


}

/// @nodoc
abstract mixin class _$AdminBookingCountsCopyWith<$Res> implements $AdminBookingCountsCopyWith<$Res> {
  factory _$AdminBookingCountsCopyWith(_AdminBookingCounts value, $Res Function(_AdminBookingCounts) _then) = __$AdminBookingCountsCopyWithImpl;
@override @useResult
$Res call({
 int total, int upcoming, int completed, int cancelled,@JsonKey(name: 'no_show') int noShow, int declined
});




}
/// @nodoc
class __$AdminBookingCountsCopyWithImpl<$Res>
    implements _$AdminBookingCountsCopyWith<$Res> {
  __$AdminBookingCountsCopyWithImpl(this._self, this._then);

  final _AdminBookingCounts _self;
  final $Res Function(_AdminBookingCounts) _then;

/// Create a copy of AdminBookingCounts
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? total = null,Object? upcoming = null,Object? completed = null,Object? cancelled = null,Object? noShow = null,Object? declined = null,}) {
  return _then(_AdminBookingCounts(
total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as int,upcoming: null == upcoming ? _self.upcoming : upcoming // ignore: cast_nullable_to_non_nullable
as int,completed: null == completed ? _self.completed : completed // ignore: cast_nullable_to_non_nullable
as int,cancelled: null == cancelled ? _self.cancelled : cancelled // ignore: cast_nullable_to_non_nullable
as int,noShow: null == noShow ? _self.noShow : noShow // ignore: cast_nullable_to_non_nullable
as int,declined: null == declined ? _self.declined : declined // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$AdminBookingSummary {

 String get id; String get reference; String get status;@JsonKey(name: 'starts_at') DateTime get startsAt;@JsonKey(name: 'total_cents') int get totalCents;@JsonKey(name: 'payment_method') String get paymentMethod;@JsonKey(name: 'payment_status') String get paymentStatus;@JsonKey(name: 'other_party') String? get otherParty;
/// Create a copy of AdminBookingSummary
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AdminBookingSummaryCopyWith<AdminBookingSummary> get copyWith => _$AdminBookingSummaryCopyWithImpl<AdminBookingSummary>(this as AdminBookingSummary, _$identity);

  /// Serializes this AdminBookingSummary to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AdminBookingSummary&&(identical(other.id, id) || other.id == id)&&(identical(other.reference, reference) || other.reference == reference)&&(identical(other.status, status) || other.status == status)&&(identical(other.startsAt, startsAt) || other.startsAt == startsAt)&&(identical(other.totalCents, totalCents) || other.totalCents == totalCents)&&(identical(other.paymentMethod, paymentMethod) || other.paymentMethod == paymentMethod)&&(identical(other.paymentStatus, paymentStatus) || other.paymentStatus == paymentStatus)&&(identical(other.otherParty, otherParty) || other.otherParty == otherParty));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,reference,status,startsAt,totalCents,paymentMethod,paymentStatus,otherParty);

@override
String toString() {
  return 'AdminBookingSummary(id: $id, reference: $reference, status: $status, startsAt: $startsAt, totalCents: $totalCents, paymentMethod: $paymentMethod, paymentStatus: $paymentStatus, otherParty: $otherParty)';
}


}

/// @nodoc
abstract mixin class $AdminBookingSummaryCopyWith<$Res>  {
  factory $AdminBookingSummaryCopyWith(AdminBookingSummary value, $Res Function(AdminBookingSummary) _then) = _$AdminBookingSummaryCopyWithImpl;
@useResult
$Res call({
 String id, String reference, String status,@JsonKey(name: 'starts_at') DateTime startsAt,@JsonKey(name: 'total_cents') int totalCents,@JsonKey(name: 'payment_method') String paymentMethod,@JsonKey(name: 'payment_status') String paymentStatus,@JsonKey(name: 'other_party') String? otherParty
});




}
/// @nodoc
class _$AdminBookingSummaryCopyWithImpl<$Res>
    implements $AdminBookingSummaryCopyWith<$Res> {
  _$AdminBookingSummaryCopyWithImpl(this._self, this._then);

  final AdminBookingSummary _self;
  final $Res Function(AdminBookingSummary) _then;

/// Create a copy of AdminBookingSummary
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? reference = null,Object? status = null,Object? startsAt = null,Object? totalCents = null,Object? paymentMethod = null,Object? paymentStatus = null,Object? otherParty = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,reference: null == reference ? _self.reference : reference // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,startsAt: null == startsAt ? _self.startsAt : startsAt // ignore: cast_nullable_to_non_nullable
as DateTime,totalCents: null == totalCents ? _self.totalCents : totalCents // ignore: cast_nullable_to_non_nullable
as int,paymentMethod: null == paymentMethod ? _self.paymentMethod : paymentMethod // ignore: cast_nullable_to_non_nullable
as String,paymentStatus: null == paymentStatus ? _self.paymentStatus : paymentStatus // ignore: cast_nullable_to_non_nullable
as String,otherParty: freezed == otherParty ? _self.otherParty : otherParty // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [AdminBookingSummary].
extension AdminBookingSummaryPatterns on AdminBookingSummary {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AdminBookingSummary value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AdminBookingSummary() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AdminBookingSummary value)  $default,){
final _that = this;
switch (_that) {
case _AdminBookingSummary():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AdminBookingSummary value)?  $default,){
final _that = this;
switch (_that) {
case _AdminBookingSummary() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String reference,  String status, @JsonKey(name: 'starts_at')  DateTime startsAt, @JsonKey(name: 'total_cents')  int totalCents, @JsonKey(name: 'payment_method')  String paymentMethod, @JsonKey(name: 'payment_status')  String paymentStatus, @JsonKey(name: 'other_party')  String? otherParty)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AdminBookingSummary() when $default != null:
return $default(_that.id,_that.reference,_that.status,_that.startsAt,_that.totalCents,_that.paymentMethod,_that.paymentStatus,_that.otherParty);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String reference,  String status, @JsonKey(name: 'starts_at')  DateTime startsAt, @JsonKey(name: 'total_cents')  int totalCents, @JsonKey(name: 'payment_method')  String paymentMethod, @JsonKey(name: 'payment_status')  String paymentStatus, @JsonKey(name: 'other_party')  String? otherParty)  $default,) {final _that = this;
switch (_that) {
case _AdminBookingSummary():
return $default(_that.id,_that.reference,_that.status,_that.startsAt,_that.totalCents,_that.paymentMethod,_that.paymentStatus,_that.otherParty);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String reference,  String status, @JsonKey(name: 'starts_at')  DateTime startsAt, @JsonKey(name: 'total_cents')  int totalCents, @JsonKey(name: 'payment_method')  String paymentMethod, @JsonKey(name: 'payment_status')  String paymentStatus, @JsonKey(name: 'other_party')  String? otherParty)?  $default,) {final _that = this;
switch (_that) {
case _AdminBookingSummary() when $default != null:
return $default(_that.id,_that.reference,_that.status,_that.startsAt,_that.totalCents,_that.paymentMethod,_that.paymentStatus,_that.otherParty);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AdminBookingSummary implements AdminBookingSummary {
  const _AdminBookingSummary({required this.id, required this.reference, required this.status, @JsonKey(name: 'starts_at') required this.startsAt, @JsonKey(name: 'total_cents') this.totalCents = 0, @JsonKey(name: 'payment_method') required this.paymentMethod, @JsonKey(name: 'payment_status') required this.paymentStatus, @JsonKey(name: 'other_party') this.otherParty});
  factory _AdminBookingSummary.fromJson(Map<String, dynamic> json) => _$AdminBookingSummaryFromJson(json);

@override final  String id;
@override final  String reference;
@override final  String status;
@override@JsonKey(name: 'starts_at') final  DateTime startsAt;
@override@JsonKey(name: 'total_cents') final  int totalCents;
@override@JsonKey(name: 'payment_method') final  String paymentMethod;
@override@JsonKey(name: 'payment_status') final  String paymentStatus;
@override@JsonKey(name: 'other_party') final  String? otherParty;

/// Create a copy of AdminBookingSummary
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AdminBookingSummaryCopyWith<_AdminBookingSummary> get copyWith => __$AdminBookingSummaryCopyWithImpl<_AdminBookingSummary>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AdminBookingSummaryToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AdminBookingSummary&&(identical(other.id, id) || other.id == id)&&(identical(other.reference, reference) || other.reference == reference)&&(identical(other.status, status) || other.status == status)&&(identical(other.startsAt, startsAt) || other.startsAt == startsAt)&&(identical(other.totalCents, totalCents) || other.totalCents == totalCents)&&(identical(other.paymentMethod, paymentMethod) || other.paymentMethod == paymentMethod)&&(identical(other.paymentStatus, paymentStatus) || other.paymentStatus == paymentStatus)&&(identical(other.otherParty, otherParty) || other.otherParty == otherParty));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,reference,status,startsAt,totalCents,paymentMethod,paymentStatus,otherParty);

@override
String toString() {
  return 'AdminBookingSummary(id: $id, reference: $reference, status: $status, startsAt: $startsAt, totalCents: $totalCents, paymentMethod: $paymentMethod, paymentStatus: $paymentStatus, otherParty: $otherParty)';
}


}

/// @nodoc
abstract mixin class _$AdminBookingSummaryCopyWith<$Res> implements $AdminBookingSummaryCopyWith<$Res> {
  factory _$AdminBookingSummaryCopyWith(_AdminBookingSummary value, $Res Function(_AdminBookingSummary) _then) = __$AdminBookingSummaryCopyWithImpl;
@override @useResult
$Res call({
 String id, String reference, String status,@JsonKey(name: 'starts_at') DateTime startsAt,@JsonKey(name: 'total_cents') int totalCents,@JsonKey(name: 'payment_method') String paymentMethod,@JsonKey(name: 'payment_status') String paymentStatus,@JsonKey(name: 'other_party') String? otherParty
});




}
/// @nodoc
class __$AdminBookingSummaryCopyWithImpl<$Res>
    implements _$AdminBookingSummaryCopyWith<$Res> {
  __$AdminBookingSummaryCopyWithImpl(this._self, this._then);

  final _AdminBookingSummary _self;
  final $Res Function(_AdminBookingSummary) _then;

/// Create a copy of AdminBookingSummary
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? reference = null,Object? status = null,Object? startsAt = null,Object? totalCents = null,Object? paymentMethod = null,Object? paymentStatus = null,Object? otherParty = freezed,}) {
  return _then(_AdminBookingSummary(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,reference: null == reference ? _self.reference : reference // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,startsAt: null == startsAt ? _self.startsAt : startsAt // ignore: cast_nullable_to_non_nullable
as DateTime,totalCents: null == totalCents ? _self.totalCents : totalCents // ignore: cast_nullable_to_non_nullable
as int,paymentMethod: null == paymentMethod ? _self.paymentMethod : paymentMethod // ignore: cast_nullable_to_non_nullable
as String,paymentStatus: null == paymentStatus ? _self.paymentStatus : paymentStatus // ignore: cast_nullable_to_non_nullable
as String,otherParty: freezed == otherParty ? _self.otherParty : otherParty // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$AdminUserDetail {

@JsonKey(name: 'user_id') String get userId; String get role;@JsonKey(name: 'first_name') String? get firstName;@JsonKey(name: 'last_name') String? get lastName;@JsonKey(name: 'business_name') String? get businessName; String? get email;@JsonKey(name: 'email_confirmed_at') DateTime? get emailConfirmedAt; String? get phone;/// When the phone number was confirmed by a texted code, if it was.
@JsonKey(name: 'phone_verified_at') DateTime? get phoneVerifiedAt;@JsonKey(name: 'avatar_url') String? get avatarUrl; String? get address;@JsonKey(name: 'created_at') DateTime get createdAt;@JsonKey(name: 'last_sign_in') DateTime? get lastSignIn;@JsonKey(name: 'banned_until') DateTime? get bannedUntil; AdminBookingCounts get bookings;@JsonKey(name: 'booking_settings') Map<String, dynamic>? get bookingSettings;@JsonKey(name: 'recent_bookings') List<AdminBookingSummary> get recentBookings;
/// Create a copy of AdminUserDetail
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AdminUserDetailCopyWith<AdminUserDetail> get copyWith => _$AdminUserDetailCopyWithImpl<AdminUserDetail>(this as AdminUserDetail, _$identity);

  /// Serializes this AdminUserDetail to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AdminUserDetail&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.role, role) || other.role == role)&&(identical(other.firstName, firstName) || other.firstName == firstName)&&(identical(other.lastName, lastName) || other.lastName == lastName)&&(identical(other.businessName, businessName) || other.businessName == businessName)&&(identical(other.email, email) || other.email == email)&&(identical(other.emailConfirmedAt, emailConfirmedAt) || other.emailConfirmedAt == emailConfirmedAt)&&(identical(other.phone, phone) || other.phone == phone)&&(identical(other.phoneVerifiedAt, phoneVerifiedAt) || other.phoneVerifiedAt == phoneVerifiedAt)&&(identical(other.avatarUrl, avatarUrl) || other.avatarUrl == avatarUrl)&&(identical(other.address, address) || other.address == address)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.lastSignIn, lastSignIn) || other.lastSignIn == lastSignIn)&&(identical(other.bannedUntil, bannedUntil) || other.bannedUntil == bannedUntil)&&(identical(other.bookings, bookings) || other.bookings == bookings)&&const DeepCollectionEquality().equals(other.bookingSettings, bookingSettings)&&const DeepCollectionEquality().equals(other.recentBookings, recentBookings));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,userId,role,firstName,lastName,businessName,email,emailConfirmedAt,phone,phoneVerifiedAt,avatarUrl,address,createdAt,lastSignIn,bannedUntil,bookings,const DeepCollectionEquality().hash(bookingSettings),const DeepCollectionEquality().hash(recentBookings));

@override
String toString() {
  return 'AdminUserDetail(userId: $userId, role: $role, firstName: $firstName, lastName: $lastName, businessName: $businessName, email: $email, emailConfirmedAt: $emailConfirmedAt, phone: $phone, phoneVerifiedAt: $phoneVerifiedAt, avatarUrl: $avatarUrl, address: $address, createdAt: $createdAt, lastSignIn: $lastSignIn, bannedUntil: $bannedUntil, bookings: $bookings, bookingSettings: $bookingSettings, recentBookings: $recentBookings)';
}


}

/// @nodoc
abstract mixin class $AdminUserDetailCopyWith<$Res>  {
  factory $AdminUserDetailCopyWith(AdminUserDetail value, $Res Function(AdminUserDetail) _then) = _$AdminUserDetailCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'user_id') String userId, String role,@JsonKey(name: 'first_name') String? firstName,@JsonKey(name: 'last_name') String? lastName,@JsonKey(name: 'business_name') String? businessName, String? email,@JsonKey(name: 'email_confirmed_at') DateTime? emailConfirmedAt, String? phone,@JsonKey(name: 'phone_verified_at') DateTime? phoneVerifiedAt,@JsonKey(name: 'avatar_url') String? avatarUrl, String? address,@JsonKey(name: 'created_at') DateTime createdAt,@JsonKey(name: 'last_sign_in') DateTime? lastSignIn,@JsonKey(name: 'banned_until') DateTime? bannedUntil, AdminBookingCounts bookings,@JsonKey(name: 'booking_settings') Map<String, dynamic>? bookingSettings,@JsonKey(name: 'recent_bookings') List<AdminBookingSummary> recentBookings
});


$AdminBookingCountsCopyWith<$Res> get bookings;

}
/// @nodoc
class _$AdminUserDetailCopyWithImpl<$Res>
    implements $AdminUserDetailCopyWith<$Res> {
  _$AdminUserDetailCopyWithImpl(this._self, this._then);

  final AdminUserDetail _self;
  final $Res Function(AdminUserDetail) _then;

/// Create a copy of AdminUserDetail
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? userId = null,Object? role = null,Object? firstName = freezed,Object? lastName = freezed,Object? businessName = freezed,Object? email = freezed,Object? emailConfirmedAt = freezed,Object? phone = freezed,Object? phoneVerifiedAt = freezed,Object? avatarUrl = freezed,Object? address = freezed,Object? createdAt = null,Object? lastSignIn = freezed,Object? bannedUntil = freezed,Object? bookings = null,Object? bookingSettings = freezed,Object? recentBookings = null,}) {
  return _then(_self.copyWith(
userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as String,firstName: freezed == firstName ? _self.firstName : firstName // ignore: cast_nullable_to_non_nullable
as String?,lastName: freezed == lastName ? _self.lastName : lastName // ignore: cast_nullable_to_non_nullable
as String?,businessName: freezed == businessName ? _self.businessName : businessName // ignore: cast_nullable_to_non_nullable
as String?,email: freezed == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String?,emailConfirmedAt: freezed == emailConfirmedAt ? _self.emailConfirmedAt : emailConfirmedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,phone: freezed == phone ? _self.phone : phone // ignore: cast_nullable_to_non_nullable
as String?,phoneVerifiedAt: freezed == phoneVerifiedAt ? _self.phoneVerifiedAt : phoneVerifiedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,avatarUrl: freezed == avatarUrl ? _self.avatarUrl : avatarUrl // ignore: cast_nullable_to_non_nullable
as String?,address: freezed == address ? _self.address : address // ignore: cast_nullable_to_non_nullable
as String?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,lastSignIn: freezed == lastSignIn ? _self.lastSignIn : lastSignIn // ignore: cast_nullable_to_non_nullable
as DateTime?,bannedUntil: freezed == bannedUntil ? _self.bannedUntil : bannedUntil // ignore: cast_nullable_to_non_nullable
as DateTime?,bookings: null == bookings ? _self.bookings : bookings // ignore: cast_nullable_to_non_nullable
as AdminBookingCounts,bookingSettings: freezed == bookingSettings ? _self.bookingSettings : bookingSettings // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,recentBookings: null == recentBookings ? _self.recentBookings : recentBookings // ignore: cast_nullable_to_non_nullable
as List<AdminBookingSummary>,
  ));
}
/// Create a copy of AdminUserDetail
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AdminBookingCountsCopyWith<$Res> get bookings {
  
  return $AdminBookingCountsCopyWith<$Res>(_self.bookings, (value) {
    return _then(_self.copyWith(bookings: value));
  });
}
}


/// Adds pattern-matching-related methods to [AdminUserDetail].
extension AdminUserDetailPatterns on AdminUserDetail {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AdminUserDetail value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AdminUserDetail() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AdminUserDetail value)  $default,){
final _that = this;
switch (_that) {
case _AdminUserDetail():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AdminUserDetail value)?  $default,){
final _that = this;
switch (_that) {
case _AdminUserDetail() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'user_id')  String userId,  String role, @JsonKey(name: 'first_name')  String? firstName, @JsonKey(name: 'last_name')  String? lastName, @JsonKey(name: 'business_name')  String? businessName,  String? email, @JsonKey(name: 'email_confirmed_at')  DateTime? emailConfirmedAt,  String? phone, @JsonKey(name: 'phone_verified_at')  DateTime? phoneVerifiedAt, @JsonKey(name: 'avatar_url')  String? avatarUrl,  String? address, @JsonKey(name: 'created_at')  DateTime createdAt, @JsonKey(name: 'last_sign_in')  DateTime? lastSignIn, @JsonKey(name: 'banned_until')  DateTime? bannedUntil,  AdminBookingCounts bookings, @JsonKey(name: 'booking_settings')  Map<String, dynamic>? bookingSettings, @JsonKey(name: 'recent_bookings')  List<AdminBookingSummary> recentBookings)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AdminUserDetail() when $default != null:
return $default(_that.userId,_that.role,_that.firstName,_that.lastName,_that.businessName,_that.email,_that.emailConfirmedAt,_that.phone,_that.phoneVerifiedAt,_that.avatarUrl,_that.address,_that.createdAt,_that.lastSignIn,_that.bannedUntil,_that.bookings,_that.bookingSettings,_that.recentBookings);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'user_id')  String userId,  String role, @JsonKey(name: 'first_name')  String? firstName, @JsonKey(name: 'last_name')  String? lastName, @JsonKey(name: 'business_name')  String? businessName,  String? email, @JsonKey(name: 'email_confirmed_at')  DateTime? emailConfirmedAt,  String? phone, @JsonKey(name: 'phone_verified_at')  DateTime? phoneVerifiedAt, @JsonKey(name: 'avatar_url')  String? avatarUrl,  String? address, @JsonKey(name: 'created_at')  DateTime createdAt, @JsonKey(name: 'last_sign_in')  DateTime? lastSignIn, @JsonKey(name: 'banned_until')  DateTime? bannedUntil,  AdminBookingCounts bookings, @JsonKey(name: 'booking_settings')  Map<String, dynamic>? bookingSettings, @JsonKey(name: 'recent_bookings')  List<AdminBookingSummary> recentBookings)  $default,) {final _that = this;
switch (_that) {
case _AdminUserDetail():
return $default(_that.userId,_that.role,_that.firstName,_that.lastName,_that.businessName,_that.email,_that.emailConfirmedAt,_that.phone,_that.phoneVerifiedAt,_that.avatarUrl,_that.address,_that.createdAt,_that.lastSignIn,_that.bannedUntil,_that.bookings,_that.bookingSettings,_that.recentBookings);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'user_id')  String userId,  String role, @JsonKey(name: 'first_name')  String? firstName, @JsonKey(name: 'last_name')  String? lastName, @JsonKey(name: 'business_name')  String? businessName,  String? email, @JsonKey(name: 'email_confirmed_at')  DateTime? emailConfirmedAt,  String? phone, @JsonKey(name: 'phone_verified_at')  DateTime? phoneVerifiedAt, @JsonKey(name: 'avatar_url')  String? avatarUrl,  String? address, @JsonKey(name: 'created_at')  DateTime createdAt, @JsonKey(name: 'last_sign_in')  DateTime? lastSignIn, @JsonKey(name: 'banned_until')  DateTime? bannedUntil,  AdminBookingCounts bookings, @JsonKey(name: 'booking_settings')  Map<String, dynamic>? bookingSettings, @JsonKey(name: 'recent_bookings')  List<AdminBookingSummary> recentBookings)?  $default,) {final _that = this;
switch (_that) {
case _AdminUserDetail() when $default != null:
return $default(_that.userId,_that.role,_that.firstName,_that.lastName,_that.businessName,_that.email,_that.emailConfirmedAt,_that.phone,_that.phoneVerifiedAt,_that.avatarUrl,_that.address,_that.createdAt,_that.lastSignIn,_that.bannedUntil,_that.bookings,_that.bookingSettings,_that.recentBookings);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AdminUserDetail extends AdminUserDetail {
  const _AdminUserDetail({@JsonKey(name: 'user_id') required this.userId, required this.role, @JsonKey(name: 'first_name') this.firstName, @JsonKey(name: 'last_name') this.lastName, @JsonKey(name: 'business_name') this.businessName, this.email, @JsonKey(name: 'email_confirmed_at') this.emailConfirmedAt, this.phone, @JsonKey(name: 'phone_verified_at') this.phoneVerifiedAt, @JsonKey(name: 'avatar_url') this.avatarUrl, this.address, @JsonKey(name: 'created_at') required this.createdAt, @JsonKey(name: 'last_sign_in') this.lastSignIn, @JsonKey(name: 'banned_until') this.bannedUntil, this.bookings = const AdminBookingCounts(), @JsonKey(name: 'booking_settings') final  Map<String, dynamic>? bookingSettings, @JsonKey(name: 'recent_bookings') final  List<AdminBookingSummary> recentBookings = const []}): _bookingSettings = bookingSettings,_recentBookings = recentBookings,super._();
  factory _AdminUserDetail.fromJson(Map<String, dynamic> json) => _$AdminUserDetailFromJson(json);

@override@JsonKey(name: 'user_id') final  String userId;
@override final  String role;
@override@JsonKey(name: 'first_name') final  String? firstName;
@override@JsonKey(name: 'last_name') final  String? lastName;
@override@JsonKey(name: 'business_name') final  String? businessName;
@override final  String? email;
@override@JsonKey(name: 'email_confirmed_at') final  DateTime? emailConfirmedAt;
@override final  String? phone;
/// When the phone number was confirmed by a texted code, if it was.
@override@JsonKey(name: 'phone_verified_at') final  DateTime? phoneVerifiedAt;
@override@JsonKey(name: 'avatar_url') final  String? avatarUrl;
@override final  String? address;
@override@JsonKey(name: 'created_at') final  DateTime createdAt;
@override@JsonKey(name: 'last_sign_in') final  DateTime? lastSignIn;
@override@JsonKey(name: 'banned_until') final  DateTime? bannedUntil;
@override@JsonKey() final  AdminBookingCounts bookings;
 final  Map<String, dynamic>? _bookingSettings;
@override@JsonKey(name: 'booking_settings') Map<String, dynamic>? get bookingSettings {
  final value = _bookingSettings;
  if (value == null) return null;
  if (_bookingSettings is EqualUnmodifiableMapView) return _bookingSettings;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(value);
}

 final  List<AdminBookingSummary> _recentBookings;
@override@JsonKey(name: 'recent_bookings') List<AdminBookingSummary> get recentBookings {
  if (_recentBookings is EqualUnmodifiableListView) return _recentBookings;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_recentBookings);
}


/// Create a copy of AdminUserDetail
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AdminUserDetailCopyWith<_AdminUserDetail> get copyWith => __$AdminUserDetailCopyWithImpl<_AdminUserDetail>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AdminUserDetailToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AdminUserDetail&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.role, role) || other.role == role)&&(identical(other.firstName, firstName) || other.firstName == firstName)&&(identical(other.lastName, lastName) || other.lastName == lastName)&&(identical(other.businessName, businessName) || other.businessName == businessName)&&(identical(other.email, email) || other.email == email)&&(identical(other.emailConfirmedAt, emailConfirmedAt) || other.emailConfirmedAt == emailConfirmedAt)&&(identical(other.phone, phone) || other.phone == phone)&&(identical(other.phoneVerifiedAt, phoneVerifiedAt) || other.phoneVerifiedAt == phoneVerifiedAt)&&(identical(other.avatarUrl, avatarUrl) || other.avatarUrl == avatarUrl)&&(identical(other.address, address) || other.address == address)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.lastSignIn, lastSignIn) || other.lastSignIn == lastSignIn)&&(identical(other.bannedUntil, bannedUntil) || other.bannedUntil == bannedUntil)&&(identical(other.bookings, bookings) || other.bookings == bookings)&&const DeepCollectionEquality().equals(other._bookingSettings, _bookingSettings)&&const DeepCollectionEquality().equals(other._recentBookings, _recentBookings));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,userId,role,firstName,lastName,businessName,email,emailConfirmedAt,phone,phoneVerifiedAt,avatarUrl,address,createdAt,lastSignIn,bannedUntil,bookings,const DeepCollectionEquality().hash(_bookingSettings),const DeepCollectionEquality().hash(_recentBookings));

@override
String toString() {
  return 'AdminUserDetail(userId: $userId, role: $role, firstName: $firstName, lastName: $lastName, businessName: $businessName, email: $email, emailConfirmedAt: $emailConfirmedAt, phone: $phone, phoneVerifiedAt: $phoneVerifiedAt, avatarUrl: $avatarUrl, address: $address, createdAt: $createdAt, lastSignIn: $lastSignIn, bannedUntil: $bannedUntil, bookings: $bookings, bookingSettings: $bookingSettings, recentBookings: $recentBookings)';
}


}

/// @nodoc
abstract mixin class _$AdminUserDetailCopyWith<$Res> implements $AdminUserDetailCopyWith<$Res> {
  factory _$AdminUserDetailCopyWith(_AdminUserDetail value, $Res Function(_AdminUserDetail) _then) = __$AdminUserDetailCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'user_id') String userId, String role,@JsonKey(name: 'first_name') String? firstName,@JsonKey(name: 'last_name') String? lastName,@JsonKey(name: 'business_name') String? businessName, String? email,@JsonKey(name: 'email_confirmed_at') DateTime? emailConfirmedAt, String? phone,@JsonKey(name: 'phone_verified_at') DateTime? phoneVerifiedAt,@JsonKey(name: 'avatar_url') String? avatarUrl, String? address,@JsonKey(name: 'created_at') DateTime createdAt,@JsonKey(name: 'last_sign_in') DateTime? lastSignIn,@JsonKey(name: 'banned_until') DateTime? bannedUntil, AdminBookingCounts bookings,@JsonKey(name: 'booking_settings') Map<String, dynamic>? bookingSettings,@JsonKey(name: 'recent_bookings') List<AdminBookingSummary> recentBookings
});


@override $AdminBookingCountsCopyWith<$Res> get bookings;

}
/// @nodoc
class __$AdminUserDetailCopyWithImpl<$Res>
    implements _$AdminUserDetailCopyWith<$Res> {
  __$AdminUserDetailCopyWithImpl(this._self, this._then);

  final _AdminUserDetail _self;
  final $Res Function(_AdminUserDetail) _then;

/// Create a copy of AdminUserDetail
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? userId = null,Object? role = null,Object? firstName = freezed,Object? lastName = freezed,Object? businessName = freezed,Object? email = freezed,Object? emailConfirmedAt = freezed,Object? phone = freezed,Object? phoneVerifiedAt = freezed,Object? avatarUrl = freezed,Object? address = freezed,Object? createdAt = null,Object? lastSignIn = freezed,Object? bannedUntil = freezed,Object? bookings = null,Object? bookingSettings = freezed,Object? recentBookings = null,}) {
  return _then(_AdminUserDetail(
userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as String,firstName: freezed == firstName ? _self.firstName : firstName // ignore: cast_nullable_to_non_nullable
as String?,lastName: freezed == lastName ? _self.lastName : lastName // ignore: cast_nullable_to_non_nullable
as String?,businessName: freezed == businessName ? _self.businessName : businessName // ignore: cast_nullable_to_non_nullable
as String?,email: freezed == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String?,emailConfirmedAt: freezed == emailConfirmedAt ? _self.emailConfirmedAt : emailConfirmedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,phone: freezed == phone ? _self.phone : phone // ignore: cast_nullable_to_non_nullable
as String?,phoneVerifiedAt: freezed == phoneVerifiedAt ? _self.phoneVerifiedAt : phoneVerifiedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,avatarUrl: freezed == avatarUrl ? _self.avatarUrl : avatarUrl // ignore: cast_nullable_to_non_nullable
as String?,address: freezed == address ? _self.address : address // ignore: cast_nullable_to_non_nullable
as String?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,lastSignIn: freezed == lastSignIn ? _self.lastSignIn : lastSignIn // ignore: cast_nullable_to_non_nullable
as DateTime?,bannedUntil: freezed == bannedUntil ? _self.bannedUntil : bannedUntil // ignore: cast_nullable_to_non_nullable
as DateTime?,bookings: null == bookings ? _self.bookings : bookings // ignore: cast_nullable_to_non_nullable
as AdminBookingCounts,bookingSettings: freezed == bookingSettings ? _self._bookingSettings : bookingSettings // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,recentBookings: null == recentBookings ? _self._recentBookings : recentBookings // ignore: cast_nullable_to_non_nullable
as List<AdminBookingSummary>,
  ));
}

/// Create a copy of AdminUserDetail
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AdminBookingCountsCopyWith<$Res> get bookings {
  
  return $AdminBookingCountsCopyWith<$Res>(_self.bookings, (value) {
    return _then(_self.copyWith(bookings: value));
  });
}
}


/// @nodoc
mixin _$AuditEntry {

 int get id;@JsonKey(name: 'admin_email') String? get adminEmail;@JsonKey(name: 'admin_name') String? get adminName; String get action;@JsonKey(name: 'target_type') String? get targetType;@JsonKey(name: 'target_id') String? get targetId; String? get reason; Object? get before; Object? get after;@JsonKey(name: 'created_at') DateTime get createdAt;
/// Create a copy of AuditEntry
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AuditEntryCopyWith<AuditEntry> get copyWith => _$AuditEntryCopyWithImpl<AuditEntry>(this as AuditEntry, _$identity);

  /// Serializes this AuditEntry to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AuditEntry&&(identical(other.id, id) || other.id == id)&&(identical(other.adminEmail, adminEmail) || other.adminEmail == adminEmail)&&(identical(other.adminName, adminName) || other.adminName == adminName)&&(identical(other.action, action) || other.action == action)&&(identical(other.targetType, targetType) || other.targetType == targetType)&&(identical(other.targetId, targetId) || other.targetId == targetId)&&(identical(other.reason, reason) || other.reason == reason)&&const DeepCollectionEquality().equals(other.before, before)&&const DeepCollectionEquality().equals(other.after, after)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,adminEmail,adminName,action,targetType,targetId,reason,const DeepCollectionEquality().hash(before),const DeepCollectionEquality().hash(after),createdAt);

@override
String toString() {
  return 'AuditEntry(id: $id, adminEmail: $adminEmail, adminName: $adminName, action: $action, targetType: $targetType, targetId: $targetId, reason: $reason, before: $before, after: $after, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class $AuditEntryCopyWith<$Res>  {
  factory $AuditEntryCopyWith(AuditEntry value, $Res Function(AuditEntry) _then) = _$AuditEntryCopyWithImpl;
@useResult
$Res call({
 int id,@JsonKey(name: 'admin_email') String? adminEmail,@JsonKey(name: 'admin_name') String? adminName, String action,@JsonKey(name: 'target_type') String? targetType,@JsonKey(name: 'target_id') String? targetId, String? reason, Object? before, Object? after,@JsonKey(name: 'created_at') DateTime createdAt
});




}
/// @nodoc
class _$AuditEntryCopyWithImpl<$Res>
    implements $AuditEntryCopyWith<$Res> {
  _$AuditEntryCopyWithImpl(this._self, this._then);

  final AuditEntry _self;
  final $Res Function(AuditEntry) _then;

/// Create a copy of AuditEntry
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? adminEmail = freezed,Object? adminName = freezed,Object? action = null,Object? targetType = freezed,Object? targetId = freezed,Object? reason = freezed,Object? before = freezed,Object? after = freezed,Object? createdAt = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,adminEmail: freezed == adminEmail ? _self.adminEmail : adminEmail // ignore: cast_nullable_to_non_nullable
as String?,adminName: freezed == adminName ? _self.adminName : adminName // ignore: cast_nullable_to_non_nullable
as String?,action: null == action ? _self.action : action // ignore: cast_nullable_to_non_nullable
as String,targetType: freezed == targetType ? _self.targetType : targetType // ignore: cast_nullable_to_non_nullable
as String?,targetId: freezed == targetId ? _self.targetId : targetId // ignore: cast_nullable_to_non_nullable
as String?,reason: freezed == reason ? _self.reason : reason // ignore: cast_nullable_to_non_nullable
as String?,before: freezed == before ? _self.before : before ,after: freezed == after ? _self.after : after ,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [AuditEntry].
extension AuditEntryPatterns on AuditEntry {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AuditEntry value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AuditEntry() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AuditEntry value)  $default,){
final _that = this;
switch (_that) {
case _AuditEntry():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AuditEntry value)?  $default,){
final _that = this;
switch (_that) {
case _AuditEntry() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id, @JsonKey(name: 'admin_email')  String? adminEmail, @JsonKey(name: 'admin_name')  String? adminName,  String action, @JsonKey(name: 'target_type')  String? targetType, @JsonKey(name: 'target_id')  String? targetId,  String? reason,  Object? before,  Object? after, @JsonKey(name: 'created_at')  DateTime createdAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AuditEntry() when $default != null:
return $default(_that.id,_that.adminEmail,_that.adminName,_that.action,_that.targetType,_that.targetId,_that.reason,_that.before,_that.after,_that.createdAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id, @JsonKey(name: 'admin_email')  String? adminEmail, @JsonKey(name: 'admin_name')  String? adminName,  String action, @JsonKey(name: 'target_type')  String? targetType, @JsonKey(name: 'target_id')  String? targetId,  String? reason,  Object? before,  Object? after, @JsonKey(name: 'created_at')  DateTime createdAt)  $default,) {final _that = this;
switch (_that) {
case _AuditEntry():
return $default(_that.id,_that.adminEmail,_that.adminName,_that.action,_that.targetType,_that.targetId,_that.reason,_that.before,_that.after,_that.createdAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id, @JsonKey(name: 'admin_email')  String? adminEmail, @JsonKey(name: 'admin_name')  String? adminName,  String action, @JsonKey(name: 'target_type')  String? targetType, @JsonKey(name: 'target_id')  String? targetId,  String? reason,  Object? before,  Object? after, @JsonKey(name: 'created_at')  DateTime createdAt)?  $default,) {final _that = this;
switch (_that) {
case _AuditEntry() when $default != null:
return $default(_that.id,_that.adminEmail,_that.adminName,_that.action,_that.targetType,_that.targetId,_that.reason,_that.before,_that.after,_that.createdAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AuditEntry extends AuditEntry {
  const _AuditEntry({required this.id, @JsonKey(name: 'admin_email') this.adminEmail, @JsonKey(name: 'admin_name') this.adminName, required this.action, @JsonKey(name: 'target_type') this.targetType, @JsonKey(name: 'target_id') this.targetId, this.reason, this.before, this.after, @JsonKey(name: 'created_at') required this.createdAt}): super._();
  factory _AuditEntry.fromJson(Map<String, dynamic> json) => _$AuditEntryFromJson(json);

@override final  int id;
@override@JsonKey(name: 'admin_email') final  String? adminEmail;
@override@JsonKey(name: 'admin_name') final  String? adminName;
@override final  String action;
@override@JsonKey(name: 'target_type') final  String? targetType;
@override@JsonKey(name: 'target_id') final  String? targetId;
@override final  String? reason;
@override final  Object? before;
@override final  Object? after;
@override@JsonKey(name: 'created_at') final  DateTime createdAt;

/// Create a copy of AuditEntry
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AuditEntryCopyWith<_AuditEntry> get copyWith => __$AuditEntryCopyWithImpl<_AuditEntry>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AuditEntryToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AuditEntry&&(identical(other.id, id) || other.id == id)&&(identical(other.adminEmail, adminEmail) || other.adminEmail == adminEmail)&&(identical(other.adminName, adminName) || other.adminName == adminName)&&(identical(other.action, action) || other.action == action)&&(identical(other.targetType, targetType) || other.targetType == targetType)&&(identical(other.targetId, targetId) || other.targetId == targetId)&&(identical(other.reason, reason) || other.reason == reason)&&const DeepCollectionEquality().equals(other.before, before)&&const DeepCollectionEquality().equals(other.after, after)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,adminEmail,adminName,action,targetType,targetId,reason,const DeepCollectionEquality().hash(before),const DeepCollectionEquality().hash(after),createdAt);

@override
String toString() {
  return 'AuditEntry(id: $id, adminEmail: $adminEmail, adminName: $adminName, action: $action, targetType: $targetType, targetId: $targetId, reason: $reason, before: $before, after: $after, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$AuditEntryCopyWith<$Res> implements $AuditEntryCopyWith<$Res> {
  factory _$AuditEntryCopyWith(_AuditEntry value, $Res Function(_AuditEntry) _then) = __$AuditEntryCopyWithImpl;
@override @useResult
$Res call({
 int id,@JsonKey(name: 'admin_email') String? adminEmail,@JsonKey(name: 'admin_name') String? adminName, String action,@JsonKey(name: 'target_type') String? targetType,@JsonKey(name: 'target_id') String? targetId, String? reason, Object? before, Object? after,@JsonKey(name: 'created_at') DateTime createdAt
});




}
/// @nodoc
class __$AuditEntryCopyWithImpl<$Res>
    implements _$AuditEntryCopyWith<$Res> {
  __$AuditEntryCopyWithImpl(this._self, this._then);

  final _AuditEntry _self;
  final $Res Function(_AuditEntry) _then;

/// Create a copy of AuditEntry
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? adminEmail = freezed,Object? adminName = freezed,Object? action = null,Object? targetType = freezed,Object? targetId = freezed,Object? reason = freezed,Object? before = freezed,Object? after = freezed,Object? createdAt = null,}) {
  return _then(_AuditEntry(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,adminEmail: freezed == adminEmail ? _self.adminEmail : adminEmail // ignore: cast_nullable_to_non_nullable
as String?,adminName: freezed == adminName ? _self.adminName : adminName // ignore: cast_nullable_to_non_nullable
as String?,action: null == action ? _self.action : action // ignore: cast_nullable_to_non_nullable
as String,targetType: freezed == targetType ? _self.targetType : targetType // ignore: cast_nullable_to_non_nullable
as String?,targetId: freezed == targetId ? _self.targetId : targetId // ignore: cast_nullable_to_non_nullable
as String?,reason: freezed == reason ? _self.reason : reason // ignore: cast_nullable_to_non_nullable
as String?,before: freezed == before ? _self.before : before ,after: freezed == after ? _self.after : after ,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}


/// @nodoc
mixin _$AdminServiceCity {

@JsonKey(name: 'city_id') String get cityId; String get name; String get state; double get latitude; double get longitude;@JsonKey(name: 'radius_m') int get radiusM;@JsonKey(name: 'sort_order') int get sortOrder;@JsonKey(name: 'is_active') bool get isActive;@JsonKey(name: 'provider_count') int get providerCount;@JsonKey(name: 'updated_at') DateTime? get updatedAt;
/// Create a copy of AdminServiceCity
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AdminServiceCityCopyWith<AdminServiceCity> get copyWith => _$AdminServiceCityCopyWithImpl<AdminServiceCity>(this as AdminServiceCity, _$identity);

  /// Serializes this AdminServiceCity to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AdminServiceCity&&(identical(other.cityId, cityId) || other.cityId == cityId)&&(identical(other.name, name) || other.name == name)&&(identical(other.state, state) || other.state == state)&&(identical(other.latitude, latitude) || other.latitude == latitude)&&(identical(other.longitude, longitude) || other.longitude == longitude)&&(identical(other.radiusM, radiusM) || other.radiusM == radiusM)&&(identical(other.sortOrder, sortOrder) || other.sortOrder == sortOrder)&&(identical(other.isActive, isActive) || other.isActive == isActive)&&(identical(other.providerCount, providerCount) || other.providerCount == providerCount)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,cityId,name,state,latitude,longitude,radiusM,sortOrder,isActive,providerCount,updatedAt);

@override
String toString() {
  return 'AdminServiceCity(cityId: $cityId, name: $name, state: $state, latitude: $latitude, longitude: $longitude, radiusM: $radiusM, sortOrder: $sortOrder, isActive: $isActive, providerCount: $providerCount, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class $AdminServiceCityCopyWith<$Res>  {
  factory $AdminServiceCityCopyWith(AdminServiceCity value, $Res Function(AdminServiceCity) _then) = _$AdminServiceCityCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'city_id') String cityId, String name, String state, double latitude, double longitude,@JsonKey(name: 'radius_m') int radiusM,@JsonKey(name: 'sort_order') int sortOrder,@JsonKey(name: 'is_active') bool isActive,@JsonKey(name: 'provider_count') int providerCount,@JsonKey(name: 'updated_at') DateTime? updatedAt
});




}
/// @nodoc
class _$AdminServiceCityCopyWithImpl<$Res>
    implements $AdminServiceCityCopyWith<$Res> {
  _$AdminServiceCityCopyWithImpl(this._self, this._then);

  final AdminServiceCity _self;
  final $Res Function(AdminServiceCity) _then;

/// Create a copy of AdminServiceCity
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? cityId = null,Object? name = null,Object? state = null,Object? latitude = null,Object? longitude = null,Object? radiusM = null,Object? sortOrder = null,Object? isActive = null,Object? providerCount = null,Object? updatedAt = freezed,}) {
  return _then(_self.copyWith(
cityId: null == cityId ? _self.cityId : cityId // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,state: null == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as String,latitude: null == latitude ? _self.latitude : latitude // ignore: cast_nullable_to_non_nullable
as double,longitude: null == longitude ? _self.longitude : longitude // ignore: cast_nullable_to_non_nullable
as double,radiusM: null == radiusM ? _self.radiusM : radiusM // ignore: cast_nullable_to_non_nullable
as int,sortOrder: null == sortOrder ? _self.sortOrder : sortOrder // ignore: cast_nullable_to_non_nullable
as int,isActive: null == isActive ? _self.isActive : isActive // ignore: cast_nullable_to_non_nullable
as bool,providerCount: null == providerCount ? _self.providerCount : providerCount // ignore: cast_nullable_to_non_nullable
as int,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [AdminServiceCity].
extension AdminServiceCityPatterns on AdminServiceCity {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AdminServiceCity value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AdminServiceCity() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AdminServiceCity value)  $default,){
final _that = this;
switch (_that) {
case _AdminServiceCity():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AdminServiceCity value)?  $default,){
final _that = this;
switch (_that) {
case _AdminServiceCity() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'city_id')  String cityId,  String name,  String state,  double latitude,  double longitude, @JsonKey(name: 'radius_m')  int radiusM, @JsonKey(name: 'sort_order')  int sortOrder, @JsonKey(name: 'is_active')  bool isActive, @JsonKey(name: 'provider_count')  int providerCount, @JsonKey(name: 'updated_at')  DateTime? updatedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AdminServiceCity() when $default != null:
return $default(_that.cityId,_that.name,_that.state,_that.latitude,_that.longitude,_that.radiusM,_that.sortOrder,_that.isActive,_that.providerCount,_that.updatedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'city_id')  String cityId,  String name,  String state,  double latitude,  double longitude, @JsonKey(name: 'radius_m')  int radiusM, @JsonKey(name: 'sort_order')  int sortOrder, @JsonKey(name: 'is_active')  bool isActive, @JsonKey(name: 'provider_count')  int providerCount, @JsonKey(name: 'updated_at')  DateTime? updatedAt)  $default,) {final _that = this;
switch (_that) {
case _AdminServiceCity():
return $default(_that.cityId,_that.name,_that.state,_that.latitude,_that.longitude,_that.radiusM,_that.sortOrder,_that.isActive,_that.providerCount,_that.updatedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'city_id')  String cityId,  String name,  String state,  double latitude,  double longitude, @JsonKey(name: 'radius_m')  int radiusM, @JsonKey(name: 'sort_order')  int sortOrder, @JsonKey(name: 'is_active')  bool isActive, @JsonKey(name: 'provider_count')  int providerCount, @JsonKey(name: 'updated_at')  DateTime? updatedAt)?  $default,) {final _that = this;
switch (_that) {
case _AdminServiceCity() when $default != null:
return $default(_that.cityId,_that.name,_that.state,_that.latitude,_that.longitude,_that.radiusM,_that.sortOrder,_that.isActive,_that.providerCount,_that.updatedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AdminServiceCity implements AdminServiceCity {
  const _AdminServiceCity({@JsonKey(name: 'city_id') required this.cityId, required this.name, required this.state, required this.latitude, required this.longitude, @JsonKey(name: 'radius_m') required this.radiusM, @JsonKey(name: 'sort_order') this.sortOrder = 0, @JsonKey(name: 'is_active') this.isActive = true, @JsonKey(name: 'provider_count') this.providerCount = 0, @JsonKey(name: 'updated_at') this.updatedAt});
  factory _AdminServiceCity.fromJson(Map<String, dynamic> json) => _$AdminServiceCityFromJson(json);

@override@JsonKey(name: 'city_id') final  String cityId;
@override final  String name;
@override final  String state;
@override final  double latitude;
@override final  double longitude;
@override@JsonKey(name: 'radius_m') final  int radiusM;
@override@JsonKey(name: 'sort_order') final  int sortOrder;
@override@JsonKey(name: 'is_active') final  bool isActive;
@override@JsonKey(name: 'provider_count') final  int providerCount;
@override@JsonKey(name: 'updated_at') final  DateTime? updatedAt;

/// Create a copy of AdminServiceCity
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AdminServiceCityCopyWith<_AdminServiceCity> get copyWith => __$AdminServiceCityCopyWithImpl<_AdminServiceCity>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AdminServiceCityToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AdminServiceCity&&(identical(other.cityId, cityId) || other.cityId == cityId)&&(identical(other.name, name) || other.name == name)&&(identical(other.state, state) || other.state == state)&&(identical(other.latitude, latitude) || other.latitude == latitude)&&(identical(other.longitude, longitude) || other.longitude == longitude)&&(identical(other.radiusM, radiusM) || other.radiusM == radiusM)&&(identical(other.sortOrder, sortOrder) || other.sortOrder == sortOrder)&&(identical(other.isActive, isActive) || other.isActive == isActive)&&(identical(other.providerCount, providerCount) || other.providerCount == providerCount)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,cityId,name,state,latitude,longitude,radiusM,sortOrder,isActive,providerCount,updatedAt);

@override
String toString() {
  return 'AdminServiceCity(cityId: $cityId, name: $name, state: $state, latitude: $latitude, longitude: $longitude, radiusM: $radiusM, sortOrder: $sortOrder, isActive: $isActive, providerCount: $providerCount, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class _$AdminServiceCityCopyWith<$Res> implements $AdminServiceCityCopyWith<$Res> {
  factory _$AdminServiceCityCopyWith(_AdminServiceCity value, $Res Function(_AdminServiceCity) _then) = __$AdminServiceCityCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'city_id') String cityId, String name, String state, double latitude, double longitude,@JsonKey(name: 'radius_m') int radiusM,@JsonKey(name: 'sort_order') int sortOrder,@JsonKey(name: 'is_active') bool isActive,@JsonKey(name: 'provider_count') int providerCount,@JsonKey(name: 'updated_at') DateTime? updatedAt
});




}
/// @nodoc
class __$AdminServiceCityCopyWithImpl<$Res>
    implements _$AdminServiceCityCopyWith<$Res> {
  __$AdminServiceCityCopyWithImpl(this._self, this._then);

  final _AdminServiceCity _self;
  final $Res Function(_AdminServiceCity) _then;

/// Create a copy of AdminServiceCity
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? cityId = null,Object? name = null,Object? state = null,Object? latitude = null,Object? longitude = null,Object? radiusM = null,Object? sortOrder = null,Object? isActive = null,Object? providerCount = null,Object? updatedAt = freezed,}) {
  return _then(_AdminServiceCity(
cityId: null == cityId ? _self.cityId : cityId // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,state: null == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as String,latitude: null == latitude ? _self.latitude : latitude // ignore: cast_nullable_to_non_nullable
as double,longitude: null == longitude ? _self.longitude : longitude // ignore: cast_nullable_to_non_nullable
as double,radiusM: null == radiusM ? _self.radiusM : radiusM // ignore: cast_nullable_to_non_nullable
as int,sortOrder: null == sortOrder ? _self.sortOrder : sortOrder // ignore: cast_nullable_to_non_nullable
as int,isActive: null == isActive ? _self.isActive : isActive // ignore: cast_nullable_to_non_nullable
as bool,providerCount: null == providerCount ? _self.providerCount : providerCount // ignore: cast_nullable_to_non_nullable
as int,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

// dart format on
