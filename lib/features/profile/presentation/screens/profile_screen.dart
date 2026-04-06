import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../providers/profile_providers.dart';
import '../../../../providers/theme_mode_provider.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/pressable_scale.dart';
import '../../../../shared/widgets/scholar_points_badge.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  String? _displayName;

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(userProfileProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(context),
            Expanded(
              child: profileAsync.when(
                data: (profile) {
                  final name = _displayName ?? profile.displayName;
                  if (_displayName == null) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) {
                        setState(() => _displayName = profile.displayName);
                      }
                    });
                  }
                  return Column(
                    children: [
                      _buildProfileHeader(context, name, profile.university, profile.scholarPoints),
                      _buildRankCard(context, profile.rank),
                      const SizedBox(height: 12),
                      const Expanded(child: _ProfileTabs()),
                    ],
                  );
                },
                loading: () => const _ProfileSkeleton(),
                error: (err, stack) => Center(child: Text('Error: $err')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          Text('Profile', style: Theme.of(context).textTheme.displaySmall?.copyWith(fontSize: 20)),
          const Spacer(),
          PressableScale(
            onTap: _openSettingsSheet,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: const Icon(LucideIcons.settings, size: 18, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _openSettingsSheet() {
    final currentName = _displayName ?? 'Scholar';
    final controller = TextEditingController(text: currentName);
    ThemeMode selectedMode = ref.read(themeModeControllerProvider);

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Settings', style: Theme.of(context).textTheme.displaySmall?.copyWith(fontSize: 18)),
                  const SizedBox(height: 16),
                  _settingsSectionTitle('Appearance'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _modePill(
                        label: 'Dark',
                        isActive: selectedMode == ThemeMode.dark,
                        onTap: () {
                          setModalState(() => selectedMode = ThemeMode.dark);
                          ref.read(themeModeControllerProvider.notifier).setMode(ThemeMode.dark);
                        },
                      ),
                      const SizedBox(width: 12),
                      _modePill(
                        label: 'Light',
                        isActive: selectedMode == ThemeMode.light,
                        onTap: () {
                          setModalState(() => selectedMode = ThemeMode.light);
                          ref.read(themeModeControllerProvider.notifier).setMode(ThemeMode.light);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _settingsSectionTitle('Profile'),
                  const SizedBox(height: 8),
                  _settingsField(
                    label: 'Display name',
                    controller: controller,
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() => _displayName = controller.text.trim().isEmpty ? currentName : controller.text.trim());
                        Navigator.pop(context);
                        ScaffoldMessenger.of(this.context).showSnackBar(
                          const SnackBar(content: Text('Profile updated')),
                        );
                      },
                      child: const Text('Save Changes'),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _settingsSectionTitle(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
      ),
    );
  }

  Widget _modePill({
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: PressableScale(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isActive ? AppColors.primary : AppColors.background,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: isActive ? AppColors.primary : AppColors.border),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isActive ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _settingsField({
    required String label,
    required TextEditingController controller,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: TextField(
            controller: controller,
            decoration: const InputDecoration(
              border: InputBorder.none,
              hintText: 'Enter display name',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileHeader(BuildContext context, String name, String university, int points) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
      child: Row(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(LucideIcons.userRound, size: 36, color: Colors.white),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: Theme.of(context).textTheme.displaySmall?.copyWith(fontSize: 22)),
                const SizedBox(height: 6),
                Text(university, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary)),
                const SizedBox(height: 10),
                ScholarPointsBadge(points: points),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRankCard(BuildContext context, int rank) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: const Icon(LucideIcons.trophy, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Leaderboard Rank', style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 4),
                Text('#$rank', style: Theme.of(context).textTheme.displaySmall?.copyWith(fontSize: 20)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileTabs extends StatefulWidget {
  const _ProfileTabs();

  @override
  State<_ProfileTabs> createState() => _ProfileTabsState();
}

class _ProfileTabsState extends State<_ProfileTabs> with SingleTickerProviderStateMixin {
  late TabController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: TabBar(
            controller: _controller,
            indicator: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            labelColor: Colors.white,
            unselectedLabelColor: AppColors.textSecondary,
            tabs: const [
              Tab(text: 'My Uploads'),
              Tab(text: 'Downloaded'),
              Tab(text: 'Bookmarks'),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: TabBarView(
            controller: _controller,
            children: const [
              _EmptyTab(message: 'No uploads yet.'),
              _EmptyTab(message: 'No downloads yet.'),
              _EmptyTab(message: 'No bookmarks yet.'),
            ],
          ),
        ),
      ],
    );
  }
}

class _EmptyTab extends StatelessWidget {
  final String message;
  const _EmptyTab({required this.message});

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      title: 'Nothing here',
      message: message,
    );
  }
}

class _ProfileSkeleton extends StatelessWidget {
  const _ProfileSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(width: 120, height: 18, color: Colors.white10),
          const SizedBox(height: 16),
          Container(width: double.infinity, height: 100, color: Colors.white10),
          const SizedBox(height: 16),
          Container(width: double.infinity, height: 80, color: Colors.white10),
        ],
      ),
    );
  }
}
