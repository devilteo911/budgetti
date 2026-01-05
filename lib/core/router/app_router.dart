import 'dart:async';
import 'package:flutter/material.dart';
import 'package:budgetti/features/auth/login_screen.dart';
import 'package:budgetti/features/auth/onboarding_screen.dart';
import 'package:budgetti/features/dashboard/dashboard_screen.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/dashboard',
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/dashboard',
        builder: (context, state) => const DashboardScreen(),
      ),
    ],
    redirect: (context, state) {
      final session = Supabase.instance.client.auth.currentSession;
      final isLoggingIn = state.uri.toString() == '/login';
      
      if (session == null && !isLoggingIn) return '/login';
      if (session != null && isLoggingIn) return '/dashboard';
      
      // We will handle profile check inside Dashboard for now to avoid async redirect complexity
      // or we could use a text check if we had the profile loaded in memory.
      
      return null;
    },
    refreshListenable: GoRouterRefreshStream(Supabase.instance.client.auth.onAuthStateChange),
  );
});

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<AuthState> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen(
      (dynamic _) => notifyListeners(),
    );
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
