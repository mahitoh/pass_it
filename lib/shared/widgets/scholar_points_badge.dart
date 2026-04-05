import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/theme/app_colors.dart';

class ScholarPointsBadge extends StatelessWidget {
  final int points;

  const ScholarPointsBadge({super.key, required this.points});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(LucideIcons.sparkles, size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: points.toDouble()),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return Text(
                value.round().toString(),
                style: Theme.of(context).textTheme.displaySmall?.copyWith(fontSize: 18),
              );
            },
          ),
          const SizedBox(width: 6),
          Text(
            'Points',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
