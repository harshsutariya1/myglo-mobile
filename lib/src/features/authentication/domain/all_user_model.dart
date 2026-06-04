import 'package:freezed_annotation/freezed_annotation.dart';
import 'user_role.dart';

part 'all_user_model.freezed.dart';
part 'all_user_model.g.dart';

@freezed
abstract class AllUserModel with _$AllUserModel {
  const factory AllUserModel({
    required String id,
    required String email,
    required UserRole role,
    @JsonKey(name: 'first_name') String? firstName,
    @JsonKey(name: 'last_name') String? lastName,
    @JsonKey(name: 'phone_number') String? phoneNumber,
    @JsonKey(name: 'profile_pic') String? profilePic,
  }) = _AllUserModel;

  factory AllUserModel.fromJson(Map<String, dynamic> json) => _$AllUserModelFromJson(json);
}
