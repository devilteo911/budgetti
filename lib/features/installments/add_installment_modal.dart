import 'package:budgetti/core/providers/providers.dart';
import 'package:budgetti/models/installment.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

/// Create or edit an installment plan. Four inputs (what, how much in total,
/// how many rates, when the first one is charged) — everything else about the
/// plan is derived from them.
class AddInstallmentModal extends ConsumerStatefulWidget {
  const AddInstallmentModal({super.key, this.existing});

  final Installment? existing;

  @override
  ConsumerState<AddInstallmentModal> createState() =>
      _AddInstallmentModalState();
}

class _AddInstallmentModalState extends ConsumerState<AddInstallmentModal> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _description;
  late final TextEditingController _total;
  late final TextEditingController _count;
  late DateTime _startDate;
  String? _category;
  String? _accountId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _description = TextEditingController(text: e?.description ?? '');
    _total = TextEditingController(
      text: e == null ? '' : e.totalAmount.toStringAsFixed(2),
    );
    _count = TextEditingController(text: e?.installmentCount.toString() ?? '');
    _startDate = e?.startDate ?? DateTime.now();
    _category = e?.category;
    _accountId = e?.accountId;
  }

  @override
  void dispose() {
    _description.dispose();
    _total.dispose();
    _count.dispose();
    super.dispose();
  }

  double? get _perRate {
    final total = double.tryParse(_total.text.replaceAll(',', '.'));
    final count = int.tryParse(_count.text);
    if (total == null || count == null || count <= 0) return null;
    return total / count;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _startDate = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref.read(financeServiceProvider).upsertInstallment(Installment(
            id: widget.existing?.id ?? '',
            userId: '',
            description: _description.text.trim(),
            totalAmount: double.parse(_total.text.replaceAll(',', '.')),
            installmentCount: int.parse(_count.text),
            startDate: _startDate,
            category: _category,
            accountId: _accountId,
          ));
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error saving plan: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final currency = ref.watch(currencyProvider);
    final categories = (ref.watch(categoriesProvider).value ?? const [])
        .where((c) => c.type == 'expense')
        .toList();
    final accounts = ref.watch(accountsProvider).value ?? const [];
    final perRate = _perRate;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20,
        right: 20,
        top: 8,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
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
              _Label(widget.existing == null ? 'NEW PLAN' : 'EDIT PLAN'),
              const SizedBox(height: 14),
              TextFormField(
                controller: _description,
                autofocus: widget.existing == null,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'What is it for',
                  hintText: 'Sofa, laptop, holiday…',
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _total,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        labelText: 'Total',
                        prefixText: '${currency.currencySymbol} ',
                      ),
                      validator: (v) {
                        final parsed =
                            double.tryParse((v ?? '').replaceAll(',', '.'));
                        if (parsed == null) return 'Invalid';
                        if (parsed <= 0) return 'Must be positive';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _count,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(labelText: 'Rates'),
                      validator: (v) {
                        final parsed = int.tryParse(v ?? '');
                        if (parsed == null) return 'Invalid';
                        if (parsed < 1) return 'At least 1';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                perRate == null
                    ? 'Monthly rate appears here'
                    : '${currency.format(perRate)} / month',
                style: GoogleFonts.jetBrainsMono(
                  color: perRate == null
                      ? scheme.onSurfaceVariant
                      : scheme.primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: _pickDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'First rate on',
                  ),
                  child: Row(
                    children: [
                      Text(
                        DateFormat.yMMMd().format(_startDate),
                        style: TextStyle(color: scheme.onSurface, fontSize: 15),
                      ),
                      const Spacer(),
                      Icon(Icons.calendar_today,
                          size: 16, color: scheme.onSurfaceVariant),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String?>(
                initialValue: categories.any((c) => c.name == _category)
                    ? _category
                    : null,
                isExpanded: true,
                decoration:
                    const InputDecoration(labelText: 'Category (optional)'),
                items: [
                  const DropdownMenuItem<String?>(
                      value: null, child: Text('None')),
                  ...categories.map((c) => DropdownMenuItem<String?>(
                        value: c.name,
                        child: Text(c.name),
                      )),
                ],
                onChanged: (v) => setState(() => _category = v),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String?>(
                initialValue:
                    accounts.any((a) => a.id == _accountId) ? _accountId : null,
                isExpanded: true,
                decoration:
                    const InputDecoration(labelText: 'Wallet (optional)'),
                items: [
                  const DropdownMenuItem<String?>(
                      value: null, child: Text('None')),
                  ...accounts.map((a) => DropdownMenuItem<String?>(
                        value: a.id,
                        child: Text(a.name),
                      )),
                ],
                onChanged: (v) => setState(() => _accountId = v),
              ),
              if (widget.existing != null) ...[
                const SizedBox(height: 24),
                _LinkedPayments(plan: widget.existing!),
              ],
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
                  disabledBackgroundColor:
                      scheme.primary.withValues(alpha: 0.3),
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
                        widget.existing == null ? 'Add plan' : 'Update plan',
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700),
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

/// The real charges attached to this plan, and a way to attach one more.
///
/// The plan's own schedule ("6 rates due by now") says what *should* have been
/// charged; these links say what actually was, so a missing rate is visible
/// instead of implied.
///
/// ponytail: the attach list is every unlinked expense, newest first — no
/// amount/date matching. Add a "likely rates first" filter if the list gets
/// annoying to scroll.
class _LinkedPayments extends ConsumerWidget {
  const _LinkedPayments({required this.plan});

  final Installment plan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final currency = ref.watch(currencyProvider);
    final txns = ref.watch(transactionsProvider(null)).value ?? const [];
    final linked = txns.where((t) => t.installmentId == plan.id).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    final due = plan.paidCount();
    final service = ref.read(financeServiceProvider);

    final candidates = txns
        .where((t) => t.type == 'expense' && t.installmentId == null)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Label('LINKED PAYMENTS · ${linked.length}/$due'),
        const SizedBox(height: 4),
        Text(
          linked.length >= due
              ? 'Every rate due so far is accounted for.'
              : '${due - linked.length} of the $due rates due so far '
                  'have no transaction attached.',
          style: TextStyle(
            color: linked.length >= due ? scheme.primary : scheme.onSurfaceVariant,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 8),
        for (final t in linked)
          ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Text(
              t.description.isEmpty ? t.category : t.description,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              '${DateFormat.yMMMd().format(t.date)} · '
              '${currency.format(t.amount.abs())}',
            ),
            trailing: IconButton(
              icon: const Icon(Icons.link_off, size: 18),
              tooltip: 'Unlink',
              onPressed: () =>
                  service.linkTransactionToInstallment(t.id, null),
            ),
          ),
        if (candidates.isEmpty)
          Text(
            'No unlinked expenses to attach.',
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
          )
        else
          DropdownButtonFormField<String>(
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Attach a payment'),
            items: candidates
                .take(60)
                .map((t) => DropdownMenuItem(
                      value: t.id,
                      child: Text(
                        '${DateFormat.yMMMd().format(t.date)} · '
                        '${currency.format(t.amount.abs())} · '
                        '${t.description.isEmpty ? t.category : t.description}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ))
                .toList(),
            onChanged: (id) {
              if (id != null) service.linkTransactionToInstallment(id, plan.id);
            },
          ),
      ],
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.jetBrainsMono(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        fontSize: 10,
        fontWeight: FontWeight.w600,
        letterSpacing: 2.2,
      ),
    );
  }
}
