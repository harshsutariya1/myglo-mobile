enum UserRole { customer, business }

class AppUser {
  final String id;
  final String email;
  final UserRole? role;
  final String? name;
  final String? avatarUrl;

  AppUser({
    required this.id,
    required this.email,
    this.role,
    this.name,
    this.avatarUrl,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as String,
      email: json['email'] as String,
      role: json['role'] != null
          ? UserRole.values.firstWhere((e) => e.name == json['role'])
          : null,
      name: json['name'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'role': role?.name,
      'name': name,
      'avatarUrl': avatarUrl,
    };
  }
}
