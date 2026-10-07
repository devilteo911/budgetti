import 'package:budgetti/core/error_text.dart';
import 'package:budgetti/core/l10n.dart';
import 'package:budgetti/core/providers/providers.dart';
import 'package:budgetti/core/widgets/app_sheet.dart';
import 'package:budgetti/features/piva/piva_deadline_sheet.dart';
import 'package:budgetti/features/piva/piva_format.dart';
import 'package:budgetti/features/piva/piva_income_section.dart' show PivaTile;
import 'package:budgetti/features/stats/widgets/section_label.dart';
import 'package:budgetti/models/piva.dart';
import 'package:budgetti/models/transaction.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

/// Whether a deadline can go "back to the estimate": it is a saved row and, with
/// that row gone, the calendar still has an estimate under the same `key`. The
/// calendar is recomputed without the row, because an official amount of
/// contributions also moves the estimated tax rows: looking at the current list
/// is not enough. A hand-made row (empty `key`) or one whose `key` the calendar
/// no longer generates has nothing to go back to — it can only be deleted.
bool canRevertToEstimate(
  PivaProfileData profile,
  List<Transaction> txns,
  List<PivaPaymentData> payments,
  PivaDeadline d,
  DateTime now,
) {
  final id = d.paymentId;
  if (id == null || d.key.isEmpty) return false;
  final without = [
    for (final p in payments)
      if (p.id != id) p,
  ];
  return deadlines(profile, txns, without, now).any((r) => r.key == d.key && r.estimated);
}

/// The next deadline: of the unpaid ones still ahead (today counts), the one
/// whose day comes first; `null` if there is none. A row with no day is never
/// "next", nor is a past one (overdue or not recorded) or a paid one. The one
/// definition of it: the section's third tile and the dashboard card both ask
/// here. Of two on the same day the first in [rows] wins.
PivaDeadline? nextPivaDeadline(List<PivaDeadline> rows, DateTime today) {
  PivaDeadline? next;
  for (final r in rows) {
    final due = r.dueDate;
    if (due == null || deadlineState(r, today) != DeadlineState.due) continue;
    final best = next?.dueDate;
    if (best == null || _ord(due) < _ord(best)) next = r;
  }
  return next;
}

/// The local day of [d] as a number that sorts like the calendar — only year,
/// month and day count, as in the engine.
int _ord(DateTime d) {
  final l = d.toLocal();
  return l.year * 10000 + l.month * 100 + l.day;
}

/// Latest day first, a missing day last.
int _latestFirst(DateTime? a, DateTime? b) {
  if (a == null && b == null) return 0;
  if (a == null) return 1;
  if (b == null) return -1;
  return _ord(b).compareTo(_ord(a));
}

/// Up to this system text scale the tiles sit side by side and a row keeps its
/// button on the right; above it they stack, because there is no room.
const _roomyScale = 1.3;

bool _roomy(BuildContext context) => MediaQuery.textScalerOf(context).scale(1) <= _roomyScale;

/// The deadlines of the Partita IVA screen: three tiles, then the calendar by
/// state — open ones first, the past estimates nobody recorded, the paid ones —
/// with a tap on a row to edit it and one button per row to mark it paid.
/// Mirrors the "Calendar" card of `web/src/components/PivaForecast.tsx`.
///
/// Everything comes from the caller, and nothing fiscal is computed here: the
/// rows are the engine's [deadlines], the sums its [deadlineTotals]. [now] is the
/// day of "today" (the screen supplies the clock). Writes go to the database and
/// the lists below refresh from its streams.
class PivaDeadlinesSection extends ConsumerWidget {
  const PivaDeadlinesSection({
    super.key,
    required this.profile,
    required this.payments,
    required this.txns,
    required this.now,
  });

  final PivaProfileData profile;
  final List<PivaPaymentData> payments;
  final List<Transaction> txns;
  final DateTime now;

  /// The sheet of a row ([deadline] null: a new one). Whether the row can go back
  /// to its estimate is asked once, here, as the sheet opens.
  void _open(BuildContext context, {PivaDeadline? deadline, bool markPaid = false}) {
    final canRevert = deadline != null && canRevertToEstimate(profile, txns, payments, deadline, now);
    showAppSheet(
      context,
      isScrollControlled: true,
      builder: (_) =>
          PivaDeadlineSheet(deadline: deadline, markPaid: markPaid, canRevert: canRevert, now: now),
    );
  }

