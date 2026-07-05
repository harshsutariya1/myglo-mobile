// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'provider_details_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ProviderDetailsModel {

 String get id;@JsonKey(name: 'provider_name') String? get providerName;@JsonKey(name: 'address_text') String? get addressText; String? get bio; double? get latitude; double? get longitude;
/// Create a copy of ProviderDetailsModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProviderDetailsModelCopyWith<ProviderDetailsModel> get copyWith => _$ProviderDetailsModelCopyWithImpl<ProviderDetailsModel>(this as ProviderDetailsModel, _$identity);

  /// Serializes this ProviderDetailsModel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProviderDetailsModel&&(identical(other.id, id) || other.id == id)&&(identical(other.providerName, providerName) || other.providerName == providerName)&&(identical(other.addressText, addressText) || other.addressText == addressText)&&(identical(other.bio, bio) || other.bio == bio)&&(identical(other.latitude, latitude) || other.latitude == latitude)&&(identical(other.longitude, longitude) || other.longitude == longitude));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,providerName,addressText,bio,latitude,longitude);

@override
String toString() {
  return 'ProviderDetailsModel(id: $id, providerName: $providerName, addressText: $addressText, bio: $bio, latitude: $latitude, longitude: $longitude)';
}


}

/// @nodoc
abstract mixin class $ProviderDetailsModelCopyWith<$Res>  {
  factory $ProviderDetailsModelCopyWith(ProviderDetailsModel value, $Res Function(ProviderDetailsModel) _then) = _$ProviderDetailsModelCopyWithImpl;
@useResult
$Res call({
 String id,@JsonKey(name: 'provider_name') String? providerName,@JsonKey(name: 'address_text') String? addressText, String? bio, double? latitude, double? longitude
});




}
/// @nodoc
class _$ProviderDetailsModelCopyWithImpl<$Res>
    implements $ProviderDetailsModelCopyWith<$Res> {
  _$ProviderDetailsModelCopyWithImpl(this._self, this._then);

  final ProviderDetailsModel _self;
  final $Res Function(ProviderDetailsModel) _then;

/// Create a copy of ProviderDetailsModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? providerName = freezed,Object? addressText = freezed,Object? bio = freezed,Object? latitude = freezed,Object? longitude = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,providerName: freezed == providerName ? _self.providerName : providerName // ignore: cast_nullable_to_non_nullable
as String?,addressText: freezed == addressText ? _self.addressText : addressText // ignore: cast_nullable_to_non_nullable
as String?,bio: freezed == bio ? _self.bio : bio // ignore: cast_nullable_to_non_nullable
as String?,latitude: freezed == latitude ? _self.latitude : latitude // ignore: cast_nullable_to_non_nullable
as double?,longitude: freezed == longitude ? _self.longitude : longitude // ignore: cast_nullable_to_non_nullable
as double?,
  ));
}

}


/// Adds pattern-matching-related methods to [ProviderDetailsModel].
extension ProviderDetailsModelPatterns on ProviderDetailsModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ProviderDetailsModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ProviderDetailsModel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ProviderDetailsModel value)  $default,){
final _that = this;
switch (_that) {
case _ProviderDetailsModel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ProviderDetailsModel value)?  $default,){
final _that = this;
switch (_that) {
case _ProviderDetailsModel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'provider_name')  String? providerName, @JsonKey(name: 'address_text')  String? addressText,  String? bio,  double? latitude,  double? longitude)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ProviderDetailsModel() when $default != null:
return $default(_that.id,_that.providerName,_that.addressText,_that.bio,_that.latitude,_that.longitude);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'provider_name')  String? providerName, @JsonKey(name: 'address_text')  String? addressText,  String? bio,  double? latitude,  double? longitude)  $default,) {final _that = this;
switch (_that) {
case _ProviderDetailsModel():
return $default(_that.id,_that.providerName,_that.addressText,_that.bio,_that.latitude,_that.longitude);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id, @JsonKey(name: 'provider_name')  String? providerName, @JsonKey(name: 'address_text')  String? addressText,  String? bio,  double? latitude,  double? longitude)?  $default,) {final _that = this;
switch (_that) {
case _ProviderDetailsModel() when $default != null:
return $default(_that.id,_that.providerName,_that.addressText,_that.bio,_that.latitude,_that.longitude);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ProviderDetailsModel implements ProviderDetailsModel {
  const _ProviderDetailsModel({required this.id, @JsonKey(name: 'provider_name') this.providerName, @JsonKey(name: 'address_text') this.addressText, this.bio, this.latitude, this.longitude});
  factory _ProviderDetailsModel.fromJson(Map<String, dynamic> json) => _$ProviderDetailsModelFromJson(json);

@override final  String id;
@override@JsonKey(name: 'provider_name') final  String? providerName;
@override@JsonKey(name: 'address_text') final  String? addressText;
@override final  String? bio;
@override final  double? latitude;
@override final  double? longitude;

/// Create a copy of ProviderDetailsModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ProviderDetailsModelCopyWith<_ProviderDetailsModel> get copyWith => __$ProviderDetailsModelCopyWithImpl<_ProviderDetailsModel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ProviderDetailsModelToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ProviderDetailsModel&&(identical(other.id, id) || other.id == id)&&(identical(other.providerName, providerName) || other.providerName == providerName)&&(identical(other.addressText, addressText) || other.addressText == addressText)&&(identical(other.bio, bio) || other.bio == bio)&&(identical(other.latitude, latitude) || other.latitude == latitude)&&(identical(other.longitude, longitude) || other.longitude == longitude));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,providerName,addressText,bio,latitude,longitude);

@override
String toString() {
  return 'ProviderDetailsModel(id: $id, providerName: $providerName, addressText: $addressText, bio: $bio, latitude: $latitude, longitude: $longitude)';
}


}

/// @nodoc
abstract mixin class _$ProviderDetailsModelCopyWith<$Res> implements $ProviderDetailsModelCopyWith<$Res> {
  factory _$ProviderDetailsModelCopyWith(_ProviderDetailsModel value, $Res Function(_ProviderDetailsModel) _then) = __$ProviderDetailsModelCopyWithImpl;
@override @useResult
$Res call({
 String id,@JsonKey(name: 'provider_name') String? providerName,@JsonKey(name: 'address_text') String? addressText, String? bio, double? latitude, double? longitude
});




}
/// @nodoc
class __$ProviderDetailsModelCopyWithImpl<$Res>
    implements _$ProviderDetailsModelCopyWith<$Res> {
  __$ProviderDetailsModelCopyWithImpl(this._self, this._then);

  final _ProviderDetailsModel _self;
  final $Res Function(_ProviderDetailsModel) _then;

/// Create a copy of ProviderDetailsModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? providerName = freezed,Object? addressText = freezed,Object? bio = freezed,Object? latitude = freezed,Object? longitude = freezed,}) {
  return _then(_ProviderDetailsModel(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,providerName: freezed == providerName ? _self.providerName : providerName // ignore: cast_nullable_to_non_nullable
as String?,addressText: freezed == addressText ? _self.addressText : addressText // ignore: cast_nullable_to_non_nullable
as String?,bio: freezed == bio ? _self.bio : bio // ignore: cast_nullable_to_non_nullable
as String?,latitude: freezed == latitude ? _self.latitude : latitude // ignore: cast_nullable_to_non_nullable
as double?,longitude: freezed == longitude ? _self.longitude : longitude // ignore: cast_nullable_to_non_nullable
as double?,
  ));
}


}

// dart format on
