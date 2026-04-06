import 'package:freezed_annotation/freezed_annotation.dart';

part 'user_model.freezed.dart';
part 'user_model.g.dart';

@freezed
abstract class UserModel with _$UserModel {
  const factory UserModel({
    required String uid,
    required String email,
    required String displayName,
    required String university,
    required int scholarPoints,
    required int rank,
    String? photoUrl,
    @Default([]) List<String> bookmarkedPapers,
    @Default([]) List<String> uploadedPapers,
  }) = _UserModel;

  factory UserModel.fromJson(Map<String, dynamic> json) => _$UserModelFromJson(json);
}
