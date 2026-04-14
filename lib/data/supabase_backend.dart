import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_config.dart';

/// All Supabase calls live here. Column names match the SQL schema exactly:
///   paper_uploads.status  = 'pending' | 'approved' | 'rejected'
///   profiles.user_type    = 'student' | 'admin'
class SupabaseBackend {
  SupabaseBackend._();
  static final SupabaseBackend instance = SupabaseBackend._();

  bool _isReady = false;
  String? _errorMessage;
  bool _isAdminFlag = false;

  bool get isReady => _isReady;
  String? get errorMessage => _errorMessage;

  SupabaseClient get _client => Supabase.instance.client;

  User? get currentUser => _isReady ? _client.auth.currentUser : null;

  /// Whether the current user is an admin.
  /// Source of truth: profiles.user_type = 'admin'.
  /// Fallback: JWT app_metadata.user_type / role (set via Section 8 of SQL).
  bool get isAdmin => _isAdminFlag;

  // ── Initialisation ──────────────────────────────────────────────────────────

  Future<void> initialize() async {
    final url = supabaseUrl.trim();
    final key = supabaseAnonKey.trim();

    if (url.isEmpty ||
        url.startsWith('YOUR_') ||
        key.isEmpty ||
        key.startsWith('YOUR_')) {
      _isReady = false;
      _errorMessage =
          'Fill supabase_config.dart with your project URL and anon key.';
      return;
    }

    try {
      await Supabase.initialize(
        url: url,
        anonKey: key,
        authOptions: const FlutterAuthClientOptions(
          authFlowType: AuthFlowType.pkce,
        ),
      );
      _isReady = true;
      _errorMessage = null;
    } catch (e) {
      _isReady = false;
      _errorMessage = e.toString();
    }
  }

  // ── Admin status ────────────────────────────────────────────────────────────

  /// Call this after sign-in and after every hydration cycle.
  Future<void> refreshAdminStatus() async {
    final user = currentUser;
    if (user == null) {
      _isAdminFlag = false;
      return;
    }

    // 1. Source of truth: profiles table
    if (_isReady) {
      try {
        final row = await _client
            .from('profiles')
            .select('user_type')
            .eq('id', user.id)
            .maybeSingle()
            .timeout(const Duration(seconds: 10));

        if (row != null) {
          final t = (row['user_type'] ?? '').toString().trim().toLowerCase();
          _isAdminFlag =
              (t == 'admin' || t == 'super_admin' || t == 'moderator');
          return;
        }
      } catch (_) {
        // profiles table may not exist yet — fall through to JWT fallback
      }
    }

    // 2. Fallback: JWT app_metadata (set in Section 8 of the SQL script)
    final app = user.appMetadata;
    final candidates = [app['user_type'], app['role'], app['account_role']];
    for (final c in candidates) {
      final v = (c ?? '').toString().trim().toLowerCase();
      if (v == 'admin' || v == 'true' || v == '1') {
        _isAdminFlag = true;
        return;
      }
    }

    // 3. Last resort: hardcoded email list from supabase_config.dart
    final email = (user.email ?? '').trim().toLowerCase();
    _isAdminFlag = adminEmails
        .map((e) => e.trim().toLowerCase())
        .contains(email);
  }

  // ── Profile ─────────────────────────────────────────────────────────────────

  Future<Map<String, String>?> fetchUserProfile(String userId) async {
    if (!_isReady || userId.isEmpty) return null;
    try {
      final row = await _client
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle()
          .timeout(const Duration(seconds: 10));

      if (row == null) return null;
      return {
        'full_name': (row['full_name'] ?? '').toString(),
        'institution': (row['institution'] ?? '').toString(),
        'department': (row['department'] ?? '').toString(),
        'role': (row['user_type'] ?? 'student').toString(),
        'is_verified_to_upload': (row['is_verified_uploader'] ?? false)
            .toString(),
        'points_balance': (row['points_balance'] ?? 0).toString(),
      };
    } catch (_) {
      try {
        final row = await _client
            .from('profiles')
            .select()
            .eq('id', userId)
            .maybeSingle()
            .timeout(const Duration(seconds: 18));
        if (row == null) return null;
        return {
          'full_name': (row['full_name'] ?? '').toString(),
          'institution': (row['institution'] ?? '').toString(),
          'department': (row['department'] ?? '').toString(),
          'role': (row['user_type'] ?? 'student').toString(),
          'is_verified_to_upload': (row['is_verified_uploader'] ?? false)
              .toString(),
          'points_balance': (row['points_balance'] ?? 0).toString(),
        };
      } catch (_) {
        return null;
      }
    }
  }

