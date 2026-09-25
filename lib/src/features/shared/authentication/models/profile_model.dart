import 'package:freezed_annotation/freezed_annotation.dart';
import 'user_role.dart';

part 'profile_model.freezed.dart';
part 'profile_model.g.dart';

@freezed
abstract class LocationCoordinates with _$LocationCoordinates {
  const factory LocationCoordinates({
    required String type,
    required List<double> coordinates,
  }) = _LocationCoordinates;

  factory LocationCoordinates.fromJson(Map<String, dynamic> json) =>
      _$LocationCoordinatesFromJson(json);
}

@freezed
abstract class ProfileModel with _$ProfileModel {
  const factory ProfileModel({
    required String id,
    required UserRole role,
    @JsonKey(name: 'first_name') String? firstName,
    @JsonKey(name: 'last_name') String? lastName,
    String? email,
    @JsonKey(name: 'phone_number') String? phoneNumber,
    @JsonKey(name: 'profile_pic') String? profilePic,
    String? bio,
    @JsonKey(name: 'followers_count') @Default(0) int followersCount,
    @JsonKey(name: 'following_count') @Default(0) int followingCount,
    @JsonKey(name: 'is_email_public') @Default(false) bool isEmailPublic,
    @JsonKey(name: 'is_phone_public') @Default(false) bool isPhonePublic,
    @JsonKey(name: 'provider_name') String? providerName,
    @JsonKey(name: 'address_text') String? addressText,
    LocationCoordinates? coordinates,
  }) = _ProfileModel;

  factory ProfileModel.fromJson(Map<String, dynamic> json) =>
      _$ProfileModelFromJson(json);
}
