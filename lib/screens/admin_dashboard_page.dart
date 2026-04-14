import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/app_state.dart';
import '../data/supabase_backend.dart';
import 'admin_users_page.dart';
import 'admin_institutions_page.dart';

// ─── Shell ────────────────────────────────────────────────────────────────────

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});
  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  int _tab = 0;

  static const _pages = [
    AdminPapersView(),
    AdminUsersPage(),
    AdminInstitutionsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: IndexedStack(index: _tab, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        backgroundColor: cs.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: cs.primary.withValues(alpha: 0.12),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: [
          NavigationDestination(
            icon: Icon(Icons.inbox_outlined, color: cs.onSurfaceVariant),
            selectedIcon: Icon(Icons.inbox_rounded, color: cs.primary),
            label: 'Reviews',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline_rounded, color: cs.onSurfaceVariant),
            selectedIcon: Icon(Icons.people_rounded, color: cs.primary),
            label: 'Users',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_outlined, color: cs.onSurfaceVariant),
            selectedIcon: Icon(Icons.account_balance_rounded, color: cs.primary),
            label: 'Institutions',
          ),
        ],
      ),
    );
  }
}

// ─── Papers View ──────────────────────────────────────────────────────────────

class AdminPapersView extends StatefulWidget {
  const AdminPapersView({super.key});
  @override
  State<AdminPapersView> createState() => _AdminPapersViewState();
}

class _AdminPapersViewState extends State<AdminPapersView> {
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _rows = const [];
  final Set<String> _busy = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  // ── data ──────────────────────────────────────────────────────────────────