  /// The one-tap write of "Mark paid" / "Undo": the same saved row with a new
  /// `paidDate`. A failure (the database, nothing else can fail here) is a
  /// SnackBar; the list stays as it was, since it only changes with the data.
  Future<void> _setPaid(BuildContext context, WidgetRef ref, PivaDeadline r, DateTime? paidDate) async {
    try {
      await ref
          .read(financeServiceProvider)
          .savePivaPayment(
            id: r.paymentId,
            key: r.key,
            kind: r.kind,
            label: r.label,
            dueDate: r.dueDate,
            amount: r.amount,
            paidDate: paidDate,
            note: r.note,
          );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.pivaDlSaveError(errorText(context, e)))),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final currency = ref.watch(currencyProvider);

    final rows = deadlines(profile, txns, payments, now);
    final totals = deadlineTotals(rows, now);
    final next = nextPivaDeadline(rows, now);
    DeadlineState stateOf(PivaDeadline r) => deadlineState(r, now);
    final current = [
      for (final r in rows)
        if (stateOf(r) case DeadlineState.due || DeadlineState.overdue) r,
    ];
    final unrecorded = [
      for (final r in rows)
        if (stateOf(r) == DeadlineState.unrecorded) r,
    ];
    final paid = [
      for (final r in rows)
        if (stateOf(r) == DeadlineState.paid) r,
    ];
    // Most recent payment first, then the later due day, then the engine's order
    // (`List.sort` is not stable).
    final order = {for (var i = 0; i < rows.length; i++) rows[i]: i};
    paid.sort((a, b) {
      final byPaid = _latestFirst(a.paidDate, b.paidDate);
      if (byPaid != 0) return byPaid;
      final byDue = _latestFirst(a.dueDate, b.dueDate);
      return byDue != 0 ? byDue : order[a]!.compareTo(order[b]!);
    });

    Widget rowFor(PivaDeadline r) {
      final state = stateOf(r);
      return _DeadlineRow(
        key: ValueKey(r.paymentId ?? r.key),
        row: r,
        state: state,
        currency: currency,
        onOpen: () => _open(context, deadline: r),
        onAction: () {
          if (state == DeadlineState.paid) {
            _setPaid(context, ref, r, null);
          } else if (r.estimated) {
            // Saving an estimate freezes it as the official amount: ask first.
            _open(context, deadline: r, markPaid: true);
          } else {
            _setPaid(context, ref, r, now);
          }
        },
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Header(onAdd: () => _open(context)),
        _TileGrid(
          tiles: [
            PivaTile(
              // The calendar year of today, not whatever year the compensi show.
              label: l10n.pivaDlDueByDec(now.toLocal().year),
              value: currency.format(totals.upcoming),
              sub: l10n.pivaDlCount(totals.count.upcoming),
            ),
            if (totals.overdue > 0)
              PivaTile(
                label: l10n.pivaDlOverdue,
                value: currency.format(totals.overdue),
                sub: l10n.pivaDlOverdueCount(totals.count.overdue),
                subInk: scheme.error,
              )
            else if (totals.unrecorded > 0)
              PivaTile(
                label: l10n.pivaDlNotRecorded,
                value: currency.format(totals.unrecorded),
                sub: l10n.pivaDlNotRecordedHint(totals.count.unrecorded),
              )
            else
              PivaTile(
                label: l10n.pivaDlOverdue,
                value: currency.format(0),
                sub: l10n.pivaDlNothingOverdue,
              ),
            PivaTile(
              label: l10n.pivaDlNext,
              value: next == null ? '—' : DateFormat.yMMMd().format(next.dueDate!),
              sub: next == null
                  ? l10n.pivaDlNothingUpcoming
                  : pivaNoBreak('${next.label} · ${currency.format(next.amount)}'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (rows.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Text(
              l10n.pivaDlEmpty,
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13, height: 1.4),
            ),
          )
        else ...[
          for (final r in current) rowFor(r),
          if (unrecorded.isNotEmpty) ...[
            SectionLabel(text: l10n.pivaDlGroupUnrecorded, count: unrecorded.length),
            for (final r in unrecorded) rowFor(r),
          ],
          if (paid.isNotEmpty) ...[
            SectionLabel(text: l10n.pivaDlGroupPaid, count: paid.length),
            for (final r in paid) rowFor(r),
          ],
        ],
      ],
    );
  }
}

/// "DEADLINES" in the look of a `SectionLabel`, and the button that adds one. A
/// `Wrap`, not a `Row`: at a large font the button drops under the title at its
/// full size instead of shrinking below a touch target.
class _Header extends StatelessWidget {
  const _Header({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 8, 4),
      child: SizedBox(
        width: double.infinity,
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Semantics(
              header: true,
              child: Text(
                l10n.pivaDlTitle.toUpperCase(),
                style: GoogleFonts.jetBrainsMono(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: onAdd,
              style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
              icon: const Icon(Icons.add, size: 18),
              label: Text(l10n.pivaDlAdd),
            ),
          ],
        ),
      ),
    );
  }
}

/// The three tiles in the bordered grid of the compensi: side by side only on a
/// wide screen (a tablet), one under the other on a phone. At 390 dp each of three
/// tiles has ~100 dp of text: "Da versare entro dic 2026" shrinks to ~7 sp and
/// the hint under the middle one wraps to six lines.
class _TileGrid extends StatelessWidget {
  const _TileGrid({required this.tiles});

