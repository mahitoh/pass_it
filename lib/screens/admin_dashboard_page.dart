import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/app_state.dart';
import '../data/supabase_backend.dart';
import 'admin_users_page.dart';
import 'admin_institutions_page.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: const [
          AdminPapersView(),
          AdminUsersPage(),
          AdminInstitutionsPage(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        selectedItemColor: cs.primary,
        unselectedItemColor: cs.onSurfaceVariant,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.description_outlined),
            activeIcon: Icon(Icons.description),
            label: 'Papers',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people_outline),
            activeIcon: Icon(Icons.people),
            label: 'Users',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.school_outlined),
            activeIcon: Icon(Icons.school),
            label: 'Institutes',
          ),
        ],
      ),
    );
  }
}

class AdminPapersView extends StatefulWidget {
  const AdminPapersView({super.key});

  @override
  State<AdminPapersView> createState() => _AdminPapersViewState();
}

class _AdminPapersViewState extends State<AdminPapersView> {
  bool _isLoading = true;
  String? _error;

  // All pending rows fetched from DB
  List<Map<String, dynamic>> _pendingRows = const [];
  // Track which paperIds are being actioned so the button shows a spinner
  final Set<String> _actioningIds = {};

  @override
  void initState() {
    super.initState();
    _loadPending();
  }

  // ── Data loading ─────────────────────────────────────────────────────────

