import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'supabase_backend.dart';

enum PaperCategory { university, competitive, highSchool, professional }

class ExamPaper {
  const ExamPaper({
    required this.id,
    required this.title,
    required this.institution,
    required this.course,
    required this.category,
    required this.year,
    required this.points,
    required this.downloads,
    required this.views,
    required this.description,
    required this.tags,
    this.status = 'approved', // 'pending' | 'approved' | 'rejected'
    this.remoteUrl,
    this.storagePath,
    this.isTrending = false,
    this.isRecent = false,
    this.isBookmarked = false,
  });

  final String id;
  final String title;
  final String institution;
  final String course;
  final PaperCategory category;
  final int year;
  final int points;
  final int downloads;
  final int views;
  final String description;
  final List<String> tags;
  final String status; // ← NEW: tracks moderation state
  final String? remoteUrl;
  final String? storagePath;
  final bool isTrending;
  final bool isRecent;
  final bool isBookmarked;

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';

  ExamPaper copyWith({
    bool? isBookmarked,
    int? downloads,
    int? views,
    String? status,
  }) {
    return ExamPaper(
      id: id,
      title: title,
      institution: institution,
      course: course,
      category: category,
      year: year,
      points: points,
      downloads: downloads ?? this.downloads,
      views: views ?? this.views,
      description: description,
      tags: tags,
      status: status ?? this.status,
      remoteUrl: remoteUrl,
      storagePath: storagePath,
      isTrending: isTrending,
      isRecent: isRecent,
      isBookmarked: isBookmarked ?? this.isBookmarked,
    );
  }
}

class ContributionDraft {
  const ContributionDraft({
    required this.level,
    required this.institution,
    required this.course,
    required this.year,
    required this.fileName,
    this.storagePath,
    this.remoteUrl,
    this.remoteRecordId,
  });

  final String level;
  final String institution;
  final String course;
  final int year;
  final String fileName;
  final String? storagePath;
  final String? remoteUrl;
  final String? remoteRecordId;
}

class RewardItem {
  const RewardItem({
    required this.title,
    required this.subtitle,
    required this.costPoints,
    required this.icon,
    this.isRedeemed = false,
  });

  final String title;
  final String subtitle;
  final int costPoints;
  final IconData icon;
  final bool isRedeemed;

  RewardItem copyWith({bool? isRedeemed}) {
    return RewardItem(
      title: title,
      subtitle: subtitle,
      costPoints: costPoints,
      icon: icon,
      isRedeemed: isRedeemed ?? this.isRedeemed,
    );
  }
}

class LeaderboardEntry {
  const LeaderboardEntry({
    required this.name,
    required this.points,
    required this.rank,
  });

  final String name;
  final int points;
  final int rank;
}

class AppState extends ChangeNotifier {
  AppState._();

  static final AppState instance = AppState._();
  static const Duration _viewRepeatWindow = Duration(minutes: 30);

  // ── Public feed: only APPROVED papers ─────────────────────────────────────
  // Never contains pending or rejected papers. Drives home/explore/browse.
  final List<ExamPaper> _papers = [];

  // ── My uploads: current user's OWN papers (all statuses) ──────────────────
  // Drives the profile "My Contributions" section.
  final List<ExamPaper> _myUploads = [];

  final List<RewardItem> _rewards = [];
  final List<String> studyGroups = const [];
  List<LeaderboardEntry> _leaderboard = const [];

  ThemeMode _themeMode = ThemeMode.light;
  ThemeMode get themeMode => _themeMode;

  final List<Map<String, dynamic>> _notifications = [];
  List<Map<String, dynamic>> get notifications =>
      List.unmodifiable(_notifications);

  bool _hasSeenOnboarding = false;
  bool get hasSeenOnboarding => _hasSeenOnboarding;

  // ── Points come from profiles.points_balance, NOT from summing papers ──────
  int _points = 0;
  bool _isAdmin = false;
  String _userName = 'Guest User';
  String _institution = 'Not set';
  String _department = 'Not set';

