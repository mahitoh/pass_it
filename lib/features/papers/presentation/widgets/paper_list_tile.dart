import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/models/paper_model.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/pressable_scale.dart';
import 'assessment_type_chip.dart';

class PaperListTile extends StatelessWidget {
  final Paper paper;
  final VoidCallback onTap;

  const PaperListTile({
    super.key,
    required this.paper,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: PressableScale(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              Hero(
                tag: 'paper-thumb-${paper.id}',
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Icon(LucideIcons.fileText, size: 32, color: AppColors.primary),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          paper.courseCode,
                          style: Theme.of(context).textTheme.displaySmall?.copyWith(fontSize: 16),
                        ),
                        const SizedBox(width: 8),
                        AssessmentTypeChip(type: paper.type),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      paper.courseName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${paper.instructor} - ${paper.year}',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12),
                        ),
                        Row(
                          children: [
                            const Icon(LucideIcons.thumbsUp, size: 12, color: AppColors.accent),
                            const SizedBox(width: 4),
                            Text(
                              '${paper.upvotes}',
                              style: Theme.of(context).textTheme.labelLarge?.copyWith(fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
