/// An account the signed-in user has blocked (`list_blocked_users`).
class BlockedUser {
  const BlockedUser({
    required this.userId,
    required this.displayName,
    this.avatarUrl,
    this.role,
    required this.blockedAt,
  });

  factory BlockedUser.fromJson(Map<String, dynamic> json) => BlockedUser(
        userId: json['user_id'] as String,
        displayName: (json['display_name'] as String?)?.trim().isNotEmpty == true
            ? (json['display_name'] as String).trim()
            : 'Myglo member',
        avatarUrl: json['avatar_url'] as String?,
        role: json['role'] as String?,
        blockedAt: DateTime.parse(json['blocked_at'] as String),
      );

  final String userId;
  final String displayName;
  final String? avatarUrl;

  /// `customer` or `provider`.
  final String? role;
  final DateTime blockedAt;

  bool get isProvider => role == 'provider';
}
