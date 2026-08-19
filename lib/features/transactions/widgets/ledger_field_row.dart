import 'package:budgetti/core/l10n.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class LedgerFieldRow extends StatelessWidget {
  final String kicker;
  final String? value;
  final String? placeholder;
  final IconData? leadingIcon;
  final Color? leadingColor;
  final bool showStripe;
  final bool isError;
  final VoidCallback? onTap;
  final Widget? trailing;
  final Widget? valueOverride;

  const LedgerFieldRow({
    super.key,
    required this.kicker,
    this.value,
    this.placeholder,
    this.leadingIcon,
    this.leadingColor,
    this.showStripe = false,
    this.isError = false,
    this.onTap,
    this.trailing,
    this.valueOverride,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final stripeColor = leadingColor ?? scheme.onSurfaceVariant;
    final hasValue = (value != null && value!.isNotEmpty) || valueOverride != null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (showStripe) ...[
                Container(
                  width: 3,
                  height: 32,
                  decoration: BoxDecoration(
                    color: stripeColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              if (leadingIcon != null) ...[
                Icon(
                  leadingIcon,
                  size: 18,
                  color: leadingColor ?? scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
              ],
              SizedBox(
                width: 92,
                child: Text(
                  kicker,
                  style: GoogleFonts.jetBrainsMono(
                    color: isError ? scheme.error : scheme.onSurfaceVariant,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              Expanded(
                child: valueOverride ??
                    Text(
                      hasValue
                          ? value!
                          : (placeholder ?? context.l10n.txSelect),
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: hasValue
                            ? scheme.onSurface
                            : (isError
                                ? scheme.error
                                : scheme.onSurfaceVariant),
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0,
                      ),
                    ),
              ),
              const SizedBox(width: 8),
              trailing ??
                  (onTap != null
                      ? Icon(
                          Icons.chevron_right_rounded,
                          size: 18,
                          color: scheme.onSurfaceVariant
                              .withValues(alpha: 0.6),
                        )
                      : const SizedBox(width: 18)),
            ],
          ),
        ),
      ),
    );
  }
}

class LedgerDivider extends StatelessWidget {
  const LedgerDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      color:
          Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.2),
    );
  }
}
