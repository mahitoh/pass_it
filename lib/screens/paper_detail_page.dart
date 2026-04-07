import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/app_state.dart';
import 'pdf_viewer_page.dart';

class PaperDetailPage extends StatelessWidget {
  const PaperDetailPage({super.key, required this.paperId});
  final String paperId;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final appState = AppStateScope.of(context);
    final paper = appState.paperById(paperId);

    if (paper == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Paper not found')),
        body: const Center(child: Text('This paper is no longer available.')),
      );
    }

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        surfaceTintColor: Colors.transparent,
        title: Text(
          paper.title,
          style: GoogleFonts.manrope(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: cs.onSurface,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            onPressed: () => appState.toggleBookmark(paper.id),
            icon: Icon(
              paper.isBookmarked
                  ? Icons.bookmark_rounded
                  : Icons.bookmark_border_rounded,
              color: paper.isBookmarked ? cs.primary : cs.onSurface,
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _HeroCard(paper: paper),
          const SizedBox(height: 24),

          // Description
          Text(
            'About this paper',
            style: GoogleFonts.manrope(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            paper.description,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: cs.onSurfaceVariant,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 16),

          // Tags
          if (paper.tags.isNotEmpty) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: paper.tags.map((tag) => _Tag(label: tag)).toList(),
            ),
            const SizedBox(height: 28),
          ],

          // ── Primary action: Read in app ──────────────────────────────────
          _ReadButton(paper: paper, appState: appState),
          const SizedBox(height: 12),

          // ── Secondary action: Download / open in browser ─────────────────
          _DownloadButton(paper: paper, appState: appState),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ─── Read in-app button ───────────────────────────────────────────────────────

class _ReadButton extends StatelessWidget {
  final ExamPaper paper;
  final AppState appState;
  const _ReadButton({required this.paper, required this.appState});

  Future<void> _onTap(BuildContext context) async {
    final url = paper.remoteUrl ?? '';
    if (url.trim().isEmpty) {
      _snack(context, 'This paper does not have a file yet.');
      return;
    }

    await appState.recordView(paper.id);
    await appState.recordDownload(paper.id);
    if (!context.mounted) return;

    final totalDownloads =
        appState.paperById(paper.id)?.downloads ?? (paper.downloads + 1);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.download_done_rounded,
              color: Colors.white,
              size: 16,
            ),
            const SizedBox(width: 8),
            Text('Download counted - $totalDownloads total'),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );

    // If the file is an image type, just open in browser — no point using PDF viewer
    final isImage =
        paper.storagePath != null &&
        RegExp(
          r'\.(jpe?g|png|webp)$',
          caseSensitive: false,
        ).hasMatch(paper.storagePath!);

    if (isImage) {
      await _launchBrowser(context, url);
      return;
    }

    // Navigate to the PDF viewer — it handles timeouts and errors internally
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PdfViewerPage(paper: paper)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton.icon(
        onPressed: () => _onTap(context),
        icon: const Icon(
          Icons.chrome_reader_mode_rounded,
          size: 20,
          color: Colors.white,
        ),
        label: Text(
          'Read Document',
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: cs.primary,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}

// ─── Download / browser button ────────────────────────────────────────────────

class _DownloadButton extends StatelessWidget {
  final ExamPaper paper;
  final AppState appState;
  const _DownloadButton({required this.paper, required this.appState});

  Future<void> _onTap(BuildContext context) async {
    final url = paper.remoteUrl ?? '';
    if (url.trim().isEmpty) {
      _snack(context, 'No download link available.');
      return;
    }

    await appState.recordDownload(paper.id);
    if (!context.mounted) return;

    await _launchBrowser(context, url);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton.icon(
        onPressed: () => _onTap(context),
        icon: Icon(Icons.download_outlined, size: 18, color: cs.primary),
        label: Text(
          'Download / Open in browser',
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: cs.primary,
          ),
        ),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.4)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}

// ─── Shared helpers ───────────────────────────────────────────────────────────

Future<void> _launchBrowser(BuildContext context, String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) {
    _snack(context, 'Invalid URL.');
    return;
  }
  final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) {
    _snack(context, 'Could not open the link on this device.');
  }
}

void _snack(BuildContext context, String msg) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
  );
}

// ─── Hero card ────────────────────────────────────────────────────────────────

class _HeroCard extends StatelessWidget {
  final ExamPaper paper;
  const _HeroCard({required this.paper});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.picture_as_pdf_rounded,
                  color: cs.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      paper.institution,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      paper.title,
                      style: GoogleFonts.manrope(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: cs.onSurface,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            '${paper.course}  ·  ${paper.year}',
            style: GoogleFonts.inter(fontSize: 13, color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _InfoPill(
                label: '${paper.downloads} downloads',
                icon: Icons.download_rounded,
                color: cs.primary,
              ),
              _InfoPill(
                label: '${paper.views} views',
                icon: Icons.visibility_rounded,
                color: cs.secondary,
              ),
              _InfoPill(
                label: paper.category.name,
                icon: Icons.school_rounded,
                color: const Color(0xFF7B2D8B),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  const _InfoPill({
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;
  const _Tag({required this.label});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: cs.primary,
        ),
      ),
    );
  }
}
