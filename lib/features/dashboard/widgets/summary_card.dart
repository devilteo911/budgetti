import 'package:budgetti/core/providers/providers.dart';
import 'package:budgetti/core/widgets/skeleton.dart';
import 'package:budgetti/features/dashboard/widgets/carousel_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SummaryCard extends ConsumerWidget {
  final String title;
  final String amount;
  final String trend;
  final bool isPositive;
  final bool isVisible;
  final VoidCallback? onToggleVisibility;

  const SummaryCard({
    super.key,
    required this.title,
    required this.amount,
    required this.trend,
    this.isPositive = true,
    this.isVisible = true,
    this.onToggleVisibility,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final trendColor = isPositive ? scheme.primary : scheme.error;
    final series = ref.watch(monthlyNetFlowHistoryProvider);

    return CarouselCard(
      icon: Icons.account_balance_wallet_rounded,
      label: title.toUpperCase(),
      onLongPress: onToggleVisibility == null
          ? null
          : () {
              HapticFeedback.mediumImpact();
              onToggleVisibility?.call();
            },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            isVisible ? amount : "******",
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: scheme.onSurface,
                  letterSpacing: -0.8,
                  height: 1.1,
                ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Visibility(
                  visible: isVisible,
                  maintainSize: true,
                  maintainAnimation: true,
                  maintainState: true,
                  child: SizedBox(
                    height: 36,
                    child: _Sparkline(
                      values: series,
                      positiveColor: scheme.primary,
                      negativeColor: scheme.error,
                      muted: scheme.onSurfaceVariant.withValues(alpha: 0.45),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Visibility(
                visible: isVisible,
                maintainSize: true,
                maintainAnimation: true,
                maintainState: true,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: trendColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    trend,
                    style: TextStyle(
                      color: trendColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Sparkline extends StatelessWidget {
  final List<double> values;
  final Color positiveColor;
  final Color negativeColor;
  final Color muted;

  const _Sparkline({
    required this.values,
    required this.positiveColor,
    required this.negativeColor,
    required this.muted,
  });

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) {
      return const SizedBox.shrink();
    }
    return LayoutBuilder(
      builder: (ctx, c) {
        final n = values.length;
        final maxAbs = values.fold<double>(
          0,
          (m, v) => v.abs() > m ? v.abs() : m,
        );
        if (maxAbs == 0) return const SizedBox.shrink();

        final barW = (c.maxWidth - (n - 1) * 3) / n;
        return Row(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            for (int i = 0; i < n; i++) ...[
              if (i > 0) const SizedBox(width: 3),
              SizedBox(
                width: barW,
                height: c.maxHeight,
                child: _SparkBar(
                  value: values[i],
                  maxAbs: maxAbs,
                  isLast: i == n - 1,
                  positiveColor: positiveColor,
                  negativeColor: negativeColor,
                  muted: muted,
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class SummaryCardSkeleton extends StatelessWidget {
  const SummaryCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Skeleton(height: 20, width: 20, borderRadius: 10),
              SizedBox(width: 8),
              Skeleton(height: 10, width: 100),
            ],
          ),
          const SizedBox(height: 16),
          const Skeleton(height: 28, width: 160, borderRadius: 8),
          const SizedBox(height: 20),
          Row(
            children: const [
              Expanded(child: Skeleton(height: 20, borderRadius: 4)),
              SizedBox(width: 10),
              Skeleton(height: 20, width: 80, borderRadius: 20),
            ],
          ),
        ],
      ),
    );
  }
}

class _SparkBar extends StatelessWidget {
  final double value;
  final double maxAbs;
  final bool isLast;
  final Color positiveColor;
  final Color negativeColor;
  final Color muted;

  const _SparkBar({
    required this.value,
    required this.maxAbs,
    required this.isLast,
    required this.positiveColor,
    required this.negativeColor,
    required this.muted,
  });

  @override
  Widget build(BuildContext context) {
    final fill = isLast
        ? (value >= 0 ? positiveColor : negativeColor)
        : muted;
    final ratio = (value.abs() / maxAbs).clamp(0.05, 1.0);

    return Align(
      alignment: Alignment.bottomCenter,
      child: FractionallySizedBox(
        heightFactor: ratio,
        child: Container(
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}