  final List<Widget> tiles;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 720 && _roomy(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Table(
        border: TableBorder.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.12)),
        children: wide
            ? [TableRow(children: tiles)]
            : [
                for (final t in tiles) TableRow(children: [t]),
              ],
      ),
    );
  }
}

/// One deadline: label and amount, the day and the kind, the note, then the state
/// chips with the button that marks it paid (or takes that back) at the end of
/// their line. The whole row opens the sheet.
class _DeadlineRow extends StatelessWidget {
  const _DeadlineRow({
    super.key,
    required this.row,
    required this.state,
    required this.currency,
    required this.onOpen,
    required this.onAction,
  });

  final PivaDeadline row;
  final DeadlineState state;
  final NumberFormat currency;
  final VoidCallback onOpen, onAction;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final quiet = scheme.onSurfaceVariant;
    final paid = state == DeadlineState.paid;
    final ink = paid ? quiet : scheme.onSurface;
    final due = row.dueDate;
    final date = due == null ? l10n.pivaDlNoDate : DateFormat.yMMMd().format(due);
    final type = isPassThrough(row)
        ? l10n.pivaDlTypePassThrough
        : row.kind == 'contributi'
        ? pivaContributions
        : pivaTaxKind;
    final small = GoogleFonts.jetBrainsMono(color: quiet, fontSize: 11, letterSpacing: 0.3, height: 1.4);

    final top = <Widget>[
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              pivaNoBreak(row.label),
              style: GoogleFonts.bricolageGrotesque(color: ink, fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            currency.format(row.amount),
            style: GoogleFonts.jetBrainsMono(color: ink, fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ],
      ),
      const SizedBox(height: 2),
      Text('$date · $type', style: small),
      if (row.note.isNotEmpty) Text(row.note, style: small),
    ];

    final action = paid ? l10n.pivaDlUndoPaid : l10n.pivaDlMarkPaid;
    // The button's own text is the same on every row: the label says which one.
    final button = Semantics(
      container: true,
      button: true,
      label: '$action: ${row.label}',
      onTap: onAction,
      excludeSemantics: true,
      child: TextButton(
        onPressed: onAction,
        style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
        child: Text(action),
      ),
    );

    // Label and amount across the whole row, the state chips and the button on the
    // line below: a button on the right would leave the label a third of the width.
    return InkWell(
      onTap: onOpen,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 8, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: top),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (state == DeadlineState.unrecorded)
                        _Chip(l10n.pivaDlChipNotRecorded, ink: quiet)
                      else if (row.estimated)
                        _Chip(l10n.pivaDlChipEstimate, ink: quiet)
                      else
                        _Chip(l10n.pivaDlChipOfficial, ink: scheme.primary),
                      if (state == DeadlineState.overdue) _Chip(l10n.pivaDlOverdue, ink: scheme.error),
                      if (paid)
                        _Chip(l10n.pivaDlPaidOn(DateFormat.yMMMd().format(row.paidDate!)), ink: quiet),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                button,
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A small outlined tag. There is no shared chip widget in `core/widgets`.
class _Chip extends StatelessWidget {
  const _Chip(this.text, {required this.ink});

  final String text;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: ink.withValues(alpha: 0.45)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Text(
          text,
          style: GoogleFonts.jetBrainsMono(
            color: ink,
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.6,
          ),
        ),
      ),
    );
  }
}
