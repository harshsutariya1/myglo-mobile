// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'profile_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$LocationCoordinates {

 String get type; List<double> get coordinates;
/// Create a copy of LocationCoordinates
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LocationCoordinatesCopyWith<LocationCoordinates> get copyWith => _$LocationCoordinatesCopyWithImpl<LocationCoordinates>(this as LocationCoordinates, _$identity);

  /// Serializes this LocationCoordinates to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LocationCoordinates&&(identical(other.type, type) || other.type == type)&&const DeepCollectionEquality().equals(other.coordinates, coordinates));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,type,const DeepCollectionEquality().hash(coordinates));

@override
String toString() {
  return 'LocationCoordinates(type: $type, coordinates: $coordinates)';
}


}

/// @nodoc
abstract mixin class $LocationCoordinatesCopyWith<$Res>  {
  factory $LocationCoordinatesCopyWith(LocationCoordinates value, $Res Function(LocationCoordinates) _then) = _$LocationCoordinatesCopyWithImpl;
@useResult
$Res call({
 String type, List<double> coordinates
});




}
/// @nodoc
class _$LocationCoordinatesCopyWithImpl<$Res>
    implements $LocationCoordinatesCopyWith<$Res> {
  _$LocationCoordinatesCopyWithImpl(this._self, this._then);

  final LocationCoordinates _self;
  final $Res Function(LocationCoordinates) _then;

/// Create a copy of LocationCoordinates
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? type = null,Object? coordinates = null,}) {
  return _then(_self.copyWith(
type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,coordinates: null == coordinates ? _self.coordinates : coordinates // ignore: cast_nullable_to_non_nullable
as List<double>,
  ));
}

}


/// Adds pattern-matching-related methods to [LocationCoordinates].
extension LocationCoordinatesPatterns on LocationCoordinates {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LocationCoordinates value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LocationCoordinates() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LocationCoordinates value)  $default,){
final _that = this;
switch (_that) {
case _LocationCoordinates():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LocationCoordinates value)?  $default,){
final _that = this;
switch (_that) {
case _LocationCoordinates() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String type,  List<double> coordinates)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LocationCoordinates() when $default != null:
return $default(_that.type,_that.coordinates);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String type,  List<double> coordinates)  $default,) {final _that = this;
switch (_that) {
case _LocationCoordinates():
return $default(_that.type,_that.coordinates);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String type,  List<double> coordinates)?  $default,) {final _that = this;
switch (_that) {
case _LocationCoordinates() when $default != null:
return $default(_that.type,_that.coordinates);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _LocationCoordinates implements LocationCoordinates {
  const _LocationCoordinates({required this.type, required final  List<double> coordinates}): _coordinates = coordinates;
  factory _LocationCoordinates.fromJson(Map<String, dynamic> json) => _$LocationCoordinatesFromJson(json);

@override final  String type;
 final  List<double> _coordinates;
@override List<double> get coordinates {
  if (_coordinates is EqualUnmodifiableListView) return _coordinates;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_coordinates);
}


/// Create a copy of LocationCoordinates
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LocationCoordinatesCopyWith<_LocationCoordinates> get copyWith => __$LocationCoordinatesCopyWithImpl<_LocationCoordinates>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LocationCoordinatesToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _LocationCoordinates&&(identical(other.type, type) || other.type == type)&&const DeepCollectionEquality().equals(other._coordinates, _coordinates));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,type,const DeepCollectionEquality().hash(_coordinates));

@override
String toString() {
  return 'LocationCoordinates(type: $type, coordinates: $coordinates)';
}


}

