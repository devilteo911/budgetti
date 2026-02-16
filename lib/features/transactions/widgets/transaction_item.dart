import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:budgetti/core/providers/providers.dart';
import 'package:budgetti/core/theme/app_theme.dart';
import 'package:budgetti/models/transaction.dart';

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
    final isIncome = transaction.amount > 0;
    final formatter = ref.watch(currencyProvider);
    final categoryMap = ref.watch(categoryMapProvider);

    final category = categoryMap[transaction.category];
    final categoryColor = category != null
        ? Color(category.colorHex)
        : AppTheme.primaryGreen;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onLongPress: onLongPress,
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    isSelected
                        ? AppTheme.primaryGreen.withOpacity(0.15)
                        : AppTheme.surfaceGrey.withOpacity(0.8),
                    isSelected
                        ? AppTheme.primaryGreen.withOpacity(0.05)
                        : AppTheme.surfaceGrey.withOpacity(0.4),
                  ],
                ),
                border: Border.all(
                  color: isSelected
                      ? AppTheme.primaryGreen
                      : categoryColor.withOpacity(0.15),
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  // Inline Date Indicator
                  SizedBox(
                    width: 42,
                    child: showDate
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                DateFormat('dd').format(transaction.date),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              Text(
                                DateFormat(
                                  'EEE',
                                ).format(transaction.date).toUpperCase(),
                                style: TextStyle(
                                  color: AppTheme.textGrey.withOpacity(0.6),
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
                  // Icon Container with glass effect
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          categoryColor.withOpacity(0.2),
                          categoryColor.withOpacity(0.05),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: categoryColor.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Center(
                      child: isSelected
                          ? const Icon(
                              Icons.check,
                              color: AppTheme.primaryGreen,
                              size: 20,
                            )
                          : transaction.type == 'transfer'
                          ? const Icon(
                              Icons.swap_horiz,
                              color: Colors.blue,
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
                          transaction.description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontSize: 16,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              transaction.category,
                              style: const TextStyle(
                                color: AppTheme.textGrey,
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
                                  decoration: const BoxDecoration(
                                    color: AppTheme.textGrey,
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
                                    color: AppTheme.textGrey.withOpacity(0.7),
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
                          fontWeight: FontWeight.w900,
                          color: transaction.type == 'transfer'
                              ? Colors.blue
                              : (isIncome
                                    ? AppTheme.primaryGreen
                                    : Colors.white),
                          fontSize: 16,
                          letterSpacing: 0.5,
                        ),
                      ),
                      if (transaction.type == 'transfer')
                        const Text(
                          "TRANSFER",
                          style: TextStyle(
                            color: Colors.blue,
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
