import 'package:flutter/material.dart';

import '../data/app_state.dart';
import 'paper_detail_page.dart';

class UniversityPapersPage extends StatelessWidget {
  const UniversityPapersPage({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);
    final papers = appState.papersForCategory(PaperCategory.university);

    return Scaffold(
      appBar: AppBar(
        title: const Text('University Papers'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: CustomScrollView(
        slivers: [
          _buildHeroHeader(context),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader(context, 'Engineering & Tech'),
                  const SizedBox(height: 12),
                  _buildPaperList(
                    context,
                    papers
                        .where(
                          (paper) =>
                              paper.course.contains('Engineering') ||
                              paper.course.contains('Computer'),
                        )
                        .toList(growable: false),
                  ),
                  const SizedBox(height: 32),
                  _buildSectionHeader(context, 'Business & Management'),
                  const SizedBox(height: 12),
                  _buildPaperList(
                    context,
                    papers
                        .where(
                          (paper) =>
                              paper.course.contains('Accounting') ||
                              paper.course.contains('Finance'),
                        )
                        .toList(growable: false),
                  ),
                  const SizedBox(height: 32),
                  _buildSectionHeader(context, 'Health Sciences'),
                  const SizedBox(height: 12),
                  _buildPaperList(
                    context,
                    papers
                        .where(
                          (paper) =>
                              paper.course.contains('Science') ||
                              paper.course.contains('Physics') ||
                              paper.course.contains('Chemistry'),
                        )
                        .toList(growable: false),
                  ),
                ],
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
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 48),
        color: theme.colorScheme.surfaceContainerLow,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'University of Buea',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Academic Archives',
              style: theme.textTheme.displayLarge?.copyWith(fontSize: 36),
            ),
            const SizedBox(height: 16),
            Text(
              'Explore thousands of past papers curated by students and verified by our academic committee.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontSize: 20),
    );
  }

  Widget _buildPaperList(BuildContext context, List<ExamPaper> papers) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: papers.length,
        separatorBuilder: (context, index) => Divider(
          color: theme.colorScheme.outlineVariant.withOpacity(0.1),
          height: 1,
          indent: 16,
          endIndent: 16,
        ),
        itemBuilder: (context, index) {
          return ListTile(
            title: Text(
              papers[index].title,
              style: theme.textTheme.titleMedium?.copyWith(fontSize: 15),
            ),
            subtitle: Text(
              '${papers[index].institution} • ${papers[index].year}',
              style: theme.textTheme.labelSmall,
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 14),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      PaperDetailPage(paperId: papers[index].id),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
