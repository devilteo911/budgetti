import 'package:budgetti/core/providers/providers.dart';
import 'package:budgetti/core/theme/app_theme.dart';
import 'package:budgetti/features/dashboard/widgets/budget_saturation_recap.dart';
import 'package:budgetti/features/dashboard/widgets/dashboard_skeletons.dart';
import 'package:budgetti/features/dashboard/widgets/summary_card.dart';
import 'package:budgetti/features/transactions/add_transaction_modal.dart';
import 'package:budgetti/core/widgets/skeleton.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountsAsync = ref.watch(accountsProvider);
    final userProfileAsync = ref.watch(userProfileProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          HapticFeedback.heavyImpact();
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: AppTheme.surfaceGrey,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            builder: (context) => const AddTransactionModal(),
          );
        },
        backgroundColor: AppTheme.primaryGreen,
        child: const Icon(Icons.add, color: AppTheme.backgroundBlack),
      ),
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

            final username = profile['username'] as String;
            
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
                
                // Use selected wallet or default to ALL (null)
            
                
                // Calculate balance based on selection
                double totalBalance;
                // Always show combined balance on Dashboard
                totalBalance = accounts.fold(0.0, (sum, acc) => sum + acc.balance);

                // Watch transactions for ALL accounts (ignore selectedWalletId on Dashboard)
                final transactionsAsync = ref.watch(transactionsProvider(null));
                
                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Padding(
                        padding: const EdgeInsets.only(bottom: 32.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Good Evening,",
                                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                        color: AppTheme.textGrey,
                                      ),
                                ),
                                Text(
                                  username,
                                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.textWhite,
                                      ),
                                ),
                              ],
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
                                child: const Icon(Icons.person, color: AppTheme.primaryGreen),
                              ),
                            ),
                          )
                      ],
                    ),
                  ),

                      // Summary Cards Row
                  transactionsAsync.when(
                    data: (transactions) {
                      final now = DateTime.now();
                          final currentMonth = now.month;
                          final currentYear = now.year;

                          // Monthly Expenses calculation
                          final monthlyExpenses = transactions
                              .where(
                                (t) =>
                                    t.date.month == currentMonth &&
                                    t.date.year == currentYear &&
                                    t.amount < 0,
                              )
                              .fold(0.0, (sum, t) => sum + t.amount.abs());

                      final last30Days = now.subtract(const Duration(days: 30));
                      final netFlow = transactions
                          .where((t) => t.date.isAfter(last30Days))
                          .fold(0.0, (sum, t) => sum + t.amount);
                      
                      final isPositive = netFlow >= 0;
                      final sign = isPositive ? "+" : "";
                      final isVisible = ref.watch(balanceVisibilityProvider);
                      
                          return Row(
                            children: [
                              Expanded(
                                child: SummaryCard(
                                  title: "Total Balance",
                                  amount: formatter.format(totalBalance),
                                  trend: "$sign${formatter.format(netFlow)}",
                                  isPositive: isPositive,
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
                                  amount: formatter.format(monthlyExpenses),
                                  trend: "This month",
                                  isPositive: false,
                                  isVisible: true,
                                ),
                              ),
                            ],
                      );
                    },
                        loading: () => ShimmerLoading(
                          child: Row(
                            children: const [
                              Expanded(child: SummaryCardSkeleton()),
                              SizedBox(width: 12),
                              Expanded(child: SummaryCardSkeleton()),
                            ],
                          ),
                        ),
                        error: (_, __) => Row(
                          children: [
                            Expanded(
                              child: SummaryCard(
                                title: "Total Balance",
                                amount: formatter.format(totalBalance),
                                trend: "Error",
                                isPositive: false,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(child: SizedBox()),
                          ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Budget Saturation recap
                  const BudgetSaturationRecap(),

                  const SizedBox(height: 32),
                  // Recent Transactions
                  if (accounts.isNotEmpty)
                    Consumer(
                      builder: (context, ref, child) {
                    
                        final transactionsAsync = ref.watch(transactionsProvider(null));
                        final categoriesAsync = ref.watch(categoriesProvider);
                        
                        return transactionsAsync.when(
                          data: (transactions) => categoriesAsync.when(
                            data: (categories) => Column(
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
                                    ...transactions.take(3).map((t) {
                                      final category = categories.firstWhere(
                                        (c) => c.name == t.category,
                                        orElse: () => categories.first,
                                      );
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
                            loading: () => const Center(child: CircularProgressIndicator()),
                            error: (_, __) => const SizedBox.shrink(),
                          ),
                          loading: () => ShimmerLoading(
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
                                ...List.generate(3, (index) => const TransactionItemSkeleton()),
                              ],
                            ),
                          ),
                          error: (e, s) => const SizedBox.shrink(),
                        );
                      },
                    ),
                ],
              ),
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
