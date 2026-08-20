import 'package:budgetti/core/l10n.dart';
import 'package:budgetti/core/error_text.dart';
import 'package:budgetti/core/providers/providers.dart';
import 'package:budgetti/features/settings/widgets/category_editor_modal.dart';
import 'package:budgetti/models/category.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:budgetti/core/theme/ledger_style.dart';
import 'package:budgetti/core/widgets/app_sheet.dart';

class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  void _showEditor(BuildContext context, WidgetRef ref, {Category? category}) {
    showAppSheet(
      context,
      isScrollControlled: true,
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
          context.l10n.setCategories,
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
                  title: Text(ctx.l10n.setRestoreDefaultsTitle),
                  content: Text(
                    ctx.l10n.setRestoreCategoriesBody,
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: Text(ctx.l10n.commonCancel),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: Text(ctx.l10n.setRestore),
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
                    SnackBar(
                      content: Text(context.l10n.setCategoriesRestored),
                    ),
                  );
                }
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem<String>(
                value: 'restore',
                child: Text(context.l10n.setRestoreDefaults),
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
                    context.l10n.setNoCategories,
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
                    child: Text(context.l10n.setCreateFirstCategory),
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
                _sectionLabel(context, context.l10n.setExpenses),
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
                _sectionLabel(context, context.l10n.setIncome),
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
        error: (e, _) =>
            Center(child: Text(context.l10n.setErrorWithDetails(errorText(context, e)))),
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
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _CategoryTile extends ConsumerWidget {
  final Category category;
  final VoidCallback onTap;
  final Future<void> Function() onDelete;

  const _CategoryTile({
    required this.category,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    // Show what the category actually looks like everywhere else, not the
    // stored colorHex — otherwise this screen is the one place that disagrees.
    final color = ref.watch(categoryColorCacheProvider(
            scheme.brightness))[category.name] ??
        unknownCategoryInk(scheme);

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
              title: Text(ctx.l10n.setDeleteCategoryTitle),
              content: Text(
                ctx.l10n.setDeleteConfirmBody(category.name),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(ctx.l10n.commonCancel),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: TextButton.styleFrom(foregroundColor: scheme.error),
                  child: Text(ctx.l10n.commonDelete),
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
                      ref.watch(categoryIconCacheProvider)[category.name] ??
                          categoryIcon(category.name,
                              iconCode: category.iconCode),
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

