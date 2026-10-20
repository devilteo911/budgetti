import 'package:budgetti/core/l10n.dart';
import 'package:budgetti/core/providers/providers.dart';
import 'package:budgetti/core/theme/ledger_style.dart';
import 'package:budgetti/features/transactions/widgets/receivable_badge.dart';
import 'package:budgetti/models/tag.dart';
import 'package:budgetti/models/transaction.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class TransactionLedgerRow extends ConsumerWidget {
  final Transaction txn;
  final NumberFormat currencyFormatter;
  final Map<String, Tag> tagMap;

  const TransactionLedgerRow({
    super.key,
    required this.txn,
    required this.currencyFormatter,
    required this.tagMap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    // The category's rows are the raw list, so a shared expense and the income
    // that pays it back are both here: say what is owed, like the ledger.
    final tag = shareTag(
      context.l10n,
      currencyFormatter,
      txn,
      ref.watch(receivablesProvider).value ?? const <String, Receivable>{},
    );
    final amount = txn.amount.abs();
    final isExpense = txn.amount < 0;
    final amountColor = isExpense ? scheme.onSurface : scheme.primary;
    final prefix = isExpense ? '' : '+';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 52,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormat('dd').format(txn.date),
                  style: GoogleFonts.jetBrainsMono(
                    color: scheme.onSurface,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  DateFormat('MMM').format(txn.date).toUpperCase(),
                  style: GoogleFonts.jetBrainsMono(
                    color: scheme.onSurfaceVariant,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
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
                Text(
                  txn.description.isEmpty ? '—' : txn.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    height: 1.25,
                  ),
                ),
                // Wraps rather than ellipsizes: the row has no fixed height.
                if (tag != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    tag.full,
                    style: GoogleFonts.jetBrainsMono(
                      color: tag.owed
                          ? incomeInk(scheme.brightness)
                          : scheme.onSurfaceVariant,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                ],
                if (txn.tags.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: txn.tags.map((name) {
                      final tag = tagMap[name];
                      final color = tag != null
                          ? Color(tag.colorHex)
                          : scheme.onSurfaceVariant;
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          name,
                          style: GoogleFonts.jetBrainsMono(
                            color: color,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '$prefix${currencyFormatter.format(amount)}',
            style: GoogleFonts.jetBrainsMono(
              color: amountColor,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}
