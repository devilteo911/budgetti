import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:budgetti/core/providers/providers.dart';

/// Dashboard entry point for installment plans: what's still owed and the next
/// rate due. Same bordered-strip language as [BudgetOverviewCard], including
/// its empty state — that's the only way to reach the screen and create the
/// first plan.
class InstallmentsCard extends ConsumerWidget {
  const InstallmentsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final currency = ref.watch(currencyProvider);
    final plans = ref.watch(installmentsProvider).value ?? const [];
    final active = plans.where((p) => p.isActive()).toList();

    final border = BorderSide(color: scheme.outline.withValues(alpha: 0.12));
    final boxBorder = Border(bottom: border, left: border, right: border);

    if (active.isEmpty) {
      return InkWell(
        onTap: () => context.push('/installments'),
        child: Container(
          decoration: BoxDecoration(border: boxBorder),
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Icon(Icons.receipt_long_outlined, color: scheme.primary, size: 24),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Track installments',
                        style: GoogleFonts.bricolageGrotesque(
                          color: scheme.onSurface,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        )),
                    const SizedBox(height: 2),
                    Text('See what you still owe on monthly rates',
                        style: GoogleFonts.jetBrainsMono(
                          color: scheme.onSurfaceVariant,
                          fontSize: 10,
                          letterSpacing: 0.6,
                        )),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward,
                  color: scheme.onSurfaceVariant, size: 16),
            ],
          ),
        ),
      );
    }

    final owed = active.fold<double>(0, (s, p) => s + p.remainingAmount());
    final monthly =
        active.fold<double>(0, (s, p) => s + p.amountPerInstallment);
    // Soonest upcoming rate across the running plans.
    final next = active
        .map((p) => p.nextDueDate())
        .whereType<DateTime>()
        .reduce((a, b) => a.isBefore(b) ? a : b);

    return InkWell(
      onTap: () => context.push('/installments'),
      child: Container(
        decoration: BoxDecoration(border: boxBorder),
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _KLabel('STILL OWED'),
                  const SizedBox(height: 10),
                  Text(
                    currency.format(owed),
                    style: GoogleFonts.bricolageGrotesque(
                      color: scheme.onSurface,
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1.4,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${currency.format(monthly)} / month',
                    style: GoogleFonts.jetBrainsMono(
                      color: scheme.onSurfaceVariant,
                      fontSize: 11,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _KLabel('PLANS'),
                  const SizedBox(height: 10),
                  ...active.take(3).map((p) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                p.description.toUpperCase(),
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.jetBrainsMono(
                                  color: scheme.onSurfaceVariant,
                                  fontSize: 10,
                                  letterSpacing: 0.6,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${p.paidCount()}/${p.installmentCount}',
                              style: GoogleFonts.jetBrainsMono(
                                color: scheme.onSurface,
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      )),
                  if (active.length > 3)
                    Text(
                      '+${active.length - 3} more',
                      style: GoogleFonts.jetBrainsMono(
                        color: scheme.onSurfaceVariant,
                        fontSize: 10,
                        letterSpacing: 0.6,
                      ),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    'NEXT ${DateFormat.MMMd().format(next).toUpperCase()}',
                    style: GoogleFonts.jetBrainsMono(
                      color: scheme.primary,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KLabel extends StatelessWidget {
  const _KLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Text(
      text,
      style: GoogleFonts.jetBrainsMono(
        color: scheme.onSurfaceVariant,
        fontSize: 10,
        letterSpacing: 1.8,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}
