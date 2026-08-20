import 'package:budgetti/core/l10n.dart';
import 'package:budgetti/core/providers/providers.dart';
import 'package:budgetti/features/dashboard/widgets/dashboard_skeletons.dart';
import 'package:budgetti/features/dashboard/widgets/budget_overview_card.dart';
import 'package:budgetti/features/dashboard/widgets/installments_card.dart';
import 'package:budgetti/features/dashboard/widgets/dashboard_header.dart';
import 'package:budgetti/features/dashboard/widgets/dashboard_carousel.dart';
import 'package:budgetti/features/dashboard/widgets/dashboard_stat_grid.dart';
import 'package:budgetti/features/dashboard/widgets/recent_transactions_panel.dart';
import 'package:budgetti/core/widgets/skeleton.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    _checkPermissions();
    // Sync with Google Sheets on app start
    Future.microtask(() => performSheetsSync(ref));
  }

  Future<void> _checkPermissions() async {
    final persistence = ref.read(persistenceServiceProvider);
    final notificationService = ref.read(notificationServiceProvider);

    if (persistence.getNotificationsEnabled()) {
      final granted = await notificationService.isPermissionGranted();
      if (!granted) {
        await notificationService.requestPermissions();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accountsAsync = ref.watch(accountsProvider);
    final userProfileAsync = ref.watch(userProfileProvider);

    return Scaffold(
      body: SafeArea(
        child: userProfileAsync.when(
          loading: () => const ShimmerLoading(child: DashboardSkeleton()),
          error: (err, stack) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.cloud_off, size: 64, color: cs.onSurfaceVariant),
                const SizedBox(height: 16),
                Text(
                  context.l10n.dashConnectivityIssue,
                  style: TextStyle(
                    color: cs.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  context.l10n.dashConnectivityMessage,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => ref.invalidate(userProfileProvider),
                  child: Text(context.l10n.commonRetry),
                ),
              ],
            ),
          ),
          data: (profile) {
            // Check if profile exists, if not redirect to onboarding
            if (profile == null) {
              // Schedule redirect after build
              WidgetsBinding.instance.addPostFrameCallback((_) {
                 context.go('/onboarding');
              });
              return const Center(child: CircularProgressIndicator());
            }

            return accountsAsync.when(
              loading: () => const ShimmerLoading(child: DashboardSkeleton()),
              error: (err, stack) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.sync_problem,
                      size: 64,
                      color: cs.onSurfaceVariant,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      context.l10n.dashSyncFailed,
                      style: TextStyle(
                        color: cs.onSurface,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () => ref.invalidate(accountsProvider),
                      child: Text(context.l10n.commonRetry),
                    ),
                  ],
                ),
              ),
              data: (accounts) {
                if (accounts.isEmpty) {
                  return Center(
                    child: Text(
                      context.l10n.dashNoAccounts,
                      style: TextStyle(color: cs.onSurface),
                    ),
                  );
                }

                final dashboardStatsAsync = ref.watch(dashboardStatsProvider);

                return dashboardStatsAsync.when(
                  loading: () =>
                      const ShimmerLoading(child: DashboardSkeleton()),
                  error: (err, stack) => Center(
                      child: Text(context.l10n.dashErrorCalculatingStats)),
                  data: (stats) {
                    return SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 24,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const DashboardHeader(),
                          const DashboardCarousel(),
                          const SizedBox(height: 14),
                          const DashboardStatGrid(),
                          const BudgetOverviewCard(),
                          const InstallmentsCard(),
                          const SizedBox(height: 14),
                          RepaintBoundary(
                            child: RecentTransactionsPanel(
                              transactions: stats.recentTransactions,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }

}
