import 'package:freezed_annotation/freezed_annotation.dart';
import '../../../../core/location/geo_point.dart';
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

/// Reads a `geography` point however PostgREST sends it: hex EWKB (its
/// default for geography columns) or GeoJSON. Anything else reads as null
/// rather than failing the whole profile.
class LocationCoordinatesConverter implements JsonConverter<LocationCoordinates?, Object?> {
  const LocationCoordinatesConverter();

  @override
  LocationCoordinates? fromJson(Object? json) {
    final point = PostgisPoint.parse(json);
    return point == null ? null : LocationCoordinates(type: 'Point', coordinates: point.toGeoJsonCoordinates());
  }

  @override
  Object? toJson(LocationCoordinates? object) => object?.toJson();
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
    @LocationCoordinatesConverter() LocationCoordinates? coordinates,
  }) = _ProfileModel;

  factory ProfileModel.fromJson(Map<String, dynamic> json) =>
      _$ProfileModelFromJson(json);
}
