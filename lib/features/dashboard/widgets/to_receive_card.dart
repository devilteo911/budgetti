import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:budgetti/core/l10n.dart';
import 'package:budgetti/core/providers/providers.dart';
import 'package:budgetti/core/theme/ledger_style.dart';
import 'package:budgetti/core/widgets/app_sheet.dart';
import 'package:budgetti/features/transactions/add_transaction_modal.dart';
import 'package:budgetti/models/transaction.dart';

/// Dashboard read for the shared expenses the others still owe on: the total
/// and one row per open expense, each opening the expense in the editor (mirror:
/// the web's `ToReceive.tsx`). Same bordered-strip language as
/// [InstallmentsCard]. Hidden while loading, on error and while nothing is
/// owed, so the home never advertises an unused feature. There is no screen
/// behind it: the editor of the expense is where its reimbursements are linked.
class ToReceiveCard extends ConsumerWidget {
  const ToReceiveCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final open = ref.watch(toReceiveProvider).value;
    final byId =
        ref.watch(receivablesProvider).value ?? const <String, Receivable>{};
    if (open == null || open.expenses.isEmpty) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    final currency = ref.watch(currencyProvider);
    final border = BorderSide(color: scheme.outline.withValues(alpha: 0.12));

    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: border, left: border, right: border),
      ),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _KLabel(context.l10n.dashToReceive.toUpperCase()),
          const SizedBox(height: 10),
          Text(
            currency.format(open.total),
            style: GoogleFonts.bricolageGrotesque(
              color: scheme.onSurface,
              fontSize: 34,
              fontWeight: FontWeight.w800,
              letterSpacing: -1.4,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 8),
          // ponytail: every open expense is listed, no cap: few are expected (as
          // the web's panel). A cap with "+N more" comes if the card grows long.
          for (final t in open.expenses)
            if (byId[t.id] case final r?) _Row(t: t, r: r, currency: currency),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.t, required this.r, required this.currency});

  final Transaction t;
  final Receivable r;
  final NumberFormat currency;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final description = t.description.trim();
    final title = description.isEmpty ? t.category : description;
    final outstanding = currency.format(r.outstanding);

    // As the ledger's long-press selection does (`_editSelected`).
    void openEditor() => showAppSheet(
          context,
          isScrollControlled: true,
          showDragHandle: true,
          builder: (_) => AddTransactionModal(transaction: t),
        );

    // The label replaces the row's texts, so the tap is repeated on the node.
    return Semantics(
      label: l10n.dashOpenToReceive(title, outstanding),
      button: true,
      onTap: openEditor,
      excludeSemantics: true,
      child: InkWell(
        onTap: openEditor,
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: scheme.outline.withValues(alpha: 0.06)),
            ),
          ),
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.bricolageGrotesque(
                        color: scheme.onSurface,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 3),
                    // Wraps rather than ellipsizes: what is owed and what came
                    // back is what the card is for.
                    Text(
                      '${DateFormat.MMMd().format(t.date)} · '
                      '${l10n.dashOwedReceived(currency.format(r.owed), currency.format(r.received))}',
                      style: GoogleFonts.jetBrainsMono(
                        color: scheme.onSurfaceVariant,
                        fontSize: 11,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                outstanding,
                style: GoogleFonts.jetBrainsMono(
                  color: incomeInk(scheme.brightness),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
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
        fontSize: 11,
        letterSpacing: 1.2,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}