  Future<String> fetchProfileRole(String userId) async {
    if (!_isReady || userId.isEmpty) return '';
    try {
      final row = await _client
          .from('profiles')
          .select('user_type')
          .eq('id', userId)
          .maybeSingle()
          .timeout(const Duration(seconds: 10));
      return (row?['user_type'] ?? '').toString().trim();
    } catch (_) {
      return '';
    }
  }

  // ── Papers — fetch ──────────────────────────────────────────────────────────

  /// Fetches papers visible to the current user:
  ///   - approved papers for everyone
  ///   - all papers (including pending/rejected) for admins
  ///   - uploader's own papers for authenticated users
  /// RLS enforces this server-side; this query just asks for everything
  /// and lets the DB return what the user is allowed to see.
  Future<List<Map<String, dynamic>>> fetchContributions() async {
    if (!_isReady) return const [];
    try {
      final rows = await _client
          .from(supabaseTableName)
          .select()
          .order('created_at', ascending: false)
          .timeout(const Duration(seconds: 20));
      return List<Map<String, dynamic>>.from(rows);
    } catch (_) {
      try {
        final rows = await _client
            .from(supabaseTableName)
            .select()
            .order('created_at', ascending: false)
            .timeout(const Duration(seconds: 35));
        return List<Map<String, dynamic>>.from(rows);
      } catch (_) {
        return const [];
      }
    }
  }

  /// Admin-only: returns all pending papers joined with uploader name.
  /// Uses the get_pending_papers() RPC defined in the SQL script.
  Future<List<Map<String, dynamic>>> fetchPendingContributions() async {
    if (!_isReady) return const [];
    try {
      // Use the RPC first (returns uploader name in one query)
      final rows = await _client
          .rpc('get_pending_papers')
          .timeout(const Duration(seconds: 20));
      return List<Map<String, dynamic>>.from(rows);
    } catch (_) {
      try {
        final rows = await _client
            .rpc('get_pending_papers')
            .timeout(const Duration(seconds: 35));
        return List<Map<String, dynamic>>.from(rows);
      } catch (_) {}
      // Fallback: direct query (no joined uploader name)
      try {
        final rows = await _client
            .from(supabaseTableName)
            .select()
            .eq('status', 'pending')
            .order('created_at', ascending: true)
            .timeout(const Duration(seconds: 20));
        return List<Map<String, dynamic>>.from(rows);
      } catch (_) {
        return const [];
      }
    }
  }

  // ── Papers — write ──────────────────────────────────────────────────────────

  Future<SupabaseUploadResult> uploadFile({
    required File file,
    required String fileName,
  }) async {
    if (!_isReady) throw StateError('Supabase is not initialised.');

    final userId = currentUser?.id ?? 'anon';
    final storagePath =
        '$userId/${DateTime.now().millisecondsSinceEpoch}_$fileName';

    final uploadTimeout = await _storageUploadTimeout(file);
    Object? lastError;

    for (var attempt = 1; attempt <= 3; attempt++) {
      try {
        await _client.storage
            .from(supabaseStorageBucket)
            .upload(
              storagePath,
              file,
              fileOptions: const FileOptions(upsert: true),
            )
            .timeout(
              uploadTimeout,
              onTimeout: () {
                throw TimeoutException(
                  'Upload timed out after ${uploadTimeout.inMinutes} minutes.',
                );
              },
            );

        return SupabaseUploadResult(
          storagePath: storagePath,
          publicUrl: _client.storage
              .from(supabaseStorageBucket)
              .getPublicUrl(storagePath),
        );
      } catch (error) {
        lastError = error;
        if (attempt >= 3 || !_isRetryableUploadError(error)) {
          rethrow;
        }

        final delay = Duration(seconds: attempt * attempt * 2);
        await Future<void>.delayed(delay);
      }
    }

    throw Exception('Upload failed: $lastError');
  }

