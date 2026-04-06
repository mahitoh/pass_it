import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Manages progressive PDF downloads with disk caching.
///
/// Files are cached by paper ID so subsequent opens skip the download entirely.
/// Cache lives in the app's temporary directory and is cleaned up by the OS
/// when storage is low.
class PdfCacheManager {
  PdfCacheManager._();
  static final PdfCacheManager instance = PdfCacheManager._();

  /// Currently active download controllers, keyed by paper ID.
  /// Allows cancellation from the UI.
  final Map<String, _DownloadController> _active = {};

  // ── Cache directory ────────────────────────────────────────────────────────

  Future<Directory> _cacheDir() async {
    final tmp = await getTemporaryDirectory();
    final dir = Directory('${tmp.path}/pdf_cache');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<File> _cacheFile(String paperId) async {
    final dir = await _cacheDir();
    // Sanitise the ID so it's safe as a filename
    final safe = paperId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    return File('${dir.path}/$safe.pdf');
  }

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Returns the cached file for [paperId] if it already exists on disk.
  /// Returns null if the file has not been downloaded yet.
  Future<File?> getCached(String paperId) async {
    final f = await _cacheFile(paperId);
    if (await f.exists() && await f.length() > 0) return f;
    return null;
  }

  /// Clears the cached file for a single paper (e.g. after a storage update).
  Future<void> evict(String paperId) async {
    final f = await _cacheFile(paperId);
    if (await f.exists()) await f.delete();
  }

  /// Clears every cached PDF.
  Future<void> clearAll() async {
    final dir = await _cacheDir();
    await for (final entity in dir.list()) {
      await entity.delete();
    }
  }

  /// Downloads [url] to disk, calling [onProgress] as bytes arrive.
  ///
  /// Returns the local [File] on success.
  /// Throws [PdfDownloadCancelledException] if [cancel] is called mid-download.
  /// Throws [PdfDownloadException] on network or HTTP errors.
  ///
  /// If the file is already cached, returns it immediately without a network
  /// request.
  Future<File> download({
    required String paperId,
    required String url,
    required void Function(PdfDownloadProgress) onProgress,
  }) async {
    // Return cache hit immediately
    final cached = await getCached(paperId);
    if (cached != null) {
      onProgress(
        PdfDownloadProgress(
          downloaded: await cached.length(),
          total: await cached.length(),
          phase: DownloadPhase.done,
        ),
      );
      return cached;
    }

    // Cancel any existing download for this paper
    _active[paperId]?.cancel();

    final controller = _DownloadController();
    _active[paperId] = controller;

    try {
      return await _download(
        paperId: paperId,
        url: url,
        onProgress: onProgress,
        controller: controller,
      );
    } finally {
      _active.remove(paperId);
    }
  }

  /// Cancels an in-progress download for [paperId].
  void cancel(String paperId) {
    _active[paperId]?.cancel();
    _active.remove(paperId);
  }

  // ── Internal ───────────────────────────────────────────────────────────────

  Future<File> _download({
    required String paperId,
    required String url,
    required void Function(PdfDownloadProgress) onProgress,
    required _DownloadController controller,
  }) async {
    final destFile = await _cacheFile(paperId);
    final tmpFile = File('${destFile.path}.tmp');

    // Clean up any leftover partial download
    if (await tmpFile.exists()) await tmpFile.delete();

    final uri = Uri.parse(url);

    onProgress(
      PdfDownloadProgress(
        downloaded: 0,
        total: 0,
        phase: DownloadPhase.connecting,
      ),
    );

    // HEAD request first to get Content-Length (best-effort)
    int total = 0;
    try {
      final head = await http.head(uri).timeout(const Duration(seconds: 10));
      final cl = head.headers['content-length'];
      if (cl != null) total = int.tryParse(cl) ?? 0;
    } catch (_) {
      // Can't get size — that's fine, we'll still show bytes downloaded
    }

    if (controller.cancelled) throw const PdfDownloadCancelledException();

    // Stream GET request
    final request = http.Request('GET', uri);
    http.StreamedResponse response;
    try {
      response = await http.Client()
          .send(request)
          .timeout(
            const Duration(seconds: 20),
            onTimeout: () => throw PdfDownloadException(
              'Connection timed out. Check your internet and try again.',
            ),
          );
    } catch (e) {
      if (e is PdfDownloadException) rethrow;
      throw PdfDownloadException('Could not connect: $e');
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw PdfDownloadException(
        'Server returned ${response.statusCode}. The file may have moved or expired.',
      );
    }

    // Update total from response headers if HEAD didn't work
    if (total == 0) {
      final cl = response.headers['content-length'];
      if (cl != null) total = int.tryParse(cl) ?? 0;
    }

    onProgress(
      PdfDownloadProgress(
        downloaded: 0,
        total: total,
        phase: DownloadPhase.downloading,
      ),
    );

    // Write stream to temp file, reporting progress every ~64 KB
    int downloaded = 0;
    int lastReport = 0;
    final sink = tmpFile.openWrite();

    try {
      await for (final chunk in response.stream) {
        if (controller.cancelled) {
          await sink.close();
          if (await tmpFile.exists()) await tmpFile.delete();
          throw const PdfDownloadCancelledException();
        }

        sink.add(chunk);
        downloaded += chunk.length;

        // Throttle callbacks: report every 64 KB or when total is unknown
        if (downloaded - lastReport >= 65536 || total == 0) {
          lastReport = downloaded;
          onProgress(
            PdfDownloadProgress(
              downloaded: downloaded,
              total: total,
              phase: DownloadPhase.downloading,
            ),
          );
        }
      }
    } finally {
      await sink.flush();
      await sink.close();
    }

    if (controller.cancelled) {
      if (await tmpFile.exists()) await tmpFile.delete();
      throw const PdfDownloadCancelledException();
    }

    // Verify the file is not empty
    if (await tmpFile.length() == 0) {
      await tmpFile.delete();
      throw const PdfDownloadException('Downloaded file is empty.');
    }

    // Rename tmp → final cache file
    await tmpFile.rename(destFile.path);

    onProgress(
      PdfDownloadProgress(
        downloaded: downloaded,
        total: downloaded,
        phase: DownloadPhase.done,
      ),
    );

    return destFile;
  }
}

class _DownloadController {
  bool _cancelled = false;
  bool get cancelled => _cancelled;
  void cancel() => _cancelled = true;
}

// ── Data classes ──────────────────────────────────────────────────────────────

enum DownloadPhase { connecting, downloading, done }

class PdfDownloadProgress {
  const PdfDownloadProgress({
    required this.downloaded,
    required this.total,
    required this.phase,
  });

  final int downloaded; // bytes received so far
  final int total; // 0 = unknown
  final DownloadPhase phase;

  /// 0.0–1.0, or null if total is unknown
  double? get fraction =>
      total > 0 ? (downloaded / total).clamp(0.0, 1.0) : null;

  String get downloadedLabel => _fmt(downloaded);
  String get totalLabel => _fmt(total);

  static String _fmt(int bytes) {
    if (bytes <= 0) return '0 KB';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class PdfDownloadException implements Exception {
  final String message;
  const PdfDownloadException(this.message);
  @override
  String toString() => message;
}

class PdfDownloadCancelledException implements Exception {
  const PdfDownloadCancelledException();
  @override
  String toString() => 'Download cancelled.';
}
