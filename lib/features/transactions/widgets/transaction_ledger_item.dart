import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:budgetti/core/providers/providers.dart';
import 'package:budgetti/core/theme/ledger_style.dart';
import 'package:budgetti/models/transaction.dart';

/// Left edge shared by every element of the ledger: the hero, the month
/// headers, the rows and the dividers all hang off this one inset.
const double kLedgerInset = 20;

/// Where the title column starts, measured from [kLedgerInset]: day column +
/// gap + icon tile + gap. Dividers are inset to it so they separate content
/// rather than cutting the screen in half.
const double kLedgerTextOffset = 28 + 12 + 36 + 14;

/// Every row is this tall, no exceptions — a row with a tag must not be taller
/// than one without, or the list loses its rhythm.
const double kLedgerRowHeight = 64;

class TransactionLedgerItem extends ConsumerWidget {
  final Transaction transaction;
  final bool isSelected;

  /// Whether to print the wallet name. The list passes false when this row's
  /// wallet is the same as the row above, so a column of eleven identical
  /// "WIDIBA" labels collapses to one.
  final bool showWallet;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const TransactionLedgerItem({
    super.key,
    required this.transaction,
    this.isSelected = false,
    this.showWallet = false,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final categoryColors =
        ref.watch(categoryColorCacheProvider(scheme.brightness));
    final categoryIcons = ref.watch(categoryIconCacheProvider);
    final accountMap = ref.watch(accountMapProvider);
    final formatter = ref.watch(currencyProvider);

    final isTransfer = transaction.type == 'transfer';
    final isIncome = transaction.amount > 0 && !isTransfer;

    // A transfer is not a category, so it borrows the muted ink instead of
    // colouring itself in whatever category happens to be attached.
    final accent = isTransfer
        ? scheme.onSurfaceVariant
        : categoryColors[transaction.category] ?? unknownCategoryInk(scheme);
    final icon = isTransfer
        ? Icons.swap_horiz
        : categoryIcons[transaction.category] ??
            categoryIcon(transaction.category, isIncome: isIncome);

    final amountText = isTransfer
        ? formatter.format(transaction.amount.abs())
        : (isIncome
            ? '+${formatter.format(transaction.amount)}'
            : formatter.format(transaction.amount));

    // ponytail: wallet only when it adds something — one account means nothing
    // to tell apart, and a repeat of the row above means nothing new.
    final walletName = showWallet && accountMap.length > 1
        ? accountMap[transaction.accountId]?.name
        : null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          height: kLedgerRowHeight,
          color: isSelected
              ? scheme.primary.withValues(alpha: 0.10)
              : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: kLedgerInset),
          child: Row(
            children: [
              SizedBox(
                width: 28,
                child: isSelected
                    ? Icon(Icons.check, size: 18, color: scheme.primary)
                    : Text(
                        DateFormat('dd').format(transaction.date),
                        style: GoogleFonts.jetBrainsMono(
                          color: scheme.onSurfaceVariant,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          height: 1.0,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  // Pure black eats low-alpha fills, and it eats the cool hues
                  // hardest — the greens vanished at 0.16 while the ambers were
                  // fine. Lifted until the dimmest slot still reads as a tile.
                  color: accent.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Center(child: Icon(icon, color: accent, size: 18)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
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
                    const SizedBox(height: 3),
                    _MetaRow(
                      category: transaction.category,
                      tags: transaction.tags,
                      ink: scheme.onSurfaceVariant,
                      outline: scheme.outlineVariant,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    amountText,
                    style: GoogleFonts.jetBrainsMono(
                      color: amountInk(
                        scheme,
                        isTransfer: isTransfer,
                        isIncome: isIncome,
                      ),
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0,
                      height: 1.2,
                      fontFeatures: const [FontFeature.tabularFigures()],
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
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                        height: 1.0,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Category, then its tags. A tag is a filter facet, not a semantic — it gets a
/// hairline outline and the same muted ink as everything else, instead of the
/// filled per-tag colour chip that used to make the least important datum on the
/// row the loudest thing on it.
class _MetaRow extends StatelessWidget {
  final String category;
  final List<String> tags;
  final Color ink;
  final Color outline;

  const _MetaRow({
    required this.category,
    required this.tags,
    required this.ink,
    required this.outline,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Flexible(
          child: Text(
            category,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: ink,
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              height: 1.2,
            ),
          ),
        ),
        for (final name in tags) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
            decoration: BoxDecoration(
              border: Border.all(color: outline, width: 1),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              name,
              style: TextStyle(
                color: ink,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                height: 1.2,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
