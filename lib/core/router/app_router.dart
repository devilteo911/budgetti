import 'dart:async';
import 'package:flutter/material.dart';
import 'package:budgetti/features/auth/login_screen.dart';
import 'package:budgetti/features/auth/onboarding_screen.dart';
import 'package:budgetti/features/auth/sync_setup_screen.dart';
import 'package:budgetti/features/dashboard/dashboard_screen.dart';
import 'package:budgetti/features/profile/profile_screen.dart';
import 'package:budgetti/features/home/scaffold_with_nav_bar.dart';
import 'package:budgetti/features/home/widgets/branch_animation_wrapper.dart';
import 'package:budgetti/features/transactions/transactions_screen.dart';
import 'package:budgetti/features/transactions/email_inbox_screen.dart';
import 'package:budgetti/features/stats/stats_screen.dart';
import 'package:budgetti/features/budget/budget_screen.dart';
import 'package:budgetti/features/installments/installments_screen.dart';
import 'package:budgetti/features/settings/settings_screen.dart';
import 'package:budgetti/features/settings/appearance_screen.dart';
import 'package:budgetti/features/settings/preferences_screen.dart';
import 'package:budgetti/features/settings/integrations_screen.dart';
import 'package:budgetti/features/settings/categories_screen.dart';
import 'package:budgetti/features/settings/tags_screen.dart';
import 'package:budgetti/features/settings/wallets_screen.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:budgetti/core/providers/providers.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/dashboard',
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/budgets',
        builder: (context, state) => const BudgetScreen(),
      ),
      GoRoute(
        path: '/installments',
        builder: (context, state) => const InstallmentsScreen(),
      ),
      GoRoute(
        path: '/review-inbox',
        builder: (context, state) => const EmailInboxScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/sync-setup',
        builder: (context, state) => const SyncSetupScreen(),
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
                path: '/settings',
                builder: (context, state) => const SettingsScreen(),
                routes: [
                  GoRoute(
                    path: 'profile',
                    builder: (context, state) => const ProfileScreen(),
                  ),
                  GoRoute(
                    path: 'categories',
                    builder: (context, state) => const CategoriesScreen(),
                  ),
                  GoRoute(
                    path: 'tags',
                    builder: (context, state) => const TagsScreen(),
                  ),
                  GoRoute(
                    path: 'wallets',
                    builder: (context, state) => const WalletsScreen(),
                  ),
                  GoRoute(
                    path: 'appearance',
                    builder: (context, state) => const AppearanceScreen(),
                  ),
                  GoRoute(
                    path: 'preferences',
                    builder: (context, state) => const PreferencesScreen(),
                  ),
                  GoRoute(
                    path: 'integrations',
                    builder: (context, state) => const IntegrationsScreen(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
    redirect: (context, state) {
      final auth = ref.read(authServiceProvider);
      final loc = state.uri.toString();
      final isAuthRoute = loc == '/login' || loc == '/onboarding';

      // Not logged in → must authenticate (offline, a persisted session keeps
      // isValid true, so this only fires on first run / after logout).
      if (!auth.isLoggedIn && !isAuthRoute) return '/login';
      // Fresh login (still sitting on /login): decide how this device and the
      // server line up first; the sync-setup screen then forwards to
      // onboarding (no username yet) or the dashboard.
      if (auth.isLoggedIn && (loc == '/login')) {
        final p = ref.read(persistenceServiceProvider);
        if (p.getServerUrl().isNotEmpty) return '/sync-setup';
        return p.getUsername().isNotEmpty ? '/dashboard' : '/onboarding';
      }
      return null;
    },
    refreshListenable: GoRouterRefreshStream(ref.read(authServiceProvider).changes),
  );
});

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<void> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final StreamSubscription<void> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
