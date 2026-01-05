import 'package:budgetti/core/providers/providers.dart';
import 'package:budgetti/core/theme/app_theme.dart';
import 'package:budgetti/models/transaction.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

class AddTransactionModal extends ConsumerStatefulWidget {
  const AddTransactionModal({super.key});

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

  // Mock categories
  final List<String> _categories = ['Groceries', 'Entertainment', 'Transport', 'Utilities', 'Shopping', 'Salary', 'Freelance', 'Other'];

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
        id: const Uuid().v4(),
        accountId: '1', // Hardcoded main wallet for now
        amount: finalAmount,
        date: _selectedDate,
        description: _descriptionController.text,
        category: _selectedCategory,
      );

      final service = ref.read(financeServiceProvider);
      await service.addTransaction(transaction);

      // Refresh providers to update UI
      ref.invalidate(accountsProvider);
      ref.invalidate(transactionsProvider('1'));

      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transaction added')),
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
                child: ListView.separated(
                  itemCount: _categories.length,
                  separatorBuilder: (context, index) => const Divider(color: AppTheme.textGrey, height: 1),
                  itemBuilder: (context, index) {
                    final cat = _categories[index];
                    return ListTile(
                      title: Text(cat, style: const TextStyle(color: Colors.white)),
                      leading: Icon(
                        _isExpense ? Icons.shopping_bag_outlined : Icons.monetization_on_outlined, 
                        color: AppTheme.primaryGreen
                      ),
                      onTap: () {
                        setState(() => _selectedCategory = cat);
                        context.pop();
                      },
                      trailing: _selectedCategory == cat ? const Icon(Icons.check, color: AppTheme.primaryGreen) : null,
                    );
                  },
                ),
              ),
            ],
          ),
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
        child: SizedBox(
          height: 600, // Fixed height or use dynamic
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                "New Transaction",
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
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
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  prefixText: "$currencySymbol ",
                  prefixStyle: const TextStyle(color: AppTheme.primaryGreen, fontSize: 24, fontWeight: FontWeight.bold),
                  hintText: "0.00",
                  hintStyle: TextStyle(color: AppTheme.textGrey.withValues(alpha: 0.5)),
                  border: InputBorder.none,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Enter amount';
                  if (double.tryParse(value) == null) return 'Invalid';
                  return null;
                },
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
                    borderRadius: BorderRadius.circular(4),
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
                    borderRadius: BorderRadius.circular(4),
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
          
              const Spacer(),
          
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
                  child: const Text("Add Transaction", style: TextStyle(color: AppTheme.backgroundBlack, fontSize: 16, fontWeight: FontWeight.bold)),
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
