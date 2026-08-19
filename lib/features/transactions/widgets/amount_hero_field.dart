import 'package:budgetti/core/l10n.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AmountHeroField extends StatelessWidget {
  final TextEditingController controller;
  final String currencySymbol;
  final String type;

  const AmountHeroField({
    super.key,
    required this.controller,
    required this.currencySymbol,
    required this.type,
  });

  Color _typeColor(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return switch (type) {
      'expense' => scheme.error,
      'income' => scheme.primary,
      _ => scheme.tertiary,
    };
  }

  String _kicker(BuildContext context) => switch (type) {
        'expense' => context.l10n.txYouSpent,
        'income' => context.l10n.txYouReceived,
        _ => context.l10n.txYouTransferred,
      }.toUpperCase();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = _typeColor(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _kicker(context),
            style: GoogleFonts.jetBrainsMono(
              color: scheme.onSurfaceVariant,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                currencySymbol,
                style: GoogleFonts.jetBrainsMono(
                  color: scheme.onSurfaceVariant,
                  fontSize: 26,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.4,
                  height: 1.0,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: TextFormField(
                  controller: controller,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  cursorColor: color,
                  style: GoogleFonts.jetBrainsMono(
                    color: color,
                    fontSize: 52,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1.8,
                    height: 1.0,
                  ),
                  decoration: InputDecoration(
                    hintText: '0.00',
                    hintStyle: GoogleFonts.jetBrainsMono(
                      color: color.withValues(alpha: 0.22),
                      fontSize: 52,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1.8,
                      height: 1.0,
                    ),
                    border: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    isDense: true,
                    filled: false,
                    errorStyle: GoogleFonts.jetBrainsMono(
                      color: scheme.error,
                      fontSize: 11,
                      letterSpacing: 1.0,
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return context.l10n.txEnterAmount;
                    }
                    final sanitized = value.replaceAll(',', '.');
                    if (double.tryParse(sanitized) == null) {
                      return context.l10n.txInvalidAmount;
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
