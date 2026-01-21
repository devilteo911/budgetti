import 'package:budgetti/core/providers/providers.dart';
import 'package:budgetti/core/theme/app_theme.dart';
import 'package:budgetti/features/dashboard/widgets/add_transaction_button.dart';
import 'package:budgetti/features/dashboard/widgets/dashboard_skeletons.dart';
import 'package:budgetti/features/dashboard/widgets/summary_card.dart';
import 'package:budgetti/core/widgets/skeleton.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

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
                const Icon(Icons.cloud_off, size: 64, color: AppTheme.textGrey),
                const SizedBox(height: 16),
                const Text(
                  "Connectivity Issue",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Unable to reach the server. Please check your connection.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.textGrey),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => ref.invalidate(userProfileProvider),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGreen,
                  ),
                  child: const Text(
                    "Retry",
                    style: TextStyle(color: AppTheme.backgroundBlack),
                  ),
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
                    const Icon(
                      Icons.sync_problem,
                      size: 64,
                      color: AppTheme.textGrey,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      "Sync Failed",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () => ref.invalidate(accountsProvider),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryGreen,
                      ),
                      child: const Text(
                        "Retry",
                        style: TextStyle(color: AppTheme.backgroundBlack),
                      ),
                    ),
                  ],
                ),
              ),
              data: (accounts) {
                if (accounts.isEmpty) {
                  return const Center(
                    child: Text(
                      "No accounts found",
                      style: TextStyle(color: Colors.white),
                    ),
                  );
                }

                final formatter = ref.watch(currencyProvider);
                final dashboardStatsAsync = ref.watch(dashboardStatsProvider);
                final categoryMap = ref.watch(categoryMapProvider);
                
                return dashboardStatsAsync.when(
                  loading: () =>
                      const ShimmerLoading(child: DashboardSkeleton()),
                  error: (err, stack) =>
                      Center(child: Text("Error calculating stats")),
                  data: (stats) {
                    final isVisible = ref.watch(balanceVisibilityProvider);

                    return SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 24,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header
                          Padding(
                            padding: const EdgeInsets.only(bottom: 32.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "budgetti",
                                  style: GoogleFonts.bricolageGrotesque(
                                    color: Colors.white,
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => context.push('/profile'),
                                  child: Hero(
                                    tag: 'profile-image',
                                    child: Container(
                                      decoration: const BoxDecoration(
                                        color: AppTheme.surfaceGreyLight,
                                        shape: BoxShape.circle,
                                      ),
                                      padding: const EdgeInsets.all(8),
                                      child: const Icon(
                                        Icons.person,
                                        color: AppTheme.primaryGreen,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Summary Cards Row
                          Row(
                            children: [
                              Expanded(
                                child: SummaryCard(
                                  title: "Total Balance",
                                  amount: formatter.format(stats.totalBalance),
                                  trend:
                                      "${stats.netFlow >= 0 ? "+" : ""}${formatter.format(stats.netFlow)}",
                                  isPositive: stats.netFlow >= 0,
                                  isVisible: isVisible,
                                  onToggleVisibility: () => ref
                                      .read(balanceVisibilityProvider.notifier)
                                      .toggle(),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: SummaryCard(
                                  title: "Monthly Expenses",
                                  amount: formatter.format(
                                    stats.monthlyExpenses,
                                  ),
                                  trend: "This month",
                                  isPositive: false,
                                  isVisible: true,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 32),

                          // Add New Transaction Button
                          const AddTransactionButton(),

                          const SizedBox(height: 32),
                          // Recent Transactions
                          RepaintBoundary(
                            child: Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          "Recent Transactions",
                                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                                fontWeight: FontWeight.bold,
                                                color: AppTheme.textWhite,
                                              ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                ...stats.recentTransactions.take(3).map((t) {
                                  final category =
                                      categoryMap[t.category] ??
                                      categoryMap.values.first;
                                      return _buildTransactionItem(
                                        context,
                                        t.description,
                                        t.category,
                                        formatter.format(t.amount.abs()),
                                        t.date,
                                        categoryIcon: IconData(category.iconCode, fontFamily: 'MaterialIcons'),
                                        categoryColor: Color(category.colorHex),
                                        isIncome: t.amount > 0,
                                      );
                                    }),
                                  ],
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

  Widget _buildTransactionItem(BuildContext context, String title, String subtitle, String amount, DateTime date,
      {required IconData categoryIcon, required Color categoryColor, bool isIncome = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: categoryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: categoryColor.withValues(alpha: 0.2), width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: categoryColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              categoryIcon,
              color: categoryColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16)),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(color: AppTheme.textGrey, fontSize: 14)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                isIncome ? "+$amount" : "-$amount",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isIncome ? AppTheme.primaryGreen : Colors.white,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "${date.day}/${date.month}",
                style: const TextStyle(color: AppTheme.textGrey, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
