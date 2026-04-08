import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:budgetti/core/providers/providers.dart';
import 'package:budgetti/models/transaction.dart';

String _titleCase(String s) {
  if (s.isEmpty) return s;
  return s.split(' ').map((w) {
    if (w.isEmpty) return w;
    return w[0].toUpperCase() + w.substring(1).toLowerCase();
  }).join(' ');
}

class TransactionItem extends ConsumerWidget {
  final Transaction transaction;
  final bool isSelected;
  final bool showDate;
  final VoidCallback? onLongPress;
  final VoidCallback? onTap;

  const TransactionItem({
    super.key,
    required this.transaction,
    this.isSelected = false,
    this.showDate = true,
    this.onLongPress,
    this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final isIncome = transaction.amount > 0;
    final formatter = ref.watch(currencyProvider);
    final categoryMap = ref.watch(categoryMapProvider);
    final transferColor = scheme.secondary;

    final category = categoryMap[transaction.category];
    final categoryColor =
        category != null ? Color(category.colorHex) : scheme.primary;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onLongPress: onLongPress,
            onTap: onTap,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: isSelected
                    ? scheme.primary.withValues(alpha: 0.12)
                    : scheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(20),
                border: isSelected
                    ? Border.all(color: scheme.primary, width: 2)
                    : null,
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 42,
                    child: showDate
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                DateFormat('dd').format(transaction.date),
                                style: TextStyle(
                                  color: scheme.onSurface,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                DateFormat('EEE')
                                    .format(transaction.date)
                                    .toUpperCase(),
                                style: TextStyle(
                                  color: scheme.onSurfaceVariant,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          )
                        : const SizedBox.shrink(),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: categoryColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: isSelected
                          ? Icon(
                              Icons.check,
                              color: scheme.primary,
                              size: 20,
                            )
                          : transaction.type == 'transfer'
                              ? Icon(
                                  Icons.swap_horiz,
                                  color: transferColor,
                                  size: 20,
                                )
                              : Icon(
                                  category != null
                                      ? IconData(
                                          category.iconCode,
                                          fontFamily: 'MaterialIcons',
                                        )
                                      : (isIncome
                                          ? Icons.arrow_downward
                                          : Icons.shopping_bag_outlined),
                                  color: categoryColor,
                                  size: 20,
                                ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _titleCase(transaction.description),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: scheme.onSurface,
                            fontSize: 15,
                            letterSpacing: 0.1,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              transaction.category,
                              style: TextStyle(
                                color: scheme.onSurfaceVariant,
                                fontSize: 13,
                              ),
                            ),
                            if (transaction.tags.isNotEmpty) ...[
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                ),
                                child: Container(
                                  width: 3,
                                  height: 3,
                                  decoration: BoxDecoration(
                                    color: scheme.onSurfaceVariant,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  transaction.tags.join(', '),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: scheme.onSurfaceVariant
                                        .withValues(alpha: 0.7),
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        transaction.type == 'transfer'
                            ? formatter.format(transaction.amount.abs())
                            : isIncome
                                ? "+${formatter.format(transaction.amount)}"
                                : formatter.format(transaction.amount),
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: transaction.type == 'transfer'
                              ? transferColor
                              : (isIncome
                                  ? scheme.primary
                                  : scheme.onSurface),
                          fontSize: 16,
                          letterSpacing: 0.3,
                        ),
                      ),
                      if (transaction.type == 'transfer')
                        Text(
                          "TRANSFER",
                          style: TextStyle(
                            color: transferColor,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
