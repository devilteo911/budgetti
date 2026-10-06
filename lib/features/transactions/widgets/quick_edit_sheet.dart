import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:budgetti/core/l10n.dart';
import 'package:budgetti/core/providers/providers.dart';
import 'package:budgetti/features/transactions/widgets/amount_hero_field.dart';
import 'package:budgetti/features/transactions/widgets/sheet_parts.dart';
import 'package:budgetti/models/transaction.dart';

/// Fix a row's title and amount in place from the swipe-through detail page.
/// Pops the edited [Transaction] (or null on dismiss); the caller saves it.
/// Everything else about a row — type, wallet, date, installment — goes
/// through the full editor.
class QuickEditSheet extends ConsumerStatefulWidget {
  final Transaction transaction;

  /// Which field takes the keyboard: whichever one was tapped to open this.
  final bool focusAmount;

  const QuickEditSheet({
    super.key,
    required this.transaction,
    this.focusAmount = false,
  });

  @override
  ConsumerState<QuickEditSheet> createState() => _QuickEditSheetState();
}

class _QuickEditSheetState extends ConsumerState<QuickEditSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.transaction.description);
  late final _amount = TextEditingController(
    text: widget.transaction.amount.abs().toStringAsFixed(2),
  );

  Transaction get _tx => widget.transaction;

  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final value = double.parse(_amount.text.replaceAll(',', '.')).abs();
    // The direction is the row's own: editing the digits never flips an
    // expense into income. Only a transfer or an income stays positive.
    final positive = _tx.type == 'transfer' || _tx.isIncome;
    Navigator.pop(
      context,
      _tx.copyWith(
        description: _title.text.trim(),
        amount: positive ? value : -value,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final kind = _tx.type == 'transfer'
        ? 'transfer'
        : _tx.isIncome
            ? 'income'
            : 'expense';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 4),
              AmountHeroField(
                controller: _amount,
                currencySymbol: ref.watch(currencyProvider).currencySymbol,
                type: kind,
                autofocus: widget.focusAmount,
              ),
              const SizedBox(height: 28),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  context.l10n.txTitleLabel.toUpperCase(),
                  style: GoogleFonts.jetBrainsMono(
                    color: scheme.onSurfaceVariant,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              TextFormField(
                controller: _title,
                autofocus: !widget.focusAmount,
                minLines: 1,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submit(),
                style: TextStyle(
                  color: scheme.onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
                decoration: const InputDecoration(
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  focusedErrorBorder: InputBorder.none,
                  contentPadding: EdgeInsets.fromLTRB(4, 10, 4, 10),
                  isDense: true,
                ),
                validator: (v) => (v ?? '').trim().isEmpty
                    ? context.l10n.txEnterDescription
                    : null,
              ),
              const SizedBox(height: 20),
              SaveButton(
                label: context.l10n.commonSave.toUpperCase(),
                color: scheme.primary,
                onColor: scheme.onPrimary,
                onTap: _submit,
              ),
              const SizedBox(height: 20),
              const KeyboardSpacer(),
            ],
          ),
        ),
      ),
    );
  }
}
