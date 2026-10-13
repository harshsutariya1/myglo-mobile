import 'package:flutter/foundation.dart';

import '../../../core/config/app_config.dart';
import 'post_model.dart';

/// A post's like and comment counts, and whether the viewer likes it, as
/// last seen by this device.
@immutable
class PostEngagement {
  const PostEngagement({
    required this.likesCount,
    required this.commentsCount,
    required this.updatedAt,
    this.liked,
  });

  /// The counts a post arrived with. Whether the viewer likes it isn't known
  /// until it's loaded.
  factory PostEngagement.fromPost(PostModel post, {DateTime? at}) => PostEngagement(
        likesCount: post.likesCount,
        commentsCount: post.commentsCount,
        updatedAt: at ?? DateTime.now(),
      );

  /// A `get_post_engagement` row.
  factory PostEngagement.fromJson(Map<String, dynamic> json, {DateTime? at}) => PostEngagement(
        likesCount: (json['likes_count'] as num? ?? 0).toInt(),
        commentsCount: (json['comments_count'] as num? ?? 0).toInt(),
        liked: json['liked'] as bool?,
        updatedAt: at ?? DateTime.now(),
      );

  final int likesCount;
  final int commentsCount;

  /// Null until the viewer's like has been loaded.
  final bool? liked;

  /// When these numbers were last loaded or changed here.
  final DateTime updatedAt;

  /// Recent enough to show instead of the counts a feed page arrived with.
  bool isFreshAt(DateTime now) => now.difference(updatedAt) < AppConfig.postEngagementCacheFor;

  PostEngagement copyWith({int? likesCount, int? commentsCount, bool? liked, DateTime? updatedAt}) => PostEngagement(
        likesCount: likesCount ?? this.likesCount,
        commentsCount: commentsCount ?? this.commentsCount,
        liked: liked ?? this.liked,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  @override
  bool operator ==(Object other) =>
      other is PostEngagement &&
      other.likesCount == likesCount &&
      other.commentsCount == commentsCount &&
      other.liked == liked &&
      other.updatedAt == updatedAt;

  @override
  int get hashCode => Object.hash(likesCount, commentsCount, liked, updatedAt);
}
