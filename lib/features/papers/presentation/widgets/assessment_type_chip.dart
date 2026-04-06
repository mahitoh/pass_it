import 'package:flutter/material.dart';
import '../../../../core/models/paper_model.dart';
import '../../../../core/theme/app_colors.dart';

class AssessmentTypeChip extends StatelessWidget {
  final AssessmentType type;

  const AssessmentTypeChip({super.key, required this.type});

  @override
  Widget build(BuildContext context) {
    final color = _getColor(type);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha(31),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(77)),
      ),
      child: Text(
        _label(type),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  String _label(AssessmentType type) {
    switch (type) {
      case AssessmentType.ca:
        return 'CA';
      case AssessmentType.quiz:
        return 'QUIZ';
      case AssessmentType.midterm:
        return 'MIDTERM';
      case AssessmentType.finalExam:
        return 'FINAL';
    }
  }

  Color _getColor(AssessmentType type) {
    switch (type) {
      case AssessmentType.ca:
        return AppColors.ca;
      case AssessmentType.quiz:
        return AppColors.quiz;
      case AssessmentType.midterm:
        return AppColors.midterm;
      case AssessmentType.finalExam:
        return AppColors.finalExam;
    }
  }
}
