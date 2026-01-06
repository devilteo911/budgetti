import 'package:budgetti/core/theme/app_theme.dart';
import 'package:budgetti/models/category.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

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

// Predefined icons (code points)
const List<IconData> _icons = [
  Icons.shopping_bag,
  Icons.fastfood,
  Icons.directions_car,
  Icons.home,
  Icons.local_hospital,
  Icons.sports_soccer,
  Icons.movie,
  Icons.school,
  Icons.flight,
  Icons.pets,
  Icons.work,
  Icons.wifi,
  Icons.phone,
  Icons.monetization_on,
  Icons.account_balance,
];

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
      _selectedIcon = _icons[0].codePoint;
      _type = 'expense';
    }
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
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 24,
      ),
      child: Form(
        key: _formKey,
        child: SizedBox(
          height: 600,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.category == null ? "New Category" : "Edit Category",
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // Name
              TextFormField(
                controller: _nameController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: "Category Name",
                  prefixIcon: Icon(Icons.label, color: AppTheme.textGrey),
                ),
                validator: (val) => val == null || val.isEmpty ? 'Enter name' : null,
              ),
              const SizedBox(height: 16),

              // Description
              TextFormField(
                controller: _descriptionController,
                style: const TextStyle(color: Colors.white),
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: "Description (Optional)",
                  prefixIcon: Icon(Icons.description, color: AppTheme.textGrey),
                  hintText: "Enter a brief description",
                ),
              ),
              const SizedBox(height: 16),

              // Type Selector
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'expense', label: Text("Expense")),
                  ButtonSegment(value: 'income', label: Text("Income")),
                ],
                selected: {_type},
                onSelectionChanged: (Set<String> selection) {
                  setState(() {
                    _type = selection.first;
                  });
                },
                style: ButtonStyle(
                   backgroundColor: WidgetStateProperty.resolveWith<Color>((Set<WidgetState> states) {
                    if (states.contains(WidgetState.selected)) {
                      return _type == 'expense' ? Theme.of(context).colorScheme.error : AppTheme.primaryGreen;
                    }
                    return AppTheme.surfaceGreyLight;
                  }),
                  foregroundColor: WidgetStateProperty.resolveWith<Color>((Set<WidgetState> states) {
                    if (states.contains(WidgetState.selected)) {
                       return AppTheme.backgroundBlack;
                    }
                    return AppTheme.textWhite;
                  }),
                ),
              ),
              const SizedBox(height: 24),

              // Color Picker
              Text("Color", style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white)),
              const SizedBox(height: 8),
              SizedBox(
                height: 50,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _colors.length,
                  itemBuilder: (context, index) {
                    final color = _colors[index];
                    final isSelected = _selectedColor == color;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedColor = color),
                      child: Container(
                        width: 40,
                        height: 40,
                        margin: const EdgeInsets.only(right: 12),
                        decoration: BoxDecoration(
                          color: Color(color),
                          shape: BoxShape.circle,
                          border: isSelected ? Border.all(color: Colors.white, width: 3) : null,
                        ),
                        child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 20) : null,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),

              // Icon Picker
              Text("Icon", style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white)),
              const SizedBox(height: 8),
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 5, mainAxisSpacing: 12, crossAxisSpacing: 12),
                  itemCount: _icons.length,
                  itemBuilder: (context, index) {
                    final iconData = _icons[index];
                    final isSelected = _selectedIcon == iconData.codePoint;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedIcon = iconData.codePoint),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected ? Color(_selectedColor) : AppTheme.surfaceGreyLight,
                          borderRadius: BorderRadius.circular(12),
                          border: isSelected ? Border.all(color: Colors.white, width: 2) : null,
                        ),
                        child: Icon(
                          iconData,
                          color: isSelected ? Colors.white : AppTheme.textGrey,
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Save Button
              ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGreen,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text("Save Category", style: TextStyle(color: AppTheme.backgroundBlack, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
