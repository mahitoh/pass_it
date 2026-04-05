import 'dart:io';

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
      remoteUrl = uploadResult.publicUrl;

      onProgress(
        UploadProgressSnapshot(
          progress: 0.8,
          stage: 'Writing Supabase metadata',
          localPath: storedPath,
          remoteUrl: remoteUrl,
        ),
      );

      remoteRecordId = await supabaseBackend.syncContribution(
        data: {
          'uploader_id': currentUser.id,
          'status': 'pending',
          'level': _dbLevelForSelection(submission.level),
          'institution': submission.institution,
          'faculty': null,
          'series': null,
          'course': submission.course,
          'paper_type': _paperTypeForLevel(submission.level),
          'year': submission.year,
          'file_name': submission.fileName,
          'storage_path': uploadResult.storagePath,
          'remote_url': remoteUrl,
          'file_type': _fileTypeForName(submission.fileName),
          'file_size_kb': (await sourceFile.length() / 1024).ceil(),
          'downloads': 0,
        },
      );
    } catch (error) {
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

  String _fileTypeForName(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    if (extension == 'jpg' || extension == 'jpeg' || extension == 'png') {
      return 'image';
    }

    return 'pdf';
  }
}
