import 'package:budgetti/core/providers/providers.dart';
import 'package:budgetti/core/theme/app_theme.dart';
import 'package:budgetti/models/budget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class SetBudgetModal extends ConsumerStatefulWidget {
  final String categoryName;
  final double currentLimit;

  const SetBudgetModal({
    super.key,
    required this.categoryName,
    required this.currentLimit,
  });

  @override
  ConsumerState<SetBudgetModal> createState() => _SetBudgetModalState();
}

class _SetBudgetModalState extends ConsumerState<SetBudgetModal> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _amountController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.currentLimit > 0 ? widget.currentLimit.toStringAsFixed(2) : '',
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _saveBudget() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final newLimit = double.parse(_amountController.text.replaceAll(',', '.'));
      final service = ref.read(financeServiceProvider);
      
      await service.upsertBudget(Budget(
        id: '', // Handled by service
        userId: '', // Handled by service
        category: widget.categoryName,
        limit: newLimit,
      ));
      
      ref.invalidate(budgetsProvider);
      
      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Budget updated successfully")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error saving budget: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = ref.watch(currencyProvider);
    final currencySymbol = currencyFormatter.currencySymbol;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SizedBox(width: 48), // Spacer
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        "Set Monthly Budget",
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                        textAlign: TextAlign.center,
                      ),
                      Text(
                        widget.categoryName,
                        style: const TextStyle(
                          color: AppTheme.textGrey,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 48), // Spacer
              ],
            ),
            const SizedBox(height: 24),

            // Amount Input Container (Unified Style)
            Container(
              decoration: BoxDecoration(
                color: AppTheme.surfaceGrey,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.textGrey.withValues(alpha: 0.3),
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: Row(
                children: [
                  // Currency Label
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                      border: Border(
                        right: BorderSide(
                          color: AppTheme.textGrey.withValues(alpha: 0.3),
                        ),
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
                  // Input Area
                  Expanded(
                    child: TextFormField(
                      controller: _amountController,
                      autofocus: true,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.right,
                      decoration: InputDecoration(
                        hintText: "0.00",
                        hintStyle: TextStyle(
                          color: AppTheme.textGrey.withValues(alpha: 0.3),
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        filled: false,
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Enter limit';
                        final sanitized = value.replaceAll(',', '.');
                        if (double.tryParse(sanitized) == null) return 'Invalid';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Save Button
            ElevatedButton(
              onPressed: _isLoading ? null : () {
                HapticFeedback.mediumImpact();
                _saveBudget();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGreen,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                disabledBackgroundColor: AppTheme.primaryGreen.withValues(alpha: 0.3),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.backgroundBlack,
                      ),
                    )
                  : const Text(
                      "Save Budget",
                      style: TextStyle(
                        color: AppTheme.backgroundBlack,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