  List<ExamPaper> get papers => List.unmodifiable(_papers);
  List<ExamPaper> get myUploads => List.unmodifiable(_myUploads);
  List<RewardItem> get rewards => List.unmodifiable(_rewards);

  int get points => _points;
  int get contributions => _myUploads.length;
  bool get isAdmin => _isAdmin || SupabaseBackend.instance.isAdmin;
  String get userName => _userName;
  String get institution => _institution;
  String get department => _department;
  List<LeaderboardEntry> get leaderboard => _leaderboard;

  int get bookmarkedCount => _papers.where((p) => p.isBookmarked).length;

  // ── Streak System ───────────────────────────────────────────────────────────
  int _streak = 0;
  DateTime? _lastActiveDate;
  int _lastTierIndex = 0;
  void Function(String newTier)? onTierUp;

  int get streak => _streak;

  int get currentTierIndex {
    if (_points >= 600) return 3;
    if (_points >= 300) return 2;
    if (_points >= 100) return 1;
    return 0;
  }

  Future<void> _loadStreak() async {
    final prefs = await SharedPreferences.getInstance();
    _streak = prefs.getInt('user_streak') ?? 0;
    _lastTierIndex = prefs.getInt('last_tier_index') ?? currentTierIndex;
    final lastActive = prefs.getString('last_active_date');
    if (lastActive != null) {
      _lastActiveDate = DateTime.tryParse(lastActive);
    }
  }

  Future<void> _updateStreak() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (_lastActiveDate == null) {
      _streak = 1;
    } else {
      final lastDate = DateTime(
        _lastActiveDate!.year,
        _lastActiveDate!.month,
        _lastActiveDate!.day,
      );
      final difference = today.difference(lastDate).inDays;

      if (difference == 0) {
        // Already logged in today, do nothing
      } else if (difference == 1) {
        // Consecutive day
        _streak++;
      } else {
        // Streak broken
        _streak = 1;
      }
    }

