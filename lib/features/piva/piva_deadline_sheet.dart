import 'dart:convert';

import 'package:budgetti/core/error_text.dart';
import 'package:budgetti/core/l10n.dart';
// Also brings `parseAmount`: providers.dart re-exports finance_math.dart.
import 'package:budgetti/core/providers/providers.dart';
import 'package:budgetti/core/widgets/discard_guard.dart';
import 'package:budgetti/core/widgets/inline_sheet_message.dart';
import 'package:budgetti/features/piva/piva_format.dart';
import 'package:budgetti/models/piva.dart' show PivaDeadline, isPassThrough;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

/// The name of the `imposta` kind on a deadline. A fiscal term, the same in both
/// languages, so a Dart constant and not an ARB key; the `contributi` kind is
/// [pivaContributions] in `piva_format.dart`. Public because the deadlines list
/// of the screen names the kind the same way.
const pivaTaxKind = 'Imposta';

const _decimal = TextInputType.numberWithOptions(decimal: true);

/// Set the official amount of a deadline, move its day, note it, mark it paid,
/// add one by hand, go back to the estimate or delete it. Mirrors the edit form
/// of the web's `PivaForecast.tsx`.
///
/// [deadline] null is a new, hand-made deadline. One with a non-empty `key` is a
/// calendar deadline: its label and kind are fixed text, only what the
/// accountant says (amount, day, note, payment) is edited. [markPaid] opens it
/// with "Paid" already on. [canRevert] says that once the saved row is gone an
/// estimate with the same `key` remains, so the destructive button reads "Back
/// to estimate" and not "Delete". [now] is for tests.
///
/// The whole form is read from the widget once, in `initState`: a sync that
/// changes the row underneath must not touch what is being typed, and saving
/// wins because its `lastUpdated` is the newest.
class PivaDeadlineSheet extends ConsumerStatefulWidget {
  const PivaDeadlineSheet({
    super.key,
    this.deadline,
    this.markPaid = false,
    this.canRevert = false,
    this.now,
  });

  final PivaDeadline? deadline;
  final bool markPaid, canRevert;
  final DateTime? now;

  @override
  ConsumerState<PivaDeadlineSheet> createState() => _PivaDeadlineSheetState();
}

class _PivaDeadlineSheetState extends ConsumerState<PivaDeadlineSheet> {
  /// The deadline the sheet opened on: everything below reads this, never
  /// `widget.deadline` again.
  late final PivaDeadline? _deadline;
  late final TextEditingController _label, _amount, _note;
  late final DateTime _now;
  late String _kind;
  DateTime? _due;
  late DateTime _paidDate;
  late bool _paid;
  bool _saving = false;

  /// The first broken rule, or a failed write, shown above the buttons: a
  /// SnackBar would be drawn behind this sheet.
  String? _error;

  /// Everything the form holds, compared against the snapshot taken when the
  /// sheet opened.
  String get _snapshot => jsonEncode([
    _kind,
    _label.text,
    _amount.text,
    _due?.toIso8601String(),
    _note.text,
    _paid,
    _paid ? _paidDate.toIso8601String() : null,
  ]);
  late final String _openedWith;

  @override
  void initState() {
    super.initState();
    final d = _deadline = widget.deadline;
    _now = widget.now ?? DateTime.now();
    // The server keeps `kind` as text: anything but `contributi` is `imposta`.
    _kind = d?.kind == 'contributi' ? 'contributi' : 'imposta';
    _label = TextEditingController(text: d?.label ?? '');
    // The shortest form of the number, never fixed decimals: `parseAmount` reads
    // a three-digit tail as thousands. A saved estimate is prefilled too: saving
    // it freezes it as the official amount.
    _amount = TextEditingController(text: d == null ? '' : pivaNumber(d.amount));
    _due = d?.dueDate;
    _note = TextEditingController(text: d?.note ?? '');
    _paid = widget.markPaid || d?.paidDate != null;
    _paidDate = d?.paidDate ?? DateTime(_now.year, _now.month, _now.day);
    _openedWith = _snapshot;
  }

