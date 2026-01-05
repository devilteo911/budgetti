import 'package:budgetti/core/providers/providers.dart';
import 'package:budgetti/core/theme/app_theme.dart';
import 'package:budgetti/models/transaction.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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

  // Mock categories
  final List<String> _categories = ['Groceries', 'Entertainment', 'Transport', 'Utilities', 'Shopping', 'Income', 'Other'];

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
        date: DateTime.now(),
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              "New Transaction",
              style: Theme.of(context).textTheme.headlineSmall,
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
            const SizedBox(height: 16),

            // Amount
            TextFormField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: "Amount",
                prefixText: "\$ ",
              ),
              validator: (value) {
                if (value == null || value.isEmpty) return 'Please enter an amount';
                if (double.tryParse(value) == null) return 'Invalid number';
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Description
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: "Description",
                hintText: "e.g. Weekly Groceries",
              ),
              validator: (value) {
                if (value == null || value.isEmpty) return 'Please enter a description';
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Category
            DropdownButtonFormField<String>(
              // ignore: deprecated_member_use
              value: _selectedCategory,
              decoration: const InputDecoration(labelText: "Category"),
              items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (val) => setState(() => _selectedCategory = val!),
            ),
            const SizedBox(height: 32),

            // Submit
            ElevatedButton(
              onPressed: _submit,
              child: const Text("Add Transaction"),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
