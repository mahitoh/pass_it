import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/app_state.dart';
import 'admin_dashboard_page.dart';
import 'competitive_exams_page.dart';
import 'explore_page.dart';
import 'leaderboard_page.dart';
import 'level_papers_page.dart';
import 'notifications_page.dart';
import 'paper_detail_page.dart';
import 'paper_scanner_page.dart';
import 'points_page.dart';
import 'profile_page.dart';
import 'upload_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    HomeContent(),
    ExplorePage(),
    SizedBox.shrink(),
    PointsPage(),
    ProfilePage(),
  ];

  void _onNavTap(int index) {
    if (index == 2) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const UploadWorkflowPage()),
      );
      return;
    }
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      drawer: const _TwitterLikeDrawer(),
      body: _pages[_currentIndex == 2 ? 0 : _currentIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          border: Border(
            top: BorderSide(
              color: cs.outlineVariant.withOpacity(0.2),
              width: 1,
            ),
          ),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 60,
            child: Row(
              children: [
                _NavItem(
                  icon: Icons.home_rounded,
                  outlinedIcon: Icons.home_outlined,
                  label: 'Home',
                  index: 0,
                  current: _currentIndex,
                  onTap: _onNavTap,
                ),
                _NavItem(
                  icon: Icons.explore_rounded,
                  outlinedIcon: Icons.explore_outlined,
                  label: 'Explore',
                  index: 1,
                  current: _currentIndex,
                  onTap: _onNavTap,
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => _onNavTap(2),
                    child: Center(
                      child: Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [cs.primaryContainer, cs.primary],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: cs.primary.withOpacity(0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.add_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                    ),
                  ),
                ),
                _NavItem(
                  icon: Icons.emoji_events_rounded,
                  outlinedIcon: Icons.emoji_events_outlined,
                  label: 'Points',
                  index: 3,
                  current: _currentIndex,
                  onTap: _onNavTap,
                ),
                _NavItem(
                  icon: Icons.person_rounded,
                  outlinedIcon: Icons.person_outlined,
                  label: 'Profile',
                  index: 4,
                  current: _currentIndex,
                  onTap: _onNavTap,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData outlinedIcon;
  final String label;
  final int index;
  final int current;
  final ValueChanged<int> onTap;

  const _NavItem({
    required this.icon,
    required this.outlinedIcon,
    required this.label,
    required this.index,
    required this.current,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final selected = index == current;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onTap(index),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              selected ? icon : outlinedIcon,
              size: 22,
              color: selected ? cs.primary : cs.onSurfaceVariant,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: selected ? cs.primary : cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HomeContent extends StatelessWidget {
  const HomeContent({super.key});

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);
    final recentPapers = appState.recentPapers();
    final trendingPapers = appState.trendingPapers();

    return CustomScrollView(
      slivers: [
        _AppBar(
          greeting: _greeting,
          userName: appState.userName,
          points: appState.points,
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _SearchBar(),
              const SizedBox(height: 28),
              _SectionHeader(title: 'Browse by Level'),
              const SizedBox(height: 14),
              _CategoryGrid(),
              const SizedBox(height: 32),
              _SectionHeader(
                title: 'Trending Now',
                actionLabel: 'See all',
                onAction: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ExplorePage()),
                  );
                },
              ),
              const SizedBox(height: 14),
              _TrendingStrip(papers: trendingPapers),
              const SizedBox(height: 32),
              _UploadBanner(),
              const SizedBox(height: 32),
              _SectionHeader(title: 'Recently Added'),
              const SizedBox(height: 14),
              _RecentList(papers: recentPapers),
              const SizedBox(height: 24),
            ]),
          ),
        ),
      ],
    );
  }
}

class _AppBar extends StatelessWidget {
  final String greeting;
  final String userName;
  final int points;
  const _AppBar({
    required this.greeting,
    required this.userName,
    required this.points,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final firstName = userName.split(' ').first;
    return SliverAppBar(
      pinned: true,
      backgroundColor: cs.surface.withOpacity(0.95),
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        icon: Icon(Icons.menu_rounded, color: cs.onSurface, size: 28),
        onPressed: () => Scaffold.of(context).openDrawer(),
      ),
      centerTitle: true,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [Icon(Icons.bolt_rounded, color: cs.primary, size: 28)],
      ),
      actions: [
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: cs.secondaryContainer.withOpacity(0.3),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.bolt_rounded, size: 14, color: cs.secondary),
                const SizedBox(width: 4),
                Text(
                  '$points pts',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: cs.secondary,
                  ),
                ),
              ],
            ),
          ),
        ),
        IconButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const NotificationsPage()),
            );
          },
          icon: Icon(
            Icons.notifications_outlined,
            color: cs.onSurface,
            size: 24,
          ),
        ),
        const SizedBox(width: 4),
      ],
    );
  }
}

