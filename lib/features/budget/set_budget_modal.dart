import 'package:budgetti/core/providers/providers.dart';
import 'package:budgetti/models/budget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

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
      text: widget.currentLimit > 0
          ? widget.currentLimit.toStringAsFixed(2)
          : '',
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
      final newLimit = double.parse(
        _amountController.text.replaceAll(',', '.'),
      );
      final service = ref.read(financeServiceProvider);

      await service.upsertBudget(Budget(
        id: '',
        userId: '',
        category: widget.categoryName,
        limit: newLimit,
      ));

      ref.invalidate(budgetsProvider);

      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Budget updated')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving budget: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _clearBudget() async {
    setState(() => _isLoading = true);
    try {
      final service = ref.read(financeServiceProvider);
      await service.upsertBudget(Budget(
        id: '',
        userId: '',
        category: widget.categoryName,
        limit: 0,
      ));
      ref.invalidate(budgetsProvider);
      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Budget cleared')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final currencyFormatter = ref.watch(currencyProvider);
    final currencySymbol = currencyFormatter.currencySymbol;
    final hasExisting = widget.currentLimit > 0;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20,
        right: 20,
        top: 8,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 4, bottom: 16),
                height: 4,
                width: 40,
                decoration: BoxDecoration(
                  color: scheme.outlineVariant.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              'MONTHLY LIMIT',
              style: GoogleFonts.jetBrainsMono(
                color: scheme.onSurfaceVariant,
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 2.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.categoryName,
              style: GoogleFonts.jetBrainsMono(
                color: scheme.onSurface,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 24),
            Container(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: scheme.outlineVariant.withValues(alpha: 0.5),
                    width: 1.5,
                  ),
                ),
              ),
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    currencySymbol,
                    style: GoogleFonts.jetBrainsMono(
                      color: scheme.onSurfaceVariant,
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _amountController,
                      autofocus: true,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 40,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1.4,
                        color: scheme.onSurface,
                      ),
                      textAlign: TextAlign.right,
                      decoration: InputDecoration(
                        hintText: '0.00',
                        hintStyle: GoogleFonts.jetBrainsMono(
                          color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
                          fontSize: 40,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1.4,
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 4),
                        filled: false,
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Enter limit';
                        }
                        final sanitized = value.replaceAll(',', '.');
                        final parsed = double.tryParse(sanitized);
                        if (parsed == null) return 'Invalid';
                        if (parsed < 0) return 'Must be positive';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                if (hasExisting) ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isLoading
                          ? null
                          : () {
                              HapticFeedback.mediumImpact();
                              _clearBudget();
                            },
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: scheme.outlineVariant.withValues(alpha: 0.5),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text(
                        'Clear',
                        style: TextStyle(
                          color: scheme.onSurface,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  flex: hasExisting ? 1 : 1,
                  child: ElevatedButton(
                    onPressed: _isLoading
                        ? null
                        : () {
                            HapticFeedback.mediumImpact();
                            _saveBudget();
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: scheme.primary,
                      foregroundColor: scheme.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      disabledBackgroundColor:
                          scheme.primary.withValues(alpha: 0.3),
                    ),
                    child: _isLoading
                        ? SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: scheme.onPrimary,
                            ),
                          )
                        : Text(
                            hasExisting ? 'Update' : 'Save',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
