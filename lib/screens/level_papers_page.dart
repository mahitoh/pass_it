import 'package:flutter/material.dart';
import '../data/app_state.dart';
import 'paper_detail_page.dart';

class LevelPapersPage extends StatelessWidget {
  final PaperCategory category;
  const LevelPapersPage({super.key, required this.category});

  String get _title => switch (category) {
    PaperCategory.university => 'University Papers',
    PaperCategory.highSchool => 'High School Papers',
    PaperCategory.competitive => 'Competitive Exams',
    PaperCategory.professional => 'Professional Papers',
  };

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);
    final papers = appState.papersForCategory(category);

    return Scaffold(
      appBar: AppBar(
        title: Text(_title),
      ),
      body: CustomScrollView(
        slivers: [
          _buildHeroHeader(context),
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: papers.isEmpty 
              ? const SliverFillRemaining(
                  child: Center(child: Text('No papers found in this category.')),
                )
              : SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final paper = papers[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        color: Theme.of(context).colorScheme.surfaceContainerLow,
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.description_outlined, color: Theme.of(context).colorScheme.primary),
                          ),
                          title: Text(
                            paper.title,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          subtitle: Text(
                            '${paper.institution} • ${paper.year}',
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PaperDetailPage(paperId: paper.id),
                              ),
                            );
                          },
                        ),
                      );
                    },
                    childCount: papers.length,
                  ),
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroHeader(BuildContext context) {
    final theme = Theme.of(context);
    return SliverToBoxAdapter(
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 48),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withValues(alpha: 0.05),
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(32),
            bottomRight: Radius.circular(32),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _title.toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Academic Excellence',
              style: theme.textTheme.displayLarge?.copyWith(fontSize: 32),
            ),
            const SizedBox(height: 16),
            Text(
              'Find and download high-quality past exams and study materials to excel in your studies.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
