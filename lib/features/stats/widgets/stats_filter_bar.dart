import 'package:budgetti/core/providers/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

/// GitHub-Store search-style filter bar for the stats screen.
///
/// Layout:
///   1. Top: segmented FilterChip row for transaction scope (All / Expenses / Income).
///   2. Below: horizontally-scrolling row of "labeled clusters" — a small label
///      ("View", "Period") next to a FilterChip showing the current value with
///      a dropdown caret. Active (non-default) clusters get a mint highlight
///      and an inline × button to clear back to default.
///
/// Tapping a cluster chip opens a bottom sheet with the full picker.
class StatsFilterBar extends ConsumerWidget {
  const StatsFilterBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: const _ClusterRow(),
    );
  }
}

String _scopeLabel(StatsScope s) => switch (s) {
      StatsScope.all => 'All',
      StatsScope.expenses => 'Expenses',
      StatsScope.income => 'Income',
    };

class _ClusterRow extends ConsumerWidget {
  const _ClusterRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(selectedStatsPeriodProvider);
    final scope = ref.watch(statsScopeProvider);
    final isMonthlyMode = period.month != null;
    final now = DateTime.now();

    final viewLabel = isMonthlyMode ? 'Month' : 'Year';
    final periodValue = isMonthlyMode
        ? DateFormat('MMM yyyy').format(DateTime(period.year, period.month!))
        : '${period.year}';

    final periodIsNonDefault = period.year != now.year ||
        (isMonthlyMode && period.month != now.month);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _LabeledCluster(
            value: _scopeLabel(scope),
            selected: scope != StatsScope.all,
            onTap: () => _openScopeSheet(context, ref, scope),
          ),
          const SizedBox(width: 10),
          _LabeledCluster(
            value: viewLabel,
            selected: false,
            onTap: () => _openViewSheet(context, ref, isMonthlyMode),
          ),
          const SizedBox(width: 10),
          _LabeledCluster(
            value: periodValue,
            selected: periodIsNonDefault,
            onClear: periodIsNonDefault
                ? () {
                    final notifier =
                        ref.read(selectedStatsPeriodProvider.notifier);
                    notifier.setYear(now.year);
                    if (isMonthlyMode) notifier.setMonth(now.month);
                  }
                : null,
            onTap: () => _openPeriodSheet(context, ref, period),
          ),
        ],
      ),
    );
  }
}

class _LabeledCluster extends StatelessWidget {
  final String value;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  const _LabeledCluster({
    required this.value,
    required this.selected,
    required this.onTap,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _GhsFilterChip(
          label: value,
          selected: selected,
          trailingIcon: Icons.keyboard_arrow_down,
          onTap: onTap,
        ),
        if (onClear != null)
          IconButton(
            visualDensity: VisualDensity.compact,
            iconSize: 18,
            icon: Icon(Icons.close, color: scheme.onSurfaceVariant),
            onPressed: onClear,
          ),
      ],
    );
  }
}

class _GhsFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final IconData? trailingIcon;
  final VoidCallback onTap;

  const _GhsFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.trailingIcon,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg =
        selected ? scheme.primary : scheme.surfaceContainerHigh;
    final fg = selected ? scheme.onPrimary : scheme.onSurface;
    final border = selected
        ? scheme.primary
        : scheme.outlineVariant.withValues(alpha: 0.4);

    return Material(
      color: bg,
      shape: StadiumBorder(side: BorderSide(color: border)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: trailingIcon == null ? 14 : 12,
            vertical: 8,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: fg,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (trailingIcon != null) ...[
                const SizedBox(width: 4),
                Icon(trailingIcon, size: 16, color: fg),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

void _openScopeSheet(
  BuildContext context,
  WidgetRef ref,
  StatsScope current,
) {
  showModalBottomSheet(
    useRootNavigator: true,
    context: context,
    showDragHandle: true,
    builder: (sheetCtx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final s in StatsScope.values)
            ListTile(
              title: Text(_scopeLabel(s)),
              trailing: s == current ? const Icon(Icons.check) : null,
              onTap: () {
                ref.read(statsScopeProvider.notifier).set(s);
                Navigator.pop(sheetCtx);
              },
            ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

void _openViewSheet(
  BuildContext context,
  WidgetRef ref,
  bool isMonthlyMode,
) {
  showModalBottomSheet(
    useRootNavigator: true,
    context: context,
    showDragHandle: true,
    builder: (sheetCtx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.calendar_today),
            title: const Text('Year'),
            trailing: !isMonthlyMode ? const Icon(Icons.check) : null,
            onTap: () {
              ref.read(selectedStatsPeriodProvider.notifier).setMonth(null);
              ref
                  .read(chartGranularityProvider.notifier)
                  .set(ChartGranularity.monthly);
              Navigator.pop(sheetCtx);
            },
          ),
          ListTile(
            leading: const Icon(Icons.calendar_view_month),
            title: const Text('Month'),
            trailing: isMonthlyMode ? const Icon(Icons.check) : null,
            onTap: () {
              ref
                  .read(selectedStatsPeriodProvider.notifier)
                  .setMonth(DateTime.now().month);
              ref
                  .read(chartGranularityProvider.notifier)
                  .set(ChartGranularity.daily);
              Navigator.pop(sheetCtx);
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

void _openPeriodSheet(
  BuildContext context,
  WidgetRef ref,
  StatsPeriod current,
) {
  final now = DateTime.now();
  final isMonthlyMode = current.month != null;
  final years = List.generate(6, (i) => now.year - i);

  showModalBottomSheet(
    useRootNavigator: true,
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    useSafeArea: true,
    constraints: BoxConstraints(
      minWidth: MediaQuery.of(context).size.width,
      maxWidth: MediaQuery.of(context).size.width,
    ),
    builder: (sheetCtx) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 12, left: 4),
                child: Text(
                  'Year',
                  style: Theme.of(sheetCtx).textTheme.labelLarge,
                ),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: years.map((y) {
                  final selected = y == current.year;
                  return FilterChip(
                    label: Text('$y'),
                    selected: selected,
                    onSelected: (_) {
                      ref
                          .read(selectedStatsPeriodProvider.notifier)
                          .setYear(y);
                      if (!isMonthlyMode) Navigator.pop(sheetCtx);
                    },
                  );
                }).toList(),
              ),
              if (isMonthlyMode) ...[
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.only(bottom: 12, left: 4),
                  child: Text(
                    'Month',
                    style: Theme.of(sheetCtx).textTheme.labelLarge,
                  ),
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: List.generate(12, (i) {
                    final m = i + 1;
                    final selected = m == current.month;
                    final isFuture = current.year == now.year && m > now.month;
                    return FilterChip(
                      label: Text(
                        DateFormat('MMM').format(DateTime(current.year, m)),
                      ),
                      selected: selected,
                      onSelected: isFuture
                          ? null
                          : (_) {
                              ref
                                  .read(selectedStatsPeriodProvider.notifier)
                                  .setMonth(m);
                              Navigator.pop(sheetCtx);
                            },
                    );
                  }),
                ),
              ],
            ],
          ),
        ),
      );
    },
  );
}
