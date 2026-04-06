import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../providers/paper_providers.dart';
import '../../../../shared/widgets/animated_background.dart';
import '../../../papers/presentation/widgets/paper_card.dart';
import '../../../papers/presentation/widgets/skeleton_loader.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recentPapersAsync = ref.watch(recentPapersProvider);

    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBackground(
                colors: [AppColors.background, AppColors.surface, Color(0xFF111122)],
              ),
            ),
          ),
          CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _buildHeader(context)),
              SliverPersistentHeader(
                pinned: true,
                delegate: _SearchBarDelegate(onFilterTap: () => _showFilterSheet(context)),
              ),
              SliverToBoxAdapter(child: _buildTrendingCourses(context)),
              SliverToBoxAdapter(child: _buildSectionHeader(context, 'Recently Added')),
              _buildRecentPapers(context, recentPapersAsync),
              const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hello, Scholar!',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 6),
              Text(
                'Explore Papers',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(fontSize: 22),
              ),
            ],
          ),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: const Icon(LucideIcons.userRound, size: 20, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendingCourses(BuildContext context) {
    final courses = ['CS201', 'CS301', 'PHY101', 'CHM102', 'MTH211'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeaderPadding('Trending Courses'),
        SizedBox(
          height: 50,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            scrollDirection: Axis.horizontal,
            itemCount: courses.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: ActionChip(
                  label: Text(courses[index]),
                  backgroundColor: AppColors.surface,
                  side: const BorderSide(color: AppColors.border),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  onPressed: () {},
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return _buildSectionHeaderPadding(title);
  }

  Widget _buildSectionHeaderPadding(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
      child: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
      ),
    );
  }

  Widget _buildRecentPapers(BuildContext context, AsyncValue recentPapersAsync) {
    return recentPapersAsync.when(
      data: (papers) => SliverToBoxAdapter(
        child: SizedBox(
          height: 260,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            scrollDirection: Axis.horizontal,
            itemCount: papers.length,
            itemBuilder: (context, index) {
              final paper = papers[index];
              return Container(
                width: 220,
                margin: EdgeInsets.only(right: index == papers.length - 1 ? 0 : 16),
                child: PaperCard(
                  paper: paper,
                  onTap: () => context.pushNamed('paper-details', extra: paper),
                ),
              );
            },
          ),
        ),
      ),
      loading: () => SliverToBoxAdapter(
        child: SizedBox(
          height: 260,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            scrollDirection: Axis.horizontal,
            itemCount: 4,
            itemBuilder: (context, index) => Container(
              width: 220,
              margin: const EdgeInsets.only(right: 16),
              child: const PaperCardSkeleton(),
            ),
          ),
        ),
      ),
      error: (err, stack) => SliverToBoxAdapter(
        child: Center(child: Text('Error: $err')),
      ),
    );
  }

  void _showFilterSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Filter papers', style: Theme.of(context).textTheme.displaySmall?.copyWith(fontSize: 18)),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: const [
                  _FilterPill(label: 'Assessment Type'),
                  _FilterPill(label: 'Academic Year'),
                  _FilterPill(label: 'Instructor'),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }
}

class _FilterPill extends StatelessWidget {
  final String label;
  const _FilterPill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
    );
  }
}

class _SearchBarDelegate extends SliverPersistentHeaderDelegate {
  final VoidCallback onFilterTap;
  _SearchBarDelegate({required this.onFilterTap});

  @override
  double get minExtent => 76;

  @override
  double get maxExtent => 76;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: AppColors.background,
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.goNamed('search'),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              const Icon(LucideIcons.search, size: 20, color: AppColors.textSecondary),
              const SizedBox(width: 12),
              Text(
                'Search course code, instructor...',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
              ),
              const Spacer(),
              GestureDetector(
                onTap: onFilterTap,
                child: const Icon(LucideIcons.listFilter, size: 20, color: AppColors.primary),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) => false;
}
