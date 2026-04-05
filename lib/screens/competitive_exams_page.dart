import 'package:flutter/material.dart';

import '../data/app_state.dart';
import 'paper_detail_page.dart';

class CompetitiveExamsPage extends StatelessWidget {
  const CompetitiveExamsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);
    final papers = appState.papersForCategory(PaperCategory.competitive);

    return Scaffold(
      appBar: AppBar(title: const Text('Competitive Exams')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildExamsHeader(context),
            const SizedBox(height: 32),
            _buildExamCategory(context, 'Engineering', [
              ...papers.where(
                (paper) => paper.institution.contains('Polytech'),
              ),
            ]),
            const SizedBox(height: 24),
            _buildExamCategory(
              context,
              'Medical & Health',
              papers
                  .where(
                    (paper) =>
                        paper.course.contains('Health') ||
                        paper.title.contains('Medical'),
                  )
                  .toList(growable: false),
            ),
            const SizedBox(height: 24),
            _buildExamCategory(
              context,
              'Teaching & Service',
              papers
                  .where(
                    (paper) =>
                        paper.institution.contains('ENS') ||
                        paper.course.contains('Teaching'),
                  )
                  .toList(growable: false),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExamsHeader(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'National Concours',
          style: theme.textTheme.displayLarge?.copyWith(fontSize: 32),
        ),
        const SizedBox(height: 8),
        Text(
          'Prepare for the most prestigious entrance examinations in Cameroon.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildExamCategory(
    BuildContext context,
    String title,
    List<ExamPaper> exams,
  ) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4.0, bottom: 12),
          child: Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.primary,
              letterSpacing: 0.5,
            ),
          ),
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.6,
          ),
          itemCount: exams.length,
          itemBuilder: (context, index) {
            return Card(
              color: theme.colorScheme.surfaceContainerLow,
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          PaperDetailPage(paperId: exams[index].id),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(16),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      exams[index].title,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
