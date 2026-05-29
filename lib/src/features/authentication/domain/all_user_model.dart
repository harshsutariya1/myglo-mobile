import 'user_role.dart';

class AllUserModel {
  final String id;
  final String email;
  final String? firstName;
  final String? lastName;
  final UserRole role;
  final String? phoneNumber;
  final String? profilePic;

  const AllUserModel({
    required this.id,
    required this.email,
    required this.role,
    this.firstName,
    this.lastName,
    this.phoneNumber,
    this.profilePic,
  });

  factory AllUserModel.fromJson(Map<String, dynamic> json) {
    return AllUserModel(
      id: json['id'] as String? ?? '',
      email: json['email'] as String? ?? '',
      role: json['role'] == 'business' ? UserRole.business : UserRole.customer,
      firstName: json['first_name'] as String?,
      lastName: json['last_name'] as String?,
      phoneNumber: json['phone_number'] as String?,
      profilePic: json['profile_pic'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'role': role.name,
      'first_name': firstName,
      'last_name': lastName,
      'phone_number': phoneNumber,
      'profile_pic': profilePic,
    };
  }

  AllUserModel copyWith({
    String? id,
    String? email,
    UserRole? role,
    String? firstName,
    String? lastName,
    String? phoneNumber,
    String? profilePic,
  }) {
    return AllUserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      role: role ?? this.role,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      profilePic: profilePic ?? this.profilePic,
    );
  }
}
