import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_page.dart';
import '../data/app_state.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  late final AnimationController _mainController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  final List<Map<String, String>> _pages = [
    {
      'title': 'Find Any Past Paper',
      'body': 'Access thousands of past exams from premium universities and institutions securely. Pass your next exam with excellence.',
      'icon': 'search',
    },
    {
      'title': 'Upload & Earn Points',
      'body': 'Contribute to the academic community by sharing exams. Earn points on every verified upload and unlock premium features.',
      'icon': 'upload',
    },
    {
      'title': 'Rank & Rewards',
      'body': 'Ascend the tiers from Bronze to Diamond. Get recognized as a top contributor and redeem your hard-earned points.',
      'icon': 'trophy',
    },
  ];

  @override
  void initState() {
    super.initState();
    _mainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.4, 1.0, curve: Curves.easeOutCubic),
    ));

    _mainController.forward();
  }

  @override
  void dispose() {
    _mainController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  IconData _getIcon(String key) {
    switch (key) {
      case 'upload': return Icons.cloud_upload_rounded;
      case 'trophy': return Icons.emoji_events_rounded;
      case 'search':
      default: return Icons.travel_explore_rounded;
    }
  }

  Future<void> _completeOnboarding() async {
    await AppStateScope.of(context).setHasSeenOnboarding(true);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: Row(
                      children: [
                        Image.asset('assets/images/logo.png', height: 24),
                        const SizedBox(width: 8),
                        Text(
                          'Pass It',
                          style: GoogleFonts.manrope(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                            color: cs.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: _completeOnboarding,
                    child: Text(
                      'Skip',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (idx) {
                  setState(() => _currentIndex = idx);
                  _mainController.reset();
                  _mainController.forward();
                },
                itemCount: _pages.length,
                itemBuilder: (context, index) {
                  final page = _pages[index];
                  return FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 200,
                              height: 200,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: cs.primaryContainer.withValues(alpha: isDark ? 0.2 : 0.1),
                              ),
                              child: Center(
                                child: Container(
                                  width: 140,
                                  height: 140,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(
                                      colors: [cs.primary, cs.primaryContainer],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: cs.primary.withValues(alpha: 0.3),
                                        blurRadius: 20,
                                        offset: const Offset(0, 10),
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    _getIcon(page['icon']!),
                                    size: 60,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 60),
                            Text(
                              page['title']!,
                              style: GoogleFonts.manrope(
                                fontSize: 32,
                                fontWeight: FontWeight.w800,
                                color: cs.onSurface,
                                letterSpacing: -1,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 20),
                            Text(
                              page['body']!,
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                color: cs.onSurfaceVariant,
                                height: 1.6,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(32),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: List.generate(
                      _pages.length,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 400),
                        margin: const EdgeInsets.only(right: 8),
                        width: _currentIndex == index ? 32 : 12,
                        height: 6,
                        decoration: BoxDecoration(
                          color: _currentIndex == index ? cs.primary : cs.outlineVariant.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: _currentIndex == _pages.length - 1
                        ? ElevatedButton(
                            key: const ValueKey('finish'),
                            onPressed: _completeOnboarding,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: cs.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              elevation: 4,
                            ),
                            child: Text(
                              'Get Started',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          )
                        : Container(
                            key: const ValueKey('next'),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: cs.primary,
                              boxShadow: [
                                BoxShadow(
                                  color: cs.primary.withValues(alpha: 0.3),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: IconButton(
                              onPressed: () {
                                _pageController.nextPage(
                                  duration: const Duration(milliseconds: 600),
                                  curve: Curves.easeInOutCubic,
                                );
                              },
                              icon: const Icon(
                                Icons.arrow_forward_rounded,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

