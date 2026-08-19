import 'package:budgetti/core/l10n.dart';
import 'package:budgetti/core/providers/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class TransactionFilterSheet extends ConsumerWidget {
  const TransactionFilterSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final filters = ref.watch(transactionFiltersProvider);
    final notifier = ref.read(transactionFiltersProvider.notifier);
    final categories = ref.watch(categoriesProvider).value ?? const [];
    final tags = ref.watch(tagsProvider).value ?? const [];

    final range = filters.dateRange;
    final customLabel = range != null && !_isPredefined(range)
        ? '${DateFormat('dd MMM').format(range.start)} → ${DateFormat('dd MMM').format(range.end)}'
        : context.l10n.txCustom;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        4,
        20,
        16 + MediaQuery.of(context).viewPadding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  context.l10n.txFilters,
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              if (!filters.isEmpty)
                TextButton(
                  onPressed: () {
                    notifier.reset();
                    Navigator.pop(context);
                  },
                  child: Text(
                    context.l10n.txResetAll.toUpperCase(),
                    style: GoogleFonts.jetBrainsMono(
                      color: scheme.error,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.4,
                    ),
                  ),
                ),
            ],
          ),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  _SectionLabel(
                      context.l10n.txDateRange.toUpperCase()),
                  _ChipWrap(children: [
                    _Chip(
                      label: context.l10n.txAllTime,
                      selected: range == null,
                      onTap: () => notifier.setDateRange(null),
                    ),
                    _Chip(
                      label: context.l10n.txLast7Days,
                      selected: _isSameRange(range, _getRange(7)),
                      onTap: () => notifier.setDateRange(_getRange(7)),
                    ),
                    _Chip(
                      label: context.l10n.txLast30Days,
                      selected: _isSameRange(range, _getRange(30)),
                      onTap: () => notifier.setDateRange(_getRange(30)),
                    ),
                    _Chip(
                      label: customLabel,
                      selected: range != null && !_isPredefined(range),
                      onTap: () async {
                        // ponytail: the picker inherits the app theme — no
                        // per-sheet ColorScheme override to keep in sync.
                        final picked = await showDateRangePicker(
                          context: context,
                          initialDateRange: range,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) notifier.setDateRange(picked);
                      },
                    ),
                  ]),
                  const SizedBox(height: 20),
                  _SectionLabel(
                      context.l10n.txCategories.toUpperCase()),
                  _ChipWrap(children: [
                    for (final c in categories)
                      _Chip(
                        label: c.name,
                        accent: Color(c.colorHex),
                        selected: filters.categories.contains(c.name),
                        onTap: () => notifier.toggleCategory(c.name),
                      ),
                  ]),
                  const SizedBox(height: 20),
                  _SectionLabel(
                      context.l10n.commonTags.toUpperCase()),
                  _ChipWrap(children: [
                    for (final t in tags)
                      _Chip(
                        label: t.name,
                        accent: Color(t.colorHex),
                        selected: filters.tags.contains(t.name),
                        onTap: () => notifier.toggleTag(t.name),
                      ),
                  ]),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.l10n.txApplyFilters),
            ),
          ),
        ],
      ),
    );
  }

  DateTimeRange _getRange(int days) {
    final now = DateTime.now();
    return DateTimeRange(
      start: DateTime(now.year, now.month, now.day)
          .subtract(Duration(days: days - 1)),
      end: DateTime(now.year, now.month, now.day),
    );
  }

  bool _isSameRange(DateTimeRange? r1, DateTimeRange r2) {
    if (r1 == null) return false;
    return DateUtils.isSameDay(r1.start, r2.start) &&
        DateUtils.isSameDay(r1.end, r2.end);
  }

  bool _isPredefined(DateTimeRange range) =>
      _isSameRange(range, _getRange(7)) || _isSameRange(range, _getRange(30));
}

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: GoogleFonts.jetBrainsMono(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 2.2,
        ),
      ),
    );
  }
}

class _ChipWrap extends StatelessWidget {
  final List<Widget> children;

  const _ChipWrap({required this.children});

  @override
  Widget build(BuildContext context) {
    return Wrap(spacing: 8, runSpacing: 8, children: children);
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color? accent;
  final VoidCallback onTap;

  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = accent ?? scheme.primary;

    return Material(
      color: selected ? color.withValues(alpha: 0.10) : scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? color.withValues(alpha: 0.45) : Colors.transparent,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? color : scheme.onSurfaceVariant,
              fontSize: 12,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
