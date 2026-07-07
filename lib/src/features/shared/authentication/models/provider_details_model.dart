import 'package:freezed_annotation/freezed_annotation.dart';

part 'provider_details_model.freezed.dart';
part 'provider_details_model.g.dart';

@freezed
abstract class ProviderDetailsModel with _$ProviderDetailsModel {
  const factory ProviderDetailsModel({
    required String id,
    @JsonKey(name: 'provider_name') String? providerName,
    @JsonKey(name: 'address_text') String? addressText,
    double? latitude,
    double? longitude,
  }) = _ProviderDetailsModel;

  factory ProviderDetailsModel.fromJson(Map<String, dynamic> json) =>
      _$ProviderDetailsModelFromJson(json);
}