/// @nodoc
abstract mixin class _$LocationCoordinatesCopyWith<$Res> implements $LocationCoordinatesCopyWith<$Res> {
  factory _$LocationCoordinatesCopyWith(_LocationCoordinates value, $Res Function(_LocationCoordinates) _then) = __$LocationCoordinatesCopyWithImpl;
@override @useResult
$Res call({
 String type, List<double> coordinates
});




}
/// @nodoc
class __$LocationCoordinatesCopyWithImpl<$Res>
    implements _$LocationCoordinatesCopyWith<$Res> {
  __$LocationCoordinatesCopyWithImpl(this._self, this._then);

  final _LocationCoordinates _self;
  final $Res Function(_LocationCoordinates) _then;

/// Create a copy of LocationCoordinates
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? type = null,Object? coordinates = null,}) {
  return _then(_LocationCoordinates(
type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,coordinates: null == coordinates ? _self._coordinates : coordinates // ignore: cast_nullable_to_non_nullable
as List<double>,
  ));
}


}


/// @nodoc
mixin _$ProfileModel {

 String get id; UserRole get role;@JsonKey(name: 'first_name') String? get firstName;@JsonKey(name: 'last_name') String? get lastName; String? get email;@JsonKey(name: 'phone_number') String? get phoneNumber;@JsonKey(name: 'profile_pic') String? get profilePic; String? get bio;@JsonKey(name: 'followers_count') int get followersCount;@JsonKey(name: 'following_count') int get followingCount;@JsonKey(name: 'is_email_public') bool get isEmailPublic;@JsonKey(name: 'is_phone_public') bool get isPhonePublic;@JsonKey(name: 'provider_name') String? get providerName;@JsonKey(name: 'address_text') String? get addressText;@LocationCoordinatesConverter() LocationCoordinates? get coordinates;/// Public URLs of up to five cover photos, in display order (providers).
@JsonKey(name: 'cover_photos') List<String> get coverPhotos;
/// Create a copy of ProfileModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProfileModelCopyWith<ProfileModel> get copyWith => _$ProfileModelCopyWithImpl<ProfileModel>(this as ProfileModel, _$identity);

  /// Serializes this ProfileModel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProfileModel&&(identical(other.id, id) || other.id == id)&&(identical(other.role, role) || other.role == role)&&(identical(other.firstName, firstName) || other.firstName == firstName)&&(identical(other.lastName, lastName) || other.lastName == lastName)&&(identical(other.email, email) || other.email == email)&&(identical(other.phoneNumber, phoneNumber) || other.phoneNumber == phoneNumber)&&(identical(other.profilePic, profilePic) || other.profilePic == profilePic)&&(identical(other.bio, bio) || other.bio == bio)&&(identical(other.followersCount, followersCount) || other.followersCount == followersCount)&&(identical(other.followingCount, followingCount) || other.followingCount == followingCount)&&(identical(other.isEmailPublic, isEmailPublic) || other.isEmailPublic == isEmailPublic)&&(identical(other.isPhonePublic, isPhonePublic) || other.isPhonePublic == isPhonePublic)&&(identical(other.providerName, providerName) || other.providerName == providerName)&&(identical(other.addressText, addressText) || other.addressText == addressText)&&(identical(other.coordinates, coordinates) || other.coordinates == coordinates)&&const DeepCollectionEquality().equals(other.coverPhotos, coverPhotos));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,role,firstName,lastName,email,phoneNumber,profilePic,bio,followersCount,followingCount,isEmailPublic,isPhonePublic,providerName,addressText,coordinates,const DeepCollectionEquality().hash(coverPhotos));

@override
String toString() {
  return 'ProfileModel(id: $id, role: $role, firstName: $firstName, lastName: $lastName, email: $email, phoneNumber: $phoneNumber, profilePic: $profilePic, bio: $bio, followersCount: $followersCount, followingCount: $followingCount, isEmailPublic: $isEmailPublic, isPhonePublic: $isPhonePublic, providerName: $providerName, addressText: $addressText, coordinates: $coordinates, coverPhotos: $coverPhotos)';
}


}

