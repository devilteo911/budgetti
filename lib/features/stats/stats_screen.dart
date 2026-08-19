import 'package:budgetti/core/l10n.dart';
import 'package:budgetti/core/providers/providers.dart';
import 'package:budgetti/core/theme/ledger_style.dart';
import 'package:budgetti/models/category.dart';
import 'package:budgetti/features/stats/category_details_screen.dart';
import 'package:budgetti/features/stats/widgets/category_distribution.dart';
import 'package:budgetti/features/stats/widgets/category_row.dart';
import 'package:budgetti/features/stats/widgets/monthly_row.dart';
import 'package:budgetti/features/stats/widgets/section_label.dart';
import 'package:budgetti/features/stats/widgets/stagger.dart';
import 'package:budgetti/features/stats/widgets/stats_filter_bar.dart';
import 'package:budgetti/features/stats/widgets/stats_hero.dart';
import 'package:budgetti/features/charts/widgets/spending_line_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

/// What the DISTRIBUTION and BREAKDOWN sections slice expenses by.
enum _StatsDimension { categories, tags }

class StatsScreen extends ConsumerStatefulWidget {
  const StatsScreen({super.key});

  @override
  ConsumerState<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends ConsumerState<StatsScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entrance;
  _StatsDimension _dimension = _StatsDimension.categories;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    )..forward();
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  void _replay() {
    _entrance
      ..reset()
      ..forward();
  }

  void _openCategoryDetails(String name) {
    final category = ref.read(categoryMapProvider)[name] ??
        Category(
          id: '',
          userId: '',
          name: name,
          iconCode: Icons.help_outline.codePoint,
          colorHex: 0xFF9E9E9E,
          type: 'expense',
        );
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => CategoryDetailsScreen(category: category)),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(selectedStatsPeriodProvider, (_, __) => _replay());
    ref.listen(statsScopeProvider, (_, __) => _replay());

    final scheme = Theme.of(context).colorScheme;
    final period = ref.watch(selectedStatsPeriodProvider);
    final statsAsync = ref.watch(statsDataProvider(period));
    final categoryMap = ref.watch(categoryMapProvider);
    final currencyFormatter = ref.watch(currencyProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.l10n.statsTitle,
          style: GoogleFonts.jetBrainsMono(
            color: scheme.onSurface,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
      ),
      body: statsAsync.when(
        loading: () => Center(
          child: CircularProgressIndicator(color: scheme.primary),
        ),
        error: (err, _) =>
            Center(child: Text(context.l10n.statsError(err.toString()))),
        data: (stats) {
          final isEmpty =
              stats.categoryTotals.isEmpty && stats.monthlyBreakdown.isEmpty;
          final totalExpenses = stats.totalExpenses;
          final isTags = _dimension == _StatsDimension.tags;
          final sortedEntries = (isTags ? stats.tagTotals : stats.categoryTotals)
              .entries
              .toList()
            ..sort((a, b) => b.value.compareTo(a.value));
          final tagColors = ref.watch(tagColorCacheProvider);
          final catColors =
              ref.watch(categoryColorCacheProvider(scheme.brightness));
          final catIcons = ref.watch(categoryIconCacheProvider);
          final colorMap = isTags ? tagColors : catColors;
          final iconFor = isTags
              ? (String _) => Icons.sell_outlined
              : (String name) => catIcons[name] ??
                  categoryIcon(
                    name,
                    iconCode: categoryMap[name]?.iconCode,
                  );

          return CustomScrollView(
            slivers: [
              const SliverToBoxAdapter(child: StatsFilterBar()),
              if (isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _EmptyState(period: period),
                )
              else ...[
                Stagger(
                  controller: _entrance,
                  begin: 0.00,
                  end: 0.55,
                  child: const SliverToBoxAdapter(child: StatsHero()),
                ),
                SliverToBoxAdapter(
                  child: _DimensionToggle(
                    value: _dimension,
                    onChanged: (d) {
                      if (d == _dimension) return;
                      setState(() => _dimension = d);
                      _replay();
                    },
                  ),
                ),
                if (sortedEntries.isNotEmpty) ...[
                  Stagger(
                    controller: _entrance,
                    begin: 0.10,
                    end: 0.65,
                    child: SliverToBoxAdapter(
                      child: SectionLabel(
                        text: context.l10n.statsDistribution.toUpperCase(),
                        count: sortedEntries.length,
                      ),
                    ),
                  ),
                  Stagger(
                    controller: _entrance,
                    begin: 0.15,
                    end: 0.75,
                    child: SliverToBoxAdapter(
                      child: CategoryDistribution(
                        sortedEntries: sortedEntries,
                        colorMap: colorMap,
                        total: totalExpenses,
                        currencyFormatter: currencyFormatter,
                      ),
                    ),
                  ),
                ] else ...[
                  const SliverToBoxAdapter(
                    child: _NoTagsHint(),
                  ),
                ],
                Stagger(
                  controller: _entrance,
                  begin: 0.25,
                  end: 0.80,
                  child: SliverToBoxAdapter(
                    child: SectionLabel(
                        text: context.l10n.statsTrends.toUpperCase()),
                  ),
                ),
                Stagger(
                  controller: _entrance,
                  begin: 0.30,
                  end: 0.85,
                  child: const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: SpendingLineChart(),
                    ),
                  ),
                ),
                if (sortedEntries.isNotEmpty) ...[
                  Stagger(
                    controller: _entrance,
                    begin: 0.35,
                    end: 0.90,
                    child: SliverToBoxAdapter(
                      child: SectionLabel(
                          text: context.l10n.statsBreakdown.toUpperCase()),
                    ),
                  ),
                  Stagger(
                    controller: _entrance,
                    begin: 0.40,
                    end: 0.95,
                    child: _BreakdownSliver(
                      sortedEntries: sortedEntries,
                      colorMap: colorMap,
                      iconFor: iconFor,
                      total: totalExpenses,
                      currencyFormatter: currencyFormatter,
                      onTap: isTags
                          ? null
                          : (name) => _openCategoryDetails(name),
                    ),
                  ),
                ],
                if (period.month == null &&
                    stats.monthlyBreakdown.isNotEmpty) ...[
                  Stagger(
                    controller: _entrance,
                    begin: 0.45,
                    end: 1.0,
                    child: SliverToBoxAdapter(
                      child: SectionLabel(
                          text: context.l10n.statsLedgerMonthly.toUpperCase()),
                    ),
                  ),
                  Stagger(
                    controller: _entrance,
                    begin: 0.50,
                    end: 1.0,
                    child: _MonthlySliver(
                      monthlyData: stats.monthlyBreakdown,
                      currencyFormatter: currencyFormatter,
                    ),
                  ),
                ],
                const SliverToBoxAdapter(child: SizedBox(height: 32)),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _BreakdownSliver extends StatelessWidget {
  final List<MapEntry<String, double>> sortedEntries;
  final Map<String, Color> colorMap;
  final IconData Function(String name) iconFor;
  final double total;
  final NumberFormat currencyFormatter;
  final void Function(String name)? onTap;

  const _BreakdownSliver({
    required this.sortedEntries,
    required this.colorMap,
    required this.iconFor,
    required this.total,
    required this.currencyFormatter,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final entry = sortedEntries[index];
          final isLast = index == sortedEntries.length - 1;
          return Column(
            children: [
              CategoryRow(
                rank: index + 1,
                name: entry.key,
                color: colorMap[entry.key] ?? unknownCategoryInk(scheme),
                icon: iconFor(entry.key),
                amount: entry.value,
                total: total,
                currencyFormatter: currencyFormatter,
                onTap: onTap == null ? null : () => onTap!(entry.key),
              ),
              if (!isLast)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    height: 1,
                    color: scheme.outlineVariant.withValues(alpha: 0.18),
                  ),
                ),
            ],
          );
        },
        childCount: sortedEntries.length,
      ),
    );
  }
}

