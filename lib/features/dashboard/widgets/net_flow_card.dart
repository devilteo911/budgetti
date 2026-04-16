import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:budgetti/core/providers/providers.dart';

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
      return const SizedBox.shrink();
    }

    final net = stats.monthlyNetFlow;
    final netPositive = net >= 0;
    final netColor = netPositive ? scheme.primary : scheme.error;

    String fmt(double v) => isVisible ? formatter.format(v) : "******";

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                "This Month",
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              Text(
                "${netPositive ? "+" : ""}${fmt(net)}",
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: netColor,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _FlowLine(
                  icon: Icons.arrow_downward_rounded,
                  label: "Income",
                  amount: fmt(stats.monthlyIncome),
                  color: scheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _FlowLine(
                  icon: Icons.arrow_upward_rounded,
                  label: "Expenses",
                  amount: fmt(stats.monthlyExpenses),
                  color: scheme.error,
                ),
              ),
            ],
          ),
        ],
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
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          amount,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: scheme.onSurface,
              ),
        ),
      ],
    );
  }
}
