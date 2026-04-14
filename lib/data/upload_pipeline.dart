import 'dart:io';
import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path_provider/path_provider.dart';

import 'app_state.dart';
import 'supabase_backend.dart';

class UploadSubmission {
  const UploadSubmission({
    required this.level,
    required this.institution,
    required this.course,
    required this.year,
    required this.fileName,
    required this.sourcePath,
  });

  final String level;
  final String institution;
  final String course;
  final int year;
  final String fileName;
  final String sourcePath;
}

class UploadProgressSnapshot {
  const UploadProgressSnapshot({
    required this.progress,
    required this.stage,
    this.localPath,
    this.remoteUrl,
    this.remoteRecordId,
  });

  final double progress;
  final String stage;
  final String? localPath;
  final String? remoteUrl;
  final String? remoteRecordId;
}

class _UploadProgressTicker {
  _UploadProgressTicker({
    required this.initialProgress,
    required this.capProgress,
    required this.fileSizeBytes,
    required this.onUpdate,
  }) : _currentProgress = initialProgress;

  final double initialProgress;
  final double capProgress;
  final int fileSizeBytes;
  final void Function(double) onUpdate;

  Timer? _timer;
  double _currentProgress;
  DateTime? _startedAt;

  static const int _assumedBytesPerSecond = 320 * 1024;

