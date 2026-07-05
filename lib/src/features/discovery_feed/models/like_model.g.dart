// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'like_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_LikeModel _$LikeModelFromJson(Map<String, dynamic> json) => _LikeModel(
  id: json['id'] as String,
  postId: json['post_id'] as String,
  userId: json['user_id'] as String,
  createdAt: DateTime.parse(json['created_at'] as String),
);

Map<String, dynamic> _$LikeModelToJson(_LikeModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'post_id': instance.postId,
      'user_id': instance.userId,
      'created_at': instance.createdAt.toIso8601String(),
    };
