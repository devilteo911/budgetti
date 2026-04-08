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
import 'package:budgetti/features/settings/settings_screen.dart';
import 'package:budgetti/features/settings/appearance_screen.dart';
import 'package:budgetti/features/settings/preferences_screen.dart';
import 'package:budgetti/features/settings/integrations_screen.dart';
import 'package:budgetti/features/settings/categories_screen.dart';
import 'package:budgetti/features/settings/tags_screen.dart';
import 'package:budgetti/features/settings/wallets_screen.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/budgets',
        builder: (context, state) => const BudgetScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/bank-callback',
        builder: (context, state) {
          return const _BankCallbackScreen();
        },
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

class _BankCallbackScreen extends ConsumerStatefulWidget {
  const _BankCallbackScreen();

  @override
  ConsumerState<_BankCallbackScreen> createState() => _BankCallbackScreenState();
}

class _BankCallbackScreenState extends ConsumerState<_BankCallbackScreen> {
  @override
  void initState() {
    super.initState();
    _completeConnection();
  }

  Future<void> _completeConnection() async {
    try {
      final persistence = ref.read(persistenceServiceProvider);
      final ebService = ref.read(enableBankingServiceProvider);

      final sessionId = persistence.getEbSessionId();
      if (sessionId == null) {
        if (mounted) context.go('/profile');
        return;
      }

      // Poll session until linked
      final session = await ebService.getSession(sessionId);
      final accounts = session['accounts'] as List? ?? [];

      if (accounts.isNotEmpty) {
        final accountIds = accounts.map((a) => a['id'].toString()).toList();
        await persistence.setEbAccountIds(accountIds);
        await persistence.setEbIsLinked(true);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bank connected successfully!'),
            backgroundColor: Color(0xFF63E6BE),
          ),
        );
        context.go('/profile');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Connection error: $e'), backgroundColor: Colors.red),
        );
        context.go('/profile');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFF63E6BE)),
            SizedBox(height: 24),
            Text('Connecting to your bank...', style: TextStyle(color: Colors.white, fontSize: 18)),
          ],
        ),
      ),
    );
  }
}

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