    _lastActiveDate = now;
    await prefs.setInt('user_streak', _streak);
    await prefs.setString('last_active_date', now.toIso8601String());
    await prefs.setInt('last_tier_index', currentTierIndex);
    notifyListeners();
  }

  Future<void> _checkTierUpgrade() async {
    final newTierIndex = currentTierIndex;
    if (newTierIndex > _lastTierIndex) {
      final tierNames = ['Bronze', 'Silver', 'Gold', 'Platinum'];
      final newTierName = tierNames[newTierIndex];
      _lastTierIndex = newTierIndex;
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('last_tier_index', newTierIndex);
      
      onTierUp?.call(newTierName);
      notifyListeners();
    }
  }

  // ── Hydration ──────────────────────────────────────────────────────────────

  /// Full hydration: fetches profile (and points balance) + papers from Supabase.
  Future<void> hydrateFromSupabase(SupabaseBackend backend) async {
    // Load and update streak on app open
    await _loadStreak();
    await _updateStreak();

    // 1. Refresh admin flag
    await backend.refreshAdminStatus();
    _isAdmin = backend.isAdmin;

    // 2. Refresh profile — this is where _points is now set
    await _refreshUserProfile(backend);

    // Check for tier upgrade
    await _checkTierUpgrade();

    // Render cached papers immediately so the app stays responsive on slow networks.
    final cached = await _loadLocalPapers();
    if (cached.isNotEmpty) {
      _papers
        ..clear()
        ..addAll(cached.where((p) => p.isApproved));
      notifyListeners();
    }

    if (!backend.isReady) {
      if (cached.isNotEmpty) {
        _papers
          ..clear()
          ..addAll(cached.where((p) => p.isApproved));
        _myUploads
          ..clear()
          ..addAll(
            cached.where(
              (p) => p.id.startsWith(backend.currentUser?.id ?? '__none__'),
            ),
          );
      }
      notifyListeners();
      return;
    }

    try {
      final rows = await backend.fetchContributions();
      final allPapers = _papersFromRows(rows);

      // ── Public feed: only approved papers go here ────────────────────────
      // This is the critical fix. Previously every returned row (including
      // the uploader's own pending papers) went into _papers, which made
      // pending uploads appear in the home feed AND gave every user points
      // for papers they never uploaded.
      final approvedPapers = allPapers.where((p) => p.isApproved).toList();

      // ── My uploads: current user's own papers (all statuses) ─────────────
      final myId = backend.currentUser?.id ?? '';
      final myRows = rows.where((r) {
        final uid = (r['uploader_id'] ?? r['user_id'] ?? '').toString();
        return uid == myId && myId.isNotEmpty;
      }).toList();
      final myPapers = _papersFromRows(myRows);

      // Preserve bookmarks
      final bookmarkIds = {
        for (final p in _papers)
          if (p.isBookmarked) p.id,
      };
      final withBookmarks = approvedPapers
          .map(
            (p) =>
                bookmarkIds.contains(p.id) ? p.copyWith(isBookmarked: true) : p,
          )
          .toList();

      _papers
        ..clear()
        ..addAll(withBookmarks);

      _myUploads
        ..clear()
        ..addAll(myPapers);

      // 3. Optional: Leaderboard & local data
      await _loadThemeMode();
      await _loadOnboardingStatus();
      await _refreshLeaderboard(backend);
      _ensureDefaultNotifications();

      await _persistLocalPapers();
      notifyListeners();
    } catch (_) {
      // Offline fallback: use cache
      await _loadThemeMode();
      await _loadOnboardingStatus();
      final cached = await _loadLocalPapers();
      if (cached.isNotEmpty) {
        _papers
          ..clear()
          ..addAll(cached.where((p) => p.isApproved));
      }
      notifyListeners();
    }
  }

  Future<void> _refreshLeaderboard(SupabaseBackend backend) async {
    final rows = await backend.fetchLeaderboard(limit: 100);
    if (rows.isEmpty) return;

    final mapped = <LeaderboardEntry>[];
    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      final points = _toInt(row['points_balance'], fallback: 0);
      final name = (row['full_name'] ?? '').toString().trim();
      mapped.add(
        LeaderboardEntry(
          name: name.isNotEmpty ? name : 'User',
          points: points,
          rank: i + 1,
        ),
      );
    }
    _leaderboard = mapped;
  }

  void _ensureDefaultNotifications() {
    if (_notifications.isEmpty) {
      _notifications.addAll([
        {
          'title': 'Paper Approved!',
          'body': 'Your discrete mathematics paper has been approved. +50 pts',
          'time': '2h ago',
          'is_read': false,
        },
        {
          'title': 'New Resource in ICTU',
          'body':
              'A new Operating Systems exam has been uploaded to your department.',
          'time': '5h ago',
          'is_read': true,
        },
      ]);
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_mode', mode.name);
    notifyListeners();
  }

  Future<void> _loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final mode = prefs.getString('theme_mode');
    if (mode == 'light') _themeMode = ThemeMode.light;
    if (mode == 'dark') _themeMode = ThemeMode.dark;
    if (mode == 'system') _themeMode = ThemeMode.system;
  }

  Future<void> setHasSeenOnboarding(bool seen) async {
    _hasSeenOnboarding = seen;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_onboarding', seen);
    notifyListeners();
  }

  Future<void> _loadOnboardingStatus() async {
    final prefs = await SharedPreferences.getInstance();
    _hasSeenOnboarding = prefs.getBool('has_seen_onboarding') ?? false;
  }

  Future<void> refreshData() => hydrateFromSupabase(SupabaseBackend.instance);

  Future<bool> deletePaper(String paperId, String? storagePath) async {
    final success = await SupabaseBackend.instance.deletePaper(paperId, storagePath);
    if (success) {
      _papers.removeWhere((p) => p.id == paperId);
      _myUploads.removeWhere((p) => p.id == paperId);
      notifyListeners();
    }
    return success;
  }

  // ── Queries ────────────────────────────────────────────────────────────────

  ExamPaper? paperById(String id) {
    try {
      return _papers.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  List<ExamPaper> papersForCategory(PaperCategory category) =>
      _papers.where((p) => p.category == category).toList();

  List<ExamPaper> searchPapers(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return List.unmodifiable(_papers);
    return _papers
        .where(
          (p) =>
              p.title.toLowerCase().contains(q) ||
              p.institution.toLowerCase().contains(q) ||
              p.course.toLowerCase().contains(q) ||
              p.tags.any((t) => t.toLowerCase().contains(q)) ||
              p.year.toString().contains(q),
        )
        .toList();
  }

  List<ExamPaper> recentPapers({int limit = 4}) {
    final sorted = List<ExamPaper>.from(_papers)
      ..sort((a, b) => b.year.compareTo(a.year));
    return sorted.take(limit).toList();
  }

  List<ExamPaper> trendingPapers({int limit = 3}) {
    final sorted = List<ExamPaper>.from(_papers)
      ..sort((a, b) => b.downloads.compareTo(a.downloads));
    return sorted.take(limit).toList();
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  void toggleBookmark(String paperId) {
    final i = _papers.indexWhere((p) => p.id == paperId);
    if (i == -1) return;
    _papers[i] = _papers[i].copyWith(isBookmarked: !_papers[i].isBookmarked);
    unawaited(_persistLocalPapers());
    notifyListeners();
  }

  Future<void> recordDownload(String paperId) async {
    final i = _papers.indexWhere((p) => p.id == paperId);
    if (i == -1) return;
    final next = _papers[i].downloads + 1;
    _papers[i] = _papers[i].copyWith(downloads: next);
    unawaited(_persistLocalPapers());
    notifyListeners();
    try {
      await SupabaseBackend.instance.incrementDownloadCount(
        paperId: _papers[i].id,
        downloads: next,
      );
    } catch (_) {}
  }

  Future<void> recordView(String paperId) async {
    final i = _papers.indexWhere((p) => p.id == paperId);
    if (i == -1) return;

    final shouldCount = await _shouldCountView(paperId);
    if (!shouldCount) return;

    final next = _papers[i].views + 1;
    _papers[i] = _papers[i].copyWith(views: next);
    unawaited(_persistLocalPapers());
    notifyListeners();
    try {
      await SupabaseBackend.instance.incrementViewCount(paperId: _papers[i].id);
    } catch (_) {}
  }

  Future<void> openPaper(String paperId) => recordView(paperId);

  Future<bool> _shouldCountView(String paperId) async {
    final prefs = await SharedPreferences.getInstance();
    final uid = SupabaseBackend.instance.currentUser?.id ?? 'guest';
    final key = 'viewed_at_${uid}_$paperId';
    final now = DateTime.now().millisecondsSinceEpoch;
    final lastSeen = prefs.getInt(key) ?? 0;

    if (lastSeen > 0) {
      final elapsedMs = now - lastSeen;
      if (elapsedMs >= 0 && elapsedMs < _viewRepeatWindow.inMilliseconds) {
        return false;
      }
    }

    await prefs.setInt(key, now);
    return true;
  }

  /// Called after a successful upload. Adds the paper to _myUploads as
  /// 'pending' so the profile page shows it immediately. Does NOT add
  /// to _papers (public feed) and does NOT award points — those only
  /// happen when the admin approves via the DB trigger.
  void addContribution(ContributionDraft draft) {
    final courseSlug = draft.course.trim().toLowerCase().replaceAll(' ', '-');
    final institutionSlug = draft.institution.trim().toLowerCase().replaceAll(
      ' ',
      '-',
    );

    final pending = ExamPaper(
      id: draft.remoteRecordId?.isNotEmpty == true
          ? draft.remoteRecordId!
          : '$courseSlug-${draft.year}-$institutionSlug',
      title: '${draft.course} ${draft.year}',
      institution: draft.institution,
      course: draft.course,
      category: _categoryForLevel(draft.level),
      year: draft.year,
      points: 0, // no points until approved
      downloads: 0,
      views: 0,
      description: 'Pending admin review.',
      tags: [draft.level, draft.institution, draft.course],
      status: 'pending', // ← correctly marked pending
      remoteUrl: draft.remoteUrl,
      storagePath: draft.storagePath,
      isRecent: true,
    );

    // Only add to myUploads, not to the public _papers list
    _myUploads.insert(0, pending);
    // contributions count updates automatically via getter
    notifyListeners();
  }

  bool redeemReward(RewardItem reward) {
    if (_points < reward.costPoints) return false;
    final i = _rewards.indexWhere((r) => r.title == reward.title);
    if (i == -1 || _rewards[i].isRedeemed) return false;
    _points -= reward.costPoints;
    _rewards[i] = _rewards[i].copyWith(isRedeemed: true);
    notifyListeners();
    return true;
  }

  void clearForSignedOut() {
    _papers.clear();
    _myUploads.clear();
    _rewards.clear();
    _points = 0;
    _isAdmin = false;
    _userName = 'Guest User';
    _institution = 'Not set';
    _department = 'Not set';
    notifyListeners();
  }

  // ── Profile refresh ────────────────────────────────────────────────────────

  Future<void> _refreshUserProfile(SupabaseBackend backend) async {
    final user = backend.currentUser;
    if (user == null) {
      _userName = 'Guest User';
      _institution = 'Not set';
      _department = 'Not set';
      _points = 0;
      return;
    }

    if (backend.isReady) {
      final profile = await backend.fetchUserProfile(user.id);
      if (profile != null) {
        _userName = profile['full_name']?.isNotEmpty == true
            ? profile['full_name']!
            : (user.email ?? 'User');
        _institution = profile['institution']?.isNotEmpty == true
            ? profile['institution']!
            : 'Not set';
        _department = profile['department']?.isNotEmpty == true
            ? profile['department']!
            : 'Not set';

        // ── Points come from the DB, not from summing papers ────────────────
        _points = int.tryParse(profile['points_balance'] ?? '0') ?? 0;
        return;
      }
    }

    // JWT fallback (no points available from JWT — stays 0)
    final meta = user.userMetadata ?? {};
    _userName = (meta['full_name'] ?? meta['name'] ?? user.email ?? 'User')
        .toString();
    _institution = (meta['institution'] ?? meta['school'] ?? 'Not set')
        .toString();
    _department = (meta['department'] ?? meta['faculty'] ?? 'Not set')
        .toString();
  }

  // ── Row → ExamPaper conversion ─────────────────────────────────────────────

  List<ExamPaper> _papersFromRows(List<Map<String, dynamic>> rows) {
    final now = DateTime.now().toUtc();
    return rows.asMap().entries.map((entry) {
      final i = entry.key;
      final row = entry.value;

      final level = (_read(row, 'level') ?? 'university').toString();
      final institution = (_read(row, 'institution') ?? 'Unknown').toString();
      final course = (_read(row, 'course') ?? 'Unknown').toString();
      final year = _toInt(_read(row, 'year'), fallback: now.year);
      final downloads = _toInt(_read(row, 'downloads'), fallback: 0);
      final views = _toInt(
        _read(row, 'views') ?? _read(row, 'view_count'),
        fallback: 0,
      );
      final fileName = (_read(row, 'file_name') ?? '$course $year').toString();
      final status = (_read(row, 'status') ?? 'pending').toString();
      final remoteUrl = (_read(row, 'remote_url') ?? _read(row, 'file_url'))
          ?.toString();
      final storagePath = (_read(row, 'storage_path') ?? _read(row, 'path'))
          ?.toString();
      final createdAt = DateTime.tryParse(
        (_read(row, 'created_at') ?? '').toString(),
      );
      final ageDays = createdAt == null
          ? 999
          : now.difference(createdAt).inDays;

      return ExamPaper(
        id: (_read(row, 'id') ?? _read(row, 'paper_id') ?? '$course-$year-$i')
            .toString(),
        title: fileName,
        institution: institution,
        course: course,
        category: _categoryForLevel(level),
        year: year,
        points:
            50, // display value — actual earned points are in profiles.points_balance
        downloads: downloads,
        views: views,
        description: 'Paper from $institution',
        tags: [level, institution, course],
        status: status,
        remoteUrl: remoteUrl,
        storagePath: storagePath,
        isTrending: downloads > 20,
        isRecent: ageDays <= 120,
      );
    }).toList();
  }

  // ── Local cache ────────────────────────────────────────────────────────────

  String get _papersCacheKey {
    final uid = SupabaseBackend.instance.currentUser?.id;
    return uid != null ? 'papers_cache_$uid' : 'papers_cache_guest';
  }

  Future<void> _persistLocalPapers() async {
    final prefs = await SharedPreferences.getInstance();
    final payload = _papers
        .map(
          (p) => {
            'id': p.id,
            'title': p.title,
            'institution': p.institution,
            'course': p.course,
            'category': p.category.name,
            'year': p.year,
            'points': p.points,
            'downloads': p.downloads,
            'views': p.views,
            'description': p.description,
            'tags': p.tags,
            'status': p.status,
            'remoteUrl': p.remoteUrl,
            'storagePath': p.storagePath,
            'isTrending': p.isTrending,
            'isRecent': p.isRecent,
            'isBookmarked': p.isBookmarked,
          },
        )
        .toList();
    await prefs.setString(_papersCacheKey, jsonEncode(payload));
  }

  Future<List<ExamPaper>> _loadLocalPapers() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_papersCacheKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .map(_paperFromCache)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  ExamPaper _paperFromCache(Map<String, dynamic> data) {
    return ExamPaper(
      id: (data['id'] ?? '').toString(),
      title: (data['title'] ?? '').toString(),
      institution: (data['institution'] ?? '').toString(),
      course: (data['course'] ?? '').toString(),
      category: _categoryFromName((data['category'] ?? '').toString()),
      year: _toInt(data['year'], fallback: DateTime.now().year),
      points: _toInt(data['points'], fallback: 50),
      downloads: _toInt(data['downloads'], fallback: 0),
      views: _toInt(data['views'], fallback: 0),
      description: (data['description'] ?? '').toString(),
      tags: data['tags'] is List
          ? (data['tags'] as List).map((e) => e.toString()).toList()
          : [],
      status: (data['status'] ?? 'approved').toString(),
      remoteUrl: data['remoteUrl']?.toString(),
      storagePath: data['storagePath']?.toString(),
      isTrending: data['isTrending'] == true,
      isRecent: data['isRecent'] == true,
      isBookmarked: data['isBookmarked'] == true,
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  int _toInt(dynamic v, {required int fallback}) {
    if (v is int) return v;
    return int.tryParse(v?.toString() ?? '') ?? fallback;
  }

  dynamic _read(Map<String, dynamic> row, String key) {
    if (row.containsKey(key)) return row[key];
    final alt = key.contains('_') ? _snakeToCamel(key) : _camelToSnake(key);
    return row[alt];
  }

  String _camelToSnake(String v) => v.replaceAllMapped(
    RegExp(r'[A-Z]'),
    (m) => '_${m.group(0)!.toLowerCase()}',
  );

  String _snakeToCamel(String v) {
    final parts = v.split('_');
    return parts.first +
        parts
            .skip(1)
            .map((s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1))
            .join();
  }

  PaperCategory _categoryFromName(String v) {
    switch (v) {
      case 'competitive':
        return PaperCategory.competitive;
      case 'highSchool':
        return PaperCategory.highSchool;
      case 'professional':
        return PaperCategory.professional;
      default:
        return PaperCategory.university;
    }
  }

  PaperCategory _categoryForLevel(String level) {
    switch (level.trim().toLowerCase().replaceAll(' ', '_')) {
      case 'competitive':
        return PaperCategory.competitive;
      case 'high_school':
        return PaperCategory.highSchool;
      case 'professional':
        return PaperCategory.professional;
      default:
        return PaperCategory.university;
    }
  }
}

class AppStateScope extends InheritedNotifier<AppState> {
  const AppStateScope({
    super.key,
    required AppState super.notifier,
    required super.child,
  });

  static AppState of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppStateScope>();
    assert(scope != null, 'AppStateScope not found in context');
    return scope!.notifier!;
  }
}
