import 'dart:convert';

import 'package:budgetti/core/error_text.dart';
import 'package:budgetti/core/l10n.dart';
// Also brings `parseAmount`: providers.dart re-exports finance_math.dart.
import 'package:budgetti/core/providers/providers.dart';
import 'package:budgetti/core/widgets/discard_guard.dart';
import 'package:budgetti/core/widgets/inline_sheet_message.dart';
import 'package:budgetti/features/piva/piva_format.dart';
import 'package:budgetti/models/piva.dart'
    show PivaProfileData, ProfileFormError, ProfileFormValues, coefficientFor, parseProfileForm;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

// Fiscal terms the shared `piva_format.dart` does not carry. Dart constants and
// not ARB keys: identical in both languages (decision of the parent issue).
const _coefficientLabel = 'Coefficiente di redditività (%)';
const _subjectiveLabel = 'Contributo soggettivo (%)';
const _integrativeLabel = 'Contributo integrativo (%)';
const _minSubjectiveLabel = 'Minimo soggettivo (€)';
const _minIntegrativeLabel = 'Minimo integrativo (€)';
const _inpsReductionLabel = 'Riduzione contributiva 35%';

const _decimal = TextInputType.numberWithOptions(decimal: true);

/// Create or edit the Partita IVA profile. [existing] null creates, a profile
/// edits. The rules live in `parseProfileForm` (`models/piva.dart`): the sheet
/// holds text, asks it, and shows the first error in field order, like the web
/// form (`PivaProfileForm.tsx`) it mirrors.
class PivaProfileSheet extends ConsumerStatefulWidget {
  const PivaProfileSheet({super.key, this.existing});

  final PivaProfileData? existing;

  @override
  ConsumerState<PivaProfileSheet> createState() => _PivaProfileSheetState();
}

class _PivaProfileSheetState extends ConsumerState<PivaProfileSheet> {
  // Seeded once from `existing` and never re-synced: a sync arriving while the
  // owner types must not wipe the form.
  late final TextEditingController _ateco,
      _coefficient,
      _startYear,
      _fundName,
      _subjective,
      _integrative,
      _minSubjective,
      _minIntegrative;
  late bool _startup, _reduction;
  late String _fund;
  late final Set<String> _categories;

  /// The last coefficient put in the field from the ATECO code: only a field
  /// still holding it (or empty) is overwritten, a hand-typed value never is.
  double? _prefilled;
  bool _saving = false;

  /// The first broken rule, or a failed save, shown above the button: a
  /// SnackBar would be drawn behind this sheet.
  String? _error;

