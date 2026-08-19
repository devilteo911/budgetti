import 'package:budgetti/core/l10n.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class TypeSelector extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;

  const TypeSelector({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        _chip(context, 'expense', context.l10n.commonExpense.toUpperCase(),
            scheme.error, scheme.onError),
        const SizedBox(width: 8),
        _chip(context, 'income', context.l10n.commonIncome.toUpperCase(),
            scheme.primary, scheme.onPrimary),
        const SizedBox(width: 8),
        _chip(context, 'transfer', context.l10n.commonTransfer.toUpperCase(),
            scheme.tertiary, scheme.onTertiary),
      ],
    );
  }

  Widget _chip(
    BuildContext context,
    String value,
    String label,
    Color accent,
    Color onAccent,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final isSelected = selected == value;
    return Expanded(
      child: Material(
        color: isSelected ? accent : Colors.transparent,
        shape: StadiumBorder(
          side: BorderSide(
            color: isSelected
                ? accent
                : scheme.outlineVariant.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: () => onChanged(value),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Center(
              child: Text(
                label,
                style: GoogleFonts.jetBrainsMono(
                  color: isSelected ? onAccent : scheme.onSurfaceVariant,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
