import 'dart:async';
import 'package:flutter/material.dart';
import 'package:budgetti/features/auth/login_screen.dart';
import 'package:budgetti/features/auth/onboarding_screen.dart';
import 'package:budgetti/features/dashboard/dashboard_screen.dart';
import 'package:budgetti/features/profile/profile_screen.dart';
import 'package:budgetti/features/home/scaffold_with_nav_bar.dart';
import 'package:budgetti/features/home/widgets/branch_animation_wrapper.dart';
import 'package:budgetti/features/transactions/transactions_screen.dart';
import 'package:budgetti/features/stats/stats_screen.dart';
import 'package:budgetti/features/budget/budget_screen.dart';
import 'package:budgetti/features/bank_sync/bank_sync_settings_screen.dart';
import 'package:budgetti/features/bank_sync/pending_transactions_screen.dart';
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
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/bank-sync-settings',
        builder: (context, state) => const BankSyncSettingsScreen(),
      ),
      GoRoute(
        path: '/pending-transactions',
        builder: (context, state) => const PendingTransactionsScreen(),
      ),
      // ShellRoute for Bottom Navigation
      StatefulShellRoute(
        builder: (context, state, navigationShell) {
          return ScaffoldWithNavBar(navigationShell: navigationShell);
        },
        navigatorContainerBuilder: (context, navigationShell, children) {
          return BranchAnimationWrapper(
            currentIndex: navigationShell.currentIndex,
            child: children[navigationShell.currentIndex],
          );
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/dashboard',
                builder: (context, state) => const DashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/transactions',
                builder: (context, state) => const TransactionsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/stats',
                builder: (context, state) => const StatsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/budgets',
                builder: (context, state) => const BudgetScreen(),
              ),
            ],
          ),
        ],
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