  /// Everything the form holds, compared against the snapshot taken when the
  /// sheet opened. Categories are sorted: the order they were ticked in is not
  /// a change.
  String get _snapshot => jsonEncode([
        _ateco.text,
        _coefficient.text,
        _startYear.text,
        _fundName.text,
        _subjective.text,
        _integrative.text,
        _minSubjective.text,
        _minIntegrative.text,
        _startup,
        _reduction,
        _fund,
        _categories.toList()..sort(),
      ]);
  late final String _openedWith;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    // Numbers go back into the fields in their shortest form, never with fixed
    // decimals: `parseAmount` reads a three-digit tail as thousands.
    _ateco = TextEditingController(text: e?.atecoCode ?? '');
    _coefficient = TextEditingController(text: e == null ? '' : pivaNumber(e.coefficient));
    _startYear = TextEditingController(text: e == null ? '' : '${e.startYear}');
    _fundName = TextEditingController(text: e?.fundName ?? '');
    _subjective = TextEditingController(text: e == null ? '' : pivaNumber(e.subjectiveRate));
    _integrative = TextEditingController(text: e == null ? '' : pivaNumber(e.integrativeRate));
    _minSubjective = TextEditingController(text: e == null ? '' : pivaNumber(e.minSubjective));
    _minIntegrative = TextEditingController(text: e == null ? '' : pivaNumber(e.minIntegrative));
    _startup = e?.startupRate ?? false;
    _reduction = e?.inpsReduction ?? false;
    _fund = e?.fundType ?? 'gestione_separata';
    _categories = {...?e?.incomeCategories};
    _prefilled = e == null ? null : coefficientFor(e.atecoCode);
    _openedWith = _snapshot;
  }

  @override
  void dispose() {
    for (final c in [
      _ateco,
      _coefficient,
      _startYear,
      _fundName,
      _subjective,
      _integrative,
      _minSubjective,
      _minIntegrative,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Every edit goes through here: the form rebuilds (so `DiscardGuard` sees
  /// the new snapshot) and a message left over from the last save is gone.
  void _changed(VoidCallback edit) => setState(() {
        edit();
        _error = null;
      });

  void _onAteco(String code) => _changed(() {
        final hit = coefficientFor(code);
        final typed = _coefficient.text.trim();
        if (hit != null && (typed.isEmpty || (_prefilled != null && typed == pivaNumber(_prefilled!)))) {
          _coefficient.text = pivaNumber(hit);
          _prefilled = hit;
        }
      });

  String _message(ProfileFormError error) {
    final l10n = context.l10n;
    return switch (error) {
      ProfileFormError.atecoCode => l10n.pivaProfileErrAteco,
      ProfileFormError.coefficient => l10n.pivaProfileErrCoefficient,
      ProfileFormError.startYear => l10n.pivaProfileErrStartYear,
      ProfileFormError.fundType => l10n.pivaProfileErrFund,
      ProfileFormError.subjectiveRate => l10n.pivaProfileErrSubjective,
      ProfileFormError.integrativeRate => l10n.pivaProfileErrIntegrative,
      ProfileFormError.minimums => l10n.pivaProfileErrMinimums,
      ProfileFormError.incomeCategories => l10n.pivaProfileErrCategories,
    };
  }

  Future<void> _save() async {
    final parsed = parseProfileForm(
      ProfileFormValues(
        atecoCode: _ateco.text,
        coefficient: _coefficient.text,
        startYear: _startYear.text,
        startupRate: _startup,
        fundType: _fund,
        fundName: _fundName.text,
        subjectiveRate: _subjective.text,
        integrativeRate: _integrative.text,
        minSubjective: _minSubjective.text,
        minIntegrative: _minIntegrative.text,
        inpsReduction: _reduction,
        incomeCategories: _categories.toList(),
      ),
      DateTime.now(),
    );
    final error = parsed.error;
    if (error != null) {
      setState(() => _error = _message(error));
      return;
    }
    setState(() {
      _error = null;
      _saving = true;
    });
    try {
      await ref.read(financeServiceProvider).savePivaProfile(parsed.profile!);
      // `_saving` stays set: the button must not take a second tap while the
      // sheet slides away.
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = context.l10n.pivaProfileSaveError(errorText(context, e));
          _saving = false;
        });
      }
    }
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    String? hint,
    TextInputType? type,
    bool autofocus = false,
    TextCapitalization capitalization = TextCapitalization.none,
    List<TextInputFormatter>? formatters,
    ValueChanged<String>? onChanged,
  }) =>
      TextField(
        controller: controller,
        autofocus: autofocus,
        keyboardType: type,
        textCapitalization: capitalization,
        inputFormatters: formatters,
        onChanged: onChanged ?? (_) => _changed(() {}),
        decoration: InputDecoration(labelText: label, hintText: hint),
      );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final note = TextStyle(color: scheme.onSurfaceVariant, fontSize: 12, height: 1.4);

    // The live income categories plus the ones the profile already holds that no
    // longer exist (renamed, deleted), listed so a save does not drop them.
    // ponytail: lower-case compare, so an accented name sorts after "z"; swap in
    // a collator if a category ever starts with one.
    final names = <String>{
      for (final c in ref.watch(categoriesProvider).value ?? const [])
        if (c.type == 'income') c.name,
      ...?widget.existing?.incomeCategories,
    }.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    final group = coefficientFor(_ateco.text);

    return DiscardGuard(
      isDirty: () => _snapshot != _openedWith,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 20,
          right: 20,
          top: 8,
        ),
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
              _Label(widget.existing == null ? l10n.pivaProfileNew : l10n.pivaProfileEdit),
              const SizedBox(height: 14),
              _Pair(
                labels: (l10n.pivaProfileAtecoLabel, _coefficientLabel),
                first: _field(
                  _ateco,
                  l10n.pivaProfileAtecoLabel,
                  hint: '62.01.00',
                  autofocus: widget.existing == null,
                  type: _decimal,
                  // A decimal keyboard on an Italian phone may offer only the comma.
                  formatters: [FilteringTextInputFormatter.deny(',', replacementString: '.')],
                  onChanged: _onAteco,
                ),
                second: _field(_coefficient, _coefficientLabel, type: _decimal),
              ),
              const SizedBox(height: 12),
              // One child of the sheet's column however many lines it shows, so the
              // fields below keep their place (and their state) as the hint comes
              // and goes while the code is typed.
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(l10n.pivaProfileAtecoNote, style: note),
                  if (group == null) ...[
                    if (_ateco.text.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(l10n.pivaProfileNoGroup, style: note),
                    ],
                  ] else if (parseAmount(_coefficient.text) != group)
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(l10n.pivaProfileMinisterialGroup(pivaNumber(group)), style: note),
                        TextButton(
                          onPressed: () => _changed(() {
                            _coefficient.text = pivaNumber(group);
                            _prefilled = group;
                          }),
                          child: Text(l10n.pivaProfileUseIt),
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 16),
              _field(
                _startYear,
                l10n.pivaProfileStartYearLabel,
                hint: '${DateTime.now().year}',
                type: TextInputType.number,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.pivaProfileStartupRate),
                value: _startup,
                onChanged: (v) => _changed(() => _startup = v),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                // A `fundType` the table does not know (the server keeps text) shows
                // no choice, and saving it asks for one.
                initialValue: pivaFundLabels.containsKey(_fund) ? _fund : null,
                isExpanded: true,
                decoration: InputDecoration(labelText: l10n.pivaProfileFundLabel),
                items: [
                  for (final f in pivaFundLabels.entries)
                    DropdownMenuItem(
                      value: f.key,
                      child: Text(f.value, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (v) => _changed(() => _fund = v ?? _fund),
              ),
              // Off the tree, not out of the state: the controllers keep their text,
              // so going back to `cassa` finds it.
              if (_fund == 'cassa') ...[
                const SizedBox(height: 16),
                _field(
                  _fundName,
                  l10n.pivaProfileFundNameLabel,
                  hint: l10n.pivaProfileOptional,
                  capitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 16),
                _Pair(
                  labels: (_subjectiveLabel, _integrativeLabel),
                  first: _field(_subjective, _subjectiveLabel, type: _decimal),
                  second: _field(_integrative, _integrativeLabel, type: _decimal),
                ),
                const SizedBox(height: 16),
                _Pair(
                  labels: (_minSubjectiveLabel, _minIntegrativeLabel),
                  first: _field(_minSubjective, _minSubjectiveLabel, type: _decimal),
                  second: _field(_minIntegrative, _minIntegrativeLabel, type: _decimal),
                ),
                const SizedBox(height: 12),
                Text(l10n.pivaProfileIntegrativoNote, style: note),
              ],
              if (_fund == 'artigiani' || _fund == 'commercianti')
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(_inpsReductionLabel),
                  value: _reduction,
                  onChanged: (v) => _changed(() => _reduction = v),
                ),
              const SizedBox(height: 24),
              _Label(l10n.pivaProfileIncomeCategoriesLabel),
              const SizedBox(height: 4),
              if (names.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(l10n.pivaProfileNoIncomeCategories, style: note),
                ),
              for (final name in names)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(name),
                  value: _categories.contains(name),
                  onChanged: (v) => _changed(() => v == true ? _categories.add(name) : _categories.remove(name)),
                ),
              InlineSheetMessage(_error),
              const SizedBox(height: 24),
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
                        l10n.pivaProfileSave,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                      ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