  Future<void> _load() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final rows = await SupabaseBackend.instance.fetchPendingContributions();
      if (!mounted) return;
      setState(() { _rows = rows; _isLoading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  // ── actions ───────────────────────────────────────────────────────────────

  Future<void> _approve(Map<String, dynamic> row) async {
    final id = _rowId(row);
    if (id.isEmpty) return;
    setState(() => _busy.add(id));
    try {
      await SupabaseBackend.instance.approveContribution(paperId: id);
      if (!mounted) return;
      setState(() {
        _rows = _rows.where((r) => _rowId(r) != id).toList();
        _busy.remove(id);
      });
      await AppState.instance.refreshData();
      if (mounted) _toast('✅ Approved — uploader earned 50 pts!');
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy.remove(id));
      _toast('Approve failed: $e', isError: true);
    }
  }

  Future<void> _reject(Map<String, dynamic> row) async {
    final id = _rowId(row);
    if (id.isEmpty) return;
    final note = await _askRejectionNote();
    if (note == null) return;
    setState(() => _busy.add(id));
    try {
      await SupabaseBackend.instance.rejectContribution(paperId: id, rejectionNote: note);
      if (!mounted) return;
      setState(() {
        _rows = _rows.where((r) => _rowId(r) != id).toList();
        _busy.remove(id);
      });
      if (mounted) _toast('Paper rejected.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy.remove(id));
      _toast('Reject failed: $e', isError: true);
    }
  }

  Future<void> _editApprove(Map<String, dynamic> row) async {
    final id = _rowId(row);
    if (id.isEmpty) return;
    final titleCtrl = TextEditingController(text: _val(row, ['file_name', 'title']));
    final instCtrl  = TextEditingController(text: _val(row, ['institution']));
    final courseCtrl = TextEditingController(text: _val(row, ['course']));
    final yearCtrl  = TextEditingController(text: _val(row, ['year']));

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit & Approve', style: GoogleFonts.manrope(fontWeight: FontWeight.w800)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _field(titleCtrl,  'Paper title'),
              _field(instCtrl,   'Institution'),
              _field(courseCtrl, 'Course'),
              _field(yearCtrl,   'Year', numeric: true),
            ],
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          OutlinedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save & Approve'),
          ),
        ],
      ),
    );

    if (ok != true || !mounted) return;
    final changes = <String, dynamic>{
      if (titleCtrl.text.trim().isNotEmpty)  'file_name':   titleCtrl.text.trim(),
      if (instCtrl.text.trim().isNotEmpty)   'institution': instCtrl.text.trim(),
      if (courseCtrl.text.trim().isNotEmpty) 'course':      courseCtrl.text.trim(),
      if (yearCtrl.text.trim().isNotEmpty)   'year':        int.tryParse(yearCtrl.text.trim()),
    };
    if (changes.isNotEmpty) {
      try {
        await SupabaseBackend.instance.updateContributionDraft(paperId: id, changes: changes);
      } catch (e) {
        _toast('Edit failed: $e', isError: true);
        return;
      }
    }
    await _approve(row);
  }

  Future<void> _openLink(Map<String, dynamic> row) async {
    final url = _val(row, ['remote_url', 'file_url', 'url']);
    if (url.isEmpty) { _toast('No link attached to this paper.', isError: true); return; }
    final uri = Uri.tryParse(url);
    if (uri == null || !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      _toast('Could not open link.', isError: true);
    }
  }

  Future<String?> _askRejectionNote() {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Rejection reason', style: GoogleFonts.manrope(fontWeight: FontWeight.w800)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'e.g. Wrong year, duplicate, low quality…',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          OutlinedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton.tonal(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.errorContainer),
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: Text('Reject', style: TextStyle(color: Theme.of(ctx).colorScheme.onErrorContainer)),
          ),
        ],
      ),
    );
  }

  // ── helpers ───────────────────────────────────────────────────────────────

  String _rowId(Map<String, dynamic> r) =>
      (r['id'] ?? r['paper_id'] ?? r['uuid'] ?? '').toString().trim();

  String _val(Map<String, dynamic> r, List<String> keys) {
    for (final k in keys) {
      final v = r[k];
      if (v != null && v.toString().trim().isNotEmpty) return v.toString().trim();
    }
    return '';
  }

  Widget _field(TextEditingController c, String label, {bool numeric = false}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: c,
          keyboardType: numeric ? TextInputType.number : TextInputType.text,
          decoration: InputDecoration(
            labelText: label,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
          ),
        ),
      );

  void _toast(String msg, {bool isError = false}) {
    if (!mounted) return;
    final cs = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
      backgroundColor: isError ? cs.errorContainer : cs.primaryContainer,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  // ── build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        surfaceTintColor: Colors.transparent,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: cs.primaryContainer,
              child: Icon(Icons.admin_panel_settings_rounded, size: 18, color: cs.primary),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Admin Reviews',
                    style: GoogleFonts.manrope(fontSize: 17, fontWeight: FontWeight.w800)),
                Text(
                  _isLoading ? 'Loading…' : '${_rows.length} pending',
                  style: GoogleFonts.inter(fontSize: 11, color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _isLoading ? null : _load,
            icon: _isLoading
                ? SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: cs.primary))
                : const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _buildBody(cs),
    );
  }

  Widget _buildBody(ColorScheme cs) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off_rounded, size: 56, color: cs.error.withValues(alpha: 0.4)),
              const SizedBox(height: 16),
              Text('Could not load papers',
                  style: GoogleFonts.manrope(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(_error!, textAlign: TextAlign.center,
                  style: GoogleFonts.inter(fontSize: 13, color: cs.onSurfaceVariant)),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    }

    if (_rows.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88, height: 88,
              decoration: BoxDecoration(
                color: cs.primaryContainer.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.check_circle_outline_rounded, size: 44, color: cs.primary),
            ),
            const SizedBox(height: 20),
            Text('All clear!',
                style: GoogleFonts.manrope(fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text('No papers awaiting review.',
                style: GoogleFonts.inter(fontSize: 14, color: cs.onSurfaceVariant)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: CustomScrollView(
        slivers: [
          // ── Stats strip ────────────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            sliver: SliverToBoxAdapter(
              child: Row(
                children: [
                  _StatChip(
                    icon: Icons.hourglass_top_rounded,
                    label: 'Pending',
                    value: '${_rows.length}',
                    color: Colors.orange,
                    cs: cs,
                  ),
                  const SizedBox(width: 10),
                  _StatChip(
                    icon: Icons.verified_rounded,
                    label: 'Status',
                    value: 'Live',
                    color: Colors.green,
                    cs: cs,
                  ),
                ],
              ),
            ),
          ),

          // ── Cards ──────────────────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            sliver: SliverList.separated(
              itemCount: _rows.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (ctx, i) => _PaperCard(
                row: _rows[i],
                isBusy: _busy.contains(_rowId(_rows[i])),
                onApprove: () => _approve(_rows[i]),
                onReject:  () => _reject(_rows[i]),
                onEdit:    () => _editApprove(_rows[i]),
                onView:    () => _openLink(_rows[i]),
                valOf: _val,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Paper Card ───────────────────────────────────────────────────────────────

class _PaperCard extends StatelessWidget {
  const _PaperCard({
    required this.row,
    required this.isBusy,
    required this.onApprove,
    required this.onReject,
    required this.onEdit,
    required this.onView,
    required this.valOf,
  });

  final Map<String, dynamic> row;
  final bool isBusy;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onEdit;
  final VoidCallback onView;
  final String Function(Map<String, dynamic>, List<String>) valOf;

  @override
  Widget build(BuildContext context) {
    final cs   = Theme.of(context).colorScheme;
    final title   = valOf(row, ['file_name', 'title', 'name']).isNotEmpty
        ? valOf(row, ['file_name', 'title', 'name'])
        : 'Untitled paper';
    final inst    = valOf(row, ['institution', 'school']);
    final course  = valOf(row, ['course', 'subject']);
    final year    = valOf(row, ['year']);
    final uploader = valOf(row, ['uploader_name', 'uploader_id', 'user_id']);
    final level   = valOf(row, ['level']);
    final size    = valOf(row, ['file_size_kb']);
    final hasLink = valOf(row, ['remote_url', 'file_url', 'url']).isNotEmpty;

    return AnimatedOpacity(
      opacity: isBusy ? 0.5 : 1.0,
      duration: const Duration(milliseconds: 200),
      child: Container(
        decoration: BoxDecoration(
          color: cs.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
              color: cs.shadow.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── Top strip: level badge + pending badge ──────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Row(
                children: [
                  if (level.isNotEmpty) ...[
                    _LevelBadge(level: level),
                    const SizedBox(width: 8),
                  ],
                  const Spacer(),
                  _Badge(
                    label: isBusy ? 'Processing…' : 'Pending',
                    color: isBusy ? Colors.blue : Colors.orange,
                  ),
                ],
              ),
            ),

            // ── Title + meta ────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.manrope(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    children: [
                      if (inst.isNotEmpty)
                        _MetaItem(icon: Icons.school_outlined, text: inst),
                      if (course.isNotEmpty)
                        _MetaItem(icon: Icons.book_outlined, text: course),
                      if (year.isNotEmpty)
                        _MetaItem(icon: Icons.calendar_today_outlined, text: year),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.person_outline_rounded, size: 13, color: cs.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          uploader.isNotEmpty ? uploader : 'Unknown uploader',
                          style: GoogleFonts.inter(fontSize: 12, color: cs.onSurfaceVariant),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (size.isNotEmpty) ...[
                        Icon(Icons.insert_drive_file_outlined, size: 12, color: cs.onSurfaceVariant),
                        const SizedBox(width: 3),
                        Text(
                          '$size KB',
                          style: GoogleFonts.inter(fontSize: 11, color: cs.onSurfaceVariant),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),
            Divider(height: 1, indent: 16, endIndent: 16, color: cs.outlineVariant.withValues(alpha: 0.2)),

            // ── Actions ─────────────────────────────────────────────────
            if (isBusy)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Center(child: SizedBox(width: 24, height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2))),
              )
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
                child: Column(
                  children: [
                    // Row 1: view + edit
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: hasLink ? onView : null,
                            icon: const Icon(Icons.open_in_new_rounded, size: 15),
                            label: const Text('View'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 9),
                              textStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: onEdit,
                            icon: const Icon(Icons.edit_outlined, size: 15),
                            label: const Text('Edit & Approve'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 9),
                              textStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Row 2: reject + approve
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: onReject,
                            icon: Icon(Icons.cancel_outlined, size: 15, color: cs.error),
                            label: Text('Reject', style: TextStyle(color: cs.error)),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 9),
                              side: BorderSide(color: cs.error.withValues(alpha: 0.4)),
                              textStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: onApprove,
                            icon: const Icon(Icons.check_circle_outline_rounded, size: 15),
                            label: const Text('Approve'),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 9),
                              textStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Supporting widgets ───────────────────────────────────────────────────────

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.cs,
  });
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: color.withValues(alpha: 0.8))),
                Text(value,  style: GoogleFonts.manrope(fontSize: 18, fontWeight: FontWeight.w800, color: color, height: 1.1)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LevelBadge extends StatelessWidget {
  const _LevelBadge({required this.level});
  final String level;

  static Color _color(String l) {
    switch (l.toLowerCase()) {
      case 'university':   return const Color(0xFF003F98);
      case 'high_school':  return const Color(0xFF6B4226);
      case 'competitive':  return const Color(0xFF7B2D8B);
      case 'professional': return const Color(0xFF1B6D24);
      default:             return Colors.blueGrey;
    }
  }
  static String _label(String l) => l.replaceAll('_', ' ').toUpperCase();

  @override
  Widget build(BuildContext context) {
    final c = _color(level);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: c.withValues(alpha: 0.25)),
      ),
      child: Text(_label(level), style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: c)),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(label, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

class _MetaItem extends StatelessWidget {
  const _MetaItem({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: cs.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(text, style: GoogleFonts.inter(fontSize: 12, color: cs.onSurfaceVariant)),
      ],
    );
  }
}
