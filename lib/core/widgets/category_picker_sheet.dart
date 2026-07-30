import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:budgetti/core/providers/providers.dart';
import 'package:budgetti/core/theme/app_theme.dart';
import 'package:budgetti/models/category.dart';

class CategoryPickerSheet extends ConsumerWidget {
  final String title;
  final String? selectedCategoryName;
  final String? type; // 'expense', 'income', or null for all
  final Function(Category) onCategorySelected;

  const CategoryPickerSheet({
    super.key,
    this.title = "Select Category",
    this.selectedCategoryName,
    this.type,
    required this.onCategorySelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoriesProvider);
    final categoryColors = ref.watch(categoryColorCacheProvider(Theme.of(context).colorScheme.brightness));
    final categoryIcons = ref.watch(categoryIconCacheProvider);

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      child: Padding(
        padding: const EdgeInsets.only(top: 24, bottom: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.textGrey.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
            ),
            const SizedBox(height: 16),
            categoriesAsync.when(
              data: (categories) {
                final filtered = type != null
                    ? categories.where((c) => c.type == type).toList()
                    : categories;

                if (filtered.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(
                      child: Text(
                        "No categories found",
                        style: TextStyle(color: AppTheme.textGrey),
                      ),
                    ),
                  );
                }

                return Expanded(
                  child: ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final cat = filtered[index];
                      final isSelected = selectedCategoryName == cat.name;
                      final color = categoryColors[cat.name] ?? Colors.grey;
                      final icon = categoryIcons[cat.name] ?? Icons.category;

                      return ListTile(
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                        title: Text(
                          cat.name,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            icon,
                            color: color,
                            size: 20,
                          ),
                        ),
                        onTap: () {
                          onCategorySelected(cat);
                          Navigator.of(context).pop();
                        },
                        trailing: isSelected
                            ? const Icon(Icons.check_circle,
                                color: AppTheme.primaryGreen)
                            : null,
                      );
                    },
                  ),
                );
              },
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(color: AppTheme.primaryGreen),
                ),
              ),
              error: (e, s) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text("Error: $e",
                      style: const TextStyle(color: Colors.red)),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
