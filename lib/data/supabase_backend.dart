import 'dart:async';
import 'dart:io';

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

    await _client.storage
        .from(supabaseStorageBucket)
        .upload(storagePath, file)
        .timeout(
          const Duration(seconds: 60),
          onTimeout: () => throw TimeoutException(
            'Upload timed out. Check your internet and bucket policies.',
          ),
        );

    return SupabaseUploadResult(
      storagePath: storagePath,
      publicUrl: _client.storage
          .from(supabaseStorageBucket)
          .getPublicUrl(storagePath),
    );
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
    try {
      // Delete from storage first
      if (storagePath != null && storagePath.isNotEmpty) {
        try {
          await _client.storage.from(supabaseStorageBucket).remove([storagePath]);
        } catch (_) {}
      }
      // Delete from database
      await _client.from(supabaseTableName).delete().eq('id', paperId);
      return true;
    } catch (_) {
      return false;
    }
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
