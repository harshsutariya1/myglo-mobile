class BusinessModel {
  final String id;
  final String email;
  final String? firstName;
  final String? lastName;
  final String? businessName;
  final String? phoneNumber;
  final String? profilePicUrl;

  const BusinessModel({
    required this.id,
    required this.email,
    this.firstName,
    this.lastName,
    this.businessName,
    this.phoneNumber,
    this.profilePicUrl,
  });

  factory BusinessModel.fromJson(Map<String, dynamic> json) {
    return BusinessModel(
      id: json['id'] as String? ?? '',
      email: json['email'] as String? ?? '',
      firstName: json['first_name'] as String?,
      lastName: json['last_name'] as String?,
      businessName: json['business_name'] as String?,
      phoneNumber: json['phone_number'] as String?,
      profilePicUrl: json['profile_pic'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'first_name': firstName,
      'last_name': lastName,
      'business_name': businessName,
      'phone_number': phoneNumber,
      'profile_pic': profilePicUrl,
    };
  }

  BusinessModel copyWith({
    String? id,
    String? email,
    String? firstName,
    String? lastName,
    String? businessName,
    String? phoneNumber,
    String? profilePicUrl,
  }) {
    return BusinessModel(
      id: id ?? this.id,
      email: email ?? this.email,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      businessName: businessName ?? this.businessName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      profilePicUrl: profilePicUrl ?? this.profilePicUrl,
    );
  }
}