/// Stadium pill pair switching the breakdown dimension. Matches the
/// StatsFilterBar chip styling so the two rows read as one family.
class _DimensionToggle extends StatelessWidget {
  final _StatsDimension value;
  final ValueChanged<_StatsDimension> onChanged;

  const _DimensionToggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Row(
        children: [
          for (var i = 0; i < _StatsDimension.values.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            _ToggleSegment(
              label: switch (_StatsDimension.values[i]) {
                _StatsDimension.categories =>
                  context.l10n.statsCategories,
                _StatsDimension.tags => context.l10n.commonTags,
              },
              selected: _StatsDimension.values[i] == value,
              onTap: () => onChanged(_StatsDimension.values[i]),
            ),
          ],
        ],
      ),
    );
  }
}

class _ToggleSegment extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ToggleSegment({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = selected ? scheme.primary : scheme.surfaceContainerHigh;
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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _NoTagsHint extends StatelessWidget {
  const _NoTagsHint();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Text(
        context.l10n.statsNoTagsHint,
        style: TextStyle(
          color: scheme.onSurfaceVariant,
          fontSize: 13,
          height: 1.4,
        ),
      ),
    );
  }
}

class _MonthlySliver extends StatelessWidget {
  final Map<String, Map<String, double>> monthlyData;
  final NumberFormat currencyFormatter;

  const _MonthlySliver({
    required this.monthlyData,
    required this.currencyFormatter,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final sortedMonths = monthlyData.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final monthKey = sortedMonths[index];
          final data = monthlyData[monthKey]!;
          final displayMonth = DateFormat('MMMM yyyy')
              .format(DateTime.parse('$monthKey-01'));
          final isLast = index == sortedMonths.length - 1;
          return Column(
            children: [
              MonthlyRow(
                month: displayMonth,
                earned: data['earned'] ?? 0.0,
                spent: data['spent'] ?? 0.0,
                currencyFormatter: currencyFormatter,
              ),
              if (!isLast)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    height: 1,
                    color: scheme.outlineVariant.withValues(alpha: 0.18),
                  ),
                ),
            ],
          );
        },
        childCount: sortedMonths.length,
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final StatsPeriod period;
  const _EmptyState({required this.period});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final label = period.month != null
        ? DateFormat('MMMM yyyy').format(DateTime(period.year, period.month!))
        : '${period.year}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 48, 32, 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '—',
            style: GoogleFonts.jetBrainsMono(
              color: scheme.onSurfaceVariant,
              fontSize: 72,
              fontWeight: FontWeight.w300,
              height: 0.8,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            context.l10n.statsNoActivity.toUpperCase(),
            style: GoogleFonts.jetBrainsMono(
              color: scheme.onSurfaceVariant,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 2.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.statsNothingRecorded(label),
            style: TextStyle(
              color: scheme.onSurface,
              fontSize: 17,
              fontWeight: FontWeight.w500,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            context.l10n.statsTryAnotherPeriod,
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
