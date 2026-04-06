import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_page.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  final List<Map<String, String>> _pages = [
    {
      'title': 'Find Any Past Paper',
      'body': 'Access thousands of past exams securely. Pass your next exam with flying colors.',
      'icon': 'search',
    },
    {
      'title': 'Upload & Earn',
      'body': 'Contribute to the community by uploading exams you have. Earn points on every verified upload.',
      'icon': 'upload',
    },
    {
      'title': 'Rank & Rewards',
      'body': 'Ascend the tiers from Bronze to Diamond. Get recognized as a top contributor and redeem rewards.',
      'icon': 'trophy',
    },
  ];

  IconData _getIcon(String key) {
    switch (key) {
      case 'upload': return Icons.cloud_upload_rounded;
      case 'trophy': return Icons.emoji_events_rounded;
      case 'search':
      default: return Icons.travel_explore_rounded;
    }
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_onboarding', true);
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const AuthPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: _completeOnboarding,
                child: Text('Skip', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: cs.onSurfaceVariant)),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (idx) => setState(() => _currentIndex = idx),
                itemCount: _pages.length,
                itemBuilder: (context, index) {
                  final page = _pages[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: cs.primaryContainer,
                          ),
                          child: Icon(_getIcon(page['icon']!), size: 70, color: cs.primary),
                        ),
                        const SizedBox(height: 60),
                        Text(
                          page['title']!,
                          style: GoogleFonts.manrope(fontSize: 28, fontWeight: FontWeight.w800, color: cs.onSurface),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        Text(
                          page['body']!,
                          style: GoogleFonts.inter(fontSize: 16, color: cs.onSurfaceVariant, height: 1.5),
                          textAlign: TextAlign.center,
                        ),
                      ],
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
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.only(right: 8),
                        width: _currentIndex == index ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _currentIndex == index ? cs.primary : cs.outlineVariant.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                  _currentIndex == _pages.length - 1
                      ? ElevatedButton(
                          onPressed: _completeOnboarding,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: cs.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: Text('Get Started', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700)),
                        )
                      : Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: cs.primary,
                          ),
                          child: IconButton(
                            onPressed: () {
                              _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic);
                            },
                            icon: const Icon(Icons.arrow_forward_rounded, color: Colors.white),
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
