import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  bool? _hasSeenOnboarding;

  @override
  void initState() {
    super.initState();
    _authReady = SupabaseBackend.instance.isReady;
    _checkOnboardingAndInit();
  }

  Future<void> _checkOnboardingAndInit() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeenOnboarding = prefs.getBool('has_seen_onboarding') ?? false;
    if (mounted) {
      setState(() {
        _hasSeenOnboarding = hasSeenOnboarding;
      });
    } else {
      _hasSeenOnboarding = hasSeenOnboarding;
    }

    if (_authReady) {
      _session = Supabase.instance.client.auth.currentSession;
      _authSubscription = Supabase.instance.client.auth.onAuthStateChange
          .listen((authState) {
            final nextSession = authState.session;
            final didSessionChange =
                nextSession?.accessToken != _session?.accessToken;
            _session = nextSession;

            if (!mounted) {
              return;
            }

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
      if (mounted) {
        setState(() => _isHydrating = false);
      }
      return;
    }

    await AppState.instance
        .hydrateFromSupabase(SupabaseBackend.instance)
        .timeout(const Duration(seconds: 12), onTimeout: () {});
    if (mounted) {
      setState(() => _isHydrating = false);
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasSeenOnboarding == false) {
      return const OnboardingPage();
    }

    if (_hasSeenOnboarding == null || _isHydrating) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!_authReady) {
      return const AuthPage();
    }

    if (_session == null) {
      return const AuthPage();
    }

    return const HomePage();
  }
}
