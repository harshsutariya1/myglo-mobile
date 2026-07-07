// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'provider_details_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ProviderDetailsModel _$ProviderDetailsModelFromJson(
  Map<String, dynamic> json,
) => _ProviderDetailsModel(
  id: json['id'] as String,
  providerName: json['provider_name'] as String?,
  addressText: json['address_text'] as String?,
  latitude: (json['latitude'] as num?)?.toDouble(),
  longitude: (json['longitude'] as num?)?.toDouble(),
);

Map<String, dynamic> _$ProviderDetailsModelToJson(
  _ProviderDetailsModel instance,
) => <String, dynamic>{
  'id': instance.id,
  'provider_name': instance.providerName,
  'address_text': instance.addressText,
  'latitude': instance.latitude,
  'longitude': instance.longitude,
};