  Future<String> syncContribution({required Map<String, dynamic> data}) async {
    if (!_isReady) throw StateError('Supabase is not initialised.');

    final row = await _client
        .from(supabaseTableName)
        .insert(data)
        .select('id')
        .single()
        .timeout(
          const Duration(seconds: 20),
          onTimeout: () => throw TimeoutException(
            'Metadata save timed out. Check your table policies.',
          ),
        );
    return (row['id'] ?? '').toString();
  }

  // ── Moderation (admin only) ─────────────────────────────────────────────────
  //
  // Both methods call SECURITY DEFINER RPCs (admin_approve_paper /
  // admin_reject_paper) defined in passit_patch.sql.  Those functions run as
  // the DB owner so RLS on paper_uploads never fires — the admin check is
  // done *inside* the function body instead.  This eliminates the empty-rows
  // problem that occurred when RLS silently blocked the direct .update() call.

  /// Approves a paper. The `on_paper_approved` trigger awards 50 pts automatically.
  Future<void> approveContribution({
    required String paperId,
    Map<String, dynamic>? rowHints,
  }) async {
    if (!_isReady || paperId.isEmpty) {
      throw StateError(
        'Cannot approve: Supabase not ready or paperId is empty.',
      );
    }

    try {
      final result = await _client
          .rpc('admin_approve_paper', params: {'p_paper_id': paperId})
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () => throw TimeoutException('Approve timed out.'),
          );

      // The RPC returns {ok: true, id: ..., status: 'approved'} on success,
      // or raises a Postgres exception which surfaces as a StorageException /
      // PostgrestException here.
      final map = result as Map<String, dynamic>? ?? {};
      if (map['ok'] != true) {
        throw Exception('Approve RPC returned unexpected result: $result');
      }
    } on PostgrestException catch (e) {
      // Translate Postgres error codes into readable messages.
      if (e.code == 'insufficient_privilege') {
        throw Exception(
          'Admin permission denied.\n'
          'Make sure you ran the PATCH SQL and your profile has user_type = \'admin\'.\n'
          'Postgres detail: ${e.message}',
        );
      }
      if (e.code == 'no_data_found') {
        throw Exception('Paper not found in the database (id: $paperId).');
      }
      rethrow;
    }
  }

  /// Rejects a paper with an optional note.
  Future<void> rejectContribution({
    required String paperId,
    String rejectionNote = '',
    Map<String, dynamic>? rowHints,
  }) async {
    if (!_isReady || paperId.isEmpty) {
      throw StateError(
        'Cannot reject: Supabase not ready or paperId is empty.',
      );
    }

    try {
      final result = await _client
          .rpc(
            'admin_reject_paper',
            params: {
              'p_paper_id': paperId,
              'p_note': rejectionNote.isNotEmpty ? rejectionNote : null,
            },
          )
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () => throw TimeoutException('Reject timed out.'),
          );

      final map = result as Map<String, dynamic>? ?? {};
      if (map['ok'] != true) {
        throw Exception('Reject RPC returned unexpected result: $result');
      }
    } on PostgrestException catch (e) {
      if (e.code == 'insufficient_privilege') {
        throw Exception(
          'Admin permission denied.\n'
          'Make sure you ran the PATCH SQL and your profile has user_type = \'admin\'.\n'
          'Postgres detail: ${e.message}',
        );
      }
      if (e.code == 'no_data_found') {
        throw Exception('Paper not found in the database (id: $paperId).');
      }
      rethrow;
    }
  }

  Future<void> updateContributionDraft({
    required String paperId,
    required Map<String, dynamic> changes,
  }) async {
    if (!_isReady || paperId.isEmpty || changes.isEmpty) return;
    await _client
        .from(supabaseTableName)
        .update(changes)
        .eq('id', paperId)
        .timeout(const Duration(seconds: 15));
  }

  // ── Downloads ───────────────────────────────────────────────────────────────

  Future<void> incrementDownloadCount({
    required String paperId,
    required int
    downloads, // kept for API compat, not used (DB does atomic increment)
  }) async {
    if (!_isReady || paperId.isEmpty) return;
    try {
      await _client
          .rpc('increment_downloads', params: {'paper_id': paperId})
          .timeout(const Duration(seconds: 10));
    } catch (_) {
      // Fire and forget — don't fail the whole download flow
    }
  }

  Future<void> incrementViewCount({required String paperId}) async {
    if (!_isReady || paperId.isEmpty) return;

    final rpcNames = [
      'increment_views',
      'increment_view_count',
      'increment_reads',
    ];
    for (final rpc in rpcNames) {
      try {
        await _client
            .rpc(rpc, params: {'paper_id': paperId})
            .timeout(const Duration(seconds: 10));
        return;
      } catch (_) {
        // Try the next known RPC name.
      }
    }
  }

  // ── Leaderboard / profiles lookup ───────────────────────────────────────────

  Future<List<Map<String, dynamic>>> fetchLeaderboard({int limit = 50}) async {
    if (!_isReady) return const [];
    try {
      final rows = await _client
          .from('profiles')
          .select('id, full_name, points_balance')
          .order('points_balance', ascending: false)
          .limit(limit)
          .timeout(const Duration(seconds: 15));
      return List<Map<String, dynamic>>.from(rows);
    } catch (_) {
      try {
        final rows = await _client
            .from('profiles')
            .select('id, full_name, points_balance')
            .order('points_balance', ascending: false)
            .limit(limit)
            .timeout(const Duration(seconds: 25));
        return List<Map<String, dynamic>>.from(rows);
      } catch (_) {
        return const [];
      }
    }
  }

  Future<Map<String, String>> fetchUploaderDisplayNames(
    Set<String> userIds,
  ) async {
    if (!_isReady || userIds.isEmpty) return const {};
    try {
      final rows = await _client
          .from('profiles')
          .select('id, full_name')
          .inFilter('id', userIds.toList())
          .timeout(const Duration(seconds: 10));

      final map = <String, String>{};
      for (final row in List<Map<String, dynamic>>.from(rows)) {
        final id = (row['id'] ?? '').toString();
        final name = (row['full_name'] ?? '').toString().trim();
        if (id.isNotEmpty) map[id] = name.isEmpty ? id : name;
      }
      return map;
    } catch (_) {
      return const {};
    }
  }

  Future<bool> deletePaper(String paperId, String? storagePath) async {
    if (!_isReady) return false;
    debugPrint(
      '[DeletePaper] Attempting to delete paperId: $paperId, storagePath: $storagePath',
    );
    try {
      var deletedRows = await _client
          .from(supabaseTableName)
          .delete()
          .eq('id', paperId)
          .select('id, storage_path');

      var deleted = List<Map<String, dynamic>>.from(deletedRows);
      debugPrint('[DeletePaper] Direct delete result: ${deleted.length} rows');

      // Fallback: older cached/local items can carry a non-DB id.
      // In that case try deleting by storage_path which is unique per upload.
      if (deleted.isEmpty && storagePath != null && storagePath.isNotEmpty) {
        deletedRows = await _client
            .from(supabaseTableName)
            .delete()
            .eq('storage_path', storagePath)
            .select('id, storage_path');
        deleted = List<Map<String, dynamic>>.from(deletedRows);
      }

      if (deleted.isEmpty) {
        return false;
      }

      final storageToDelete =
          storagePath ?? (deleted.first['storage_path'] ?? '').toString();

      if (storageToDelete.isNotEmpty) {
        try {
          await _client.storage.from(supabaseStorageBucket).remove([
            storageToDelete,
          ]);
        } catch (_) {}
      }

      return true;
    } catch (_) {
      return false;
    }
  }

  // ── Admin users ────────────────────────────────────────────────────────────

  /// Returns users from the profiles table for admin management UI.
  ///
  /// Expected profile fields:
  /// - id
  /// - full_name
  /// - user_type
  /// - points_balance
  /// - email (optional: if not present, UI falls back to empty)
  Future<List<Map<String, dynamic>>> fetchAdminUsers() async {
    if (!_isReady) return const [];
    try {
      // Preferred path: SECURITY DEFINER RPC that can join profiles with
      // auth.users and return email safely for admins.
      final rpcRows = await _client
          .rpc('admin_list_users')
          .timeout(const Duration(seconds: 20));
      return List<Map<String, dynamic>>.from(rpcRows);
    } catch (_) {
      // Fallback path: read directly from profiles only.
    }

    try {
      final rows = await _client
          .from('profiles')
          .select()
          .timeout(const Duration(seconds: 20));
      return List<Map<String, dynamic>>.from(rows);
    } catch (_) {
      try {
        final rows = await _client
            .from('profiles')
            .select()
            .timeout(const Duration(seconds: 35));
        return List<Map<String, dynamic>>.from(rows);
      } catch (_) {
        return const [];
      }
    }
  }

  /// Returns high-level usage statistics for the admin dashboard.
  ///
  /// Preferred path: RPC `admin_usage_stats()` returning one row.
  /// Fallback path: derive totals from `profiles` and `paper_uploads`.
  Future<Map<String, int>> fetchAdminUsageStats() async {
    if (!_isReady) return const {};

    try {
      final rpcRows = await _client
          .rpc('admin_usage_stats')
          .timeout(const Duration(seconds: 20));
      final rows = List<Map<String, dynamic>>.from(rpcRows);
      if (rows.isNotEmpty) {
        final row = rows.first;
        return {
          'total_users': _toInt(row['total_users']),
          'total_uploads': _toInt(row['total_uploads']),
          'approved_uploads': _toInt(row['approved_uploads']),
          'pending_uploads': _toInt(row['pending_uploads']),
          'rejected_uploads': _toInt(row['rejected_uploads']),
          'total_views': _toInt(row['total_views']),
          'total_downloads': _toInt(row['total_downloads']),
          'active_uploaders': _toInt(row['active_uploaders']),
        };
      }
    } catch (_) {
      // Fall through to table-based derivation.
    }

    try {
      final profileRows = await _client
          .from('profiles')
          .select('id')
          .timeout(const Duration(seconds: 20));

      final paperRows = await _client
          .from(supabaseTableName)
          .select('uploader_id, status, downloads, views')
          .timeout(const Duration(seconds: 20));

      final users = List<Map<String, dynamic>>.from(profileRows);
      final papers = List<Map<String, dynamic>>.from(paperRows);

      var approved = 0;
      var pending = 0;
      var rejected = 0;
      var totalViews = 0;
      var totalDownloads = 0;
      final activeUploaders = <String>{};

      for (final row in papers) {
        final status = (row['status'] ?? '').toString().trim().toLowerCase();
        if (status == 'approved') approved++;
        if (status == 'pending') pending++;
        if (status == 'rejected') rejected++;

        totalViews += _toInt(row['views']);
        totalDownloads += _toInt(row['downloads']);

        final uploaderId = (row['uploader_id'] ?? '').toString().trim();
        if (uploaderId.isNotEmpty) activeUploaders.add(uploaderId);
      }

      return {
        'total_users': users.length,
        'total_uploads': papers.length,
        'approved_uploads': approved,
        'pending_uploads': pending,
        'rejected_uploads': rejected,
        'total_views': totalViews,
        'total_downloads': totalDownloads,
        'active_uploaders': activeUploaders.length,
      };
    } catch (_) {
      return const {};
    }
  }

  /// Returns a map of uploader_id -> number of uploaded papers.
  Future<Map<String, int>> fetchUploadCountsByUser() async {
    if (!_isReady) return const {};
    try {
      final rows = await _client
          .from(supabaseTableName)
          .select('uploader_id')
          .timeout(const Duration(seconds: 20));

      final counts = <String, int>{};
      for (final row in List<Map<String, dynamic>>.from(rows)) {
        final userId = (row['uploader_id'] ?? '').toString().trim();
        if (userId.isEmpty) continue;
        counts[userId] = (counts[userId] ?? 0) + 1;
      }
      return counts;
    } catch (_) {
      return const {};
    }
  }

  // ── Admin institutions ───────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> fetchAdminInstitutions() async {
    if (!_isReady) return const [];
    try {
      final rows = await _client
          .from('institutions')
          .select('id, name, status, created_at')
          .order('name')
          .timeout(const Duration(seconds: 20));
      return List<Map<String, dynamic>>.from(rows);
    } catch (_) {
      return const [];
    }
  }

  Future<void> addInstitution({required String name}) async {
    if (!_isReady) throw StateError('Supabase is not initialised.');
    final clean = name.trim();
    if (clean.isEmpty) throw ArgumentError('Institution name is required.');

    await _client
        .from('institutions')
        .insert({'name': clean})
        .timeout(const Duration(seconds: 20));
  }

  Future<void> deleteInstitution({required String institutionId}) async {
    if (!_isReady) throw StateError('Supabase is not initialised.');
    final id = institutionId.trim();
    if (id.isEmpty) return;

    await _client
        .from('institutions')
        .delete()
        .eq('id', id)
        .timeout(const Duration(seconds: 20));
  }

  /// Returns stats keyed by institution name.
  /// Each value contains: papers, contributors.
  Future<Map<String, Map<String, int>>> fetchInstitutionUsageStats() async {
    if (!_isReady) return const {};
    try {
      final rows = await _client
          .from(supabaseTableName)
          .select('institution, uploader_id')
          .timeout(const Duration(seconds: 20));

      final papersByInstitution = <String, int>{};
      final contributorsByInstitution = <String, Set<String>>{};

      for (final row in List<Map<String, dynamic>>.from(rows)) {
        final institution = (row['institution'] ?? '').toString().trim();
        if (institution.isEmpty) continue;
        papersByInstitution[institution] =
            (papersByInstitution[institution] ?? 0) + 1;

        final uploaderId = (row['uploader_id'] ?? '').toString().trim();
        if (uploaderId.isNotEmpty) {
          contributorsByInstitution.putIfAbsent(institution, () => <String>{});
          contributorsByInstitution[institution]!.add(uploaderId);
        }
      }

      final stats = <String, Map<String, int>>{};
      for (final entry in papersByInstitution.entries) {
        stats[entry.key] = {
          'papers': entry.value,
          'contributors': contributorsByInstitution[entry.key]?.length ?? 0,
        };
      }
      return stats;
    } catch (_) {
      return const {};
    }
  }

  Future<Duration> _storageUploadTimeout(File file) async {
    final sizeBytes = await file.length();
    final sizeMb = (sizeBytes / (1024 * 1024)).ceil();

    // Larger files need more time on weak mobile connections.
    final seconds = (90 + (sizeMb * 25)).clamp(90, 420);
    return Duration(seconds: seconds);
  }

  bool _isRetryableUploadError(Object error) {
    final message = error.toString().toLowerCase();

    return error is TimeoutException ||
        error is SocketException ||
        message.contains('timeout') ||
        message.contains('socket') ||
        message.contains('network') ||
        message.contains('connection') ||
        message.contains('temporary') ||
        message.contains('fetch failed') ||
        message.contains('503') ||
        message.contains('502');
  }

  int _toInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim()) ?? fallback;
    return fallback;
  }
}

class SupabaseUploadResult {
  const SupabaseUploadResult({
    required this.storagePath,
    required this.publicUrl,
  });
  final String storagePath;
  final String publicUrl;
}
