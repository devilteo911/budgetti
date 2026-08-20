import 'package:budgetti/core/constants/category_icons.dart';
import 'package:budgetti/core/l10n.dart';
import 'package:budgetti/core/theme/ledger_style.dart';
import 'package:budgetti/models/category.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import 'package:budgetti/core/widgets/app_sheet.dart';
import 'package:budgetti/core/widgets/discard_guard.dart';

// Predefined colors
const List<int> _colors = [
  0xFF4CAF50, // Green
  0xFFF44336, // Red
  0xFF2196F3, // Blue
  0xFFFFC107, // Amber
  0xFF9C27B0, // Purple
  0xFF00BCD4, // Cyan
  0xFFFF9800, // Orange
  0xFF795548, // Brown
  0xFF607D8B, // Blue Grey
  0xFFE91E63, // Pink
];

/// Legible ink for text/icons painted directly on a user-chosen swatch — the
/// palette spans near-black to near-white, so neither white nor onSurface works
/// for all of it.
Color _inkOn(Color background) =>
    ThemeData.estimateBrightnessForColor(background) == Brightness.dark
        ? Colors.white
        : Colors.black;

class CategoryEditorModal extends ConsumerStatefulWidget {
  final Category? category;
  final Function(Category) onSave;

  const CategoryEditorModal({super.key, this.category, required this.onSave});

  @override
  ConsumerState<CategoryEditorModal> createState() => _CategoryEditorModalState();
}

