import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/app_state.dart';
import 'pdf_cache_manager.dart';

class PdfViewerPage extends StatefulWidget {
  const PdfViewerPage({super.key, required this.paper});
  final ExamPaper paper;

  @override
  State<PdfViewerPage> createState() => _PdfViewerPageState();
}

class _PdfViewerPageState extends State<PdfViewerPage> {
  final GlobalKey<SfPdfViewerState> _viewerKey = GlobalKey();

  _Phase _phase = _Phase.checkingCache;

  PdfDownloadProgress? _progress;
  String _speedLabel = '';
  String _etaLabel = '';
  String _errorMsg = '';
  File? _localFile;

  int _currentPage = 0;
  int _totalPages = 0;

  int _lastBytes = 0;
  DateTime _lastTick = DateTime.now();
  Timer? _speedTimer;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _speedTimer?.cancel();
    super.dispose();
  }

  Future<void> _start() async {
    final url = widget.paper.remoteUrl ?? '';
    if (url.trim().isEmpty) {
      setState(() => _phase = _Phase.noFile);
      return;
    }

    setState(() => _phase = _Phase.checkingCache);
    final cached = await PdfCacheManager.instance.getCached(widget.paper.id);
    if (cached != null && mounted) {
      setState(() {
        _localFile = cached;
        _phase = _Phase.rendering;
      });
      return;
    }

    _startSpeedTimer();
    if (mounted) setState(() => _phase = _Phase.downloading);

    try {
      final file = await PdfCacheManager.instance.download(
        paperId: widget.paper.id,
        url: url,
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
      );
      _stopSpeedTimer();
      if (mounted)
        setState(() {
          _localFile = file;
          _phase = _Phase.rendering;
        });
    } on PdfDownloadCancelledException {
      _stopSpeedTimer();
      if (mounted) setState(() => _phase = _Phase.cancelled);
    } catch (e) {
      _stopSpeedTimer();
      if (mounted)
        setState(() {
          _errorMsg = e.toString();
          _phase = _Phase.failed;
        });
    }
  }

  void _startSpeedTimer() {
    _lastBytes = 0;
    _lastTick = DateTime.now();
    _speedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final p = _progress;
      if (p == null || !mounted) return;
      final now = DateTime.now();
      final elapsed = now.difference(_lastTick).inMilliseconds;
      if (elapsed == 0) return;
      final bps = ((p.downloaded - _lastBytes) / elapsed * 1000).round();
      _lastBytes = p.downloaded;
      _lastTick = now;
      final speed = bps <= 0
          ? ''
          : bps < 1048576
          ? '${(bps / 1024).toStringAsFixed(0)} KB/s'
          : '${(bps / 1048576).toStringAsFixed(1)} MB/s';
      final eta = (bps > 0 && p.total > 0)
          ? () {
              final s = ((p.total - p.downloaded) / bps).ceil();
              return s < 60 ? '${s}s left' : '${(s / 60).ceil()}m left';
            }()
          : '';
      if (mounted)
        setState(() {
          _speedLabel = speed;
          _etaLabel = eta;
        });
    });
  }

  void _stopSpeedTimer() {
    _speedTimer?.cancel();
    _speedTimer = null;
  }

  void _cancelDownload() {
    PdfCacheManager.instance.cancel(widget.paper.id);
    if (mounted) setState(() => _phase = _Phase.cancelled);
  }

  Future<void> _retry() async {
    setState(() {
      _speedLabel = '';
      _etaLabel = '';
      _errorMsg = '';
      _progress = null;
    });
    await _start();
  }

  Future<void> _openInBrowser() async {
    final url = widget.paper.remoteUrl ?? '';
    if (url.isEmpty) {
      _snack('No URL available.');
      return;
    }
    final uri = Uri.tryParse(url);
    if (uri == null) {
      _snack('Invalid URL.');
      return;
    }
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) _snack('Could not open browser.');
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final appState = AppStateScope.of(context);
    final currentPaper = appState.paperById(widget.paper.id) ?? widget.paper;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        surfaceTintColor: Colors.transparent,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.paper.title,
              style: GoogleFonts.manrope(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (_phase == _Phase.rendering && _totalPages > 0)
              Text(
                'Page ${_currentPage + 1} of $_totalPages',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: cs.onSurfaceVariant,
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _openInBrowser,
            icon: Icon(
              Icons.open_in_browser_rounded,
              color: cs.onSurface,
              size: 22,
            ),
            tooltip: 'Open in browser',
          ),
          if (_phase == _Phase.rendering) ...[
            IconButton(
              onPressed: () => appState.toggleBookmark(widget.paper.id),
              icon: Icon(
                currentPaper.isBookmarked
                    ? Icons.bookmark_rounded
                    : Icons.bookmark_border_rounded,
                color: cs.onSurface,
                size: 22,
              ),
              tooltip: currentPaper.isBookmarked
                  ? 'Remove bookmark'
                  : 'Save paper',
            ),
            IconButton(
              onPressed: () => _viewerKey.currentState?.openBookmarkView(),
              icon: Icon(Icons.list_alt_rounded, color: cs.onSurface, size: 22),
              tooltip: 'Document outline',
            ),
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert_rounded, color: cs.onSurface),
              onSelected: (v) async {
                if (v == 'reload') {
                  await PdfCacheManager.instance.evict(widget.paper.id);
                  await _retry();
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'reload', child: Text('Re-download file')),
              ],
            ),
          ],
          const SizedBox(width: 4),
        ],
      ),
      body: switch (_phase) {
        _Phase.checkingCache => _CacheCheckWidget(),
        _Phase.downloading => _DownloadWidget(
          progress: _progress,
          speedLabel: _speedLabel,
          etaLabel: _etaLabel,
          paperTitle: widget.paper.title,
          onCancel: _cancelDownload,
          onBrowser: _openInBrowser,
        ),
        _Phase.rendering =>
          _localFile != null
              ? SfPdfViewer.file(
                  _localFile!,
                  key: _viewerKey,
                  canShowScrollHead: true,
                  canShowScrollStatus: true,
                  enableDoubleTapZooming: true,
                  onDocumentLoaded: (d) {
                    if (mounted)
                      setState(() => _totalPages = d.document.pages.count);
                  },
                  onPageChanged: (d) {
                    if (mounted)
                      setState(() => _currentPage = d.newPageNumber - 1);
                  },
                  onDocumentLoadFailed: (_) {
                    if (mounted)
                      setState(() {
                        _errorMsg = 'Could not render cached file.';
                        _phase = _Phase.failed;
                      });
                  },
                )
              : _ErrorWidget(
                  errorMsg: 'Local file missing.',
                  onRetry: _retry,
                  onBrowser: _openInBrowser,
                ),
        _Phase.failed => _ErrorWidget(
          errorMsg: _errorMsg,
          onRetry: _retry,
          onBrowser: _openInBrowser,
        ),
        _Phase.cancelled => _CancelledWidget(onRetry: _retry),
        _Phase.noFile => _NoFileWidget(onBack: () => Navigator.pop(context)),
      },
    );
  }
}

