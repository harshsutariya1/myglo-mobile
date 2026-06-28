// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'all_user_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$AllUserModel {

 String get id; String get email; UserRole get role;@JsonKey(name: 'first_name') String? get firstName;@JsonKey(name: 'last_name') String? get lastName;@JsonKey(name: 'phone_number') String? get phoneNumber;@JsonKey(name: 'profile_pic') String? get profilePic;
/// Create a copy of AllUserModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AllUserModelCopyWith<AllUserModel> get copyWith => _$AllUserModelCopyWithImpl<AllUserModel>(this as AllUserModel, _$identity);

  /// Serializes this AllUserModel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AllUserModel&&(identical(other.id, id) || other.id == id)&&(identical(other.email, email) || other.email == email)&&(identical(other.role, role) || other.role == role)&&(identical(other.firstName, firstName) || other.firstName == firstName)&&(identical(other.lastName, lastName) || other.lastName == lastName)&&(identical(other.phoneNumber, phoneNumber) || other.phoneNumber == phoneNumber)&&(identical(other.profilePic, profilePic) || other.profilePic == profilePic));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,email,role,firstName,lastName,phoneNumber,profilePic);

@override
String toString() {
  return 'AllUserModel(id: $id, email: $email, role: $role, firstName: $firstName, lastName: $lastName, phoneNumber: $phoneNumber, profilePic: $profilePic)';
}


}