  Future<void> _loadPending() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      // get_pending_papers() RPC returns uploader_name in one query
      final rows = await SupabaseBackend.instance.fetchPendingContributions();
      if (!mounted) return;
      setState(() {
        _pendingRows = rows;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<void> _approve(Map<String, dynamic> row) async {
    final paperId = _id(row);
    if (paperId.isEmpty) {
      _showError('This paper has no ID — cannot approve.');
      return;
    }

    setState(() => _actioningIds.add(paperId));
    try {
      await SupabaseBackend.instance.approveContribution(paperId: paperId);

      // Remove from local list immediately so the UI updates without
      // waiting for the full reload.
      if (mounted) {
        setState(() {
          _pendingRows = _pendingRows.where((r) => _id(r) != paperId).toList();
          _actioningIds.remove(paperId);
        });
      }

      // Refresh app state so the public feed picks up the newly approved paper.
      await AppState.instance.refreshData();

      if (mounted) {
        _showSuccess('Paper approved — uploader earned 50 pts!');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _actioningIds.remove(paperId));
      _showError('Approve failed: $e');
    }
  }

  Future<void> _reject(Map<String, dynamic> row) async {
    final paperId = _id(row);
    if (paperId.isEmpty) {
      _showError('This paper has no ID — cannot reject.');
      return;
    }

    // Prompt for an optional rejection reason
    final note = await _promptRejectionNote();
    if (note == null) return; // user cancelled

    setState(() => _actioningIds.add(paperId));
    try {
      await SupabaseBackend.instance.rejectContribution(
        paperId: paperId,
        rejectionNote: note,
      );

      if (mounted) {
        setState(() {
          _pendingRows = _pendingRows.where((r) => _id(r) != paperId).toList();
          _actioningIds.remove(paperId);
        });
      }

      if (mounted) _showSuccess('Paper rejected.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _actioningIds.remove(paperId));
      _showError('Reject failed: $e');
    }
  }

  Future<void> _editAndApprove(Map<String, dynamic> row) async {
    final paperId = _id(row);
    if (paperId.isEmpty) return;

    final fileNameCtrl = TextEditingController(text: _val(row, ['file_name']));
    final institutionCtrl = TextEditingController(
      text: _val(row, ['institution']),
    );
    final courseCtrl = TextEditingController(text: _val(row, ['course']));
    final yearCtrl = TextEditingController(text: _val(row, ['year']));

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Edit metadata',
          style: GoogleFonts.manrope(fontWeight: FontWeight.w700),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _editField(fileNameCtrl, 'File / Paper name'),
              _editField(institutionCtrl, 'Institution'),
              _editField(courseCtrl, 'Course'),
              _editField(yearCtrl, 'Year', numeric: true),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save & Approve'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final year = int.tryParse(yearCtrl.text.trim());
    final changes = <String, dynamic>{
      if (fileNameCtrl.text.trim().isNotEmpty)
        'file_name': fileNameCtrl.text.trim(),
      if (institutionCtrl.text.trim().isNotEmpty)
        'institution': institutionCtrl.text.trim(),
      if (courseCtrl.text.trim().isNotEmpty) 'course': courseCtrl.text.trim(),
      'year': ?year,
    };

    if (changes.isNotEmpty) {
      try {
        await SupabaseBackend.instance.updateContributionDraft(
          paperId: paperId,
          changes: changes,
        );
      } catch (e) {
        _showError('Metadata edit failed: $e');
        return;
      }
    }

    await _approve(row);
  }

  Future<void> _openLink(Map<String, dynamic> row) async {
    final url = (_val(row, ['remote_url', 'file_url', 'url']));
    if (url.isEmpty) {
      _showError('No file link for this paper.');
      return;
    }
    final uri = Uri.tryParse(url);
    if (uri == null) {
      _showError('Invalid URL.');
      return;
    }
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) _showError('Could not open link.');
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _id(Map<String, dynamic> row) =>
      (row['id'] ?? row['paper_id'] ?? row['uuid'] ?? '').toString().trim();

  String _val(Map<String, dynamic> row, List<String> keys) {
    for (final k in keys) {
      final v = row[k];
      if (v != null && v.toString().trim().isNotEmpty) return v.toString();
    }
    return '';
  }

  void _showSuccess(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Theme.of(context).colorScheme.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<String?> _promptRejectionNote() async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Rejection reason',
          style: GoogleFonts.manrope(fontWeight: FontWeight.w700),
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText:
                'Optional — e.g. "Wrong year, please re-upload with correct metadata."',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  Widget _editField(
    TextEditingController ctrl,
    String label, {
    bool numeric = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: ctrl,
        keyboardType: numeric ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        surfaceTintColor: Colors.transparent,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Admin Dashboard',
              style: GoogleFonts.manrope(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
            ),
            Text(
              '${_pendingRows.length} paper${_pendingRows.length == 1 ? '' : 's'} awaiting review',
              style: GoogleFonts.inter(
                fontSize: 11,
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _loadPending,
            icon: _isLoading
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: cs.primary,
                    ),
                  )
                : const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _buildBody(cs),
    );
  }

  Widget _buildBody(ColorScheme cs) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded, size: 48, color: cs.error),
              const SizedBox(height: 16),
              Text(
                'Could not load pending papers',
                style: GoogleFonts.manrope(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _loadPending,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_pendingRows.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle_rounded,
              size: 56,
              color: cs.primary.withOpacity(0.6),
            ),
            const SizedBox(height: 16),
            Text(
              'All caught up!',
              style: GoogleFonts.manrope(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'No papers awaiting review.',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadPending,
      color: cs.primary,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _pendingRows.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (ctx, i) => _PaperCard(
          row: _pendingRows[i],
          isActioning: _actioningIds.contains(_id(_pendingRows[i])),
          onApprove: () => _approve(_pendingRows[i]),
          onReject: () => _reject(_pendingRows[i]),
          onEdit: () => _editAndApprove(_pendingRows[i]),
          onView: () => _openLink(_pendingRows[i]),
          idOf: _id,
          valOf: _val,
        ),
      ),
    );
  }
}

// ─── Paper card widget ────────────────────────────────────────────────────────

class _PaperCard extends StatelessWidget {
  final Map<String, dynamic> row;
  final bool isActioning;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onEdit;
  final VoidCallback onView;
  final String Function(Map<String, dynamic>) idOf;
  final String Function(Map<String, dynamic>, List<String>) valOf;

  const _PaperCard({
    required this.row,
    required this.isActioning,
    required this.onApprove,
    required this.onReject,
    required this.onEdit,
    required this.onView,
    required this.idOf,
    required this.valOf,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final paperId = idOf(row);

    final title = valOf(row, ['file_name', 'title', 'name']).isNotEmpty
        ? valOf(row, ['file_name', 'title', 'name'])
        : 'Untitled paper';
    final institution = valOf(row, ['institution', 'school']).isNotEmpty
        ? valOf(row, ['institution', 'school'])
        : 'Unknown institution';
    final course = valOf(row, ['course', 'subject', 'level']).isNotEmpty
        ? valOf(row, ['course', 'subject', 'level'])
        : 'Unknown course';
    final year = valOf(row, ['year']);
    final level = valOf(row, ['level']);

    // Uploader name comes from the get_pending_papers() RPC join
    final uploaderName = valOf(row, [
      'uploader_name',
      'uploader_id',
      'user_id',
    ]);
    final fileSize = valOf(row, ['file_size_kb']);
    final fileType = valOf(row, ['file_type']);

    final hasLink = valOf(row, ['remote_url', 'file_url', 'url']).isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ─────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                // Level badge
                if (level.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: _levelColor(level).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _levelLabel(level),
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _levelColor(level),
                      ),
                    ),
                  ),
                const Spacer(),
                // Pending badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFB300).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Pending',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFFB07800),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Content ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.manrope(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    institution,
                    course,
                    if (year.isNotEmpty) year,
                  ].where((s) => s.isNotEmpty).join(' · '),
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: cs.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      Icons.person_outline_rounded,
                      size: 13,
                      color: cs.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        uploaderName.isNotEmpty
                            ? uploaderName
                            : 'Unknown uploader',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: cs.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (fileSize.isNotEmpty) ...[
                      Icon(
                        Icons.insert_drive_file_outlined,
                        size: 12,
                        color: cs.onSurfaceVariant,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '$fileSize KB',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (fileType.isNotEmpty)
                      Text(
                        fileType.toUpperCase(),
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: cs.primary.withOpacity(0.7),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),
          Divider(height: 1, color: cs.outlineVariant.withOpacity(0.2)),

          // ── Actions ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: isActioning
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: cs.primary,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Processing…',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : Column(
                    children: [
                      // View + Edit row
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: hasLink ? onView : null,
                              icon: const Icon(
                                Icons.visibility_outlined,
                                size: 16,
                              ),
                              label: const Text('View file'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                                textStyle: GoogleFonts.inter(fontSize: 13),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: onEdit,
                              icon: const Icon(Icons.edit_outlined, size: 16),
                              label: const Text('Edit & approve'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                                textStyle: GoogleFonts.inter(fontSize: 13),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Reject + Approve row
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: paperId.isEmpty ? null : onReject,
                              icon: Icon(
                                Icons.close_rounded,
                                size: 16,
                                color: cs.error,
                              ),
                              label: Text(
                                'Reject',
                                style: TextStyle(color: cs.error),
                              ),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                                side: BorderSide(
                                  color: cs.error.withOpacity(0.4),
                                ),
                                textStyle: GoogleFonts.inter(fontSize: 13),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: paperId.isEmpty ? null : onApprove,
                              icon: const Icon(Icons.check_rounded, size: 16),
                              label: const Text('Approve'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                                backgroundColor: cs.primary,
                                foregroundColor: Colors.white,
                                textStyle: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
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
    );
  }

  Color _levelColor(String level) {
    switch (level.toLowerCase()) {
      case 'university':
        return const Color(0xFF003F98);
      case 'high_school':
        return const Color(0xFF6B4226);
      case 'competitive':
        return const Color(0xFF7B2D8B);
      case 'professional':
        return const Color(0xFF1B6D24);
      default:
        return const Color(0xFF434653);
    }
  }

  String _levelLabel(String level) {
    switch (level.toLowerCase()) {
      case 'university':
        return 'University';
      case 'high_school':
        return 'High School';
      case 'competitive':
        return 'Competitive';
      case 'professional':
        return 'Professional';
      default:
        return level;
    }
  }
}
