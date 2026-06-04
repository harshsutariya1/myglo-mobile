// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'all_user_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_AllUserModel _$AllUserModelFromJson(Map<String, dynamic> json) =>
    _AllUserModel(
      id: json['id'] as String,
      email: json['email'] as String,
      role: $enumDecode(_$UserRoleEnumMap, json['role']),
      firstName: json['first_name'] as String?,
      lastName: json['last_name'] as String?,
      phoneNumber: json['phone_number'] as String?,
      profilePic: json['profile_pic'] as String?,
    );

Map<String, dynamic> _$AllUserModelToJson(_AllUserModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'email': instance.email,
      'role': _$UserRoleEnumMap[instance.role]!,
      'first_name': instance.firstName,
      'last_name': instance.lastName,
      'phone_number': instance.phoneNumber,
      'profile_pic': instance.profilePic,
    };

const _$UserRoleEnumMap = {
  UserRole.customer: 'customer',
  UserRole.business: 'business',
};
