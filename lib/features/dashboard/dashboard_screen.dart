import 'package:budgetti/core/providers/providers.dart';
import 'package:budgetti/core/theme/app_theme.dart';
import 'package:budgetti/features/dashboard/widgets/spending_chart.dart';
import 'package:budgetti/features/dashboard/widgets/summary_card.dart';
import 'package:budgetti/features/transactions/add_transaction_modal.dart';
import 'package:flutter/material.dart';
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
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: AppTheme.surfaceGrey,
            builder: (context) => const AddTransactionModal(),
          );
        },
        backgroundColor: AppTheme.primaryGreen,
        child: const Icon(Icons.add, color: AppTheme.backgroundBlack),
      ),
      body: SafeArea(
        child: userProfileAsync.when(
          loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen)),
          error: (err, stack) => Center(child: Text('Error: $err')),
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
              loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen)),
              error: (err, stack) => Center(child: Text('Error: $err', style: const TextStyle(color: Colors.red))),
              data: (accounts) {
                final totalBalance = accounts.fold(0.0, (sum, acc) => sum + acc.balance);
                final formatter = ref.watch(currencyProvider);

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
                            child: Container(
                              decoration: const BoxDecoration(
                                color: AppTheme.surfaceGreyLight,
                                shape: BoxShape.circle,
                              ),
                              padding: const EdgeInsets.all(8),
                              child: const Icon(Icons.person, color: AppTheme.primaryGreen),
                            ),
                          )
                      ],
                    ),
                  ),

                  // Summary Card
                  SummaryCard(
                    title: "Total Balance",
                    amount: formatter.format(totalBalance),
                    trend: "+12% vs last month",
                    isPositive: true,
                  ),
                  const SizedBox(height: 32),

                  // Chart
                  Text(
                    "Activity",
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textWhite,
                        ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    height: 250,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceGrey,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: accounts.isNotEmpty 
                      ? Consumer(
                          builder: (context, ref, child) {
                             final transactionsAsync = ref.watch(transactionsProvider(accounts.first.id));
                             return transactionsAsync.when(
                               data: (transactions) => SpendingChart(transactions: transactions),
                               loading: () => const Center(child: CircularProgressIndicator()),
                               error: (_, __) => const Center(child: Text("Error loading chart")),
                             );
                          }
                        )
                      : const Center(child: Text("No accounts")),
                  ),

                  const SizedBox(height: 32),
                  // Recent Transactions Mock (Should be real mostly)
                  // We'll just fetch transactions for the first account for now
                  if (accounts.isNotEmpty)
                    Consumer(
                      builder: (context, ref, child) {
                        final transactionsAsync = ref.watch(transactionsProvider(accounts.first.id));
                        return transactionsAsync.when(
                            data: (transactions) => Column(
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
                                        TextButton(
                                          onPressed: () {},
                                          child: const Text("See All"),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    ...transactions.map((t) => _buildTransactionItem(
                                          context,
                                          t.description,
                                          t.category,
                                          formatter.format(t.amount.abs()),
                                          t.date,
                                          isIncome: t.amount > 0,
                                        )),
                                  ],
                                ),
                            loading: () => const Center(child: Padding(
                              padding: EdgeInsets.all(8.0),
                              child: CircularProgressIndicator(),
                            )),
                            error: (e, s) => const SizedBox.shrink());
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
      {bool isIncome = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceGrey,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.surfaceGreyLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isIncome ? Icons.arrow_downward : Icons.shopping_bag,
              color: isIncome ? AppTheme.primaryGreen : Colors.white,
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
