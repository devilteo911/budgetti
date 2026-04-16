import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:budgetti/core/providers/providers.dart';
import 'package:budgetti/features/dashboard/widgets/carousel_card.dart';

class NetFlowCard extends ConsumerWidget {
  const NetFlowCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final statsAsync = ref.watch(dashboardStatsProvider);
    final formatter = ref.watch(currencyProvider);
    final isVisible = ref.watch(balanceVisibilityProvider);

    final stats = statsAsync.value;
    if (stats == null) {
      return const CarouselCard(
        icon: Icons.sync_alt_rounded,
        label: 'THIS MONTH',
        child: SizedBox.shrink(),
      );
    }

    final net = stats.monthlyNetFlow;
    final netPositive = net >= 0;
    final netColor = netPositive ? scheme.primary : scheme.error;

    final income = stats.monthlyIncome;
    final expenses = stats.monthlyExpenses;
    final total = income + expenses;
    final incomeRatio = total > 0 ? income / total : 0.5;

    String fmt(double v) => isVisible ? formatter.format(v) : "******";

    return CarouselCard(
      icon: Icons.sync_alt_rounded,
      label: 'THIS MONTH',
      trailing: Text(
        "${netPositive ? "+" : ""}${fmt(net)}",
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: netColor,
              letterSpacing: -0.4,
            ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Row(
            children: [
              Expanded(
                child: _FlowLine(
                  icon: Icons.arrow_downward_rounded,
                  label: "Income",
                  amount: fmt(income),
                  color: scheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _FlowLine(
                  icon: Icons.arrow_upward_rounded,
                  label: "Expenses",
                  amount: fmt(expenses),
                  color: scheme.error,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _ProportionBar(
            incomeRatio: incomeRatio,
            incomeColor: scheme.primary,
            expensesColor: scheme.error,
          ),
        ],
      ),
    );
  }
}

class _ProportionBar extends StatelessWidget {
  final double incomeRatio;
  final Color incomeColor;
  final Color expensesColor;

  const _ProportionBar({
    required this.incomeRatio,
    required this.incomeColor,
    required this.expensesColor,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: SizedBox(
        height: 5,
        child: Row(
          children: [
            Expanded(
              flex: (incomeRatio * 1000).round(),
              child: Container(color: incomeColor),
            ),
            const SizedBox(width: 2),
            Expanded(
              flex: ((1 - incomeRatio) * 1000).round(),
              child: Container(color: expensesColor),
            ),
          ],
        ),
      ),
    );
  }
}

class _FlowLine extends StatelessWidget {
  final IconData icon;
  final String label;
  final String amount;
  final Color color;

  const _FlowLine({
    required this.icon,
    required this.label,
    required this.amount,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                    fontSize: 11,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          amount,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              ),
        ),
      ],
    );
  }
}
