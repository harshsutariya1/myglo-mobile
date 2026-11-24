// GENERATED CODE - DO NOT MODIFY BY HAND

// ignore_for_file: type=lint

part of 'profile_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_LocationCoordinates _$LocationCoordinatesFromJson(Map<String, dynamic> json) =>
    _LocationCoordinates(
      type: json['type'] as String,
      coordinates: (json['coordinates'] as List<dynamic>)
          .map((e) => (e as num).toDouble())
          .toList(),
    );

Map<String, dynamic> _$LocationCoordinatesToJson(
  _LocationCoordinates instance,
) => <String, dynamic>{
  'type': instance.type,
  'coordinates': instance.coordinates,
};

_ProfileModel _$ProfileModelFromJson(Map<String, dynamic> json) =>
    _ProfileModel(
      id: json['id'] as String,
      role: $enumDecode(_$UserRoleEnumMap, json['role']),
      firstName: json['first_name'] as String?,
      lastName: json['last_name'] as String?,
      email: json['email'] as String?,
      phoneNumber: json['phone_number'] as String?,
      phoneVerifiedAt: json['phone_verified_at'] == null
          ? null
          : DateTime.parse(json['phone_verified_at'] as String),
      profilePic: json['profile_pic'] as String?,
      bio: json['bio'] as String?,
      followersCount: (json['followers_count'] as num?)?.toInt() ?? 0,
      followingCount: (json['following_count'] as num?)?.toInt() ?? 0,
      providerName: json['provider_name'] as String?,
      addressText: json['address_text'] as String?,
      coordinates: const LocationCoordinatesConverter().fromJson(
        json['coordinates'],
      ),
      coverPhotos:
          (json['cover_photos'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const <String>[],
    );

Map<String, dynamic> _$ProfileModelToJson(_ProfileModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'role': _$UserRoleEnumMap[instance.role]!,
      'first_name': instance.firstName,
      'last_name': instance.lastName,
      'email': instance.email,
      'phone_number': instance.phoneNumber,
      'phone_verified_at': instance.phoneVerifiedAt?.toIso8601String(),
      'profile_pic': instance.profilePic,
      'bio': instance.bio,
      'followers_count': instance.followersCount,
      'following_count': instance.followingCount,
      'provider_name': instance.providerName,
      'address_text': instance.addressText,
      'coordinates': const LocationCoordinatesConverter().toJson(
        instance.coordinates,
      ),
      'cover_photos': instance.coverPhotos,
    };

const _$UserRoleEnumMap = {
  UserRole.customer: 'customer',
  UserRole.provider: 'provider',
};
