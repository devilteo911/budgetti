import 'package:budgetti/core/l10n.dart';
import 'package:budgetti/core/error_text.dart';
import 'package:budgetti/core/providers/providers.dart';
import 'package:budgetti/core/services/notification_logic.dart';
import 'package:budgetti/core/widgets/category_picker_sheet.dart';
import 'package:budgetti/core/widgets/wallet_picker_sheet.dart';
import 'package:budgetti/features/transactions/widgets/amount_hero_field.dart';
import 'package:budgetti/features/transactions/widgets/ledger_field_row.dart';
import 'package:budgetti/features/transactions/widgets/type_selector.dart';
import 'package:budgetti/models/installment.dart';
import 'package:budgetti/models/transaction.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

class AddTransactionModal extends ConsumerStatefulWidget {
  final Transaction? transaction;
  final bool triggerScan;

  const AddTransactionModal({
    super.key,
    this.transaction,
    this.triggerScan = false,
  });

  @override
  ConsumerState<AddTransactionModal> createState() =>
      _AddTransactionModalState();
}

class _AddTransactionModalState extends ConsumerState<AddTransactionModal>
    with SingleTickerProviderStateMixin {
  static const _itemCount = 9;

  late final AnimationController _animation;
  late final List<Animation<double>> _itemAnimations;
  final _picker = ImagePicker();
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();

  bool _isScanning = false;
  bool _saving = false;
  String _type = 'expense';
  String? _selectedCategory;
  DateTime _selectedDate = DateTime.now();
  List<String> _selectedTags = [];
  String? _selectedAccountId;
  String? _selectedToAccountId;
  String? _selectedInstallmentId;

  @override
  void initState() {
    super.initState();
    _animation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _itemAnimations = List.generate(_itemCount, (i) {
      final start = (i * 0.08).clamp(0.0, 1.0);
      final end = (start + 0.5).clamp(0.0, 1.0);
      return CurvedAnimation(
        parent: _animation,
        curve: Interval(start, end, curve: Curves.easeOutCubic),
      );
    });

    if (widget.transaction != null) {
      final t = widget.transaction!;
      _amountController.text = t.amount.abs().toString();
      _descriptionController.text = t.description;
      _selectedCategory = t.category;
      _selectedDate = t.date;
      _type = t.type;
      _selectedTags = List.from(t.tags);
      _selectedAccountId = t.accountId;
      _selectedToAccountId = t.toAccountId;
      _selectedInstallmentId = t.installmentId;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _animation.forward();

      final accounts = ref.read(accountsProvider).value ?? [];
      if (_selectedAccountId == null && accounts.isNotEmpty) {
        final def = accounts.firstWhere(
          (a) => a.isDefault,
          orElse: () => accounts.first,
        );
        _selectedAccountId = def.id;
        setState(() {});
      }

      if (_type != 'transfer' && _selectedCategory == null) {
        final categories = ref.read(categoriesProvider).value ?? [];
        final filtered = categories.where((c) => c.type == _type).toList();
        if (filtered.isNotEmpty) {
          _selectedCategory = filtered.first.name;
          setState(() {});
        }
      }

      if (widget.triggerScan) _scanReceipt();
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    _animation.dispose();
    super.dispose();
  }

  Future<void> _scanReceipt() async {
    final image = await _picker.pickImage(source: ImageSource.camera);
    if (image == null) return;

    setState(() => _isScanning = true);
    try {
      final ocr = ref.read(ocrServiceProvider);
      final result = await ocr.recognizeReceipt(image.path);
      if (result.amount != null) {
        _amountController.text = result.amount!.toStringAsFixed(2);
      }
      if (result.merchant != null) {
        _descriptionController.text = result.merchant!;
      }
      if (result.date != null) _selectedDate = result.date!;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.txReceiptScanned)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(context.l10n.txOcrError(errorText(context, e)))),
        );
      }
    } finally {
      if (mounted) setState(() => _isScanning = false);
    }
  }

  Future<void> _submit() async {
    if (_saving) return;
    if (!_formKey.currentState!.validate()) return;
    if (_selectedAccountId == null) {
      _toast(context.l10n.txPleaseSelectWallet);
      return;
    }
    if (_type == 'transfer' &&
        (_selectedToAccountId == null ||
            _selectedToAccountId == _selectedAccountId)) {
      _toast(context.l10n.txPleaseSelectOtherWallet);
      return;
    }

    final amount = double.parse(_amountController.text.replaceAll(',', '.'));
    final transaction = Transaction(
      id: widget.transaction?.id ?? const Uuid().v4(),
      accountId: _selectedAccountId!,
      toAccountId: _type == 'transfer' ? _selectedToAccountId : null,
      amount: _type == 'expense' ? -amount.abs() : amount.abs(),
      date: _selectedDate,
      description: _descriptionController.text,
      category: _type == 'transfer'
          ? 'Transfer'
          : (_selectedCategory ?? 'Uncategorized'),
      type: _type,
      tags: _selectedTags,
      // Only an expense can be a rate; switching type away from expense drops
      // a link the user made before switching.
      installmentId: _type == 'expense' ? _selectedInstallmentId : null,
    );

    final service = ref.read(financeServiceProvider);
    // Claim synchronously: without the flag a double-tap fires two awaits,
    // each inserting its own row.
    setState(() => _saving = true);
    try {
      if (widget.transaction != null) {
        await service.updateTransaction(transaction);
      } else {
        await service.addTransaction(transaction);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }

    ref.read(notificationLogicProvider).checkBudgetAlerts(transaction);
    ref.invalidate(accountsProvider);
    ref.invalidate(transactionsProvider(null));
    ref.invalidate(transactionsProvider(_selectedAccountId));
    if (_type == 'transfer' && _selectedToAccountId != null) {
      ref.invalidate(transactionsProvider(_selectedToAccountId));
    }
    ref.invalidate(paginatedTransactionsProvider);
    if (_type != 'transfer') ref.invalidate(budgetsProvider);
    performSheetsSync(ref);

    if (!mounted) return;
    context.pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          widget.transaction != null
              ? context.l10n.txTransactionUpdated
              : context.l10n.txTransactionAdded,
        ),
      ),
    );
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate.isAfter(DateTime.now())
          ? DateTime.now()
          : _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && mounted) {
      setState(() => _selectedDate = picked);
    }
  }

  void _showWalletPicker(bool isFrom) {
    final scheme = Theme.of(context).colorScheme;
    showModalBottomSheet(
      useRootNavigator: true,
      context: context,
      backgroundColor: scheme.surfaceContainer,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => WalletPickerSheet(
        title: isFrom
            ? context.l10n.txSelectFromWallet
            : context.l10n.txSelectToWallet,
        selectedWalletId: isFrom ? _selectedAccountId : _selectedToAccountId,
        onWalletSelected: (account) {
          if (account == null) return;
          setState(() {
            if (isFrom) {
              _selectedAccountId = account.id;
            } else {
              _selectedToAccountId = account.id;
            }
          });
        },
      ),
    );
  }

  void _showCategoryPicker() {
    final scheme = Theme.of(context).colorScheme;
    showModalBottomSheet(
      useRootNavigator: true,
      context: context,
      backgroundColor: scheme.surfaceContainer,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => CategoryPickerSheet(
        title: context.l10n.txSelectCategory,
        selectedCategoryName: _selectedCategory,
        type: _type == 'expense' ? 'expense' : 'income',
        onCategorySelected: (category) {
          setState(() => _selectedCategory = category.name);
        },
      ),
    );
  }

  Widget _staggered(int index, Widget child) {
    return AnimatedBuilder(
      animation: _itemAnimations[index],
      child: child,
      builder: (context, child) {
        final v = _itemAnimations[index].value;
        return Opacity(
          opacity: v,
          child: Transform.translate(
            offset: Offset(0, 14 * (1 - v)),
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final currency = ref.watch(currencyProvider);
    final isEdit = widget.transaction != null;

    return RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 4),
                _staggered(
                  0,
                  _TopBar(title: _topBarTitle(isEdit)),
                ),
                const SizedBox(height: 24),
                _staggered(
                  1,
                  AmountHeroField(
                    controller: _amountController,
                    currencySymbol: currency.currencySymbol,
                    type: _type,
                  ),
                ),
                const SizedBox(height: 28),
                _staggered(
                  2,
                  TypeSelector(
                    selected: _type,
                    onChanged: (v) {
                      setState(() {
                        _type = v;
                        final categories =
                            ref.read(categoriesProvider).value ?? [];
                        final filtered = categories
                            .where((c) => c.type == _type)
                            .toList();
                        _selectedCategory =
                            filtered.isNotEmpty ? filtered.first.name : null;
                      });
                    },
                  ),
                ),
                const SizedBox(height: 24),
                _staggered(3, _DescriptionField(controller: _descriptionController)),
                const LedgerDivider(),
                _staggered(4, _buildWalletSection()),
                const LedgerDivider(),
                if (_type != 'transfer') ...[
                  _staggered(5, _buildCategoryRow()),
                  const LedgerDivider(),
                ],
                _staggered(6, _buildDateRow()),
                const LedgerDivider(),
                if (_type == 'expense' && _hasPlans) ...[
                  _staggered(7, _buildInstallmentRow()),
                  const LedgerDivider(),
                ],
                _staggered(8, _buildTagsSection()),
                const SizedBox(height: 28),
                Row(
                  children: [
                    Expanded(
                      child: _SaveButton(
                        label: isEdit
                            ? context.l10n.txUpdate.toUpperCase()
                            : context.l10n.commonSave.toUpperCase(),
                        color: scheme.primary,
                        onColor: scheme.onPrimary,
                        onTap: _saving ? null : _submit,
                      ),
                    ),
                    const SizedBox(width: 10),
                    _ScanButton(
                      scanning: _isScanning,
                      onTap: _isScanning ? null : _scanReceipt,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const _KeyboardSpacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _topBarTitle(bool isEdit) {
    return switch (_type) {
      'expense' =>
        isEdit ? context.l10n.txEditExpense : context.l10n.txNewExpense,
      'income' => isEdit ? context.l10n.txEditIncome : context.l10n.txNewIncome,
      _ => isEdit ? context.l10n.txEditTransfer : context.l10n.txNewTransfer,
    }.toUpperCase();
  }

  Widget _buildWalletSection() {
    final accountsAsync = ref.watch(accountsProvider);
    return accountsAsync.when(
      loading: () => LedgerFieldRow(
        kicker: _type == 'transfer'
            ? context.l10n.txFrom.toUpperCase()
            : context.l10n.commonWallet.toUpperCase(),
        valueOverride: _LoadingLine(),
      ),
      error: (_, __) => LedgerFieldRow(
        kicker: _type == 'transfer'
            ? context.l10n.txFrom.toUpperCase()
            : context.l10n.commonWallet.toUpperCase(),
        value: context.l10n.commonError,
        isError: true,
      ),
      data: (accounts) {
        final from = accounts
            .where((a) => a.id == _selectedAccountId)
            .firstOrNull;
        final to = accounts
            .where((a) => a.id == _selectedToAccountId)
            .firstOrNull;
        final isTransfer = _type == 'transfer';

        if (!isTransfer) {
          return LedgerFieldRow(
            kicker: context.l10n.commonWallet.toUpperCase(),
            value: from?.name,
            placeholder: context.l10n.txSelectWallet,
            onTap: () => _showWalletPicker(true),
          );
        }

        return _TransferPair(
          from: LedgerFieldRow(
            kicker: context.l10n.txFrom.toUpperCase(),
            value: from?.name,
            placeholder: context.l10n.txSelectSource,
            isError: _selectedAccountId == null,
            onTap: () => _showWalletPicker(true),
          ),
          to: LedgerFieldRow(
            kicker: context.l10n.txTo.toUpperCase(),
            value: to?.name,
            placeholder: context.l10n.txSelectDestination,
            isError: _selectedToAccountId == null,
            onTap: () => _showWalletPicker(false),
          ),
        );
      },
    );
  }

  Widget _buildCategoryRow() {
    final categoriesAsync = ref.watch(categoriesProvider);
    final colors = ref.watch(categoryColorCacheProvider(Theme.of(context).colorScheme.brightness));
    final icons = ref.watch(categoryIconCacheProvider);
    return categoriesAsync.when(
      loading: () => LedgerFieldRow(
        kicker: context.l10n.commonCategory.toUpperCase(),
        valueOverride: _LoadingLine(),
      ),
      error: (_, __) => LedgerFieldRow(
        kicker: context.l10n.commonCategory.toUpperCase(),
        value: context.l10n.commonError,
        isError: true,
      ),
      data: (categories) {
        final filtered = categories.where((c) => c.type == _type).toList();
        final selected = filtered
                .where((c) => c.name == _selectedCategory)
                .firstOrNull ??
            filtered.firstOrNull;
        final icon = selected != null
            ? (icons[selected.name] ?? Icons.category_outlined)
            : Icons.category_outlined;
        final color = selected != null
            ? (colors[selected.name] ?? Theme.of(context).colorScheme.onSurfaceVariant)
            : Theme.of(context).colorScheme.onSurfaceVariant;

        return LedgerFieldRow(
          kicker: context.l10n.commonCategory.toUpperCase(),
          value: selected?.name ?? _selectedCategory,
          placeholder: context.l10n.txSelectCategory,
          leadingIcon: icon,
          leadingColor: color,
          showStripe: true,
          onTap: _showCategoryPicker,
        );
      },
    );
  }

  Widget _buildDateRow() {
    final scheme = Theme.of(context).colorScheme;
    return LedgerFieldRow(
      kicker: context.l10n.commonDate.toUpperCase(),
      onTap: _pickDate,
      valueOverride: Align(
        alignment: Alignment.centerRight,
        child: Text(
          DateFormat('dd MMM yyyy').format(_selectedDate).toUpperCase(),
          style: GoogleFonts.jetBrainsMono(
            color: scheme.onSurface,
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
        ),
      ),
    );
  }

  /// Plans worth offering: everything still running, plus whichever plan this
  /// transaction is already linked to (so an old link stays visible and
  /// removable after the plan has settled).
  List<Installment> get _linkablePlans {
    final all = ref.watch(installmentsProvider).value ?? const [];
    return all
        .where((p) => p.isActive() || p.id == _selectedInstallmentId)
        .toList();
  }

  bool get _hasPlans => _linkablePlans.isNotEmpty;

  Widget _buildInstallmentRow() {
    final plans = _linkablePlans;
    final selected =
        plans.where((p) => p.id == _selectedInstallmentId).firstOrNull;
    return LedgerFieldRow(
      kicker: context.l10n.txInstallment.toUpperCase(),
      value: selected?.description,
      placeholder: context.l10n.txNotARate,
      leadingIcon: Icons.receipt_long_outlined,
      onTap: () => _showInstallmentPicker(plans),
    );
  }

  void _showInstallmentPicker(List<Installment> plans) {
    final scheme = Theme.of(context).colorScheme;
    final currency = ref.read(currencyProvider);
    showModalBottomSheet(
      useRootNavigator: true,
      context: context,
      backgroundColor: scheme.surfaceContainer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            ListTile(
              leading: const Icon(Icons.block_outlined),
              title: Text(context.l10n.txNotARate),
              selected: _selectedInstallmentId == null,
              onTap: () {
                setState(() => _selectedInstallmentId = null);
                Navigator.pop(sheetContext);
              },
            ),
            for (final p in plans)
              ListTile(
                leading: const Icon(Icons.receipt_long_outlined),
                title: Text(p.description),
                subtitle: Text(
                  context.l10n.txInstallmentOption(
                    currency.format(p.amountPerInstallment),
                    p.installmentCount,
                    p.paidCount(),
                  ),
                ),
                selected: _selectedInstallmentId == p.id,
                onTap: () {
                  setState(() {
                    _selectedInstallmentId = p.id;
                    // A rate's amount is known — prefill it when the field is
                    // still empty, rather than making the user retype it.
                    if (_amountController.text.trim().isEmpty) {
                      _amountController.text =
                          p.amountPerInstallment.toStringAsFixed(2);
                    }
                  });
                  Navigator.pop(sheetContext);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTagsSection() {
    final tagsAsync = ref.watch(tagsProvider);
    final tagColors = ref.watch(tagColorCacheProvider);
    return tagsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (tags) {
        if (tags.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.commonTags.toUpperCase(),
                style: GoogleFonts.jetBrainsMono(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: tags.map((tag) {
                  final color = tagColors[tag.name] ?? Colors.grey;
                  final selected = _selectedTags.contains(tag.name);
                  return _TagPill(
                    name: tag.name,
                    color: color,
                    selected: selected,
                    onTap: () => setState(() {
                      if (selected) {
                        _selectedTags.remove(tag.name);
                      } else {
                        _selectedTags.add(tag.name);
                      }
                    }),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TopBar extends StatelessWidget {
  final String title;

  const _TopBar({required this.title});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Text(
      title,
      style: GoogleFonts.jetBrainsMono(
        color: scheme.onSurface,
        fontSize: 14,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.2,
      ),
    );
  }
}

class _ScanButton extends StatelessWidget {
  final bool scanning;
  final VoidCallback? onTap;

  const _ScanButton({required this.scanning, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = onTap != null;
    final fg = enabled
        ? scheme.primary
        : scheme.onSurfaceVariant.withValues(alpha: 0.5);

    return Material(
      color: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: scheme.primary.withValues(alpha: enabled ? 0.45 : 0.2),
          width: 1.2,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: 108,
          height: 56,
          child: Center(
            child: scanning
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: scheme.primary,
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.document_scanner_outlined,
                        size: 15,
                        color: fg,
                      ),
                      const SizedBox(width: 7),
                      Text(
                        context.l10n.txScan.toUpperCase(),
                        style: GoogleFonts.jetBrainsMono(
                          color: fg,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _DescriptionField extends StatelessWidget {
  final TextEditingController controller;

  const _DescriptionField({required this.controller});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 92,
            child: Text(
              context.l10n.txNote.toUpperCase(),
              style: GoogleFonts.jetBrainsMono(
                color: scheme.onSurfaceVariant,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
          ),
          Expanded(
            child: TextFormField(
              controller: controller,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: scheme.onSurface,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                hintText: context.l10n.txNoteHint,
                hintStyle: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
                border: InputBorder.none,
                focusedBorder: InputBorder.none,
                enabledBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                isDense: true,
                filled: false,
                errorStyle: GoogleFonts.jetBrainsMono(
                  color: scheme.error,
                  fontSize: 11,
                  letterSpacing: 1.0,
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return context.l10n.txEnterDescription;
                }
                return null;
              },
            ),
          ),
          const SizedBox(width: 26),
        ],
      ),
    );
  }
}

class _TransferPair extends StatelessWidget {
  final Widget from;
  final Widget to;

  const _TransferPair({required this.from, required this.to});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        from,
        Padding(
          padding: const EdgeInsets.only(left: 4, top: 2, bottom: 2),
          child: Row(
            children: [
              Container(
                width: 1,
                height: 14,
                color: scheme.outlineVariant.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
        to,
      ],
    );
  }
}

class _TagPill extends StatelessWidget {
  final String name;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _TagPill({
    required this.name,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: selected ? color.withValues(alpha: 0.28) : Colors.transparent,
      shape: StadiumBorder(
        side: BorderSide(
          color: selected
              ? color
              : scheme.outlineVariant.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Text(
            name.toUpperCase(),
            style: GoogleFonts.jetBrainsMono(
              color: selected ? color : scheme.onSurfaceVariant,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
        ),
      ),
    );
  }
}

class _SaveButton extends StatelessWidget {
  final String label;
  final Color color;
  final Color onColor;

  /// Null while a save is in flight — the tap guard against double-booking.
  final VoidCallback? onTap;

  const _SaveButton({
    required this.label,
    required this.color,
    required this.onColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 56,
          alignment: Alignment.center,
          child: Text(
            label,
            style: GoogleFonts.jetBrainsMono(
              color: onColor,
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
        ),
      ),
    );
  }
}

class _LoadingLine extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerRight,
      child: SizedBox(
        width: 14,
        height: 14,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: scheme.primary,
        ),
      ),
    );
  }
}

class _KeyboardSpacer extends StatelessWidget {
  const _KeyboardSpacer();

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return SizedBox(height: bottomInset > 0 ? bottomInset : 32);
  }
}