  @override
  void dispose() {
    _label.dispose();
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  /// Every edit goes through here: the form rebuilds (so `DiscardGuard` sees
  /// the new snapshot) and a message left over from the last write is gone.
  void _changed(VoidCallback edit) => setState(() {
    edit();
    _error = null;
  });

  Future<void> _pick(DateTime? current, ValueChanged<DateTime> set) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? _now,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && mounted) _changed(() => set(picked));
  }

  void _fail(String message) => setState(() => _error = message);

  Future<void> _save() async {
    final l10n = context.l10n;
    final amount = parseAmount(_amount.text);
    final due = _due;
    // In field order, the first one stops. Zero is an amount: "nothing due" is
    // something the accountant says.
    if (amount == null || !amount.isFinite || amount < 0) {
      _fail(l10n.pivaDlErrAmount);
      return;
    }
    if (due == null) {
      _fail(l10n.pivaDlErrDue);
      return;
    }
    final d = _deadline;
    if ((d == null || d.key.isEmpty) && _label.text.trim().isEmpty) {
      _fail(l10n.pivaDlErrLabel);
      return;
    }
    setState(() {
      _error = null;
      _saving = true;
    });
    try {
      await ref
          .read(financeServiceProvider)
          .savePivaPayment(
            id: d?.paymentId,
            key: d?.key ?? '',
            kind: _kind,
            label: _label.text,
            dueDate: due,
            amount: amount,
            paidDate: _paid ? _paidDate : null,
            note: _note.text,
          );
      // `_saving` stays set: the button must not take a second tap while the
      // sheet slides away.
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = context.l10n.pivaDlSaveError(errorText(context, e));
          _saving = false;
        });
      }
    }
  }

  Future<void> _delete() async {
    final l10n = context.l10n;
    final d = _deadline;
    final id = d?.paymentId;
    if (d == null || id == null) return;
    final revert = widget.canRevert;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(revert ? l10n.pivaDlRevertTitle : l10n.pivaDlDeleteTitle),
        content: Text(
          revert
              ? l10n.pivaDlRevertBody(d.label)
              : l10n.pivaDlDeleteBody(d.label),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(revert ? l10n.pivaDlBackToEstimate : l10n.commonDelete),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() {
      _error = null;
      _saving = true;
    });
    try {
      await ref.read(financeServiceProvider).deletePivaPayment(id);
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = context.l10n.pivaDlDeleteError(errorText(context, e));
          _saving = false;
        });
      }
    }
  }

  /// The kind of a calendar deadline, as the fixed text under its label.
  String _typeName(PivaDeadline d) {
    if (isPassThrough(d)) return context.l10n.pivaDlTypePassThrough;
    return d.kind == 'contributi' ? pivaContributions : pivaTaxKind;
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    String? hint,
    String? prefix,
    TextInputType? type,
    bool autofocus = false,
    TextCapitalization capitalization = TextCapitalization.none,
  }) => TextField(
    controller: controller,
    autofocus: autofocus,
    keyboardType: type,
    textCapitalization: capitalization,
    onChanged: (_) => _changed(() {}),
    decoration: InputDecoration(
      labelText: label,
      hintText: hint,
      prefixText: prefix,
    ),
  );

  /// A day, shown with a picker behind it; [value] null shows the prompt.
  Widget _dateField(String label, DateTime? value, VoidCallback onTap) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: InputDecorator(
        decoration: InputDecoration(labelText: label),
        child: Row(
          children: [
            Text(
              value == null
                  ? context.l10n.pivaDlPickDate
                  : DateFormat.yMMMd().format(value),
              style: TextStyle(
                color: value == null ? scheme.onSurfaceVariant : scheme.onSurface,
                fontSize: 15,
              ),
            ),
            const Spacer(),
            Icon(
              Icons.calendar_today,
              size: 16,
              color: scheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final symbol = ref.watch(currencyProvider).currencySymbol;
    final d = _deadline;

    return DiscardGuard(
      isDirty: () => _snapshot != _openedWith,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 20,
          right: 20,
          top: 8,
        ),
        // The message and the buttons sit outside the scroll area: an error
        // appearing above Save must not push it off the screen, and with the
        // keyboard open it must stay in reach.
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        margin: const EdgeInsets.only(top: 4, bottom: 16),
                        height: 4,
                        width: 40,
                        decoration: BoxDecoration(
                          color: scheme.outlineVariant.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    _Label(d == null ? l10n.pivaDlNew : l10n.pivaDlEdit),
                    if (d == null || d.key.isEmpty) ...[
                      // A floating label rides ~6 above its field: 22 leaves it 16
                      // clear of the heading.
                      const SizedBox(height: 22),
                      DropdownButtonFormField<String>(
                        initialValue: _kind,
                        isExpanded: true,
                        decoration: InputDecoration(labelText: l10n.pivaDlKind),
                        items: const [
                          DropdownMenuItem(
                            value: 'imposta',
                            child: Text(pivaTaxKind),
                          ),
                          DropdownMenuItem(
                            value: 'contributi',
                            child: Text(pivaContributions),
                          ),
                        ],
                        onChanged: (v) => _changed(() => _kind = v ?? _kind),
                      ),
                      const SizedBox(height: 16),
                      _field(
                        _label,
                        l10n.pivaDlLabel,
                        hint: l10n.pivaDlLabelHint,
                        autofocus: d == null,
                        capitalization: TextCapitalization.sentences,
                      ),
                      const SizedBox(height: 16),
                    ] else ...[
                      const SizedBox(height: 12),
                      Text(
                        pivaNoBreak(d.label),
                        style: TextStyle(
                          color: scheme.onSurface,
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _typeName(d),
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                      // Plain text above, not a field: the amount's floating label
                      // would sit on it.
                      const SizedBox(height: 18),
                    ],
                    _field(
                      _amount,
                      l10n.pivaDlAmount,
                      prefix: '$symbol ',
                      type: _decimal,
                    ),
                    const SizedBox(height: 16),
                    _dateField(
                      l10n.pivaDlDueOn,
                      _due,
                      () => _pick(_due, (day) => _due = day),
                    ),
                    const SizedBox(height: 16),
                    _field(
                      _note,
                      l10n.pivaDlNote,
                      capitalization: TextCapitalization.sentences,
                    ),
                    const SizedBox(height: 4),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(l10n.pivaDlPaid),
                      value: _paid,
                      onChanged: (v) => _changed(() => _paid = v),
                    ),
                    if (_paid) ...[
                      // The switch row has no padding of its own below its text.
                      const SizedBox(height: 18),
                      _dateField(
                        l10n.pivaDlPaidOnLabel,
                        _paidDate,
                        () => _pick(_paidDate, (day) => _paidDate = day),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            InlineSheetMessage(_error),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _saving
                  ? null
                  : () {
                      HapticFeedback.mediumImpact();
                      _save();
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: scheme.primary,
                foregroundColor: scheme.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                disabledBackgroundColor: scheme.primary.withValues(alpha: 0.3),
              ),
              child: _saving
                  ? SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: scheme.onPrimary,
                      ),
                    )
                  : Text(
                      l10n.commonSave,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
            // Only a saved row can be taken back or deleted: an estimate and a new
            // deadline have nothing behind them.
            if (d?.paymentId != null) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: _saving ? null : _delete,
                style: TextButton.styleFrom(
                  foregroundColor: scheme.error,
                  minimumSize: const Size.fromHeight(48),
                ),
                child: Text(
                  widget.canRevert
                      ? l10n.pivaDlBackToEstimate
                      : l10n.commonDelete,
                ),
              ),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

/// The sheet's title, as `add_installment_modal.dart` draws it; the ARB value is
/// already in capitals.
class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.jetBrainsMono(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.2,
      ),
    );
  }
}