/// @nodoc
abstract mixin class $ProfileModelCopyWith<$Res>  {
  factory $ProfileModelCopyWith(ProfileModel value, $Res Function(ProfileModel) _then) = _$ProfileModelCopyWithImpl;
@useResult
$Res call({
 String id, UserRole role,@JsonKey(name: 'first_name') String? firstName,@JsonKey(name: 'last_name') String? lastName, String? email,@JsonKey(name: 'phone_number') String? phoneNumber,@JsonKey(name: 'profile_pic') String? profilePic, String? bio,@JsonKey(name: 'followers_count') int followersCount,@JsonKey(name: 'following_count') int followingCount,@JsonKey(name: 'is_email_public') bool isEmailPublic,@JsonKey(name: 'is_phone_public') bool isPhonePublic,@JsonKey(name: 'provider_name') String? providerName,@JsonKey(name: 'address_text') String? addressText,@LocationCoordinatesConverter() LocationCoordinates? coordinates,@JsonKey(name: 'cover_photos') List<String> coverPhotos
});


$LocationCoordinatesCopyWith<$Res>? get coordinates;

}
/// @nodoc
class _$ProfileModelCopyWithImpl<$Res>
    implements $ProfileModelCopyWith<$Res> {
  _$ProfileModelCopyWithImpl(this._self, this._then);

  final ProfileModel _self;
  final $Res Function(ProfileModel) _then;

/// Create a copy of ProfileModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? role = null,Object? firstName = freezed,Object? lastName = freezed,Object? email = freezed,Object? phoneNumber = freezed,Object? profilePic = freezed,Object? bio = freezed,Object? followersCount = null,Object? followingCount = null,Object? isEmailPublic = null,Object? isPhonePublic = null,Object? providerName = freezed,Object? addressText = freezed,Object? coordinates = freezed,Object? coverPhotos = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as UserRole,firstName: freezed == firstName ? _self.firstName : firstName // ignore: cast_nullable_to_non_nullable
as String?,lastName: freezed == lastName ? _self.lastName : lastName // ignore: cast_nullable_to_non_nullable
as String?,email: freezed == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String?,phoneNumber: freezed == phoneNumber ? _self.phoneNumber : phoneNumber // ignore: cast_nullable_to_non_nullable
as String?,profilePic: freezed == profilePic ? _self.profilePic : profilePic // ignore: cast_nullable_to_non_nullable
as String?,bio: freezed == bio ? _self.bio : bio // ignore: cast_nullable_to_non_nullable
as String?,followersCount: null == followersCount ? _self.followersCount : followersCount // ignore: cast_nullable_to_non_nullable
as int,followingCount: null == followingCount ? _self.followingCount : followingCount // ignore: cast_nullable_to_non_nullable
as int,isEmailPublic: null == isEmailPublic ? _self.isEmailPublic : isEmailPublic // ignore: cast_nullable_to_non_nullable
as bool,isPhonePublic: null == isPhonePublic ? _self.isPhonePublic : isPhonePublic // ignore: cast_nullable_to_non_nullable
as bool,providerName: freezed == providerName ? _self.providerName : providerName // ignore: cast_nullable_to_non_nullable
as String?,addressText: freezed == addressText ? _self.addressText : addressText // ignore: cast_nullable_to_non_nullable
as String?,coordinates: freezed == coordinates ? _self.coordinates : coordinates // ignore: cast_nullable_to_non_nullable
as LocationCoordinates?,coverPhotos: null == coverPhotos ? _self.coverPhotos : coverPhotos // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}
/// Create a copy of ProfileModel
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$LocationCoordinatesCopyWith<$Res>? get coordinates {
    if (_self.coordinates == null) {
    return null;
  }

  return $LocationCoordinatesCopyWith<$Res>(_self.coordinates!, (value) {
    return _then(_self.copyWith(coordinates: value));
  });
}
}


