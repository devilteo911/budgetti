import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:budgetti/core/providers/providers.dart';
import 'package:budgetti/models/tag.dart';
import 'package:budgetti/models/transaction.dart';

class TransactionLedgerItem extends ConsumerWidget {
  final Transaction transaction;
  final bool isSelected;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const TransactionLedgerItem({
    super.key,
    required this.transaction,
    this.isSelected = false,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final categoryMap = ref.watch(categoryMapProvider);
    final tagMap = ref.watch(tagMapProvider);
    final accountMap = ref.watch(accountMapProvider);
    final formatter = ref.watch(currencyProvider);

    // ponytail: with a single wallet the label is noise — only show it once
    // there is something to tell apart. For transfers it's the source wallet.
    final walletName = accountMap.length > 1
        ? accountMap[transaction.accountId]?.name
        : null;

    final isTransfer = transaction.type == 'transfer';
    final isIncome = transaction.amount > 0 && !isTransfer;
    final category = categoryMap[transaction.category];
    final categoryColor = category != null
        ? Color(category.colorHex)
        : scheme.onSurfaceVariant;

    final stripeColor = isSelected ? scheme.primary : categoryColor;
    final amountColor = isTransfer
        ? scheme.secondary
        : (isIncome ? scheme.primary : scheme.onSurface);
    final amountText = isTransfer
        ? formatter.format(transaction.amount.abs())
        : (isIncome
            ? '+${formatter.format(transaction.amount)}'
            : formatter.format(transaction.amount));

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          color: isSelected
              ? scheme.primary.withValues(alpha: 0.08)
              : Colors.transparent,
          padding: const EdgeInsets.fromLTRB(16, 13, 20, 13),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 3,
                height: 40,
                margin: const EdgeInsets.only(top: 2, right: 13),
                decoration: BoxDecoration(
                  color: stripeColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(
                width: 36,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    isSelected
                        ? Icon(
                            Icons.check,
                            size: 18,
                            color: scheme.primary,
                          )
                        : Text(
                            DateFormat('dd').format(transaction.date),
                            style: GoogleFonts.jetBrainsMono(
                              color: scheme.onSurface,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.3,
                              height: 1.0,
                            ),
                          ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('MMM').format(transaction.date).toUpperCase(),
                      style: GoogleFonts.jetBrainsMono(
                        color: scheme.onSurfaceVariant,
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: categoryColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Icon(
                    _iconFor(transaction, category?.iconCode),
                    color: isTransfer ? scheme.secondary : categoryColor,
                    size: 18,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transaction.description.isEmpty
                          ? '—'
                          : transaction.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: scheme.onSurface,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 4),
                    _MetaRow(
                      category: transaction.category,
                      tags: transaction.tags,
                      tagMap: tagMap,
                      fallbackTagColor: scheme.onSurfaceVariant,
                      mutedColor: scheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 110),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      amountText,
                      style: GoogleFonts.jetBrainsMono(
                        color: amountColor,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                        height: 1.2,
                      ),
                    ),
                    if (walletName != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        walletName.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.jetBrainsMono(
                          color: scheme.onSurfaceVariant,
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconFor(Transaction t, int? iconCode) {
    if (t.type == 'transfer') return Icons.swap_horiz;
    if (iconCode != null) {
      return IconData(iconCode, fontFamily: 'MaterialIcons');
    }
    return t.amount > 0 ? Icons.arrow_downward : Icons.shopping_bag_outlined;
  }
}

class _MetaRow extends StatelessWidget {
  final String category;
  final List<String> tags;
  final Map<String, Tag> tagMap;
  final Color fallbackTagColor;
  final Color mutedColor;

  const _MetaRow({
    required this.category,
    required this.tags,
    required this.tagMap,
    required this.fallbackTagColor,
    required this.mutedColor,
  });

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[
      Flexible(
        child: Text(
          category,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: mutedColor,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    ];

    for (final name in tags) {
      final tag = tagMap[name];
      final color = tag != null ? Color(tag.colorHex) : fallbackTagColor;
      children.add(const SizedBox(width: 6));
      children.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            name,
            style: GoogleFonts.jetBrainsMono(
              color: color,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }
}
