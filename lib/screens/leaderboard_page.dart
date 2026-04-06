import 'package:flutter/material.dart';
import '../data/app_state.dart';

class LeaderboardPage extends StatelessWidget {
  const LeaderboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final leaderboard = state.leaderboard;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Top Contributors'),
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.primaryContainer,
                    Theme.of(context).colorScheme.primary,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(32),
                  bottomRight: Radius.circular(32),
                ),
              ),
              child: Column(
                children: [
                   Icon(
                    Icons.emoji_events,
                    size: 64,
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Academic Legends',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Be among the top 10 contributors this month to earn exclusive rewards.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.8),
                        ),
                  ),
                ],
              ),
            ),
          ),
          const SliverPadding(padding: EdgeInsets.all(12)),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final entry = leaderboard[index];
                final isSelf = entry.name == state.userName;

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Card(
                    elevation: isSelf ? 2 : 0,
                    shadowColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                    color: isSelf 
                      ? Theme.of(context).colorScheme.primary.withOpacity(0.05)
                      : Theme.of(context).colorScheme.surfaceContainerLow,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: isSelf 
                        ? BorderSide(color: Theme.of(context).colorScheme.primary.withOpacity(0.3), width: 1.5)
                        : BorderSide.none,
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      leading: _RankBadge(rank: entry.rank),
                      title: Text(
                        entry.name,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: isSelf ? FontWeight.bold : FontWeight.w600,
                            ),
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${entry.points}',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          Text(
                            'Points',
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
              childCount: leaderboard.length,
            ),
          ),
        ],
      ),
    );
  }
}

class _RankBadge extends StatelessWidget {
  final int rank;
  const _RankBadge({required this.rank});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (rank) {
      case 1: color = const Color(0xFFFFD700); break; // Gold
      case 2: color = const Color(0xFFC0C0C0); break; // Silver
      case 3: color = const Color(0xFFCD7F32); break; // Bronze
      default: color = Theme.of(context).colorScheme.outlineVariant;
    }

    if (rank <= 3) {
      return Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Text(
          '$rank',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      );
    } else {
      return Container(
        width: 32,
        alignment: Alignment.center,
        child: Text(
          '$rank',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
        ),
      );
    }
  }
}
