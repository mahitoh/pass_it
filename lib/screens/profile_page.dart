import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/app_state.dart';
import 'admin_dashboard_page.dart';
import 'paper_detail_page.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  String _initials(String name) {
    final parts = name.trim().split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);
    final isAdmin = appState.isAdmin;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: cs.surface,
            surfaceTintColor: Colors.transparent,
            pinned: true,
            title: Text(
              'Profile',
              style: GoogleFonts.manrope(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
            ),
            centerTitle: false,
            titleSpacing: 20,
            actions: [
              IconButton(
                onPressed: () => _showSettings(context),
                icon: Icon(
                  Icons.settings_outlined,
                  color: cs.onSurface,
                  size: 22,
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
          SliverToBoxAdapter(
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: cs.outlineVariant.withOpacity(0.2),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 34,
                            backgroundColor: cs.primary,
                            child: Text(
                              _initials(appState.userName),
                              style: GoogleFonts.manrope(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  appState.userName,
                                  style: GoogleFonts.manrope(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: cs.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '${appState.institution} · ${appState.department}',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: cs.onSurfaceVariant,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        (isAdmin
                                                ? const Color(0xFFD4A017)
                                                : cs.primary)
                                            .withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color:
                                          (isAdmin
                                                  ? const Color(0xFFD4A017)
                                                  : cs.primary)
                                              .withOpacity(0.3),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        isAdmin
                                            ? Icons.admin_panel_settings_rounded
                                            : Icons.verified_rounded,
                                        size: 12,
                                        color: isAdmin
                                            ? const Color(0xFFD4A017)
                                            : cs.primary,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        isAdmin
                                            ? 'Administrator'
                                            : 'Verified Contributor',
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: isAdmin
                                              ? const Color(0xFFD4A017)
                                              : cs.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Divider(
                        height: 1,
                        color: cs.outlineVariant.withOpacity(0.2),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _StatBox(
                            value: '${appState.points}',
                            label: 'Points',
                            color: cs.primary,
                          ),
                          _StatDivider(),
                          _StatBox(
                            value: '${appState.contributions}',
                            label: 'Uploads',
                            color: cs.secondary,
                          ),
                          _StatDivider(),
                          _StatBox(
                            value: '${appState.bookmarkedCount}',
                            label: 'Saved',
                            color: const Color(0xFF7B2D8B),
                          ),
                          _StatDivider(),
                          _StatBox(
                            value: 'Top 5%',
                            label: 'Rank',
                            color: const Color(0xFFD4A017),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _Section(
                  title: 'Saved Papers',
                  child: _BookmarksList(appState: appState),
                ),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'Account',
                    style: GoogleFonts.manrope(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: cs.outlineVariant.withOpacity(0.2),
                    ),
                  ),
                  child: Column(
                    children: [
                      _ActionTile(
                        icon: Icons.history_rounded,
                        label: 'My Contributions',
                        onTap: () => _showContributions(context, appState),
                      ),
                      if (isAdmin)
                        _ActionTile(
                          icon: Icons.admin_panel_settings_outlined,
                          label: 'Admin Dashboard',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const AdminDashboardPage(),
                              ),
                            );
                          },
                        ),
                      _ActionTile(
                        icon: Icons.bookmark_border_rounded,
                        label: 'Bookmarked Papers',
                        onTap: () => _showBookmarkedPapers(context, appState),
                      ),
                      _ActionTile(
                        icon: Icons.notifications_none_rounded,
                        label: 'Notification Settings',
                        onTap: () => _showNotificationSettings(context),
                      ),
                      _ActionTile(
                        icon: Icons.help_outline_rounded,
                        label: 'Help & Resources',
                        onTap: () => _showHelp(context),
                      ),
                      _ActionTile(
                        icon: Icons.lock_outline_rounded,
                        label: 'Privacy & Safety',
                        onTap: () => _showPrivacy(context),
                      ),
                      _ActionTile(
                        icon: Icons.logout_rounded,
                        label: 'Sign Out',
                        isDestructive: true,
                        showDivider: false,
                        onTap: () => _confirmLogout(context),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showBookmarkedPapers(BuildContext context, AppState appState) {
    final bookmarked = appState.papers.where((p) => p.isBookmarked).toList();
    if (bookmarked.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No bookmarked papers yet.')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => SafeArea(
        child: ListView.separated(
          shrinkWrap: true,
          padding: const EdgeInsets.all(16),
          itemCount: bookmarked.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (ctx, i) {
            final p = bookmarked[i];
            return ListTile(
              title: Text(
                p.title,
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(p.institution),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PaperDetailPage(paperId: p.id),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  void _showNotificationSettings(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Notification Settings',
          style: GoogleFonts.manrope(fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Notification preferences will be available in a future update.',
          style: GoogleFonts.inter(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Okay'),
          ),
        ],
      ),
    );
  }

  void _showPrivacy(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Privacy & Safety',
          style: GoogleFonts.manrope(fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Your account uses secure authentication. Keep your credentials private and avoid sharing login links.',
          style: GoogleFonts.inter(fontSize: 14, height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  void _showSettings(BuildContext context) {
    final appState = AppStateScope.of(context);
    final cs = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Appearance',
              style: GoogleFonts.manrope(
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Customize how Pass It looks on your device.',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            Container(
              decoration: BoxDecoration(
                color: cs.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  _SettingsToggle(
                    icon: Icons.light_mode_rounded,
                    label: 'Light Mode',
                    isSelected: appState.themeMode == ThemeMode.light,
                    onTap: () {
                      appState.setThemeMode(ThemeMode.light);
                      Navigator.pop(context);
                    },
                  ),
                  Divider(
                    height: 1,
                    indent: 56,
                    color: cs.outlineVariant.withOpacity(0.2),
                  ),
                  _SettingsToggle(
                    icon: Icons.dark_mode_rounded,
                    label: 'Dark Mode',
                    isSelected: appState.themeMode == ThemeMode.dark,
                    onTap: () {
                      appState.setThemeMode(ThemeMode.dark);
                      Navigator.pop(context);
                    },
                  ),
                  Divider(
                    height: 1,
                    indent: 56,
                    color: cs.outlineVariant.withOpacity(0.2),
                  ),
                  _SettingsToggle(
                    icon: Icons.brightness_auto_rounded,
                    label: 'System Default',
                    isSelected: appState.themeMode == ThemeMode.system,
                    onTap: () {
                      appState.setThemeMode(ThemeMode.system);
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showContributions(BuildContext context, AppState appState) {
    final contributions = List<ExamPaper>.from(appState.myUploads)
      ..sort((a, b) => b.year.compareTo(a.year));
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (_, ctrl) => ListView(
          controller: ctrl,
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'My Contributions (${contributions.length})',
              style: GoogleFonts.manrope(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            if (contributions.isEmpty)
              Text(
                'No contributions yet. Upload your first paper!',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              )
            else
              ...contributions.map(
                (p) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    Icons.picture_as_pdf_rounded,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  title: Text(
                    p.title,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    p.institution,
                    style: GoogleFonts.inter(fontSize: 12),
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: _statusColor(p.status).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      p.status.isEmpty
                          ? 'Pending'
                          : '${p.status[0].toUpperCase()}${p.status.substring(1)}',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: _statusColor(p.status),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return const Color(0xFF1B6D24);
      case 'rejected':
        return const Color(0xFFB3261E);
      default:
        return const Color(0xFF8A6E00);
    }
  }

  void _showHelp(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Help & Resources',
          style: GoogleFonts.manrope(fontWeight: FontWeight.w700),
        ),
        content: Text(
          '• Use Explore to search papers\n• Tap Upload to contribute a paper\n• Earn points on every approved upload\n• Redeem points on the Points tab',
          style: GoogleFonts.inter(fontSize: 14, height: 1.7),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Sign Out',
          style: GoogleFonts.manrope(fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Are you sure you want to sign out?',
          style: GoogleFonts.inter(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await Supabase.instance.client.auth.signOut();
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Could not sign out. Try again.'),
                    ),
                  );
                }
              }
            },
            child: const Text('Sign Out', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  const _StatBox({
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.manrope(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _StatDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    width: 1,
    height: 32,
    color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.3),
  );
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.manrope(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _BookmarksList extends StatelessWidget {
  final AppState appState;
  const _BookmarksList({required this.appState});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bookmarked = appState.papers.where((p) => p.isBookmarked).toList();

    if (bookmarked.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.outlineVariant.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Icon(
              Icons.bookmark_border_rounded,
              color: cs.onSurfaceVariant,
              size: 20,
            ),
            const SizedBox(width: 12),
            Text(
              'No saved papers yet.',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.2)),
      ),
      child: Column(
        children: bookmarked.asMap().entries.map((e) {
          final i = e.key;
          final paper = e.value;
          final isLast = i == bookmarked.length - 1;
          return Column(
            children: [
              ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                leading: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: cs.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.picture_as_pdf_rounded,
                    color: cs.primary,
                    size: 18,
                  ),
                ),
                title: Text(
                  paper.title,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  paper.institution,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: cs.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Icon(
                  Icons.chevron_right_rounded,
                  color: cs.outlineVariant,
                  size: 18,
                ),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PaperDetailPage(paperId: paper.id),
                  ),
                ),
              ),
              if (!isLast)
                Divider(
                  height: 1,
                  color: cs.outlineVariant.withOpacity(0.15),
                  indent: 16,
                  endIndent: 16,
                ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;
  final bool showDivider;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = isDestructive ? cs.error : cs.onSurface;
    return Column(
      children: [
        ListTile(
          leading: Icon(
            icon,
            color: isDestructive ? cs.error : cs.onSurfaceVariant,
            size: 20,
          ),
          title: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: color,
              fontWeight: isDestructive ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
          trailing: Icon(
            Icons.chevron_right_rounded,
            size: 18,
            color: isDestructive
                ? cs.error.withOpacity(0.5)
                : cs.outlineVariant,
          ),
          onTap: onTap,
        ),
        if (showDivider)
          Divider(
            height: 1,
            color: cs.outlineVariant.withOpacity(0.15),
            indent: 54,
            endIndent: 16,
          ),
      ],
    );
  }
}

class _SettingsToggle extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _SettingsToggle({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(icon, color: isSelected ? cs.primary : cs.onSurfaceVariant),
      title: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 15,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          color: isSelected ? cs.primary : cs.onSurface,
        ),
      ),
      trailing: isSelected
          ? Icon(Icons.check_circle_rounded, color: cs.primary, size: 20)
          : null,
      onTap: onTap,
    );
  }
}
