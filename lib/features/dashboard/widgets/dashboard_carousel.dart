import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:budgetti/core/providers/providers.dart';
import 'package:budgetti/features/dashboard/widgets/summary_card.dart';
import 'package:budgetti/features/dashboard/widgets/net_flow_card.dart';

class DashboardCarousel extends ConsumerStatefulWidget {
  const DashboardCarousel({super.key});

  @override
  ConsumerState<DashboardCarousel> createState() => _DashboardCarouselState();
}

class _DashboardCarouselState extends ConsumerState<DashboardCarousel> {
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final statsAsync = ref.watch(dashboardStatsProvider);
    final formatter = ref.watch(currencyProvider);
    final isVisible = ref.watch(balanceVisibilityProvider);
    final stats = statsAsync.value;

    return Column(
      children: [
        SizedBox(
          height: 168,
          child: PageView(
            controller: _controller,
            onPageChanged: (i) => setState(() => _page = i),
            children: [
              const NetFlowCard(),
              SummaryCard(
                title: "Total Balance",
                amount: stats != null ? formatter.format(stats.totalBalance) : "—",
                trend: stats != null
                    ? "${stats.netFlow >= 0 ? "+" : ""}${formatter.format(stats.netFlow)} · 30d"
                    : "",
                isPositive: (stats?.netFlow ?? 0) >= 0,
                isVisible: isVisible,
                onToggleVisibility: () =>
                    ref.read(balanceVisibilityProvider.notifier).toggle(),
              ),
              const _WalletsRecapCard(),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (i) {
            final active = i == _page;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              height: 6,
              width: active ? 18 : 6,
              decoration: BoxDecoration(
                color: active
                    ? scheme.primary
                    : scheme.onSurfaceVariant.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(3),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _WalletsRecapCard extends ConsumerWidget {
  const _WalletsRecapCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final accountsAsync = ref.watch(accountsProvider);
    final formatter = ref.watch(currencyProvider);
    final isVisible = ref.watch(balanceVisibilityProvider);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(24),
      ),
      child: accountsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        error: (_, __) => Text(
          "Couldn't load wallets",
          style: TextStyle(color: scheme.onSurfaceVariant),
        ),
        data: (accounts) {
          if (accounts.isEmpty) {
            return Text(
              "No wallets",
              style: TextStyle(color: scheme.onSurfaceVariant),
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Wallets",
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  Text(
                    "${accounts.length}",
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.separated(
                  padding: EdgeInsets.zero,
                  itemCount: accounts.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (context, i) {
                    final acc = accounts[i];
                    final negative = acc.balance < 0;
                    return InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () {
                        ref.read(selectedWalletIdProvider.notifier).set(acc.id);
                        context.go('/transactions');
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                acc.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: scheme.onSurface,
                                      fontWeight: FontWeight.w500,
                                    ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              isVisible ? formatter.format(acc.balance) : "******",
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: negative ? scheme.error : scheme.onSurface,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
