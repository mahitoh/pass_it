import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/models/paper_model.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../providers/paper_providers.dart';
import '../../../../shared/widgets/animated_background.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../widgets/paper_list_tile.dart';
import '../widgets/skeleton_loader.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  PaperSearchFilters _filters = const PaperSearchFilters();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      setState(() {
        _filters = _filters.copyWith(query: _searchController.text);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final resultsAsync = ref.watch(searchPapersProvider(_filters));

    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBackground(
                colors: [AppColors.background, AppColors.surface, Color(0xFF101224)],
              ),
            ),
          ),
          CustomScrollView(
            slivers: [
              SliverPersistentHeader(
                pinned: true,
                delegate: _SearchBarDelegate(
                  controller: _searchController,
                  onBack: () => context.pop(),
                ),
              ),
              SliverToBoxAdapter(child: _buildFilterBar()),
              SliverToBoxAdapter(child: _buildResultsHeader(resultsAsync)),
              resultsAsync.when(
                data: (papers) {
                  if (papers.isEmpty) {
                    return SliverFillRemaining(
                      hasScrollBody: false,
                      child: EmptyState(
                        title: 'No papers found',
                        message: 'Be the first to upload and help your coursemates.',
                        actionLabel: 'Upload Paper',
                        onAction: () => context.goNamed('upload'),
                      ),
                    );
                  }
                  return SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final paper = papers[index];
                          return PaperListTile(
                            paper: paper,
                            onTap: () => context.pushNamed('paper-details', extra: paper),
                          );
                        },
                        childCount: papers.length,
                      ),
                    ),
                  );
                },
                loading: () => SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => const PaperListTileSkeleton(),
                      childCount: 6,
                    ),
                  ),
                ),
                error: (err, stack) => SliverFillRemaining(
                  child: Center(child: Text('Error: $err')),
                ),
              ),
              const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    final chips = [
      _FilterChipData(
        label: _filters.type == null ? 'Assessment Type' : _labelForType(_filters.type!),
        onTap: () => _showTypeSheet(),
        isActive: _filters.type != null,
      ),
      _FilterChipData(
        label: _filters.year == null ? 'Academic Year' : _filters.year.toString(),
        onTap: () => _showYearSheet(),
        isActive: _filters.year != null,
      ),
      _FilterChipData(
        label: _filters.instructor == null ? 'Instructor' : _filters.instructor!,
        onTap: () => _showInstructorSheet(),
        isActive: _filters.instructor != null,
      ),
    ];

    return SizedBox(
      height: 60,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        itemCount: chips.length,
        itemBuilder: (context, index) {
          final chip = chips[index];
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: InkWell(
              onTap: chip.onTap,
              borderRadius: BorderRadius.circular(18),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: chip.isActive ? AppColors.primary.withAlpha(38) : AppColors.background,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: chip.isActive ? AppColors.primary : AppColors.border),
                ),
                child: Row(
                  children: [
                    Text(
                      chip.label,
                      style: TextStyle(
                        color: chip.isActive ? Colors.white : AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(LucideIcons.chevronDown, size: 14, color: AppColors.textSecondary),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildResultsHeader(AsyncValue<List<Paper>> resultsAsync) {
    final count = resultsAsync.maybeWhen(data: (items) => items.length, orElse: () => null);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              count == null ? 'Searching...' : '$count papers found',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(color: AppColors.textSecondary),
            ),
          ),
          const Icon(LucideIcons.arrowUpDown, size: 16, color: AppColors.textSecondary),
        ],
      ),
    );
  }

  String _labelForType(AssessmentType type) {
    switch (type) {
      case AssessmentType.ca:
        return 'CA';
      case AssessmentType.quiz:
        return 'Quiz';
      case AssessmentType.midterm:
        return 'Midterm';
      case AssessmentType.finalExam:
        return 'Final Exam';
    }
  }

  void _showTypeSheet() {
    _showFilterSheet(
      title: 'Assessment Type',
      options: AssessmentType.values.map(_labelForType).toList(),
      onSelected: (value) {
        setState(() {
          _filters = _filters.copyWith(type: AssessmentType.values.firstWhere((t) => _labelForType(t) == value));
        });
      },
    );
  }

  void _showYearSheet() {
    final years = [2024, 2023, 2022, 2021, 2020];
    _showFilterSheet(
      title: 'Academic Year',
      options: years.map((e) => e.toString()).toList(),
      onSelected: (value) {
        setState(() {
          _filters = _filters.copyWith(year: int.parse(value));
        });
      },
    );
  }

  void _showInstructorSheet() {
    final instructors = ['Dr. Foka', 'Dr. Hassan', 'Prof. Ade', 'Dr. Chen'];
    _showFilterSheet(
      title: 'Instructor',
      options: instructors,
      onSelected: (value) {
        setState(() {
          _filters = _filters.copyWith(instructor: value);
        });
      },
    );
  }

  void _showFilterSheet({
    required String title,
    required List<String> options,
    required ValueChanged<String> onSelected,
  }) {
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
                  Text(title, style: Theme.of(context).textTheme.displaySmall?.copyWith(fontSize: 18)),
                  const SizedBox(height: 16),
                  ...options.map((option) => InkWell(
                        onTap: () {
                          Navigator.pop(context);
                          onSelected(option);
                        },
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(option, style: Theme.of(context).textTheme.bodyLarge),
                              const Icon(LucideIcons.chevronRight, size: 16, color: AppColors.textSecondary),
                            ],
                          ),
                        ),
                      )),
                  const SizedBox(height: 8),
                ],
              ),
            );
          },
    );
  }
}

class _FilterChipData {
  final String label;
  final VoidCallback onTap;
  final bool isActive;

  _FilterChipData({
    required this.label,
    required this.onTap,
    required this.isActive,
  });
}

class _SearchBarDelegate extends SliverPersistentHeaderDelegate {
  final TextEditingController controller;
  final VoidCallback onBack;

  _SearchBarDelegate({
    required this.controller,
    required this.onBack,
  });

  @override
  double get minExtent => 92;

  @override
  double get maxExtent => 92;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: AppColors.background,
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
      child: Row(
        children: [
          InkWell(
            onTap: onBack,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: const Icon(LucideIcons.chevronLeft, size: 18, color: Colors.white),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: ValueListenableBuilder<TextEditingValue>(
                valueListenable: controller,
                builder: (context, value, child) {
                  return Row(
                    children: [
                      const Icon(LucideIcons.search, size: 18, color: AppColors.textSecondary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: controller,
                          autofocus: true,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            hintText: 'Search course code or name',
                            border: InputBorder.none,
                            isDense: true,
                          ),
                        ),
                      ),
                      if (value.text.isNotEmpty)
                        InkWell(
                          onTap: () => controller.clear(),
                          child: const Icon(LucideIcons.x, size: 16, color: AppColors.textSecondary),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) => true;
}
