import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../data/app_state.dart';
import 'leaderboard_page.dart';

class _Tier {
  final String name;
  final int min;
  final int max;
  final Color color;
  final IconData icon;
  final String benefit;
  const _Tier(this.name, this.min, this.max, this.color, this.icon, this.benefit);
}

const _tiers = [
  _Tier('Bronze', 0, 99, Color(0xFF8C6A3F), Icons.workspace_premium_rounded, 'Basic access to all papers'),
  _Tier('Silver', 100, 299, Color(0xFF6B7280), Icons.workspace_premium_rounded, 'Early access to new uploads'),
  _Tier('Gold', 300, 599, Color(0xFFD4A017), Icons.workspace_premium_rounded, 'Priority review + 1.5x points'),
  _Tier('Platinum', 600, 9999, Color(0xFF4A90B8), Icons.diamond_rounded, 'Exclusive badges + 2x points'),
];

_Tier _tierFor(int pts) =>
    _tiers.lastWhere((t) => pts >= t.min, orElse: () => _tiers.first);

class PointsPage extends StatelessWidget {
  const PointsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);
    final pts = appState.points;
    final tier = _tierFor(pts);
    final nextTier = _tiers.indexOf(tier) < _tiers.length - 1
        ? _tiers[_tiers.indexOf(tier) + 1]
        : null;
    final progress = nextTier == null
        ? 1.0
        : ((pts - tier.min) / (nextTier.min - tier.min)).clamp(0.0, 1.0);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          _PointsHeader(
            pts: pts,
            tier: tier,
            nextTier: nextTier,
            progress: progress,
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _TierRoadmap(currentPts: pts),
                const SizedBox(height: 32),
                _HowToEarnSection(),
                const SizedBox(height: 32),
                _LeaderboardSection(appState: appState),
                const SizedBox(height: 32),
                _RewardsSection(appState: appState),
                const SizedBox(height: 24),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _PointsHeader extends StatelessWidget {
  final int pts;
  final _Tier tier;
  final _Tier? nextTier;
  final double progress;

  const _PointsHeader({
    required this.pts,
    required this.tier,
    required this.nextTier,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SliverToBoxAdapter(
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 64, 24, 32),
        decoration: BoxDecoration(color: cs.primary),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: tier.color.withOpacity(0.25),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: tier.color.withOpacity(0.5)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(tier.icon, size: 14, color: Colors.white),
                  const SizedBox(width: 6),
                  Text(
                    tier.name,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Your Balance',
              style: GoogleFonts.inter(
                color: Colors.white.withOpacity(0.75),
                fontSize: 13,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$pts',
              style: GoogleFonts.manrope(
                color: Colors.white,
                fontSize: 60,
                fontWeight: FontWeight.w800,
                height: 1,
              ),
            ),
            Text(
              'academic points',
              style: GoogleFonts.inter(
                color: Colors.white.withOpacity(0.85),
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 28),
            if (nextTier != null) ...[
              Row(
                children: [
                  Text(
                    'Progress to ${nextTier!.name}',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${nextTier!.min - pts} pts to go',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  minHeight: 8,
                  backgroundColor: Colors.white.withOpacity(0.2),
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.diamond_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Platinum — Max tier reached!',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TierRoadmap extends StatelessWidget {
  final int currentPts;
  const _TierRoadmap({required this.currentPts});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tier Roadmap',
          style: GoogleFonts.manrope(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: cs.onSurface,
          ),
        ),
        const SizedBox(height: 14),
        Container(
          decoration: BoxDecoration(
            color: cs.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: cs.outlineVariant.withOpacity(0.2)),
          ),
          child: Column(
            children: _tiers.map((t) {
              final isCurrent = t == _tierFor(currentPts);
              final isAchieved = currentPts >= t.min;
              final isLast = t == _tiers.last;
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: isAchieved
                                ? t.color.withOpacity(0.15)
                                : cs.surfaceContainerHigh,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            t.icon,
                            size: 18,
                            color: isAchieved ? t.color : cs.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    t.name,
                                    style: GoogleFonts.manrope(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: isAchieved
                                          ? cs.onSurface
                                          : cs.onSurfaceVariant,
                                    ),
                                  ),
                                  if (isCurrent) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 7,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: cs.primary.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(5),
                                      ),
                                      child: Text(
                                        'Current',
                                        style: GoogleFonts.inter(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: cs.primary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              Text(
                                '${t.min}${t == _tiers.last ? '+' : '–${t.max}'} pts',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                t.benefit,
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: isAchieved ? cs.primary : cs.onSurfaceVariant,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isAchieved)
                          Icon(
                            Icons.check_circle_rounded,
                            color: t.color,
                            size: 20,
                          )
                        else
                          Icon(
                            Icons.lock_rounded,
                            color: cs.onSurfaceVariant.withOpacity(0.4),
                            size: 18,
                          ),
                      ],
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
        ),
      ],
    );
  }
}

class _HowToEarnSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final items = [
      {'icon': Icons.upload_file_rounded, 'title': 'Upload a Paper', 'points': '+50 pts', 'desc': 'Earn points when your paper is approved'},
      {'icon': Icons.verified_rounded, 'title': 'Get Verified', 'points': '+20 pts', 'desc': 'Complete your profile with institution'},
      {'icon': Icons.people_rounded, 'title': 'Refer a Friend', 'points': '+100 pts', 'desc': 'When they upload their first paper'},
      {'icon': Icons.local_fire_department_rounded, 'title': 'Daily Login', 'points': '+5 pts', 'desc': 'Open the app every day'},
      {'icon': Icons.star_rounded, 'title': 'Rate Papers', 'points': '+10 pts', 'desc': 'Help others by rating papers'},
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'How to Earn Points',
          style: GoogleFonts.manrope(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: cs.onSurface,
          ),
        ),
        const SizedBox(height: 14),
        Container(
          decoration: BoxDecoration(
            color: cs.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: cs.outlineVariant.withOpacity(0.2)),
          ),
          child: Column(
            children: items.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              final isLast = index == items.length - 1;
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: cs.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            item['icon'] as IconData,
                            size: 20,
                            color: cs.primary,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    item['title'] as String,
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: cs.onSurface,
                                    ),
                                  ),
                                  const Spacer(),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.green.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      item['points'] as String,
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.green,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                item['desc'] as String,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
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
        ),
      ],
    );
  }
}

