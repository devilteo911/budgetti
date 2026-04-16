import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:budgetti/core/providers/providers.dart';
import 'package:budgetti/features/dashboard/widgets/carousel_card.dart';
import 'package:budgetti/features/dashboard/widgets/summary_card.dart';
import 'package:budgetti/features/dashboard/widgets/net_flow_card.dart';

class DashboardCarousel extends ConsumerStatefulWidget {
  const DashboardCarousel({super.key});

  @override
  ConsumerState<DashboardCarousel> createState() => _DashboardCarouselState();
}

class _DashboardCarouselState extends ConsumerState<DashboardCarousel> {
  final _controller = PageController(viewportFraction: 0.93);
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
              const _PageSlot(child: NetFlowCard()),
              _PageSlot(
                child: SummaryCard(
                  title: "Total Balance",
                  amount:
                      stats != null ? formatter.format(stats.totalBalance) : "—",
                  trend: stats != null
                      ? "${stats.netFlow >= 0 ? "+" : ""}${formatter.format(stats.netFlow)} · 30d"
                      : "",
                  isPositive: (stats?.netFlow ?? 0) >= 0,
                  isVisible: isVisible,
                  onToggleVisibility: () =>
                      ref.read(balanceVisibilityProvider.notifier).toggle(),
                ),
              ),
              const _PageSlot(child: _WalletsRecapCard()),
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
              height: 5,
              width: active ? 16 : 5,
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

class _PageSlot extends StatelessWidget {
  final Widget child;
  const _PageSlot({required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: child,
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

    return accountsAsync.when(
      loading: () => CarouselCard(
        icon: Icons.layers_rounded,
        label: 'WALLETS',
        child: Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: scheme.primary,
          ),
        ),
      ),
      error: (_, __) => CarouselCard(
        icon: Icons.layers_rounded,
        label: 'WALLETS',
        child: Center(
          child: Text(
            "Couldn't load wallets",
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
        ),
      ),
      data: (accounts) {
        if (accounts.isEmpty) {
          return CarouselCard(
            icon: Icons.layers_rounded,
            label: 'WALLETS',
            child: Center(
              child: Text(
                "No wallets yet",
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: 13,
                ),
              ),
            ),
          );
        }

        final visibleCount = accounts.length > 3 ? 2 : accounts.length;
        final visible = accounts.take(visibleCount).toList();
        final overflow = accounts.length - visibleCount;

        return CarouselCard(
          icon: Icons.layers_rounded,
          label: 'WALLETS',
          trailing: Text(
            '${accounts.length}',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisAlignment: accounts.length == 1
                ? MainAxisAlignment.center
                : MainAxisAlignment.start,
            children: [
              for (int i = 0; i < visible.length; i++) ...[
                _WalletRow(
                  account: visible[i],
                  formatter: formatter,
                  isVisible: isVisible,
                  onTap: () {
                    ref
                        .read(selectedWalletIdProvider.notifier)
                        .set(visible[i].id);
                    context.go('/transactions');
                  },
                ),
                if (i < visible.length - 1 || overflow > 0)
                  const SizedBox(height: 8),
              ],
              if (overflow > 0)
                GestureDetector(
                  onTap: () => context.go('/transactions'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.add_rounded,
                          size: 13,
                          color: scheme.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$overflow more',
                          style: TextStyle(
                            color: scheme.primary,
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _WalletRow extends StatelessWidget {
  final dynamic account;
  final dynamic formatter;
  final bool isVisible;
  final VoidCallback onTap;

  const _WalletRow({
    required this.account,
    required this.formatter,
    required this.isVisible,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final negative = account.balance < 0;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: negative
                    ? scheme.error.withValues(alpha: 0.7)
                    : scheme.primary.withValues(alpha: 0.7),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                account.name,
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
              isVisible ? formatter.format(account.balance) : "******",
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: negative ? scheme.error : scheme.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