class _CategoryEditorModalState extends ConsumerState<CategoryEditorModal> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  late int _selectedColor;
  late int _selectedIcon;
  late String _type;
  final _formKey = GlobalKey<FormState>();

  /// Everything the form holds, as one string, compared against the snapshot
  /// taken when the sheet opened — an untouched form still closes on the
  /// first back gesture.
  String get _snapshot =>
      '${_nameController.text}|${_descriptionController.text}'
      '|$_selectedColor|$_selectedIcon|$_type';
  late final String _openedWith;

  @override
  void initState() {
    super.initState();
    if (widget.category != null) {
      _nameController.text = widget.category!.name;
      _selectedColor = widget.category!.colorHex;
      _selectedIcon = widget.category!.iconCode;
      _type = widget.category!.type;
      _descriptionController.text = widget.category!.description ?? '';
    } else {
      _selectedColor = _colors[0];
      _selectedIcon = categoryIconGroups.first.icons.first.codePoint;
      _type = 'expense';
    }
    _openedWith = _snapshot;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      final newCategory = Category(
        id: widget.category?.id ?? const Uuid().v4(),
        userId: widget.category?.userId ?? '', // ID handled by service/DB logic usually, but here we preserve or let service handle
        name: _nameController.text,
        iconCode: _selectedIcon,
        colorHex: _selectedColor,
        type: _type,
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
      );
      widget.onSave(newCategory);
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final categoryColor = Color(_selectedColor);

    return DiscardGuard(
      isDirty: () => _snapshot != _openedWith,
      child: SafeArea(
      // The sheet already handles the top inset; belt and braces for notches.
      top: false,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border:
              Border.all(color: cs.onSurface.withValues(alpha: 0.05), width: 1),
        ),
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 12,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _dragHandle(cs),
                Text(
                  widget.category == null
                      ? context.l10n.setNewCategory
                      : context.l10n.setEditCategory,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                _buildPreview(categoryColor),
                const SizedBox(height: 28),
                Flexible(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildLabel(context.l10n.setFieldName.toUpperCase()),
                        _nameField(cs, categoryColor),
                        const SizedBox(height: 20),
                        _typeAndColorRow(cs, categoryColor),
                        const SizedBox(height: 24),
                        _buildLabel(
                            context.l10n.setFieldDescription.toUpperCase()),
                        _descriptionField(cs, categoryColor),
                        const SizedBox(height: 24),
                        _buildLabel(
                            context.l10n.setFieldSelectIcon.toUpperCase()),
                        _iconGrid(cs, categoryColor),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
                _actions(cs, categoryColor),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }

  Widget _dragHandle(ColorScheme cs) => Center(
        child: Container(
          width: 40,
          height: 4,
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            color: cs.onSurface.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      );

  /// Shared decoration for the two inputs: a hairline field on a barely-tinted
  /// fill that lights up in the category's own colour on focus.
  InputDecoration _fieldDecoration(
    ColorScheme cs,
    Color accent, {
    required String hint,
    required IconData icon,
    required double iconAlpha,
    required double focusAlpha,
    required double focusWidth,
  }) =>
      InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: cs.onSurface.withValues(alpha: 0.2)),
        filled: true,
        fillColor: cs.onSurface.withValues(alpha: 0.03),
        prefixIcon: Icon(icon, color: accent.withValues(alpha: iconAlpha)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide:
              BorderSide(color: cs.onSurface.withValues(alpha: 0.05)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: accent.withValues(alpha: focusAlpha),
            width: focusWidth,
          ),
        ),
      );

  Widget _nameField(ColorScheme cs, Color accent) => TextFormField(
        controller: _nameController,
        // Redraws the live preview as you type.
        onChanged: (_) => setState(() {}),
        style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.bold),
        decoration: _fieldDecoration(
          cs,
          accent,
          hint: context.l10n.setCategoryNameHint,
          icon: Icons.label_outline,
          iconAlpha: 0.6,
          focusAlpha: 0.5,
          focusWidth: 2,
        ),
        // The submit button is the only feedback surface here, so the message
        // itself is empty — an error string would push the layout around.
        validator: (val) => val == null || val.isEmpty ? '' : null,
      );

  Widget _descriptionField(ColorScheme cs, Color accent) => TextFormField(
        controller: _descriptionController,
        style: TextStyle(
          color: cs.onSurface.withValues(alpha: 0.8),
          fontSize: 14,
        ),
        maxLines: 2,
        decoration: _fieldDecoration(
          cs,
          accent,
          hint: context.l10n.setCategoryDescriptionHint,
          icon: Icons.notes_rounded,
          iconAlpha: 0.4,
          focusAlpha: 0.3,
          focusWidth: 1.5,
        ),
      );

  Widget _typeAndColorRow(ColorScheme cs, Color categoryColor) => Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildLabel(context.l10n.setFieldType.toUpperCase()),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: cs.onSurface.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: cs.onSurface.withValues(alpha: 0.05),
                    ),
                  ),
                  child: Row(
                    children: [
                      _buildTypeOption('expense', context.l10n.commonExpense,
                          expenseInk(cs.brightness)),
                      _buildTypeOption('income', context.l10n.commonIncome,
                          incomeInk(cs.brightness)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildLabel(context.l10n.setColor.toUpperCase()),
                GestureDetector(
                  onTap: _showColorPicker,
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: categoryColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Icon(Icons.colorize,
                          color: _inkOn(categoryColor), size: 20),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );

  Widget _iconGrid(ColorScheme cs, Color categoryColor) => SizedBox(
        // Fixed: the grid scrolls inside the sheet's own scroll view.
        height: 380,
        child: Container(
          decoration: BoxDecoration(
            color: cs.onSurface.withValues(alpha: 0.02),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: cs.onSurface.withValues(alpha: 0.05)),
          ),
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              for (final group in categoryIconGroups) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(
                      group.name.toUpperCase(),
                      style: TextStyle(
                        color: cs.onSurface.withValues(alpha: 0.3),
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 5,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) =>
                          _iconTile(cs, categoryColor, group.icons[index]),
                      childCount: group.icons.length,
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 12)),
              ],
            ],
          ),
        ),
      );

  Widget _iconTile(ColorScheme cs, Color categoryColor, IconData iconData) {
    final isSelected = _selectedIcon == iconData.codePoint;
    return GestureDetector(
      onTap: () => setState(() => _selectedIcon = iconData.codePoint),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isSelected
              ? categoryColor
              : cs.onSurface.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? cs.onSurface.withValues(alpha: 0.5)
                : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Icon(
          iconData,
          size: 20,
          color: isSelected
              ? _inkOn(categoryColor)
              : cs.onSurface.withValues(alpha: 0.4),
        ),
      ),
    );
  }

  Widget _actions(ColorScheme cs, Color categoryColor) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          children: [
            Expanded(
              child: TextButton(
                onPressed: () => context.pop(),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  context.l10n.commonCancel,
                  style: TextStyle(
                    color: cs.onSurface.withValues(alpha: 0.5),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: categoryColor,
                  foregroundColor: _inkOn(categoryColor),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  elevation: 8,
                  shadowColor: categoryColor.withValues(alpha: 0.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  context.l10n.setSaveCategory,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ],
        ),
      );

  Widget _buildLabel(String text) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Text(
        text,
        style: TextStyle(
          color: cs.onSurface.withValues(alpha: 0.4),
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildPreview(Color color) {
    final cs = Theme.of(context).colorScheme;
    final displayName = _nameController.text.isEmpty
        ? context.l10n.setNewCategory
        : _nameController.text;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              IconData(_selectedIcon, fontFamily: 'MaterialIcons'),
              color: _inkOn(color),
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: cs.onSurface,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  (_type == 'expense'
                          ? context.l10n.commonExpense
                          : context.l10n.commonIncome)
                      .toUpperCase(),
                  style: TextStyle(
                    color: _type == 'expense'
                        ? expenseInk(cs.brightness)
                        : incomeInk(cs.brightness),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeOption(String value, String label, Color color) {
    final cs = Theme.of(context).colorScheme;
    final isSelected = _type == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _type = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? color : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? _inkOn(color)
                    : cs.onSurface.withValues(alpha: 0.4),
                fontWeight: FontWeight.w900,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showColorPicker() {
    showAppSheet(
      context,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              ctx.l10n.setSelectColor,
              style: TextStyle(
                color: Theme.of(ctx).colorScheme.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            GridView.builder(
              shrinkWrap: true,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
              ),
              itemCount: _colors.length,
              itemBuilder: (ctx, index) {
                final color = _colors[index];
                final isSelected = _selectedColor == color;
                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedColor = color);
                    Navigator.pop(ctx);
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: Color(color),
                      shape: BoxShape.circle,
                      border: isSelected
                          ? Border.all(
                              color: Theme.of(ctx).colorScheme.onSurface,
                              width: 3)
                          : null,
                      boxShadow: [
                        BoxShadow(
                          color: Color(color).withValues(alpha: 0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: isSelected
                        ? Icon(Icons.check,
                            color: _inkOn(Color(color)), size: 20)
                        : null,
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
