// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'customer_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$CustomerModel {

 String get id; String get email;@JsonKey(name: 'first_name') String? get firstName;@JsonKey(name: 'last_name') String? get lastName;@JsonKey(name: 'phone_number') String? get phoneNumber;@JsonKey(name: 'profile_pic') String? get profilePicUrl;
/// Create a copy of CustomerModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CustomerModelCopyWith<CustomerModel> get copyWith => _$CustomerModelCopyWithImpl<CustomerModel>(this as CustomerModel, _$identity);

  /// Serializes this CustomerModel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CustomerModel&&(identical(other.id, id) || other.id == id)&&(identical(other.email, email) || other.email == email)&&(identical(other.firstName, firstName) || other.firstName == firstName)&&(identical(other.lastName, lastName) || other.lastName == lastName)&&(identical(other.phoneNumber, phoneNumber) || other.phoneNumber == phoneNumber)&&(identical(other.profilePicUrl, profilePicUrl) || other.profilePicUrl == profilePicUrl));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,email,firstName,lastName,phoneNumber,profilePicUrl);

@override
String toString() {
  return 'CustomerModel(id: $id, email: $email, firstName: $firstName, lastName: $lastName, phoneNumber: $phoneNumber, profilePicUrl: $profilePicUrl)';
}


}

/// @nodoc
abstract mixin class $CustomerModelCopyWith<$Res>  {
  factory $CustomerModelCopyWith(CustomerModel value, $Res Function(CustomerModel) _then) = _$CustomerModelCopyWithImpl;
@useResult
$Res call({
 String id, String email,@JsonKey(name: 'first_name') String? firstName,@JsonKey(name: 'last_name') String? lastName,@JsonKey(name: 'phone_number') String? phoneNumber,@JsonKey(name: 'profile_pic') String? profilePicUrl
});




}
/// @nodoc
class _$CustomerModelCopyWithImpl<$Res>
    implements $CustomerModelCopyWith<$Res> {
  _$CustomerModelCopyWithImpl(this._self, this._then);

  final CustomerModel _self;
  final $Res Function(CustomerModel) _then;

/// Create a copy of CustomerModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? email = null,Object? firstName = freezed,Object? lastName = freezed,Object? phoneNumber = freezed,Object? profilePicUrl = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,email: null == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String,firstName: freezed == firstName ? _self.firstName : firstName // ignore: cast_nullable_to_non_nullable
as String?,lastName: freezed == lastName ? _self.lastName : lastName // ignore: cast_nullable_to_non_nullable
as String?,phoneNumber: freezed == phoneNumber ? _self.phoneNumber : phoneNumber // ignore: cast_nullable_to_non_nullable
as String?,profilePicUrl: freezed == profilePicUrl ? _self.profilePicUrl : profilePicUrl // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [CustomerModel].
extension CustomerModelPatterns on CustomerModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CustomerModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CustomerModel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CustomerModel value)  $default,){
final _that = this;
switch (_that) {
case _CustomerModel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CustomerModel value)?  $default,){
final _that = this;
switch (_that) {
case _CustomerModel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String email, @JsonKey(name: 'first_name')  String? firstName, @JsonKey(name: 'last_name')  String? lastName, @JsonKey(name: 'phone_number')  String? phoneNumber, @JsonKey(name: 'profile_pic')  String? profilePicUrl)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CustomerModel() when $default != null:
return $default(_that.id,_that.email,_that.firstName,_that.lastName,_that.phoneNumber,_that.profilePicUrl);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String email, @JsonKey(name: 'first_name')  String? firstName, @JsonKey(name: 'last_name')  String? lastName, @JsonKey(name: 'phone_number')  String? phoneNumber, @JsonKey(name: 'profile_pic')  String? profilePicUrl)  $default,) {final _that = this;
switch (_that) {
case _CustomerModel():
return $default(_that.id,_that.email,_that.firstName,_that.lastName,_that.phoneNumber,_that.profilePicUrl);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String email, @JsonKey(name: 'first_name')  String? firstName, @JsonKey(name: 'last_name')  String? lastName, @JsonKey(name: 'phone_number')  String? phoneNumber, @JsonKey(name: 'profile_pic')  String? profilePicUrl)?  $default,) {final _that = this;
switch (_that) {
case _CustomerModel() when $default != null:
return $default(_that.id,_that.email,_that.firstName,_that.lastName,_that.phoneNumber,_that.profilePicUrl);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _CustomerModel implements CustomerModel {
  const _CustomerModel({required this.id, required this.email, @JsonKey(name: 'first_name') this.firstName, @JsonKey(name: 'last_name') this.lastName, @JsonKey(name: 'phone_number') this.phoneNumber, @JsonKey(name: 'profile_pic') this.profilePicUrl});
  factory _CustomerModel.fromJson(Map<String, dynamic> json) => _$CustomerModelFromJson(json);

@override final  String id;
@override final  String email;
@override@JsonKey(name: 'first_name') final  String? firstName;
@override@JsonKey(name: 'last_name') final  String? lastName;
@override@JsonKey(name: 'phone_number') final  String? phoneNumber;
@override@JsonKey(name: 'profile_pic') final  String? profilePicUrl;

/// Create a copy of CustomerModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CustomerModelCopyWith<_CustomerModel> get copyWith => __$CustomerModelCopyWithImpl<_CustomerModel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CustomerModelToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CustomerModel&&(identical(other.id, id) || other.id == id)&&(identical(other.email, email) || other.email == email)&&(identical(other.firstName, firstName) || other.firstName == firstName)&&(identical(other.lastName, lastName) || other.lastName == lastName)&&(identical(other.phoneNumber, phoneNumber) || other.phoneNumber == phoneNumber)&&(identical(other.profilePicUrl, profilePicUrl) || other.profilePicUrl == profilePicUrl));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,email,firstName,lastName,phoneNumber,profilePicUrl);

@override
String toString() {
  return 'CustomerModel(id: $id, email: $email, firstName: $firstName, lastName: $lastName, phoneNumber: $phoneNumber, profilePicUrl: $profilePicUrl)';
}


}

/// @nodoc
abstract mixin class _$CustomerModelCopyWith<$Res> implements $CustomerModelCopyWith<$Res> {
  factory _$CustomerModelCopyWith(_CustomerModel value, $Res Function(_CustomerModel) _then) = __$CustomerModelCopyWithImpl;
@override @useResult
$Res call({
 String id, String email,@JsonKey(name: 'first_name') String? firstName,@JsonKey(name: 'last_name') String? lastName,@JsonKey(name: 'phone_number') String? phoneNumber,@JsonKey(name: 'profile_pic') String? profilePicUrl
});




}
/// @nodoc
class __$CustomerModelCopyWithImpl<$Res>
    implements _$CustomerModelCopyWith<$Res> {
  __$CustomerModelCopyWithImpl(this._self, this._then);

  final _CustomerModel _self;
  final $Res Function(_CustomerModel) _then;

/// Create a copy of CustomerModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? email = null,Object? firstName = freezed,Object? lastName = freezed,Object? phoneNumber = freezed,Object? profilePicUrl = freezed,}) {
  return _then(_CustomerModel(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,email: null == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String,firstName: freezed == firstName ? _self.firstName : firstName // ignore: cast_nullable_to_non_nullable
as String?,lastName: freezed == lastName ? _self.lastName : lastName // ignore: cast_nullable_to_non_nullable
as String?,phoneNumber: freezed == phoneNumber ? _self.phoneNumber : phoneNumber // ignore: cast_nullable_to_non_nullable
as String?,profilePicUrl: freezed == profilePicUrl ? _self.profilePicUrl : profilePicUrl // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