class _SearchBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ExplorePage()),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.outlineVariant.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.search_rounded, color: cs.onSurfaceVariant, size: 20),
            const SizedBox(width: 10),
            Text(
              'Search papers, courses, institutions…',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: cs.onSurfaceVariant,
              ),
            ),
            const Spacer(),
            Icon(Icons.tune_rounded, color: cs.onSurfaceVariant, size: 18),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  const _SectionHeader({required this.title, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Text(
          title,
          style: GoogleFonts.manrope(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: cs.onSurface,
          ),
        ),
        const Spacer(),
        if (actionLabel != null)
          GestureDetector(
            onTap: onAction,
            child: Text(
              actionLabel!,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: cs.primary,
              ),
            ),
          ),
      ],
    );
  }
}

class _CategoryGrid extends StatelessWidget {
  static const _categories = [
    _CategoryData(
      'University',
      Icons.account_balance_rounded,
      Color(0xFF003F98),
      Color(0xFFD9E2FF),
    ),
    _CategoryData(
      'High School',
      Icons.school_rounded,
      Color(0xFF6B4226),
      Color(0xFFFFDDC8),
    ),
    _CategoryData(
      'Secondary',
      Icons.menu_book_rounded,
      Color(0xFF1B6D24),
      Color(0xFFC8F5CC),
    ),
    _CategoryData(
      'Competitive',
      Icons.emoji_events_rounded,
      Color(0xFF7B2D8B),
      Color(0xFFEFD6F5),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.6,
      children: _categories.map((cat) => _CategoryCard(data: cat)).toList(),
    );
  }
}

class _CategoryData {
  final String label;
  final IconData icon;
  final Color color;
  final Color bg;
  const _CategoryData(this.label, this.icon, this.color, this.bg);
}

class _CategoryCard extends StatelessWidget {
  final _CategoryData data;
  const _CategoryCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: data.bg,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => data.label == 'Competitive'
                ? const CompetitiveExamsPage()
                : LevelPapersPage(category: _toCategory(data.label)),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: data.color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(data.icon, color: data.color, size: 20),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.label,
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: data.color,
                    ),
                  ),
                  Text(
                    'Browse papers',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: data.color.withOpacity(0.65),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  PaperCategory _toCategory(String label) {
    switch (label.toLowerCase()) {
      case 'university':
        return PaperCategory.university;
      case 'high school':
        return PaperCategory.highSchool;
      case 'secondary':
        return PaperCategory.university;
      case 'competitive':
        return PaperCategory.competitive;
      default:
        return PaperCategory.university;
    }
  }
}

class _TrendingStrip extends StatelessWidget {
  final List<ExamPaper> papers;
  const _TrendingStrip({required this.papers});

  @override
  Widget build(BuildContext context) {
    if (papers.isEmpty) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      height: 160,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: papers.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final p = papers[i];
          return GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => PaperDetailPage(paperId: p.id)),
            ),
            child: Container(
              width: 210,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cs.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: cs.outlineVariant.withOpacity(0.25)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: cs.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.trending_up_rounded,
                          color: cs.primary,
                          size: 16,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: cs.secondaryContainer.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '+${p.points} pts',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: cs.secondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    p.title,
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${p.institution} · ${p.year}',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: cs.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.download_rounded,
                        size: 12,
                        color: cs.onSurfaceVariant,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '${p.downloads}',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _UploadBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [cs.primaryContainer, cs.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Share & Earn Points',
                  style: GoogleFonts.manrope(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Upload a paper and earn 50 pts instantly',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.85),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const UploadWorkflowPage()),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: cs.primary,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              textStyle: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            child: const Text('Upload'),
          ),
        ],
      ),
    );
  }
}

class _RecentList extends StatelessWidget {
  final List<ExamPaper> papers;
  const _RecentList({required this.papers});

  @override
  Widget build(BuildContext context) {
    if (papers.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: Text(
            'No recent papers yet.',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: papers.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) => _PaperListTile(paper: papers[i]),
    );
  }
}

