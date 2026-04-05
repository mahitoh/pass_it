import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../features/auth/presentation/screens/auth_screen.dart';
import '../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../features/papers/presentation/screens/search_screen.dart';
import '../../features/papers/presentation/screens/upload_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/papers/presentation/screens/paper_details_screen.dart';
import '../models/paper_model.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

class AppRouter {
  static final router = GoRouter(
    initialLocation: '/auth',
    navigatorKey: _rootNavigatorKey,
    routes: [
      GoRoute(
        path: '/auth',
        name: 'auth',
        builder: (context, state) => const AuthScreen(),
      ),
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) {
          return ScaffoldWithBottomNavBar(child: child);
        },
        routes: [
          GoRoute(
            path: '/',
            name: 'dashboard',
            pageBuilder: (context, state) => CustomTransitionPage(
              child: const DashboardScreen(),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                return _buildTransition(animation, child);
              },
            ),
          ),
          GoRoute(
            path: '/search',
            name: 'search',
            pageBuilder: (context, state) => CustomTransitionPage(
              child: const SearchScreen(),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                return _buildTransition(animation, child);
              },
            ),
          ),
          GoRoute(
            path: '/upload',
            name: 'upload',
            pageBuilder: (context, state) => CustomTransitionPage(
              child: const UploadScreen(),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                return _buildTransition(animation, child);
              },
            ),
          ),
          GoRoute(
            path: '/profile',
            name: 'profile',
            pageBuilder: (context, state) => CustomTransitionPage(
              child: const ProfileScreen(),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                return _buildTransition(animation, child);
              },
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/paper-details',
        name: 'paper-details',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) {
          final paper = state.extra as Paper;
          return CustomTransitionPage(
            child: PaperDetailsScreen(paper: paper),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return _buildTransition(animation, child);
            },
          );
        },
      ),
    ],
  );

  static Widget _buildTransition(Animation<double> animation, Widget child) {
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.05, 0.0),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
        child: child,
      ),
    );
  }
}

class ScaffoldWithBottomNavBar extends StatelessWidget {
  final Widget child;
  const ScaffoldWithBottomNavBar({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    final selectedIndex = _calculateSelectedIndex(location);

    return Scaffold(
      body: child,
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF161525),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white10),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(77),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _NavItem(
                  icon: LucideIcons.house,
                  label: 'Home',
                  isActive: selectedIndex == 0,
                  onTap: () => _onItemTapped(0, context),
                ),
                _NavItem(
                  icon: LucideIcons.search,
                  label: 'Search',
                  isActive: selectedIndex == 1,
                  onTap: () => _onItemTapped(1, context),
                ),
                _NavItem(
                  icon: LucideIcons.upload,
                  label: 'Upload',
                  isActive: selectedIndex == 2,
                  onTap: () => _onItemTapped(2, context),
                ),
                _NavItem(
                  icon: LucideIcons.userRound,
                  label: 'Profile',
                  isActive: selectedIndex == 3,
                  onTap: () => _onItemTapped(3, context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  int _calculateSelectedIndex(String location) {
    if (location == '/') return 0;
    if (location == '/search') return 1;
    if (location == '/upload') return 2;
    if (location == '/profile') return 3;
    return 0;
  }

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0:
        context.goNamed('dashboard');
        break;
      case 1:
        context.goNamed('search');
        break;
      case 2:
        context.goNamed('upload');
        break;
      case 3:
        context.goNamed('profile');
        break;
    }
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? Colors.white10 : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: isActive ? Border.all(color: Colors.white24) : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 20,
              color: isActive ? Colors.white : Colors.white60,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isActive ? Colors.white : Colors.white60,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
