import 'package:freezed_annotation/freezed_annotation.dart';

part 'service_model.freezed.dart';
part 'service_model.g.dart';

@freezed
abstract class ServiceModel with _$ServiceModel {
  const factory ServiceModel({
    required String id,
    @JsonKey(name: 'provider_id') required String providerId,
    required String name,
    required String description,
    required double price,
    @JsonKey(name: 'duration_minutes') required int durationMinutes,
    @JsonKey(name: 'created_at') required DateTime createdAt,
  }) = _ServiceModel;

  factory ServiceModel.fromJson(Map<String, dynamic> json) =>
      _$ServiceModelFromJson(json);
}
