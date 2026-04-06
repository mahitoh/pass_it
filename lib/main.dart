import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';

import 'data/app_state.dart';
import 'data/supabase_backend.dart';
import 'screens/auth_page.dart';
import 'screens/onboarding_page.dart';
import 'theme/app_theme.dart';
import 'screens/home_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseBackend.instance.initialize();
  runApp(const PassItApp());
}

class PassItApp extends StatelessWidget {
  const PassItApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AppStateScope(
      notifier: AppState.instance,
      child: Builder(
        builder: (context) {
          final state = AppStateScope.of(context);
          return MaterialApp(
            title: 'Pass It - Exam Papers Portal',
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: state.themeMode,
            debugShowCheckedModeBanner: false,
            home: const _AuthGate(),
          );
        },
      ),
    );
  }
}

class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  Session? _session;
  StreamSubscription<AuthState>? _authSubscription;
  bool _isHydrating = true;
  bool _authReady = false;

  @override
  void initState() {
    super.initState();
    _authReady = SupabaseBackend.instance.isReady;
    _initAuthAndData();
  }

  Future<void> _initAuthAndData() async {
    if (_authReady) {
      _session = Supabase.instance.client.auth.currentSession;
      _authSubscription = Supabase.instance.client.auth.onAuthStateChange
          .listen((authState) {
            final nextSession = authState.session;
            final didSessionChange =
                nextSession?.accessToken != _session?.accessToken;
            _session = nextSession;

            if (!mounted) return;

            if (didSessionChange) {
              _hydrateForSession();
              return;
            }

            setState(() {});
          });
      await _hydrateForSession();
    } else {
      if (mounted) {
        setState(() {
          _session = null;
          _isHydrating = false;
        });
      }
    }
  }

  Future<void> _hydrateForSession() async {
    if (mounted) {
      setState(() => _isHydrating = true);
    }

    if (_session == null) {
      AppState.instance.clearForSignedOut();
      // Ensure onboarding is loaded even if logged out
      await AppState.instance.refreshData();
      if (mounted) {
        setState(() => _isHydrating = false);
      }
      return;
    }

    await AppState.instance
        .hydrateFromSupabase(SupabaseBackend.instance)
        .timeout(const Duration(seconds: 12), onTimeout: () {});

    if (mounted) {
      AppState.instance.onTierUp = (newTier) {
        _showTierUpDialog(context, newTier);
      };
      setState(() => _isHydrating = false);
    }
  }

  void _showTierUpDialog(BuildContext context, String newTier) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.celebration_rounded, size: 48, color: Colors.amber),
            ),
            const SizedBox(height: 20),
            Text(
              '🎉 Tier Up!',
              style: GoogleFonts.manrope(
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You\'ve reached $newTier tier!',
              style: GoogleFonts.inter(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Keep uploading to unlock more rewards!',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Awesome!'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final cs = Theme.of(context).colorScheme;

    if (_isHydrating) {
      return Scaffold(
        backgroundColor: AppTheme.primary,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/images/logo.png',
                height: 100,
              ),
              const SizedBox(height: 32),
              const CircularProgressIndicator(color: Colors.white),
            ],
          ),
        ),
      );
    }

    if (!state.hasSeenOnboarding) {
      return const OnboardingPage();
    }

    if (!_authReady || _session == null) {
      return const AuthPage();
    }

    return const HomePage();
  }
}
