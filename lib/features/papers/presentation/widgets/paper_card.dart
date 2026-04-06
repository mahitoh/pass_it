import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/models/paper_model.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../providers/paper_providers.dart';
import '../../../../shared/widgets/pressable_scale.dart';
import 'assessment_type_chip.dart';

class PaperCard extends ConsumerStatefulWidget {
  final Paper paper;
  final VoidCallback onTap;

  const PaperCard({
    super.key,
    required this.paper,
    required this.onTap,
  });

  @override
  ConsumerState<PaperCard> createState() => _PaperCardState();
}

class _PaperCardState extends ConsumerState<PaperCard> {
  late int _upvotes;
  bool _liked = false;

  @override
  void initState() {
    super.initState();
    _upvotes = widget.paper.upvotes;
  }

  void _toggleLike() {
    setState(() {
      if (_liked) {
        _upvotes--;
      } else {
        _upvotes++;
      }
      _liked = !_liked;
    });
    ref.read(paperRepositoryProvider).toggleUpvote(widget.paper.id);
  }

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: widget.onTap,
      borderRadius: BorderRadius.circular(16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.paper.courseCode,
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(fontSize: 18),
                  ),
                  AssessmentTypeChip(type: widget.paper.type),
                ],
              ),
              const SizedBox(height: 12),
              Hero(
                tag: 'paper-thumb-${widget.paper.id}',
                child: Container(
                  height: 84,
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Center(
                    child: Icon(LucideIcons.fileText, size: 36, color: AppColors.primary),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(LucideIcons.userRound, size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      widget.paper.instructor,
                      style: Theme.of(context).textTheme.bodyMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: _toggleLike,
                    child: Row(
                      children: [
                        Icon(
                          _liked ? LucideIcons.thumbsUp : LucideIcons.thumbsUp,
                          size: 14,
                          color: _liked ? AppColors.primary : AppColors.accent,
                        ),
                        const SizedBox(width: 4),
                        Text('$_upvotes', style: Theme.of(context).textTheme.labelLarge),
                      ],
                    ),
                  ),
                  Text(
                    _formatDate(widget.paper.uploadedAt),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}
