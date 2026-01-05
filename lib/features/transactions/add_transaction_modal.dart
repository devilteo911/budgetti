import 'package:budgetti/core/providers/providers.dart';
import 'package:budgetti/core/theme/app_theme.dart';
import 'package:budgetti/models/transaction.dart';
import 'package:budgetti/models/tag.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

class AddTransactionModal extends ConsumerStatefulWidget {
  final Transaction? transaction;
  
  const AddTransactionModal({super.key, this.transaction});

  @override
  ConsumerState<AddTransactionModal> createState() => _AddTransactionModalState();
}

class _AddTransactionModalState extends ConsumerState<AddTransactionModal> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  bool _isExpense = true;
  String _selectedCategory = 'Groceries';
  DateTime _selectedDate = DateTime.now();
  List<String> _selectedTags = [];

  @override
  void initState() {
    super.initState();
    // If editing, populate fields
    if (widget.transaction != null) {
      final t = widget.transaction!;
      _amountController.text = t.amount.abs().toString();
      _descriptionController.text = t.description;
      _selectedCategory = t.category;
      _selectedDate = t.date;
      _isExpense = t.amount < 0;
      _selectedTags = List.from(t.tags);
    }
  }


  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _submit() async {
    if (_formKey.currentState!.validate()) {
      final amount = double.parse(_amountController.text);
      final finalAmount = _isExpense ? -amount : amount;

      final transaction = Transaction(
        id: widget.transaction?.id ?? const Uuid().v4(),
        accountId: '1', // Hardcoded main wallet for now
        amount: finalAmount,
        date: _selectedDate,
        description: _descriptionController.text,
        category: _selectedCategory,
        tags: _selectedTags,
      );

      final service = ref.read(financeServiceProvider);
      if (widget.transaction != null) {
        await service.updateTransaction(transaction);
      } else {
        await service.addTransaction(transaction);
      }

      // Refresh providers to update UI
      ref.invalidate(accountsProvider);
      ref.invalidate(transactionsProvider('1'));

      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.transaction != null ? 'Transaction updated' : 'Transaction added')),
        );
      }
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppTheme.primaryGreen,
              onPrimary: AppTheme.backgroundBlack,
              surface: AppTheme.surfaceGrey,
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      if (mounted) setState(() => _selectedDate = picked);
    }
  }

  void _showCategoryPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceGrey,
      builder: (context) {
        return Consumer(
          builder: (context, ref, child) {
            final categoriesAsync = ref.watch(categoriesProvider);
            
            return Container(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "Select Category",
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: categoriesAsync.when(
                      data: (categories) {
                         // Filter by type
                         final filtered = categories.where((c) => c.type == (_isExpense ? 'expense' : 'income')).toList();
                         if (filtered.isEmpty) return const Center(child: Text("No categories found", style: TextStyle(color: AppTheme.textGrey)));

                         return ListView.separated(
                          itemCount: filtered.length,
                          separatorBuilder: (context, index) => const Divider(color: AppTheme.textGrey, height: 1),
                          itemBuilder: (context, index) {
                            final cat = filtered[index];
                            return ListTile(
                              title: Text(cat.name, style: const TextStyle(color: Colors.white)),
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Color(cat.colorHex).withValues(alpha: 0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  IconData(cat.iconCode, fontFamily: 'MaterialIcons'),
                                  color: Color(cat.colorHex),
                                  size: 20,
                                ),
                              ),
                              onTap: () {
                                setState(() => _selectedCategory = cat.name);
                                Navigator.of(context).pop();
                              },
                              trailing: _selectedCategory == cat.name ? const Icon(Icons.check, color: AppTheme.primaryGreen) : null,
                            );
                          },
                        );
                      },
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (e, s) => Center(child: Text("Error: $e", style: TextStyle(color: Colors.red))),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Get currency symbol
    final formatter = ref.watch(currencyProvider);
    final currencySymbol = formatter.currencySymbol;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 24,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.transaction != null ? "Edit Transaction" : "New Transaction",
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const SizedBox(height: 24),
              
              // Type Selector
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: true, label: Text("Expense"), icon: Icon(Icons.arrow_downward)),
                  ButtonSegment(value: false, label: Text("Income"), icon: Icon(Icons.arrow_upward)),
                ],
                selected: {_isExpense},
                onSelectionChanged: (Set<bool> newSelection) {
                  setState(() {
                    _isExpense = newSelection.first;
                    // Reset category to a default if switching types? For now keep simple.
                    if (!_isExpense && _selectedCategory == "Groceries") _selectedCategory = "Salary";
                    if (_isExpense && _selectedCategory == "Salary") _selectedCategory = "Groceries";
                  });
                },
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.resolveWith<Color>((Set<WidgetState> states) {
                    if (states.contains(WidgetState.selected)) {
                      return _isExpense ? Theme.of(context).colorScheme.error : AppTheme.primaryGreen;
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
          
              // Amount
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.surfaceGrey,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.primaryGreen.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    // Currency indicator
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryGreen.withValues(alpha: 0.2),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(12),
                          bottomLeft: Radius.circular(12),
                        ),
                      ),
                      child: Text(
                        currencySymbol,
                        style: const TextStyle(
                          color: AppTheme.primaryGreen,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    // Input area
                    Expanded(
                      child: TextFormField(
                        controller: _amountController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                        textAlign: TextAlign.right,
                        decoration: InputDecoration(
                          hintText: "0.00",
                          hintStyle: TextStyle(color: AppTheme.textGrey.withValues(alpha: 0.5)),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Enter amount';
                          if (double.tryParse(value) == null) return 'Invalid';
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
          
              // Description
              TextFormField(
                controller: _descriptionController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: "Description",
                  prefixIcon: Icon(Icons.edit, color: AppTheme.textGrey),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Enter description';
                  return null;
                },
              ),
              const SizedBox(height: 16),
          
              // Date Picker Row
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppTheme.textGrey),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today, color: AppTheme.textGrey),
                      const SizedBox(width: 12),
                      Text(
                        DateFormat.yMMMd().format(_selectedDate),
                        style: const TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
          
              // Category Picker Row
              InkWell(
                onTap: _showCategoryPicker,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppTheme.textGrey),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.category, color: AppTheme.textGrey),
                          const SizedBox(width: 12),
                          Text(
                            _selectedCategory,
                            style: const TextStyle(color: Colors.white, fontSize: 16),
                          ),
                        ],
                      ),
                      const Icon(Icons.arrow_drop_down, color: AppTheme.textGrey),
                    ],
                  ),
                ),
              ),
          
              const SizedBox(height: 16),

              // Tags Selector
              Consumer(
                builder: (context, ref, child) {
                  final tagsAsync = ref.watch(tagsProvider);
                  return tagsAsync.when(
                    data: (tags) {
                      if (tags.isEmpty) return const SizedBox.shrink();
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Tags", style: TextStyle(color: AppTheme.textGrey, fontSize: 14)),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            children: tags.map((Tag tag) {
                              final isSelected = _selectedTags.contains(tag.name);
                              return FilterChip(
                                label: Text(tag.name),
                                selected: isSelected,
                                onSelected: (selected) {
                                  setState(() {
                                    if (selected) {
                                      _selectedTags.add(tag.name);
                                    } else {
                                      _selectedTags.remove(tag.name);
                                    }
                                  });
                                },
                                backgroundColor: AppTheme.surfaceGrey,
                                selectedColor: Color(tag.colorHex).withValues(alpha: 0.3),
                                checkmarkColor: Color(tag.colorHex),
                                labelStyle: TextStyle(
                                  color: isSelected ? Color(tag.colorHex) : Colors.white,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
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
                        ],
                      );
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  );
                },
              ),
              const SizedBox(height: 24),
          
              // Submit
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGreen,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    widget.transaction != null ? "Update Transaction" : "Add Transaction",
                    style: const TextStyle(color: AppTheme.backgroundBlack, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
