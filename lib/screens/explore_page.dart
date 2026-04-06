import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../data/app_state.dart';
import 'paper_detail_page.dart';
import '../theme/app_theme.dart';

class ExplorePage extends StatefulWidget {
  const ExplorePage({super.key, this.initialQuery = ''});
  final String initialQuery;

  @override
  State<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage> {
  late final TextEditingController _searchCtrl;
  PaperCategory? _selectedCategory;
  String _sortBy = 'downloads';
  bool _showFilters = false;

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController(text: widget.initialQuery);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<ExamPaper> _filtered(AppState appState) {
    var results = appState.searchPapers(_searchCtrl.text);
    if (_selectedCategory != null) {
      results = results.where((p) => p.category == _selectedCategory).toList();
    }
    if (_sortBy == 'recent') {
      results = [...results]..sort((a, b) => b.year.compareTo(a.year));
    } else {
      results = [...results]..sort((a, b) => b.downloads.compareTo(a.downloads));
    }
    return results;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final appState = AppStateScope.of(context);
    final papers = _filtered(appState);
    final hasQuery = _searchCtrl.text.isNotEmpty || _selectedCategory != null;

    return Scaffold(
      backgroundColor: cs.surface,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            backgroundColor: cs.surface,
            surfaceTintColor: Colors.transparent,
            title: Text('Explore', style: GoogleFonts.manrope(fontSize: 20, fontWeight: FontWeight.w700, color: cs.onSurface)),
            titleSpacing: 20,
            actions: [
              IconButton(
                onPressed: () => setState(() => _showFilters = !_showFilters),
                icon: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(Icons.tune_rounded, color: cs.onSurface, size: 22),
                    if (_selectedCategory != null || _sortBy != 'downloads')
                      Positioned(
                        top: -2, right: -2,
                        child: Container(width: 8, height: 8, decoration: BoxDecoration(color: cs.primary, shape: BoxShape.circle)),
                      ),
                  ],
                ),
              ),
              if (hasQuery)
                IconButton(
                  onPressed: () => setState(() {
                    _searchCtrl.clear();
                    _selectedCategory = null;
                    _sortBy = 'downloads';
                  }),
                  icon: Icon(Icons.filter_alt_off_outlined, color: cs.onSurface, size: 20),
                ),
              const SizedBox(width: 4),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Column(
                children: [
                  TextField(
                    controller: _searchCtrl,
                    style: GoogleFonts.inter(fontSize: 14, color: cs.onSurface),
                    textInputAction: TextInputAction.search,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Search papers, courses, institutions…',
                      hintStyle: GoogleFonts.inter(color: cs.onSurfaceVariant),
                      filled: true,
                      fillColor: cs.surfaceContainerHigh,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: cs.primary, width: 1.5),
                      ),
                      prefixIcon: Icon(Icons.search_rounded, color: cs.onSurfaceVariant, size: 20),
                      suffixIcon: _searchCtrl.text.isNotEmpty
                          ? IconButton(icon: Icon(Icons.close_rounded, color: cs.onSurfaceVariant, size: 18), onPressed: () => setState(() => _searchCtrl.clear()))
                          : null,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 34,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _CategoryChip(label: 'All', selected: _selectedCategory == null, onTap: () => setState(() => _selectedCategory = null)),
                        const SizedBox(width: 8),
                        _CategoryChip(label: 'University', category: PaperCategory.university, selected: _selectedCategory == PaperCategory.university,
                            onTap: () => setState(() => _selectedCategory = _selectedCategory == PaperCategory.university ? null : PaperCategory.university)),
                        const SizedBox(width: 8),
                        _CategoryChip(label: 'High School', category: PaperCategory.highSchool, selected: _selectedCategory == PaperCategory.highSchool,
                            onTap: () => setState(() => _selectedCategory = _selectedCategory == PaperCategory.highSchool ? null : PaperCategory.highSchool)),
                        const SizedBox(width: 8),
                        _CategoryChip(label: 'Competitive', category: PaperCategory.competitive, selected: _selectedCategory == PaperCategory.competitive,
                            onTap: () => setState(() => _selectedCategory = _selectedCategory == PaperCategory.competitive ? null : PaperCategory.competitive)),
                        const SizedBox(width: 8),
                        _CategoryChip(label: 'Professional', category: PaperCategory.professional, selected: _selectedCategory == PaperCategory.professional,
                            onTap: () => setState(() => _selectedCategory = _selectedCategory == PaperCategory.professional ? null : PaperCategory.professional)),
                      ],
                    ),
                  ),
                  if (_showFilters) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Text('Sort by:', style: GoogleFonts.inter(fontSize: 13, color: cs.onSurfaceVariant)),
                        const SizedBox(width: 10),
                        _SortChip(label: 'Most Downloaded', value: 'downloads', current: _sortBy, onTap: () => setState(() => _sortBy = 'downloads')),
                        const SizedBox(width: 8),
                        _SortChip(label: 'Most Recent', value: 'recent', current: _sortBy, onTap: () => setState(() => _sortBy = 'recent')),
                      ],
                    ),
                  ],
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Text(
                        hasQuery ? '${papers.length} result${papers.length == 1 ? '' : 's'}' : 'All Papers',
                        style: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.w700, color: cs.onSurface),
                      ),
                      const Spacer(),
                      if (!_showFilters)
                        GestureDetector(
                          onTap: () => setState(() => _showFilters = true),
                          child: Row(
                            children: [
                              Icon(Icons.swap_vert_rounded, size: 16, color: cs.primary),
                              const SizedBox(width: 4),
                              Text(_sortBy == 'downloads' ? 'Most Downloaded' : 'Most Recent', style: GoogleFonts.inter(fontSize: 13, color: cs.primary, fontWeight: FontWeight.w500)),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
          papers.isEmpty
              ? SliverToBoxAdapter(child: _EmptyState(hasQuery: hasQuery))
              : SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => Padding(
                      padding: EdgeInsets.fromLTRB(20, 0, 20, i == papers.length - 1 ? 24 : 10),
                      child: _PaperResultCard(paper: papers[i]),
                    ),
                    childCount: papers.length,
                  ),
                ),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final PaperCategory? category;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryChip({required this.label, this.category, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? cs.primary : cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label, style: GoogleFonts.inter(fontSize: 13, fontWeight: selected ? FontWeight.w600 : FontWeight.w400, color: selected ? Colors.white : cs.onSurfaceVariant)),
      ),
    );
  }
}