/// Two fields on one row when both labels fit their half whole, one above the
/// other when they do not: a floating label cut at "Contributo integr…" is not
/// readable, and on a phone (or with a large system font) the half is narrow.
/// Measured like `_ProfileTitle` in `piva_screen.dart`, with the field's own label
/// style and the system's text scale.
class _Pair extends StatelessWidget {
  const _Pair({required this.labels, required this.first, required this.second});

  final (String, String) labels;
  final Widget first, second;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyLarge;
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    return LayoutBuilder(
      builder: (context, box) {
        var widest = 0.0;
        for (final label in [labels.$1, labels.$2]) {
          final painter = TextPainter(
            text: TextSpan(text: label, style: style),
            textDirection: direction,
            textScaler: scaler,
            maxLines: 1,
          )..layout();
          if (painter.width > widest) widest = painter.width;
          painter.dispose();
        }
        // 12 between the two; 16 of padding each side inside a field.
        if (widest + 32 <= (box.maxWidth - 12) / 2) {
          return Row(
            children: [
              Expanded(child: first),
              const SizedBox(width: 12),
              Expanded(child: second),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [first, const SizedBox(height: 16), second],
        );
      },
    );
  }
}

/// The sheet's title and its section caption, as `add_installment_modal.dart`
/// draws them, in capitals like the other sheets' captions.
class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: GoogleFonts.jetBrainsMono(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.2,
      ),
    );
  }
}