/// Adds pattern-matching-related methods to [ProfileModel].
extension ProfileModelPatterns on ProfileModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ProfileModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ProfileModel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ProfileModel value)  $default,){
final _that = this;
switch (_that) {
case _ProfileModel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ProfileModel value)?  $default,){
final _that = this;
switch (_that) {
case _ProfileModel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  UserRole role, @JsonKey(name: 'first_name')  String? firstName, @JsonKey(name: 'last_name')  String? lastName,  String? email, @JsonKey(name: 'phone_number')  String? phoneNumber, @JsonKey(name: 'profile_pic')  String? profilePic,  String? bio, @JsonKey(name: 'followers_count')  int followersCount, @JsonKey(name: 'following_count')  int followingCount, @JsonKey(name: 'is_email_public')  bool isEmailPublic, @JsonKey(name: 'is_phone_public')  bool isPhonePublic, @JsonKey(name: 'provider_name')  String? providerName, @JsonKey(name: 'address_text')  String? addressText, @LocationCoordinatesConverter()  LocationCoordinates? coordinates, @JsonKey(name: 'cover_photos')  List<String> coverPhotos)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ProfileModel() when $default != null:
return $default(_that.id,_that.role,_that.firstName,_that.lastName,_that.email,_that.phoneNumber,_that.profilePic,_that.bio,_that.followersCount,_that.followingCount,_that.isEmailPublic,_that.isPhonePublic,_that.providerName,_that.addressText,_that.coordinates,_that.coverPhotos);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  UserRole role, @JsonKey(name: 'first_name')  String? firstName, @JsonKey(name: 'last_name')  String? lastName,  String? email, @JsonKey(name: 'phone_number')  String? phoneNumber, @JsonKey(name: 'profile_pic')  String? profilePic,  String? bio, @JsonKey(name: 'followers_count')  int followersCount, @JsonKey(name: 'following_count')  int followingCount, @JsonKey(name: 'is_email_public')  bool isEmailPublic, @JsonKey(name: 'is_phone_public')  bool isPhonePublic, @JsonKey(name: 'provider_name')  String? providerName, @JsonKey(name: 'address_text')  String? addressText, @LocationCoordinatesConverter()  LocationCoordinates? coordinates, @JsonKey(name: 'cover_photos')  List<String> coverPhotos)  $default,) {final _that = this;
switch (_that) {
case _ProfileModel():
return $default(_that.id,_that.role,_that.firstName,_that.lastName,_that.email,_that.phoneNumber,_that.profilePic,_that.bio,_that.followersCount,_that.followingCount,_that.isEmailPublic,_that.isPhonePublic,_that.providerName,_that.addressText,_that.coordinates,_that.coverPhotos);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  UserRole role, @JsonKey(name: 'first_name')  String? firstName, @JsonKey(name: 'last_name')  String? lastName,  String? email, @JsonKey(name: 'phone_number')  String? phoneNumber, @JsonKey(name: 'profile_pic')  String? profilePic,  String? bio, @JsonKey(name: 'followers_count')  int followersCount, @JsonKey(name: 'following_count')  int followingCount, @JsonKey(name: 'is_email_public')  bool isEmailPublic, @JsonKey(name: 'is_phone_public')  bool isPhonePublic, @JsonKey(name: 'provider_name')  String? providerName, @JsonKey(name: 'address_text')  String? addressText, @LocationCoordinatesConverter()  LocationCoordinates? coordinates, @JsonKey(name: 'cover_photos')  List<String> coverPhotos)?  $default,) {final _that = this;
switch (_that) {
case _ProfileModel() when $default != null:
return $default(_that.id,_that.role,_that.firstName,_that.lastName,_that.email,_that.phoneNumber,_that.profilePic,_that.bio,_that.followersCount,_that.followingCount,_that.isEmailPublic,_that.isPhonePublic,_that.providerName,_that.addressText,_that.coordinates,_that.coverPhotos);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ProfileModel implements ProfileModel {
  const _ProfileModel({required this.id, required this.role, @JsonKey(name: 'first_name') this.firstName, @JsonKey(name: 'last_name') this.lastName, this.email, @JsonKey(name: 'phone_number') this.phoneNumber, @JsonKey(name: 'profile_pic') this.profilePic, this.bio, @JsonKey(name: 'followers_count') this.followersCount = 0, @JsonKey(name: 'following_count') this.followingCount = 0, @JsonKey(name: 'is_email_public') this.isEmailPublic = false, @JsonKey(name: 'is_phone_public') this.isPhonePublic = false, @JsonKey(name: 'provider_name') this.providerName, @JsonKey(name: 'address_text') this.addressText, @LocationCoordinatesConverter() this.coordinates, @JsonKey(name: 'cover_photos') final  List<String> coverPhotos = const <String>[]}): _coverPhotos = coverPhotos;
  factory _ProfileModel.fromJson(Map<String, dynamic> json) => _$ProfileModelFromJson(json);

@override final  String id;
@override final  UserRole role;
@override@JsonKey(name: 'first_name') final  String? firstName;
@override@JsonKey(name: 'last_name') final  String? lastName;
@override final  String? email;
@override@JsonKey(name: 'phone_number') final  String? phoneNumber;
@override@JsonKey(name: 'profile_pic') final  String? profilePic;
@override final  String? bio;
@override@JsonKey(name: 'followers_count') final  int followersCount;
@override@JsonKey(name: 'following_count') final  int followingCount;
@override@JsonKey(name: 'is_email_public') final  bool isEmailPublic;
@override@JsonKey(name: 'is_phone_public') final  bool isPhonePublic;
@override@JsonKey(name: 'provider_name') final  String? providerName;
@override@JsonKey(name: 'address_text') final  String? addressText;
@override@LocationCoordinatesConverter() final  LocationCoordinates? coordinates;
/// Public URLs of up to five cover photos, in display order (providers).
 final  List<String> _coverPhotos;
/// Public URLs of up to five cover photos, in display order (providers).
@override@JsonKey(name: 'cover_photos') List<String> get coverPhotos {
  if (_coverPhotos is EqualUnmodifiableListView) return _coverPhotos;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_coverPhotos);
}


/// Create a copy of ProfileModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ProfileModelCopyWith<_ProfileModel> get copyWith => __$ProfileModelCopyWithImpl<_ProfileModel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ProfileModelToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ProfileModel&&(identical(other.id, id) || other.id == id)&&(identical(other.role, role) || other.role == role)&&(identical(other.firstName, firstName) || other.firstName == firstName)&&(identical(other.lastName, lastName) || other.lastName == lastName)&&(identical(other.email, email) || other.email == email)&&(identical(other.phoneNumber, phoneNumber) || other.phoneNumber == phoneNumber)&&(identical(other.profilePic, profilePic) || other.profilePic == profilePic)&&(identical(other.bio, bio) || other.bio == bio)&&(identical(other.followersCount, followersCount) || other.followersCount == followersCount)&&(identical(other.followingCount, followingCount) || other.followingCount == followingCount)&&(identical(other.isEmailPublic, isEmailPublic) || other.isEmailPublic == isEmailPublic)&&(identical(other.isPhonePublic, isPhonePublic) || other.isPhonePublic == isPhonePublic)&&(identical(other.providerName, providerName) || other.providerName == providerName)&&(identical(other.addressText, addressText) || other.addressText == addressText)&&(identical(other.coordinates, coordinates) || other.coordinates == coordinates)&&const DeepCollectionEquality().equals(other._coverPhotos, _coverPhotos));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,role,firstName,lastName,email,phoneNumber,profilePic,bio,followersCount,followingCount,isEmailPublic,isPhonePublic,providerName,addressText,coordinates,const DeepCollectionEquality().hash(_coverPhotos));

@override
String toString() {
  return 'ProfileModel(id: $id, role: $role, firstName: $firstName, lastName: $lastName, email: $email, phoneNumber: $phoneNumber, profilePic: $profilePic, bio: $bio, followersCount: $followersCount, followingCount: $followingCount, isEmailPublic: $isEmailPublic, isPhonePublic: $isPhonePublic, providerName: $providerName, addressText: $addressText, coordinates: $coordinates, coverPhotos: $coverPhotos)';
}


}

/// @nodoc
abstract mixin class _$ProfileModelCopyWith<$Res> implements $ProfileModelCopyWith<$Res> {
  factory _$ProfileModelCopyWith(_ProfileModel value, $Res Function(_ProfileModel) _then) = __$ProfileModelCopyWithImpl;
@override @useResult
$Res call({
 String id, UserRole role,@JsonKey(name: 'first_name') String? firstName,@JsonKey(name: 'last_name') String? lastName, String? email,@JsonKey(name: 'phone_number') String? phoneNumber,@JsonKey(name: 'profile_pic') String? profilePic, String? bio,@JsonKey(name: 'followers_count') int followersCount,@JsonKey(name: 'following_count') int followingCount,@JsonKey(name: 'is_email_public') bool isEmailPublic,@JsonKey(name: 'is_phone_public') bool isPhonePublic,@JsonKey(name: 'provider_name') String? providerName,@JsonKey(name: 'address_text') String? addressText,@LocationCoordinatesConverter() LocationCoordinates? coordinates,@JsonKey(name: 'cover_photos') List<String> coverPhotos
});


@override $LocationCoordinatesCopyWith<$Res>? get coordinates;

}
/// @nodoc
class __$ProfileModelCopyWithImpl<$Res>
    implements _$ProfileModelCopyWith<$Res> {
  __$ProfileModelCopyWithImpl(this._self, this._then);

  final _ProfileModel _self;
  final $Res Function(_ProfileModel) _then;

/// Create a copy of ProfileModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? role = null,Object? firstName = freezed,Object? lastName = freezed,Object? email = freezed,Object? phoneNumber = freezed,Object? profilePic = freezed,Object? bio = freezed,Object? followersCount = null,Object? followingCount = null,Object? isEmailPublic = null,Object? isPhonePublic = null,Object? providerName = freezed,Object? addressText = freezed,Object? coordinates = freezed,Object? coverPhotos = null,}) {
  return _then(_ProfileModel(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as UserRole,firstName: freezed == firstName ? _self.firstName : firstName // ignore: cast_nullable_to_non_nullable
as String?,lastName: freezed == lastName ? _self.lastName : lastName // ignore: cast_nullable_to_non_nullable
as String?,email: freezed == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String?,phoneNumber: freezed == phoneNumber ? _self.phoneNumber : phoneNumber // ignore: cast_nullable_to_non_nullable
as String?,profilePic: freezed == profilePic ? _self.profilePic : profilePic // ignore: cast_nullable_to_non_nullable
as String?,bio: freezed == bio ? _self.bio : bio // ignore: cast_nullable_to_non_nullable
as String?,followersCount: null == followersCount ? _self.followersCount : followersCount // ignore: cast_nullable_to_non_nullable
as int,followingCount: null == followingCount ? _self.followingCount : followingCount // ignore: cast_nullable_to_non_nullable
as int,isEmailPublic: null == isEmailPublic ? _self.isEmailPublic : isEmailPublic // ignore: cast_nullable_to_non_nullable
as bool,isPhonePublic: null == isPhonePublic ? _self.isPhonePublic : isPhonePublic // ignore: cast_nullable_to_non_nullable
as bool,providerName: freezed == providerName ? _self.providerName : providerName // ignore: cast_nullable_to_non_nullable
as String?,addressText: freezed == addressText ? _self.addressText : addressText // ignore: cast_nullable_to_non_nullable
as String?,coordinates: freezed == coordinates ? _self.coordinates : coordinates // ignore: cast_nullable_to_non_nullable
as LocationCoordinates?,coverPhotos: null == coverPhotos ? _self._coverPhotos : coverPhotos // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}

/// Create a copy of ProfileModel
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$LocationCoordinatesCopyWith<$Res>? get coordinates {
    if (_self.coordinates == null) {
    return null;
  }

  return $LocationCoordinatesCopyWith<$Res>(_self.coordinates!, (value) {
    return _then(_self.copyWith(coordinates: value));
  });
}
}

// dart format on
