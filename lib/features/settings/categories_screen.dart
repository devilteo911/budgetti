import 'package:budgetti/core/providers/providers.dart';
import 'package:budgetti/core/theme/app_theme.dart';
import 'package:budgetti/features/settings/widgets/category_editor_modal.dart';
import 'package:budgetti/models/category.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  void _showEditor(BuildContext context, WidgetRef ref, {Category? category}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceGrey,
      builder: (_) => CategoryEditorModal(
        category: category,
        onSave: (cat) async {
          final service = ref.read(financeServiceProvider);
          if (category == null) {
            await service.addCategory(cat);
          } else {
            await service.updateCategory(cat);
          }
          ref.invalidate(categoriesProvider);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Manage Categories", style: TextStyle(color: Colors.white)),
        backgroundColor: AppTheme.backgroundBlack,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: AppTheme.primaryGreen),
            onPressed: () {
              HapticFeedback.heavyImpact();
              _showEditor(context, ref);
            },
          ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'restore') {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: AppTheme.surfaceGrey,
                    title: const Text(
                      "Restore Defaults?",
                      style: TextStyle(color: Colors.white),
                    ),
                    content: const Text(
                      "This will restore default categories (Groceries, Transport, etc.) if they were deleted or modified. Your custom categories will not be affected.",
                      style: TextStyle(color: AppTheme.textGrey),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text("Cancel"),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text(
                          "Restore",
                          style: TextStyle(color: AppTheme.primaryGreen),
                        ),
                      ),
                    ],
                  ),
                );

                if (confirm == true) {
                  await ref
                      .read(financeServiceProvider)
                      .restoreDefaultCategories();
                  ref.invalidate(categoriesProvider);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Default categories restored"),
                      ),
                    );
                  }
                }
              }
            },
            itemBuilder: (BuildContext context) {
              return [
                const PopupMenuItem<String>(
                  value: 'restore',
                  child: Text("Restore Defaults"),
                ),
              ];
            },
          ),
        ],
      ),
      body: categoriesAsync.when(
        data: (categories) {
          if (categories.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.category_outlined, size: 64, color: AppTheme.textGrey),
                  const SizedBox(height: 16),
                  const Text("No categories yet", style: TextStyle(color: AppTheme.textGrey)),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () {
                      HapticFeedback.heavyImpact();
                      _showEditor(context, ref);
                    },
                    child: const Text("Create your first category"),
                  )
                ],
              ),
            );
          }

          final expenseCats = categories.where((c) => c.type == 'expense').toList();
          final incomeCats = categories.where((c) => c.type == 'income').toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (expenseCats.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.only(bottom: 8.0),
                  child: Text("Expenses", style: TextStyle(color: AppTheme.textGrey, fontWeight: FontWeight.bold)),
                ),
                ...expenseCats.map((c) => _buildCategoryTile(context, ref, c)),
                const SizedBox(height: 24),
              ],
              if (incomeCats.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.only(bottom: 8.0),
                  child: Text("Income", style: TextStyle(color: AppTheme.textGrey, fontWeight: FontWeight.bold)),
                ),
                ...incomeCats.map((c) => _buildCategoryTile(context, ref, c)),
              ],
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text("Error: $e", style: const TextStyle(color: Colors.red))),
      ),
    );
  }

  Widget _buildCategoryTile(BuildContext context, WidgetRef ref, Category category) {
    return Dismissible(
      key: Key(category.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        return await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppTheme.surfaceGrey,
            title: const Text("Delete Category?", style: TextStyle(color: Colors.white)),
            content: Text("Are you sure you want to delete '${category.name}'?", style: const TextStyle(color: AppTheme.textGrey)),
            actions: [
              TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text("Cancel")),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true), 
                child: const Text("Delete", style: TextStyle(color: Colors.red))
              ),
            ],
          ),
        );
      },
      onDismissed: (direction) async {
         final service = ref.read(financeServiceProvider);
         await service.deleteCategory(category.id);
         ref.invalidate(categoriesProvider);
      },
      child: Card(
        color: AppTheme.surfaceGrey,
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Color(category.colorHex).withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              IconData(category.iconCode, fontFamily: 'MaterialIcons'),
              color: Color(category.colorHex),
            ),
          ),
          title: Text(category.name, style: const TextStyle(color: Colors.white)),
          trailing: const Icon(Icons.edit, color: AppTheme.textGrey, size: 20),
          onTap: () => _showEditor(context, ref, category: category),
        ),
      ),
    );
  }
}
