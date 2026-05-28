class CustomerModel {
  final String id;
  final String email;
  final String firstName;
  final String lastName;
  final String? phone;
  final String? profilePicUrl;

  const CustomerModel({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    this.phone,
    this.profilePicUrl,
  });

  factory CustomerModel.fromJson(Map<String, dynamic> json) {
    return CustomerModel(
      id: json['id'] as String? ?? '',
      email: json['email'] as String? ?? '',
      firstName: json['first_name'] as String? ?? '',
      lastName: json['last_name'] as String? ?? '',
      phone: json['phone'] as String?,
      profilePicUrl: json['profile_pic_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'first_name': firstName,
      'last_name': lastName,
      'phone': phone,
      'profile_pic_url': profilePicUrl,
    };
  }

  CustomerModel copyWith({
    String? id,
    String? email,
    String? firstName,
    String? lastName,
    String? phone,
    String? profilePicUrl,
  }) {
    return CustomerModel(
      id: id ?? this.id,
      email: email ?? this.email,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      phone: phone ?? this.phone,
      profilePicUrl: profilePicUrl ?? this.profilePicUrl,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is CustomerModel &&
        other.id == id &&
        other.email == email &&
        other.firstName == firstName &&
        other.lastName == lastName &&
        other.phone == phone &&
        other.profilePicUrl == profilePicUrl;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        email.hashCode ^
        firstName.hashCode ^
        lastName.hashCode ^
        phone.hashCode ^
        profilePicUrl.hashCode;
  }

  @override
  String toString() {
    return 'CustomerModel(id: $id, email: $email, firstName: $firstName, lastName: $lastName, phone: $phone, profilePicUrl: $profilePicUrl)';
  }
}