  void start() {
    _timer?.cancel();
    _startedAt = DateTime.now();

    final estimatedSeconds = (fileSizeBytes / _assumedBytesPerSecond)
        .clamp(12, 240)
        .toDouble();

    _timer = Timer.periodic(const Duration(milliseconds: 700), (_) {
      final startedAt = _startedAt;
      if (startedAt == null) return;

      final elapsedSeconds =
          DateTime.now().difference(startedAt).inMilliseconds / 1000.0;

      // Main phase: linear motion based on estimated duration.
      final t = (elapsedSeconds / estimatedSeconds).clamp(0.0, 1.0);
      final linear = initialProgress + ((capProgress - initialProgress) * t);

      // If estimated time exceeded, slowly creep forward instead of freezing.
      if (t >= 1.0 && _currentProgress < capProgress - 0.001) {
        final remaining = capProgress - _currentProgress;
        final creep = (remaining * 0.08).clamp(0.0015, 0.006).toDouble();
        _currentProgress = (_currentProgress + creep).clamp(
          initialProgress,
          capProgress,
        );
      } else {
        _currentProgress = linear.clamp(initialProgress, capProgress);
      }

      onUpdate(_currentProgress);
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }
}

class UploadPipeline {
  Future<void> submit({
    required UploadSubmission submission,
    required AppState appState,
    required SupabaseBackend supabaseBackend,
    required void Function(UploadProgressSnapshot snapshot) onProgress,
  }) async {
    final sourceFile = File(submission.sourcePath);
    if (!await sourceFile.exists()) {
      throw FileSystemException(
        'Selected file does not exist',
        submission.sourcePath,
      );
    }

    onProgress(
      const UploadProgressSnapshot(progress: 0.08, stage: 'Validating file'),
    );
    await Future<void>.delayed(const Duration(milliseconds: 250));

    onProgress(
      const UploadProgressSnapshot(
        progress: 0.25,
        stage: 'Preparing local storage',
      ),
    );
    final storedPath = await _storeLocally(sourceFile, submission.fileName);

    onProgress(
      UploadProgressSnapshot(
        progress: 0.55,
        stage: 'Uploading to Supabase Storage',
        localPath: storedPath,
      ),
    );

    final sourceSizeBytes = await sourceFile.length();

    final uploadProgressTicker = _UploadProgressTicker(
      initialProgress: 0.55,
      capProgress: 0.93,
      fileSizeBytes: sourceSizeBytes,
      onUpdate: (progress) {
        onProgress(
          UploadProgressSnapshot(
            progress: progress,
            stage: 'Uploading to Supabase Storage',
            localPath: storedPath,
          ),
        );
      },
    );
    uploadProgressTicker.start();

    if (!supabaseBackend.isReady) {
      throw StateError(
        'Supabase is not ready. Please verify URL/key and initialization.',
      );
    }

    final currentUser = supabaseBackend.currentUser;
    if (currentUser == null) {
      throw StateError(
        'You must sign in to Supabase before uploading because the database policy only allows authenticated inserts.',
      );
    }

    String? remoteUrl;
    String? remoteRecordId;
    SupabaseUploadResult? uploadResult;
    try {
      uploadResult = await supabaseBackend.uploadFile(
        file: sourceFile,
        fileName: _sanitizeFileName(submission.fileName),
      );
      uploadProgressTicker.stop();
      remoteUrl = uploadResult.publicUrl;

      onProgress(
        UploadProgressSnapshot(
          progress: 0.8,
          stage: 'Writing Supabase metadata',
          localPath: storedPath,
          remoteUrl: remoteUrl,
        ),
      );

      remoteRecordId = await _syncContributionWithLevelFallback(
        supabaseBackend: supabaseBackend,
        currentUserId: currentUser.id,
        submission: submission,
        storagePath: uploadResult.storagePath,
        remoteUrl: remoteUrl,
        sourceFile: sourceFile,
      );
    } catch (error) {
      uploadProgressTicker.stop();
      onProgress(
        UploadProgressSnapshot(
          progress: 0.82,
          stage: 'Supabase save failed',
          localPath: storedPath,
        ),
      );
      throw Exception('Supabase save failed: $error');
    }

    onProgress(
      UploadProgressSnapshot(
        progress: 0.9,
        stage: 'Syncing contribution index',
        localPath: storedPath,
        remoteUrl: remoteUrl,
        remoteRecordId: remoteRecordId,
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 300));

    appState.addContribution(
      ContributionDraft(
        level: submission.level,
        institution: submission.institution,
        course: submission.course,
        year: submission.year,
        fileName: submission.fileName,
        storagePath: uploadResult.storagePath,
        remoteUrl: remoteUrl,
        remoteRecordId: remoteRecordId,
      ),
    );

    onProgress(
      UploadProgressSnapshot(
        progress: 1,
        stage: 'Supabase upload complete',
        localPath: storedPath,
        remoteUrl: remoteUrl,
        remoteRecordId: remoteRecordId,
      ),
    );
  }

  Future<String> _storeLocally(File sourceFile, String fileName) async {
    // For large files, avoid the expensive local duplicate copy before upload.
    final bytes = await sourceFile.length();
    if (bytes >= 8 * 1024 * 1024) {
      return sourceFile.path;
    }

    final directory = await getApplicationSupportDirectory();
    final archiveDirectory = Directory(
      '${directory.path}${Platform.pathSeparator}pass_it_uploads',
    );
    if (!await archiveDirectory.exists()) {
      await archiveDirectory.create(recursive: true);
    }

    final sanitizedName = _sanitizeFileName(fileName);
    final destinationPath =
        '${archiveDirectory.path}${Platform.pathSeparator}${DateTime.now().millisecondsSinceEpoch}_$sanitizedName';
    await sourceFile.copy(destinationPath);
    return destinationPath;
  }

  String _sanitizeFileName(String fileName) {
    final trimmed = fileName.trim();
    if (trimmed.isEmpty) {
      return 'past-paper.pdf';
    }

    return trimmed.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
  }

  String _paperTypeForLevel(String level) {
    switch (level) {
      case 'University':
        return 'main_exam';
      case 'High School':
        return 'gce_ol';
      case 'Professional':
        return 'mock';
      case 'Competitive':
        return 'competitive';
      default:
        return 'main_exam';
    }
  }

  String _dbLevelForSelection(String level) {
    switch (level) {
      case 'University':
        return 'university';
      case 'High School':
        return 'high_school';
      case 'Professional':
        return 'professional';
      case 'Competitive':
        return 'competitive';
      default:
        return level.trim().toLowerCase().replaceAll(' ', '_');
    }
  }

  Future<String> _syncContributionWithLevelFallback({
    required SupabaseBackend supabaseBackend,
    required String currentUserId,
    required UploadSubmission submission,
    required String storagePath,
    required String remoteUrl,
    required File sourceFile,
  }) async {
    final fileSizeKb = (await sourceFile.length() / 1024).ceil();
    final normalizedLevel = _dbLevelForSelection(submission.level);
    final legacyLevel = _paperTypeForLevel(submission.level);
    final candidateLevels = <String>{
      submission.level.trim(),
      normalizedLevel,
      if (submission.level.trim().toLowerCase() == 'high school') 'secondary',
      if (submission.level.trim().toLowerCase() == 'professional') 'secondary',
      legacyLevel,
    }.where((value) => value.isNotEmpty).toList(growable: false);

    PostgrestException? lastPostgrestException;
    Object? lastError;

    for (final level in candidateLevels) {
      try {
        return await supabaseBackend.syncContribution(
          data: {
            'uploader_id': currentUserId,
            'status': 'pending',
            'level': level,
            'institution': submission.institution,
            'faculty': null,
            'series': null,
            'course': submission.course,
            'paper_type': _paperTypeForLevel(submission.level),
            'year': submission.year,
            'file_name': submission.fileName,
            'storage_path': storagePath,
            'remote_url': remoteUrl,
            'file_type': _fileTypeForName(submission.fileName),
            'file_size_kb': fileSizeKb,
            'downloads': 0,
          },
        );
      } on PostgrestException catch (error) {
        lastPostgrestException = error;
        lastError = error;
        if (error.code != '23514' ||
            !error.message.contains('paper_uploads_level_check')) {
          rethrow;
        }
      } catch (error) {
        lastError = error;
        rethrow;
      }
    }

    if (lastPostgrestException != null) {
      throw Exception(
        'Supabase save failed: level value "${submission.level}" does not match the database constraint. '
        'Tried ${candidateLevels.join(' and ')}. Original error: ${lastPostgrestException.message}',
      );
    }

    throw Exception('Supabase save failed: $lastError');
  }

  String _fileTypeForName(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    if (extension == 'jpg' || extension == 'jpeg' || extension == 'png') {
      return 'image';
    }

    return 'pdf';
  }
}
