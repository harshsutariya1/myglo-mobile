// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'follow_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$FollowModel {

@JsonKey(name: 'follower_id') String get followerId;@JsonKey(name: 'following_id') String get followingId;@JsonKey(name: 'created_at') DateTime get createdAt;
/// Create a copy of FollowModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FollowModelCopyWith<FollowModel> get copyWith => _$FollowModelCopyWithImpl<FollowModel>(this as FollowModel, _$identity);

  /// Serializes this FollowModel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FollowModel&&(identical(other.followerId, followerId) || other.followerId == followerId)&&(identical(other.followingId, followingId) || other.followingId == followingId)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,followerId,followingId,createdAt);

@override
String toString() {
  return 'FollowModel(followerId: $followerId, followingId: $followingId, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class $FollowModelCopyWith<$Res>  {
  factory $FollowModelCopyWith(FollowModel value, $Res Function(FollowModel) _then) = _$FollowModelCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'follower_id') String followerId,@JsonKey(name: 'following_id') String followingId,@JsonKey(name: 'created_at') DateTime createdAt
});




}
/// @nodoc
class _$FollowModelCopyWithImpl<$Res>
    implements $FollowModelCopyWith<$Res> {
  _$FollowModelCopyWithImpl(this._self, this._then);

  final FollowModel _self;
  final $Res Function(FollowModel) _then;

/// Create a copy of FollowModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? followerId = null,Object? followingId = null,Object? createdAt = null,}) {
  return _then(_self.copyWith(
followerId: null == followerId ? _self.followerId : followerId // ignore: cast_nullable_to_non_nullable
as String,followingId: null == followingId ? _self.followingId : followingId // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [FollowModel].
extension FollowModelPatterns on FollowModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _FollowModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _FollowModel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _FollowModel value)  $default,){
final _that = this;
switch (_that) {
case _FollowModel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _FollowModel value)?  $default,){
final _that = this;
switch (_that) {
case _FollowModel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'follower_id')  String followerId, @JsonKey(name: 'following_id')  String followingId, @JsonKey(name: 'created_at')  DateTime createdAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _FollowModel() when $default != null:
return $default(_that.followerId,_that.followingId,_that.createdAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'follower_id')  String followerId, @JsonKey(name: 'following_id')  String followingId, @JsonKey(name: 'created_at')  DateTime createdAt)  $default,) {final _that = this;
switch (_that) {
case _FollowModel():
return $default(_that.followerId,_that.followingId,_that.createdAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'follower_id')  String followerId, @JsonKey(name: 'following_id')  String followingId, @JsonKey(name: 'created_at')  DateTime createdAt)?  $default,) {final _that = this;
switch (_that) {
case _FollowModel() when $default != null:
return $default(_that.followerId,_that.followingId,_that.createdAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _FollowModel implements FollowModel {
  const _FollowModel({@JsonKey(name: 'follower_id') required this.followerId, @JsonKey(name: 'following_id') required this.followingId, @JsonKey(name: 'created_at') required this.createdAt});
  factory _FollowModel.fromJson(Map<String, dynamic> json) => _$FollowModelFromJson(json);

@override@JsonKey(name: 'follower_id') final  String followerId;
@override@JsonKey(name: 'following_id') final  String followingId;
@override@JsonKey(name: 'created_at') final  DateTime createdAt;

/// Create a copy of FollowModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FollowModelCopyWith<_FollowModel> get copyWith => __$FollowModelCopyWithImpl<_FollowModel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$FollowModelToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _FollowModel&&(identical(other.followerId, followerId) || other.followerId == followerId)&&(identical(other.followingId, followingId) || other.followingId == followingId)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,followerId,followingId,createdAt);

@override
String toString() {
  return 'FollowModel(followerId: $followerId, followingId: $followingId, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$FollowModelCopyWith<$Res> implements $FollowModelCopyWith<$Res> {
  factory _$FollowModelCopyWith(_FollowModel value, $Res Function(_FollowModel) _then) = __$FollowModelCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'follower_id') String followerId,@JsonKey(name: 'following_id') String followingId,@JsonKey(name: 'created_at') DateTime createdAt
});




}
/// @nodoc
class __$FollowModelCopyWithImpl<$Res>
    implements _$FollowModelCopyWith<$Res> {
  __$FollowModelCopyWithImpl(this._self, this._then);

  final _FollowModel _self;
  final $Res Function(_FollowModel) _then;

/// Create a copy of FollowModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? followerId = null,Object? followingId = null,Object? createdAt = null,}) {
  return _then(_FollowModel(
followerId: null == followerId ? _self.followerId : followerId // ignore: cast_nullable_to_non_nullable
as String,followingId: null == followingId ? _self.followingId : followingId // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}

// dart format on