class _PaperListTile extends StatelessWidget {
  final ExamPaper paper;
  const _PaperListTile({required this.paper});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => PaperDetailPage(paperId: paper.id)),
      ),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.outlineVariant.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 50,
              decoration: BoxDecoration(
                color: cs.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.picture_as_pdf_rounded,
                    color: cs.primary,
                    size: 20,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${paper.year}',
                    style: GoogleFonts.inter(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: cs.primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    paper.title,
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    paper.institution,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: cs.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _LevelBadge(paper.category),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.download_rounded,
                        size: 12,
                        color: cs.onSurfaceVariant,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '${paper.downloads}',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right_rounded,
              color: cs.outlineVariant,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _LevelBadge extends StatelessWidget {
  final PaperCategory category;
  const _LevelBadge(this.category);

  String get _label => switch (category) {
    PaperCategory.university => 'University',
    PaperCategory.highSchool => 'High School',
    PaperCategory.competitive => 'Competitive',
    PaperCategory.professional => 'Professional',
  };

  Color get _color => switch (category) {
    PaperCategory.university => const Color(0xFF003F98),
    PaperCategory.highSchool => const Color(0xFF6B4226),
    PaperCategory.competitive => const Color(0xFF7B2D8B),
    PaperCategory.professional => const Color(0xFF1B6D24),
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: _color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        _label,
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: _color,
        ),
      ),
    );
  }
}

class _TwitterLikeDrawer extends StatelessWidget {
  const _TwitterLikeDrawer();

  void _showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$feature is coming soon.')));
  }

  void _showHelp(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Help Center'),
        content: const Text(
          'Use Explore to find papers, Scanner to open papers from QR codes, and Upload to contribute resources.',
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

  Future<void> _confirmLogout(BuildContext context) async {
    final shouldLogout =
        await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Log out'),
            content: const Text('Are you sure you want to log out?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Log out'),
              ),
            ],
          ),
        ) ??
        false;

    if (!shouldLogout) return;

    try {
      await Supabase.instance.client.auth.signOut();
      if (!context.mounted) return;
      AppState.instance.clearForSignedOut();
      Navigator.pop(context);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not log out. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final appState = AppStateScope.of(context);

    return Drawer(
      backgroundColor: cs.surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: cs.primaryContainer,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      appState.userName.isNotEmpty
                          ? appState.userName[0].toUpperCase()
                          : '?',
                      style: GoogleFonts.manrope(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: cs.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    appState.userName,
                    style: GoogleFonts.manrope(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.bolt_rounded, size: 16, color: cs.secondary),
                      const SizedBox(width: 4),
                      Text(
                        '${appState.points} Points',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: cs.secondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            const SizedBox(height: 10),
            _DrawerTile(
              icon: Icons.person_outline_rounded,
              title: 'Profile',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProfilePage()),
                );
              },
            ),
            _DrawerTile(
              icon: Icons.star_outline_rounded,
              title: 'Leaderboard',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LeaderboardPage()),
                );
              },
            ),
            _DrawerTile(
              icon: Icons.bookmark_border_rounded,
              title: 'Saved Papers',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProfilePage()),
                );
              },
            ),
            _DrawerTile(
              icon: Icons.qr_code_scanner_rounded,
              title: 'Scan Paper',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PaperScannerPage()),
                );
              },
            ),
            _DrawerTile(
              icon: Icons.settings_outlined,
              title: 'Settings and privacy',
              onTap: () => _showComingSoon(context, 'Settings & privacy'),
            ),
            _DrawerTile(
              icon: Icons.help_outline_rounded,
              title: 'Help Center',
              onTap: () => _showHelp(context),
            ),
            _DrawerTile(
              icon: appState.themeMode == ThemeMode.dark
                  ? Icons.light_mode_outlined
                  : Icons.dark_mode_outlined,
              title: appState.themeMode == ThemeMode.dark
                  ? 'Light Mode'
                  : 'Dark Mode',
              onTap: () {
                appState.setThemeMode(
                  appState.themeMode == ThemeMode.dark
                      ? ThemeMode.light
                      : ThemeMode.dark,
                );
              },
            ),
            if (appState.isAdmin) ...[
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Divider(
                  height: 1,
                  color: cs.outlineVariant.withOpacity(0.2),
                ),
              ),
              const SizedBox(height: 4),
              _DrawerTile(
                icon: Icons.admin_panel_settings_rounded,
                title: 'Admin Panel',
                iconColor: cs.primary,
                textColor: cs.primary,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AdminDashboardPage(),
                    ),
                  );
                },
              ),
            ],
            const Spacer(),
            const Divider(height: 1),
            _DrawerTile(
              icon: Icons.logout_rounded,
              title: 'Log out',
              iconColor: cs.error,
              textColor: cs.error,
              onTap: () => _confirmLogout(context),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _DrawerTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Color? iconColor;
  final Color? textColor;

  const _DrawerTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.iconColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(icon, color: iconColor ?? cs.onSurfaceVariant, size: 26),
      title: Text(
        title,
        style: GoogleFonts.manrope(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: textColor ?? cs.onSurface,
        ),
      ),
      onTap: onTap,
    );
  }
}
