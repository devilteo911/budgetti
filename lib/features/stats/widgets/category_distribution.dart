import 'package:budgetti/core/l10n.dart';
import 'package:budgetti/core/theme/ledger_style.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

/// Stacked distribution bar + legend. Keys in [sortedEntries] are names
/// (category or tag); [colorMap] resolves each to its ink.
class CategoryDistribution extends StatefulWidget {
  final List<MapEntry<String, double>> sortedEntries;
  final Map<String, Color> colorMap;
  final double total;
  final NumberFormat currencyFormatter;

  const CategoryDistribution({
    super.key,
    required this.sortedEntries,
    required this.colorMap,
    required this.total,
    required this.currencyFormatter,
  });

  @override
  State<CategoryDistribution> createState() => _CategoryDistributionState();
}

class _CategoryDistributionState extends State<CategoryDistribution> {
  int? _focused;

  @override
  Widget build(BuildContext context) {
    if (widget.sortedEntries.isEmpty || widget.total <= 0) {
      return const SizedBox.shrink();
    }

    final scheme = Theme.of(context).colorScheme;
    final resolved = widget.sortedEntries
        .map((e) => _ResolvedEntry(
              entry: e,
              color: widget.colorMap[e.key] ?? unknownCategoryInk(scheme),
            ))
        .toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StackedBar(
            entries: resolved,
            total: widget.total,
            focused: _focused,
            onTap: (i) => setState(() => _focused = _focused == i ? null : i),
          ),
          const SizedBox(height: 18),
          _Legend(
            entries: resolved,
            total: widget.total,
            focused: _focused,
            currencyFormatter: widget.currencyFormatter,
            onTap: (i) => setState(() => _focused = _focused == i ? null : i),
          ),
        ],
      ),
    );
  }
}

class _ResolvedEntry {
  final MapEntry<String, double> entry;
  final Color color;
  _ResolvedEntry({
    required this.entry,
    required this.color,
  });
  double get value => entry.value;
  String get name => entry.key;
}

class _StackedBar extends StatelessWidget {
  final List<_ResolvedEntry> entries;
  final double total;
  final int? focused;
  final void Function(int) onTap;

  const _StackedBar({
    required this.entries,
    required this.total,
    required this.focused,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (context, t, _) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 18,
            child: Row(
              children: [
                for (var i = 0; i < entries.length; i++) ...[
                  Expanded(
                    flex: ((entries[i].value / total) * 10000).round(),
                    child: GestureDetector(
                      onTap: () => onTap(i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        color: entries[i].color.withValues(
                          alpha: focused == null
                              ? 0.95 * t
                              : (focused == i ? 1.0 : 0.25) * t,
                        ),
                      ),
                    ),
                  ),
                  if (i < entries.length - 1) const SizedBox(width: 2),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Legend extends StatelessWidget {
  final List<_ResolvedEntry> entries;
  final double total;
  final int? focused;
  final NumberFormat currencyFormatter;
  final void Function(int) onTap;

  const _Legend({
    required this.entries,
    required this.total,
    required this.focused,
    required this.currencyFormatter,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const maxItems = 6;
    final visible = entries.take(maxItems).toList();
    final overflow = entries.length - visible.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 18,
          runSpacing: 12,
          children: [
            for (var i = 0; i < visible.length; i++)
              SizedBox(
                width: (MediaQuery.of(context).size.width - 40 - 18) / 2,
                child: _LegendItem(
                  entry: visible[i],
                  total: total,
                  dimmed: focused != null && focused != i,
                  currencyFormatter: currencyFormatter,
                  onTap: () => onTap(i),
                ),
              ),
          ],
        ),
        if (overflow > 0) ...[
          const SizedBox(height: 12),
          Text(
            context.l10n.statsMore(overflow),
            style: GoogleFonts.jetBrainsMono(
              color: scheme.onSurfaceVariant,
              fontSize: 11,
              fontWeight: FontWeight.w500,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  final _ResolvedEntry entry;
  final double total;
  final bool dimmed;
  final NumberFormat currencyFormatter;
  final VoidCallback onTap;

  const _LegendItem({
    required this.entry,
    required this.total,
    required this.dimmed,
    required this.currencyFormatter,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final pct = (entry.value / total * 100);
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 220),
      opacity: dimmed ? 0.35 : 1.0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 6),
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: entry.color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '${pct.toStringAsFixed(0)}%',
                          style: GoogleFonts.jetBrainsMono(
                            color: scheme.onSurface,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            entry.name,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: scheme.onSurface,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      currencyFormatter.format(entry.value),
                      style: GoogleFonts.jetBrainsMono(
                        color: scheme.onSurfaceVariant,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
