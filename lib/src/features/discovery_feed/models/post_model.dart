import 'package:freezed_annotation/freezed_annotation.dart';

part 'post_model.freezed.dart';
part 'post_model.g.dart';

@freezed
abstract class PostModel with _$PostModel {
  const factory PostModel({
    required String id,
    @JsonKey(name: 'author_id') required String authorId,
    @JsonKey(name: 'media_urls') required List<String> mediaUrls,
    String? caption,
    @JsonKey(name: 'service_id') String? serviceId,
    @JsonKey(name: 'tagged_provider_id') String? taggedProviderId,
    @JsonKey(name: 'tag_status') required String tagStatus,
    @JsonKey(name: 'likes_count') required int likesCount,
    @JsonKey(name: 'comments_count') required int commentsCount,
    @JsonKey(name: 'created_at') required DateTime createdAt,
    @JsonKey(name: 'updated_at') required DateTime updatedAt,
  }) = _PostModel;

  factory PostModel.fromJson(Map<String, dynamic> json) =>
      _$PostModelFromJson(json);
}
