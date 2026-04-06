import 'package:freezed_annotation/freezed_annotation.dart';

part 'paper_model.freezed.dart';
part 'paper_model.g.dart';

@freezed
abstract class Paper with _$Paper {
  const factory Paper({
    required String id,
    required String courseCode,
    required String courseName,
    required String instructor,
    required AssessmentType type,
    required int year,
    required int semester,
    required String fileUrl,
    required String uploaderId,
    required DateTime uploadedAt,
    @Default(0) int upvotes,
  }) = _Paper;

  factory Paper.fromJson(Map<String, dynamic> json) => _$PaperFromJson(json);
}

enum AssessmentType { ca, quiz, midterm, finalExam }
