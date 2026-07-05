// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'post_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_PostModel _$PostModelFromJson(Map<String, dynamic> json) => _PostModel(
  id: json['id'] as String,
  authorId: json['author_id'] as String,
  mediaUrls: (json['media_urls'] as List<dynamic>)
      .map((e) => e as String)
      .toList(),
  caption: json['caption'] as String?,
  serviceId: json['service_id'] as String?,
  taggedProviderId: json['tagged_provider_id'] as String?,
  tagStatus: json['tag_status'] as String,
  likesCount: (json['likes_count'] as num).toInt(),
  commentsCount: (json['comments_count'] as num).toInt(),
  createdAt: DateTime.parse(json['created_at'] as String),
  updatedAt: DateTime.parse(json['updated_at'] as String),
);

Map<String, dynamic> _$PostModelToJson(_PostModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'author_id': instance.authorId,
      'media_urls': instance.mediaUrls,
      'caption': instance.caption,
      'service_id': instance.serviceId,
      'tagged_provider_id': instance.taggedProviderId,
      'tag_status': instance.tagStatus,
      'likes_count': instance.likesCount,
      'comments_count': instance.commentsCount,
      'created_at': instance.createdAt.toIso8601String(),
      'updated_at': instance.updatedAt.toIso8601String(),
    };
