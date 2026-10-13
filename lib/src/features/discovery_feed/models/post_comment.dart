import 'package:flutter/foundation.dart';

import '../../shared/authentication/models/user_role.dart';

/// One comment on a post, with its author's public name and photo (a
/// `list_post_comments` row).
@immutable
class PostComment {
  const PostComment({
    required this.id,
    required this.postId,
    required this.authorId,
    required this.authorName,
    required this.content,
    required this.createdAt,
    this.authorAvatarUrl,
    this.authorRole,
    this.pending = false,
  });

  final String id;
  final String postId;
  final String authorId;

  /// Business name for providers, otherwise the person's name.
  final String authorName;
  final String? authorAvatarUrl;
  final UserRole? authorRole;
  final String content;
  final DateTime createdAt;

  /// Shown already, still being saved.
  final bool pending;

  factory PostComment.fromJson(Map<String, dynamic> json) => PostComment(
        id: json['id'] as String,
        postId: json['post_id'] as String,
        authorId: json['author_id'] as String,
        authorName: (json['author_name'] as String?)?.trim().isNotEmpty == true
            ? (json['author_name'] as String).trim()
            : 'Myglo member',
        authorAvatarUrl: json['author_avatar_url'] as String?,
        authorRole: switch (json['author_role']) {
          'provider' => UserRole.provider,
          'customer' => UserRole.customer,
          _ => null,
        },
        content: json['content'] as String? ?? '',
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  PostComment copyWith({bool? pending, DateTime? createdAt}) => PostComment(
        id: id,
        postId: postId,
        authorId: authorId,
        authorName: authorName,
        authorAvatarUrl: authorAvatarUrl,
        authorRole: authorRole,
        content: content,
        createdAt: createdAt ?? this.createdAt,
        pending: pending ?? this.pending,
      );
}
