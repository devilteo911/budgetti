import 'package:budgetti/core/providers/providers.dart';
import 'package:budgetti/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TransactionFilterSheet extends ConsumerWidget {
  const TransactionFilterSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filters = ref.watch(transactionFiltersProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final tagsAsync = ref.watch(tagsProvider);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: AppTheme.backgroundBlack,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Filters",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: () {
                  ref.read(transactionFiltersProvider.notifier).reset();
                  Navigator.pop(context);
                },
                child: const Text(
                  "Reset All",
                  style: TextStyle(color: Colors.redAccent),
                ),
              ),
            ],
          ),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 24),
                  // Date Filter
                  const Text(
                    "Date Range",
                    style: TextStyle(color: AppTheme.textGrey, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [
                      _FilterChip(
                        label: "All Time",
                        isSelected: filters.dateRange == null,
                        onSelected: (_) => ref.read(transactionFiltersProvider.notifier).setDateRange(null),
                      ),
                      _FilterChip(
                        label: "Last 7 Days",
                        isSelected: _isSameRange(filters.dateRange, _getRange(7)),
                        onSelected: (_) => ref.read(transactionFiltersProvider.notifier).setDateRange(_getRange(7)),
                      ),
                      _FilterChip(
                        label: "Last 30 Days",
                        isSelected: _isSameRange(filters.dateRange, _getRange(30)),
                        onSelected: (_) => ref.read(transactionFiltersProvider.notifier).setDateRange(_getRange(30)),
                      ),
                      _FilterChip(
                        label: "Custom",
                        isSelected: filters.dateRange != null && !_isPredefined(filters.dateRange!),
                        onSelected: (_) async {
                          final range = await showDateRangePicker(
                            context: context,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now(),
                            builder: (context, child) => Theme(
                              data: Theme.of(context).copyWith(
                                colorScheme: const ColorScheme.dark(
                                  primary: AppTheme.primaryGreen,
                                  onPrimary: AppTheme.backgroundBlack,
                                  surface: AppTheme.surfaceGrey,
                                  onSurface: Colors.white,
                                ),
                              ),
                              child: child!,
                            ),
                          );
                          if (range != null) {
                            ref.read(transactionFiltersProvider.notifier).setDateRange(range);
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Categories Filter
                  const Text(
                    "Categories",
                    style: TextStyle(color: AppTheme.textGrey, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  categoriesAsync.when(
                    data: (categories) => Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: categories.map((category) {
                        final isSelected = filters.categories.contains(category.name);
                        return FilterChip(
                          label: Text(category.name),
                          selected: isSelected,
                          onSelected: (_) => ref.read(transactionFiltersProvider.notifier).toggleCategory(category.name),
                          backgroundColor: AppTheme.surfaceGrey,
                          selectedColor: AppTheme.primaryGreen.withValues(alpha: 0.3),
                          checkmarkColor: AppTheme.primaryGreen,
                          labelStyle: TextStyle(
                            color: isSelected ? AppTheme.primaryGreen : Colors.white,
                            fontSize: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(
                              color: isSelected ? AppTheme.primaryGreen : Colors.transparent,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    loading: () => const LinearProgressIndicator(color: AppTheme.primaryGreen),
                    error: (_, __) => const Text("Error loading categories", style: TextStyle(color: Colors.red)),
                  ),
                  const SizedBox(height: 24),

                  // Tags Filter
                  const Text(
                    "Tags",
                    style: TextStyle(color: AppTheme.textGrey, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  tagsAsync.when(
                    data: (tags) => Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: tags.map((tag) {
                        final isSelected = filters.tags.contains(tag.name);
                        return FilterChip(
                          label: Text(tag.name),
                          selected: isSelected,
                          onSelected: (_) => ref.read(transactionFiltersProvider.notifier).toggleTag(tag.name),
                          backgroundColor: AppTheme.surfaceGrey,
                          selectedColor: Color(tag.colorHex).withValues(alpha: 0.3),
                          checkmarkColor: Color(tag.colorHex),
                          labelStyle: TextStyle(
                            color: isSelected ? Color(tag.colorHex) : Colors.white,
                            fontSize: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(
                              color: isSelected ? Color(tag.colorHex) : Colors.transparent,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    loading: () => const LinearProgressIndicator(color: AppTheme.primaryGreen),
                    error: (_, __) => const Text("Error loading tags", style: TextStyle(color: Colors.red)),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGreen,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text(
                "Apply Filters",
                style: TextStyle(
                  color: AppTheme.backgroundBlack,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  DateTimeRange _getRange(int days) {
    final now = DateTime.now();
    return DateTimeRange(
      start: DateTime(now.year, now.month, now.day).subtract(Duration(days: days - 1)),
      end: DateTime(now.year, now.month, now.day),
    );
  }

  bool _isSameRange(DateTimeRange? r1, DateTimeRange r2) {
    if (r1 == null) return false;
    return r1.start.year == r2.start.year &&
        r1.start.month == r2.start.month &&
        r1.start.day == r2.start.day &&
        r1.end.year == r2.end.year &&
        r1.end.month == r2.end.month &&
        r1.end.day == r2.end.day;
  }

  bool _isPredefined(DateTimeRange range) {
    return _isSameRange(range, _getRange(7)) || _isSameRange(range, _getRange(30));
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final ValueChanged<bool> onSelected;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: onSelected,
      backgroundColor: AppTheme.surfaceGrey,
      selectedColor: AppTheme.primaryGreen.withValues(alpha: 0.3),
      labelStyle: TextStyle(
        color: isSelected ? AppTheme.primaryGreen : Colors.white,
        fontSize: 12,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? AppTheme.primaryGreen : Colors.transparent,
        ),
      ),
      showCheckmark: false,
    );
  }
}