enum _Phase { checkingCache, downloading, rendering, failed, cancelled, noFile }

// ─── Cache check ──────────────────────────────────────────────────────────────

class _CacheCheckWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 36,
            height: 36,
            child: CircularProgressIndicator(
              color: cs.primary,
              strokeWidth: 2.5,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Checking saved files…',
            style: GoogleFonts.inter(fontSize: 14, color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

// ─── Download progress ────────────────────────────────────────────────────────

class _DownloadWidget extends StatelessWidget {
  final PdfDownloadProgress? progress;
  final String speedLabel;
  final String etaLabel;
  final String paperTitle;
  final VoidCallback onCancel;
  final VoidCallback onBrowser;

  const _DownloadWidget({
    required this.progress,
    required this.speedLabel,
    required this.etaLabel,
    required this.paperTitle,
    required this.onCancel,
    required this.onBrowser,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final p = progress;
    final frac = p?.fraction;
    final pct = frac != null ? '${(frac * 100).toStringAsFixed(0)}%' : null;
    final phase = p?.phase ?? DownloadPhase.connecting;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Circular progress with percentage inside
            SizedBox(
              width: 88,
              height: 88,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 88,
                    height: 88,
                    child: CircularProgressIndicator(
                      value: frac,
                      color: cs.primary,
                      backgroundColor: cs.surfaceContainerHigh,
                      strokeWidth: 5,
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (pct != null)
                        Text(
                          pct,
                          style: GoogleFonts.manrope(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: cs.primary,
                          ),
                        )
                      else
                        Icon(
                          Icons.picture_as_pdf_rounded,
                          color: cs.primary,
                          size: 34,
                        ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            Text(
              phase == DownloadPhase.connecting
                  ? 'Connecting…'
                  : 'Downloading…',
              style: GoogleFonts.manrope(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              paperTitle,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: cs.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),

            const SizedBox(height: 20),

            // Linear progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: frac,
                minHeight: 10,
                backgroundColor: cs.surfaceContainerHigh,
                valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
              ),
            ),
            const SizedBox(height: 8),

            // Bytes / speed / ETA row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  p == null
                      ? ''
                      : p.total > 0
                      ? '${p.downloadedLabel} / ${p.totalLabel}'
                      : p.downloadedLabel,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: cs.onSurfaceVariant,
                  ),
                ),
                Row(
                  children: [
                    if (speedLabel.isNotEmpty) ...[
                      Icon(
                        Icons.speed_rounded,
                        size: 13,
                        color: cs.onSurfaceVariant,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        speedLabel,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                    if (etaLabel.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Text(
                        '· $etaLabel',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Info tip
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 14,
                    color: cs.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Will open automatically when done. '
                      'Saved to your device — next time is instant.',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: cs.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Cancel
            SizedBox(
              width: double.infinity,
              height: 46,
              child: OutlinedButton.icon(
                onPressed: onCancel,
                icon: const Icon(Icons.close_rounded, size: 18),
                label: Text('Cancel', style: GoogleFonts.inter(fontSize: 14)),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: cs.outlineVariant.withOpacity(0.5)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Browser fallback
            SizedBox(
              width: double.infinity,
              height: 46,
              child: TextButton.icon(
                onPressed: onBrowser,
                icon: Icon(
                  Icons.open_in_browser_rounded,
                  size: 18,
                  color: cs.primary,
                ),
                label: Text(
                  'Open in browser instead',
                  style: GoogleFonts.inter(fontSize: 14, color: cs.primary),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Error ────────────────────────────────────────────────────────────────────

class _ErrorWidget extends StatelessWidget {
  final String errorMsg;
  final VoidCallback onRetry;
  final VoidCallback onBrowser;
  const _ErrorWidget({
    required this.errorMsg,
    required this.onRetry,
    required this.onBrowser,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: cs.error.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.picture_as_pdf_outlined,
                size: 40,
                color: cs.error,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Download failed',
              style: GoogleFonts.manrope(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
            ),
            if (errorMsg.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  errorMsg,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: cs.onSurfaceVariant,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 20),
                label: Text(
                  'Retry download',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: cs.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: OutlinedButton.icon(
                onPressed: onBrowser,
                icon: const Icon(Icons.open_in_browser_rounded, size: 18),
                label: Text(
                  'Open in browser',
                  style: GoogleFonts.inter(fontSize: 14),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: cs.outlineVariant.withOpacity(0.5)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Cancelled ────────────────────────────────────────────────────────────────

class _CancelledWidget extends StatelessWidget {
  final VoidCallback onRetry;
  const _CancelledWidget({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cancel_outlined, size: 56, color: cs.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              'Download cancelled',
              style: GoogleFonts.manrope(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(
                'Download again',
                style: GoogleFonts.inter(fontSize: 14),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── No file ──────────────────────────────────────────────────────────────────

class _NoFileWidget extends StatelessWidget {
  final VoidCallback onBack;
  const _NoFileWidget({required this.onBack});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: cs.surfaceContainerHigh,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.picture_as_pdf_outlined,
                size: 40,
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No file attached',
              style: GoogleFonts.manrope(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'This paper has no file yet. It may still be under admin review.',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: cs.onSurfaceVariant,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            OutlinedButton.icon(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_rounded, size: 18),
              label: const Text('Go back'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
