import 'package:budgetti/core/providers/providers.dart';
import 'package:budgetti/features/settings/widgets/category_editor_modal.dart';
import 'package:budgetti/models/category.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  void _showEditor(BuildContext context, WidgetRef ref, {Category? category}) {
    showModalBottomSheet(
      useRootNavigator: true,
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
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
    final scheme = Theme.of(context).colorScheme;
    final categoriesAsync = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Categories',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: scheme.onSurface,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              HapticFeedback.heavyImpact();
              _showEditor(context, ref);
            },
          ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value != 'restore') return;
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Restore Defaults?'),
                  content: const Text(
                    'This will restore default categories if they were deleted or modified. Your custom categories will not be affected.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Restore'),
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
                      content: Text('Default categories restored'),
                    ),
                  );
                }
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem<String>(
                value: 'restore',
                child: Text('Restore Defaults'),
              ),
            ],
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
                  Icon(Icons.category_outlined,
                      size: 64,
                      color: scheme.onSurface.withValues(alpha: 0.3)),
                  const SizedBox(height: 16),
                  Text(
                    'No categories yet',
                    style: TextStyle(
                      color: scheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () {
                      HapticFeedback.heavyImpact();
                      _showEditor(context, ref);
                    },
                    child: const Text('Create your first category'),
                  ),
                ],
              ),
            );
          }

          final expense =
              categories.where((c) => c.type == 'expense').toList();
          final income =
              categories.where((c) => c.type == 'income').toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              if (expense.isNotEmpty) ...[
                _sectionLabel(context, 'Expenses'),
                ...expense.map((c) => _CategoryTile(
                      category: c,
                      onTap: () => _showEditor(context, ref, category: c),
                      onDelete: () async {
                        await ref
                            .read(financeServiceProvider)
                            .deleteCategory(c.id);
                        ref.invalidate(categoriesProvider);
                      },
                    )),
                const SizedBox(height: 24),
              ],
              if (income.isNotEmpty) ...[
                _sectionLabel(context, 'Income'),
                ...income.map((c) => _CategoryTile(
                      category: c,
                      onTap: () => _showEditor(context, ref, category: c),
                      onDelete: () async {
                        await ref
                            .read(financeServiceProvider)
                            .deleteCategory(c.id);
                        ref.invalidate(categoriesProvider);
                      },
                    )),
              ],
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _sectionLabel(BuildContext context, String text) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12, top: 8),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          color: scheme.onSurface.withValues(alpha: 0.4),
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  final Category category;
  final VoidCallback onTap;
  final Future<void> Function() onDelete;

  const _CategoryTile({
    required this.category,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = Color(category.colorHex);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Dismissible(
        key: Key(category.id),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            color: scheme.errorContainer,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(Icons.delete, color: scheme.onErrorContainer),
        ),
        confirmDismiss: (_) async {
          return await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Delete Category?'),
              content: Text(
                "Are you sure you want to delete '${category.name}'?",
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: TextButton.styleFrom(foregroundColor: scheme.error),
                  child: const Text('Delete'),
                ),
              ],
            ),
          );
        },
        onDismissed: (_) => onDelete(),
        child: Material(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      IconData(category.iconCode,
                          fontFamily: 'MaterialIcons'),
                      color: color,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      category.name,
                      style: TextStyle(
                        color: scheme.onSurface,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.edit_outlined,
                    color: scheme.onSurface.withValues(alpha: 0.35),
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