class _SortChip extends StatelessWidget {
  final String label;
  final String value;
  final String current;
  final VoidCallback onTap;

  const _SortChip({required this.label, required this.value, required this.current, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final selected = value == current;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? cs.primary.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: selected ? cs.primary : cs.outlineVariant.withOpacity(0.3)),
        ),
        child: Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: selected ? cs.primary : cs.onSurfaceVariant)),
      ),
    );
  }
}

class _PaperResultCard extends StatelessWidget {
  final ExamPaper paper;
  const _PaperResultCard({required this.paper});

  Color _categoryColor() => switch (paper.category) {
    PaperCategory.university => const Color(0xFF003F98),
    PaperCategory.highSchool => const Color(0xFF6B4226),
    PaperCategory.competitive => const Color(0xFF7B2D8B),
    PaperCategory.professional => const Color(0xFF1B6D24),
  };

  String _categoryLabel() => switch (paper.category) {
    PaperCategory.university => 'University',
    PaperCategory.highSchool => 'High School',
    PaperCategory.competitive => 'Competitive',
    PaperCategory.professional => 'Professional',
  };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = _categoryColor();

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PaperDetailPage(paperId: paper.id))),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppTheme.ambientShadow(),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 50,
              decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.picture_as_pdf_rounded, color: color, size: 20),
                  const SizedBox(height: 2),
                  Text('${paper.year}', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w600, color: color)),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(paper.title, style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w700, color: cs.onSurface), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  Text(paper.institution, style: GoogleFonts.inter(fontSize: 11, color: cs.onSurfaceVariant), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(5)),
                        child: Text(_categoryLabel(), style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.download_rounded, size: 12, color: cs.onSurfaceVariant),
                      const SizedBox(width: 3),
                      Text('${paper.downloads}', style: GoogleFonts.inter(fontSize: 11, color: cs.onSurfaceVariant)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(color: cs.secondaryContainer.withOpacity(0.25), borderRadius: BorderRadius.circular(5)),
                        child: Text('+${paper.points} pts', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: cs.secondary)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right_rounded, color: cs.outlineVariant, size: 18),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool hasQuery;
  const _EmptyState({required this.hasQuery});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 48),
      child: Column(
        children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(color: cs.surfaceContainerHigh, shape: BoxShape.circle),
            child: Icon(hasQuery ? Icons.search_off_rounded : Icons.folder_open_rounded, size: 36, color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          Text(hasQuery ? 'No papers matched your search' : 'No papers yet', style: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.w700, color: cs.onSurface)),
          const SizedBox(height: 8),
          Text(
            hasQuery ? 'Try different keywords or clear the filter to browse all papers.' : 'Be the first to upload a paper and earn points!',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 13, color: cs.onSurfaceVariant, height: 1.5),
          ),
        ],
      ),
    );
  }
}