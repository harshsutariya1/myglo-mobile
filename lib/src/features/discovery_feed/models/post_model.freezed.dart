// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'post_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$PostModel {

 String get id;@JsonKey(name: 'author_id') String get authorId;@JsonKey(name: 'media_urls') List<String> get mediaUrls; String? get caption;@JsonKey(name: 'service_id') String? get serviceId;@JsonKey(name: 'tagged_provider_id') String? get taggedProviderId;@JsonKey(name: 'tag_status') String get tagStatus;@JsonKey(name: 'likes_count') int get likesCount;@JsonKey(name: 'comments_count') int get commentsCount;@JsonKey(name: 'created_at') DateTime get createdAt;@JsonKey(name: 'updated_at') DateTime get updatedAt;
/// Create a copy of PostModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PostModelCopyWith<PostModel> get copyWith => _$PostModelCopyWithImpl<PostModel>(this as PostModel, _$identity);

  /// Serializes this PostModel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PostModel&&(identical(other.id, id) || other.id == id)&&(identical(other.authorId, authorId) || other.authorId == authorId)&&const DeepCollectionEquality().equals(other.mediaUrls, mediaUrls)&&(identical(other.caption, caption) || other.caption == caption)&&(identical(other.serviceId, serviceId) || other.serviceId == serviceId)&&(identical(other.taggedProviderId, taggedProviderId) || other.taggedProviderId == taggedProviderId)&&(identical(other.tagStatus, tagStatus) || other.tagStatus == tagStatus)&&(identical(other.likesCount, likesCount) || other.likesCount == likesCount)&&(identical(other.commentsCount, commentsCount) || other.commentsCount == commentsCount)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,authorId,const DeepCollectionEquality().hash(mediaUrls),caption,serviceId,taggedProviderId,tagStatus,likesCount,commentsCount,createdAt,updatedAt);