class _LeaderboardSection extends StatelessWidget {
  final AppState appState;
  const _LeaderboardSection({required this.appState});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Leaderboard',
              style: GoogleFonts.manrope(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
            ),
            const Spacer(),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LeaderboardPage()),
                );
              },
              child: Text(
                'See All',
                style: GoogleFonts.inter(fontSize: 13, color: cs.primary),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: cs.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: cs.outlineVariant.withOpacity(0.2)),
          ),
          child: Column(
            children: appState.leaderboard.asMap().entries.map((e) {
              final i = e.key;
              final entry = e.value;
              final isLast = i == appState.leaderboard.length - 1;
              return Column(
                children: [
                  _LeaderboardRow(
                    rank: entry.rank,
                    name: entry.name,
                    pts: entry.points,
                  ),
                  if (!isLast)
                    Divider(
                      height: 1,
                      color: cs.outlineVariant.withOpacity(0.12),
                      indent: 16,
                      endIndent: 16,
                    ),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _LeaderboardRow extends StatelessWidget {
  final int rank;
  final String name;
  final int pts;
  const _LeaderboardRow({
    required this.rank,
    required this.name,
    required this.pts,
  });

  Color _medalColor() => switch (rank) {
    1 => const Color(0xFFD4A017),
    2 => const Color(0xFF9EA3A8),
    3 => const Color(0xFF8C6A3F),
    _ => Colors.transparent,
  };

  IconData _medalIcon() =>
      rank <= 3 ? Icons.emoji_events_rounded : Icons.remove_rounded;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isTop3 = rank <= 3;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: isTop3
                ? Icon(_medalIcon(), color: _medalColor(), size: 22)
                : Text(
                    '$rank',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
          ),
          const SizedBox(width: 12),
          CircleAvatar(
            radius: 17,
            backgroundColor: cs.primary.withOpacity(0.1),
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: GoogleFonts.manrope(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: cs.primary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              name,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: isTop3 ? FontWeight.w600 : FontWeight.w400,
                color: cs.onSurface,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isTop3
                  ? _medalColor().withOpacity(0.12)
                  : cs.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$pts pts',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isTop3 ? _medalColor() : cs.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RewardsSection extends StatelessWidget {
  final AppState appState;
  const _RewardsSection({required this.appState});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Redeem Points',
          style: GoogleFonts.manrope(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: cs.onSurface,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Exchange your points for exclusive benefits.',
          style: GoogleFonts.inter(fontSize: 13, color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 14),
        ...appState.rewards.map(
          (r) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _RewardCard(reward: r, appState: appState),
          ),
        ),
      ],
    );
  }
}

class _RewardCard extends StatelessWidget {
  final RewardItem reward;
  final AppState appState;
  const _RewardCard({required this.reward, required this.appState});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final canAfford = appState.points >= reward.costPoints;

    return Container(
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
            height: 44,
            decoration: BoxDecoration(
              color: cs.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(reward.icon, color: cs.primary, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reward.title,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                  ),
                ),
                Text(
                  reward.subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          reward.isRedeemed
              ? Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: cs.secondaryContainer.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Redeemed',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: cs.secondary,
                    ),
                  ),
                )
              : ElevatedButton(
                  onPressed: canAfford
                      ? () {
                          final ok = appState.redeemReward(reward);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                ok
                                    ? '${reward.title} redeemed!'
                                    : 'Not enough points.',
                              ),
                              backgroundColor: ok ? cs.secondary : cs.error,
                            ),
                          );
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: cs.primary,
                    disabledBackgroundColor: cs.surfaceContainerHigh,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    minimumSize: Size.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    textStyle: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  child: Text('${reward.costPoints} pts'),
                ),
        ],
      ),
    );
  }
}
