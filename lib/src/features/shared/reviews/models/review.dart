import 'package:flutter/foundation.dart';

/// A client's review of a completed booking, as everyone sees it (a
/// `list_reviews` row).
@immutable
class Review {
  const Review({
    required this.id,
    required this.bookingId,
    required this.providerId,
    required this.clientId,
    required this.reviewerName,
    required this.rating,
    required this.createdAt,
    this.reviewerAvatarUrl,
    this.body,
    this.serviceIds = const [],
    this.serviceNames = const [],
    this.photoUrls = const [],
    this.postId,
    this.reply,
    this.repliedAt,
    this.editedAt,
  });

  final String id;
  final String bookingId;
  final String providerId;
  final String clientId;

  /// "First L." — clients are never shown by full name on reviews.
  final String reviewerName;
  final String? reviewerAvatarUrl;

  /// 1–5 stars.
  final int rating;
  final String? body;

  /// The services on the reviewed booking (ids of those still offered).
  final List<String> serviceIds;
  final List<String> serviceNames;

  /// Photos, published as the Discovery post [postId].
  final List<String> photoUrls;
  final String? postId;

  /// The provider's public reply.
  final String? reply;
  final DateTime? repliedAt;

  /// When the client last changed the stars or text.
  final DateTime? editedAt;
  final DateTime createdAt;

  bool get isEdited => editedAt != null;

  bool get hasReply => (reply ?? '').trim().isNotEmpty;

  factory Review.fromJson(Map<String, dynamic> json) => Review(
        id: json['id'] as String,
        bookingId: json['booking_id'] as String,
        providerId: json['provider_id'] as String,
        clientId: json['client_id'] as String,
        reviewerName: _text(json['reviewer_name']) ?? 'Myglo client',
        reviewerAvatarUrl: _text(json['reviewer_avatar_url']),
        rating: (json['rating'] as num).toInt().clamp(1, 5),
        body: _text(json['body']),
        serviceIds: _strings(json['service_ids']),
        serviceNames: _strings(json['service_names']),
        photoUrls: _strings(json['photo_urls']),
        postId: json['post_id'] as String?,
        reply: _text(json['reply']),
        repliedAt: _time(json['replied_at']),
        editedAt: _time(json['edited_at']),
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  static String? _text(Object? value) {
    final text = value is String ? value.trim() : null;
    return text == null || text.isEmpty ? null : text;
  }

  static List<String> _strings(Object? value) => [
        for (final item in (value as List?) ?? const [])
          if (_text(item) case final String text) text,
      ];

  static DateTime? _time(Object? value) => value is String ? DateTime.parse(value) : null;
}