@override
String toString() {
  return 'PostModel(id: $id, authorId: $authorId, mediaUrls: $mediaUrls, caption: $caption, serviceId: $serviceId, taggedProviderId: $taggedProviderId, tagStatus: $tagStatus, likesCount: $likesCount, commentsCount: $commentsCount, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class $PostModelCopyWith<$Res>  {
  factory $PostModelCopyWith(PostModel value, $Res Function(PostModel) _then) = _$PostModelCopyWithImpl;
@useResult
$Res call({
 String id,@JsonKey(name: 'author_id') String authorId,@JsonKey(name: 'media_urls') List<String> mediaUrls, String? caption,@JsonKey(name: 'service_id') String? serviceId,@JsonKey(name: 'tagged_provider_id') String? taggedProviderId,@JsonKey(name: 'tag_status') String tagStatus,@JsonKey(name: 'likes_count') int likesCount,@JsonKey(name: 'comments_count') int commentsCount,@JsonKey(name: 'created_at') DateTime createdAt,@JsonKey(name: 'updated_at') DateTime updatedAt
});




}
/// @nodoc
class _$PostModelCopyWithImpl<$Res>
    implements $PostModelCopyWith<$Res> {
  _$PostModelCopyWithImpl(this._self, this._then);

  final PostModel _self;
  final $Res Function(PostModel) _then;

/// Create a copy of PostModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? authorId = null,Object? mediaUrls = null,Object? caption = freezed,Object? serviceId = freezed,Object? taggedProviderId = freezed,Object? tagStatus = null,Object? likesCount = null,Object? commentsCount = null,Object? createdAt = null,Object? updatedAt = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,authorId: null == authorId ? _self.authorId : authorId // ignore: cast_nullable_to_non_nullable
as String,mediaUrls: null == mediaUrls ? _self.mediaUrls : mediaUrls // ignore: cast_nullable_to_non_nullable
as List<String>,caption: freezed == caption ? _self.caption : caption // ignore: cast_nullable_to_non_nullable
as String?,serviceId: freezed == serviceId ? _self.serviceId : serviceId // ignore: cast_nullable_to_non_nullable
as String?,taggedProviderId: freezed == taggedProviderId ? _self.taggedProviderId : taggedProviderId // ignore: cast_nullable_to_non_nullable
as String?,tagStatus: null == tagStatus ? _self.tagStatus : tagStatus // ignore: cast_nullable_to_non_nullable
as String,likesCount: null == likesCount ? _self.likesCount : likesCount // ignore: cast_nullable_to_non_nullable
as int,commentsCount: null == commentsCount ? _self.commentsCount : commentsCount // ignore: cast_nullable_to_non_nullable
as int,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [PostModel].
extension PostModelPatterns on PostModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PostModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PostModel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PostModel value)  $default,){
final _that = this;
switch (_that) {
case _PostModel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PostModel value)?  $default,){
final _that = this;
switch (_that) {
case _PostModel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'author_id')  String authorId, @JsonKey(name: 'media_urls')  List<String> mediaUrls,  String? caption, @JsonKey(name: 'service_id')  String? serviceId, @JsonKey(name: 'tagged_provider_id')  String? taggedProviderId, @JsonKey(name: 'tag_status')  String tagStatus, @JsonKey(name: 'likes_count')  int likesCount, @JsonKey(name: 'comments_count')  int commentsCount, @JsonKey(name: 'created_at')  DateTime createdAt, @JsonKey(name: 'updated_at')  DateTime updatedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PostModel() when $default != null:
return $default(_that.id,_that.authorId,_that.mediaUrls,_that.caption,_that.serviceId,_that.taggedProviderId,_that.tagStatus,_that.likesCount,_that.commentsCount,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'author_id')  String authorId, @JsonKey(name: 'media_urls')  List<String> mediaUrls,  String? caption, @JsonKey(name: 'service_id')  String? serviceId, @JsonKey(name: 'tagged_provider_id')  String? taggedProviderId, @JsonKey(name: 'tag_status')  String tagStatus, @JsonKey(name: 'likes_count')  int likesCount, @JsonKey(name: 'comments_count')  int commentsCount, @JsonKey(name: 'created_at')  DateTime createdAt, @JsonKey(name: 'updated_at')  DateTime updatedAt)  $default,) {final _that = this;
switch (_that) {
case _PostModel():
return $default(_that.id,_that.authorId,_that.mediaUrls,_that.caption,_that.serviceId,_that.taggedProviderId,_that.tagStatus,_that.likesCount,_that.commentsCount,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id, @JsonKey(name: 'author_id')  String authorId, @JsonKey(name: 'media_urls')  List<String> mediaUrls,  String? caption, @JsonKey(name: 'service_id')  String? serviceId, @JsonKey(name: 'tagged_provider_id')  String? taggedProviderId, @JsonKey(name: 'tag_status')  String tagStatus, @JsonKey(name: 'likes_count')  int likesCount, @JsonKey(name: 'comments_count')  int commentsCount, @JsonKey(name: 'created_at')  DateTime createdAt, @JsonKey(name: 'updated_at')  DateTime updatedAt)?  $default,) {final _that = this;
switch (_that) {
case _PostModel() when $default != null:
return $default(_that.id,_that.authorId,_that.mediaUrls,_that.caption,_that.serviceId,_that.taggedProviderId,_that.tagStatus,_that.likesCount,_that.commentsCount,_that.createdAt,_that.updatedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PostModel implements PostModel {
  const _PostModel({required this.id, @JsonKey(name: 'author_id') required this.authorId, @JsonKey(name: 'media_urls') required final  List<String> mediaUrls, this.caption, @JsonKey(name: 'service_id') this.serviceId, @JsonKey(name: 'tagged_provider_id') this.taggedProviderId, @JsonKey(name: 'tag_status') required this.tagStatus, @JsonKey(name: 'likes_count') required this.likesCount, @JsonKey(name: 'comments_count') required this.commentsCount, @JsonKey(name: 'created_at') required this.createdAt, @JsonKey(name: 'updated_at') required this.updatedAt}): _mediaUrls = mediaUrls;
  factory _PostModel.fromJson(Map<String, dynamic> json) => _$PostModelFromJson(json);

@override final  String id;
@override@JsonKey(name: 'author_id') final  String authorId;
 final  List<String> _mediaUrls;
@override@JsonKey(name: 'media_urls') List<String> get mediaUrls {
  if (_mediaUrls is EqualUnmodifiableListView) return _mediaUrls;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_mediaUrls);
}

@override final  String? caption;
@override@JsonKey(name: 'service_id') final  String? serviceId;
@override@JsonKey(name: 'tagged_provider_id') final  String? taggedProviderId;
@override@JsonKey(name: 'tag_status') final  String tagStatus;
@override@JsonKey(name: 'likes_count') final  int likesCount;
@override@JsonKey(name: 'comments_count') final  int commentsCount;
@override@JsonKey(name: 'created_at') final  DateTime createdAt;
@override@JsonKey(name: 'updated_at') final  DateTime updatedAt;

/// Create a copy of PostModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PostModelCopyWith<_PostModel> get copyWith => __$PostModelCopyWithImpl<_PostModel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PostModelToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PostModel&&(identical(other.id, id) || other.id == id)&&(identical(other.authorId, authorId) || other.authorId == authorId)&&const DeepCollectionEquality().equals(other._mediaUrls, _mediaUrls)&&(identical(other.caption, caption) || other.caption == caption)&&(identical(other.serviceId, serviceId) || other.serviceId == serviceId)&&(identical(other.taggedProviderId, taggedProviderId) || other.taggedProviderId == taggedProviderId)&&(identical(other.tagStatus, tagStatus) || other.tagStatus == tagStatus)&&(identical(other.likesCount, likesCount) || other.likesCount == likesCount)&&(identical(other.commentsCount, commentsCount) || other.commentsCount == commentsCount)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,authorId,const DeepCollectionEquality().hash(_mediaUrls),caption,serviceId,taggedProviderId,tagStatus,likesCount,commentsCount,createdAt,updatedAt);

@override
String toString() {
  return 'PostModel(id: $id, authorId: $authorId, mediaUrls: $mediaUrls, caption: $caption, serviceId: $serviceId, taggedProviderId: $taggedProviderId, tagStatus: $tagStatus, likesCount: $likesCount, commentsCount: $commentsCount, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class _$PostModelCopyWith<$Res> implements $PostModelCopyWith<$Res> {
  factory _$PostModelCopyWith(_PostModel value, $Res Function(_PostModel) _then) = __$PostModelCopyWithImpl;
@override @useResult
$Res call({
 String id,@JsonKey(name: 'author_id') String authorId,@JsonKey(name: 'media_urls') List<String> mediaUrls, String? caption,@JsonKey(name: 'service_id') String? serviceId,@JsonKey(name: 'tagged_provider_id') String? taggedProviderId,@JsonKey(name: 'tag_status') String tagStatus,@JsonKey(name: 'likes_count') int likesCount,@JsonKey(name: 'comments_count') int commentsCount,@JsonKey(name: 'created_at') DateTime createdAt,@JsonKey(name: 'updated_at') DateTime updatedAt
});




}
/// @nodoc
class __$PostModelCopyWithImpl<$Res>
    implements _$PostModelCopyWith<$Res> {
  __$PostModelCopyWithImpl(this._self, this._then);

  final _PostModel _self;
  final $Res Function(_PostModel) _then;

/// Create a copy of PostModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? authorId = null,Object? mediaUrls = null,Object? caption = freezed,Object? serviceId = freezed,Object? taggedProviderId = freezed,Object? tagStatus = null,Object? likesCount = null,Object? commentsCount = null,Object? createdAt = null,Object? updatedAt = null,}) {
  return _then(_PostModel(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,authorId: null == authorId ? _self.authorId : authorId // ignore: cast_nullable_to_non_nullable
as String,mediaUrls: null == mediaUrls ? _self._mediaUrls : mediaUrls // ignore: cast_nullable_to_non_nullable
as List<String>,caption: freezed == caption ? _self.caption : caption // ignore: cast_nullable_to_non_nullable
as String?,serviceId: freezed == serviceId ? _self.serviceId : serviceId // ignore: cast_nullable_to_non_nullable
as String?,taggedProviderId: freezed == taggedProviderId ? _self.taggedProviderId : taggedProviderId // ignore: cast_nullable_to_non_nullable
as String?,tagStatus: null == tagStatus ? _self.tagStatus : tagStatus // ignore: cast_nullable_to_non_nullable
as String,likesCount: null == likesCount ? _self.likesCount : likesCount // ignore: cast_nullable_to_non_nullable
as int,commentsCount: null == commentsCount ? _self.commentsCount : commentsCount // ignore: cast_nullable_to_non_nullable
as int,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}

// dart format on