/// @nodoc
abstract mixin class $AllUserModelCopyWith<$Res>  {
  factory $AllUserModelCopyWith(AllUserModel value, $Res Function(AllUserModel) _then) = _$AllUserModelCopyWithImpl;
@useResult
$Res call({
 String id, String email, UserRole role,@JsonKey(name: 'first_name') String? firstName,@JsonKey(name: 'last_name') String? lastName,@JsonKey(name: 'phone_number') String? phoneNumber,@JsonKey(name: 'profile_pic') String? profilePic
});




}
/// @nodoc
class _$AllUserModelCopyWithImpl<$Res>
    implements $AllUserModelCopyWith<$Res> {
  _$AllUserModelCopyWithImpl(this._self, this._then);

  final AllUserModel _self;
  final $Res Function(AllUserModel) _then;

/// Create a copy of AllUserModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? email = null,Object? role = null,Object? firstName = freezed,Object? lastName = freezed,Object? phoneNumber = freezed,Object? profilePic = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,email: null == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String,role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as UserRole,firstName: freezed == firstName ? _self.firstName : firstName // ignore: cast_nullable_to_non_nullable
as String?,lastName: freezed == lastName ? _self.lastName : lastName // ignore: cast_nullable_to_non_nullable
as String?,phoneNumber: freezed == phoneNumber ? _self.phoneNumber : phoneNumber // ignore: cast_nullable_to_non_nullable
as String?,profilePic: freezed == profilePic ? _self.profilePic : profilePic // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [AllUserModel].
extension AllUserModelPatterns on AllUserModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AllUserModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AllUserModel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AllUserModel value)  $default,){
final _that = this;
switch (_that) {
case _AllUserModel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AllUserModel value)?  $default,){
final _that = this;
switch (_that) {
case _AllUserModel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String email,  UserRole role, @JsonKey(name: 'first_name')  String? firstName, @JsonKey(name: 'last_name')  String? lastName, @JsonKey(name: 'phone_number')  String? phoneNumber, @JsonKey(name: 'profile_pic')  String? profilePic)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AllUserModel() when $default != null:
return $default(_that.id,_that.email,_that.role,_that.firstName,_that.lastName,_that.phoneNumber,_that.profilePic);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String email,  UserRole role, @JsonKey(name: 'first_name')  String? firstName, @JsonKey(name: 'last_name')  String? lastName, @JsonKey(name: 'phone_number')  String? phoneNumber, @JsonKey(name: 'profile_pic')  String? profilePic)  $default,) {final _that = this;
switch (_that) {
case _AllUserModel():
return $default(_that.id,_that.email,_that.role,_that.firstName,_that.lastName,_that.phoneNumber,_that.profilePic);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String email,  UserRole role, @JsonKey(name: 'first_name')  String? firstName, @JsonKey(name: 'last_name')  String? lastName, @JsonKey(name: 'phone_number')  String? phoneNumber, @JsonKey(name: 'profile_pic')  String? profilePic)?  $default,) {final _that = this;
switch (_that) {
case _AllUserModel() when $default != null:
return $default(_that.id,_that.email,_that.role,_that.firstName,_that.lastName,_that.phoneNumber,_that.profilePic);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AllUserModel implements AllUserModel {
  const _AllUserModel({required this.id, required this.email, required this.role, @JsonKey(name: 'first_name') this.firstName, @JsonKey(name: 'last_name') this.lastName, @JsonKey(name: 'phone_number') this.phoneNumber, @JsonKey(name: 'profile_pic') this.profilePic});
  factory _AllUserModel.fromJson(Map<String, dynamic> json) => _$AllUserModelFromJson(json);

@override final  String id;
@override final  String email;
@override final  UserRole role;
@override@JsonKey(name: 'first_name') final  String? firstName;
@override@JsonKey(name: 'last_name') final  String? lastName;
@override@JsonKey(name: 'phone_number') final  String? phoneNumber;
@override@JsonKey(name: 'profile_pic') final  String? profilePic;

/// Create a copy of AllUserModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AllUserModelCopyWith<_AllUserModel> get copyWith => __$AllUserModelCopyWithImpl<_AllUserModel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AllUserModelToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AllUserModel&&(identical(other.id, id) || other.id == id)&&(identical(other.email, email) || other.email == email)&&(identical(other.role, role) || other.role == role)&&(identical(other.firstName, firstName) || other.firstName == firstName)&&(identical(other.lastName, lastName) || other.lastName == lastName)&&(identical(other.phoneNumber, phoneNumber) || other.phoneNumber == phoneNumber)&&(identical(other.profilePic, profilePic) || other.profilePic == profilePic));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,email,role,firstName,lastName,phoneNumber,profilePic);

@override
String toString() {
  return 'AllUserModel(id: $id, email: $email, role: $role, firstName: $firstName, lastName: $lastName, phoneNumber: $phoneNumber, profilePic: $profilePic)';
}


}

/// @nodoc
abstract mixin class _$AllUserModelCopyWith<$Res> implements $AllUserModelCopyWith<$Res> {
  factory _$AllUserModelCopyWith(_AllUserModel value, $Res Function(_AllUserModel) _then) = __$AllUserModelCopyWithImpl;
@override @useResult
$Res call({
 String id, String email, UserRole role,@JsonKey(name: 'first_name') String? firstName,@JsonKey(name: 'last_name') String? lastName,@JsonKey(name: 'phone_number') String? phoneNumber,@JsonKey(name: 'profile_pic') String? profilePic
});




}
/// @nodoc
class __$AllUserModelCopyWithImpl<$Res>
    implements _$AllUserModelCopyWith<$Res> {
  __$AllUserModelCopyWithImpl(this._self, this._then);

  final _AllUserModel _self;
  final $Res Function(_AllUserModel) _then;

/// Create a copy of AllUserModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? email = null,Object? role = null,Object? firstName = freezed,Object? lastName = freezed,Object? phoneNumber = freezed,Object? profilePic = freezed,}) {
  return _then(_AllUserModel(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,email: null == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String,role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as UserRole,firstName: freezed == firstName ? _self.firstName : firstName // ignore: cast_nullable_to_non_nullable
as String?,lastName: freezed == lastName ? _self.lastName : lastName // ignore: cast_nullable_to_non_nullable
as String?,phoneNumber: freezed == phoneNumber ? _self.phoneNumber : phoneNumber // ignore: cast_nullable_to_non_nullable
as String?,profilePic: freezed == profilePic ? _self.profilePic : profilePic // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
