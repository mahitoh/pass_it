import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/theme/app_colors.dart';

enum UploadState { inProgress, success, error }

class UploadProgressSheet extends StatelessWidget {
  final UploadState state;
  final double progress;
  final VoidCallback? onRetry;

  const UploadProgressSheet({
    super.key,
    required this.state,
    this.progress = 0,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          const SizedBox(height: 24),
          if (state == UploadState.inProgress) ...[
            const Icon(LucideIcons.upload, size: 32, color: AppColors.primary),
            const SizedBox(height: 12),
            Text('Uploading...', style: Theme.of(context).textTheme.displaySmall?.copyWith(fontSize: 18)),
            const SizedBox(height: 16),
            LinearProgressIndicator(value: progress),
          ],
          if (state == UploadState.success) ...[
            const Icon(LucideIcons.circleCheck, size: 32, color: AppColors.primary),
            const SizedBox(height: 12),
            Text('Uploaded!', style: Theme.of(context).textTheme.displaySmall?.copyWith(fontSize: 18)),
            const SizedBox(height: 8),
            Text('Your paper is live for everyone.', style: Theme.of(context).textTheme.bodyMedium),
          ],
          if (state == UploadState.error) ...[
            const Icon(LucideIcons.circleAlert, size: 32, color: AppColors.error),
            const SizedBox(height: 12),
            Text('Upload failed', style: Theme.of(context).textTheme.displaySmall?.copyWith(fontSize: 18)),
            const SizedBox(height: 8),
            Text('Please check your connection and retry.', style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onRetry,
                child: const Text('Retry'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
