import 'dart:async';

import 'package:budgetti/core/l10n.dart';
import 'package:budgetti/core/services/bank_sync_service.dart' show learnedCategory;
import 'package:budgetti/core/error_text.dart';
import 'package:budgetti/core/providers/providers.dart';
import 'package:budgetti/core/services/notification_logic.dart';
import 'package:budgetti/core/theme/ledger_style.dart' show incomeInk;
import 'package:budgetti/core/widgets/category_picker_sheet.dart';
import 'package:budgetti/core/widgets/wallet_picker_sheet.dart';
import 'package:budgetti/features/transactions/widgets/amount_hero_field.dart';
import 'package:budgetti/features/transactions/widgets/receivable_badge.dart';
import 'package:budgetti/features/transactions/widgets/sheet_parts.dart';
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
import 'package:budgetti/core/widgets/app_sheet.dart';
import 'package:budgetti/core/widgets/discard_guard.dart';
import 'package:budgetti/core/widgets/inline_sheet_message.dart';

class AddTransactionModal extends ConsumerStatefulWidget {
  final Transaction? transaction;
  final bool triggerScan;

  /// A new transaction that starts from these values (the inbox's edit-and-
  /// approve). Not an edit: [transaction] stays the only thing that makes it one.
  /// An empty wallet or category, or a zero amount, is left for the user or the
  /// defaults to fill.
  final Transaction? prefill;

  /// Replaces the plain insert/update on save. Everything after it — budget
  /// alerts, invalidations, sheets sync, closing, the snackbar — still runs.
  final Future<void> Function(Transaction)? onSave;

  const AddTransactionModal({
    super.key,
    this.transaction,
    this.triggerScan = false,
    this.prefill,
    this.onSave,
  });

  @override
  ConsumerState<AddTransactionModal> createState() =>
      _AddTransactionModalState();
}

class _AddTransactionModalState extends ConsumerState<AddTransactionModal>
    with SingleTickerProviderStateMixin {
  static const _itemCount = 10;

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

  /// What the others owe on this expense, 0 = not shared; and the shared expense
  /// this income pays back, null = none. Kept across a type switch like
  /// [_selectedInstallmentId]; the type rule is applied at save.
  double _othersShare = 0;
  String? _reimbursesId;

  /// The owner chose the category (or arrived with one from the inbox): the
  /// description no longer suggests one. A type switch re-arms it.
  late bool _categoryTouched;
  Timer? _suggestTimer;

  /// What the sheet has to tell the owner (a refused save, a failed scan), drawn
  /// above the Save button. Not a SnackBar: while the sheet is open the root
  /// ScaffoldMessenger draws that BEHIND it, so the owner only saw the sheet
  /// refusing to close.
  String? _message;
  bool _messageIsError = true;

  /// Raise the keyboard only for a blank new sheet: not an edit, not a scan, and
  /// not a prefill that already carries its amount.
  late final bool _autofocusAmount;

  /// Only what the user typed. Wallet and category are auto-filled after the
  /// first frame, so including them would make an untouched sheet look dirty.
  /// The split and the link are the owner's too: abandoning one must ask.
  String get _typed => '${_amountController.text}|${_descriptionController.text}'
      '|$_selectedTags|$_othersShare|$_reimbursesId';
  late final String _openedWith;

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

    final isPrefill = widget.transaction == null && widget.prefill != null;
    final t = widget.transaction ?? widget.prefill;
    if (t != null) {
      _amountController.text = !isPrefill
          ? t.amount.abs().toString()
          : (t.amount == 0 ? '' : t.amount.abs().toStringAsFixed(2));
      _descriptionController.text = t.description;
      // A prefill leaves what it doesn't know empty, for the defaults below to
      // fill. An existing row keeps exactly what it has, empty or not.
      _selectedCategory = isPrefill && t.category.isEmpty ? null : t.category;
      _selectedDate = t.date;
      // An existing row is what its sign says, as everywhere else in the ledger
      // (list, RECENTI, totals) and in the web editor. The stored type can
      // disagree on legacy rows, and saving re-signs the amount from `_type`:
      // starting from the stored type flipped +11,95 "expense" to −11,95.
      _type = widget.transaction == null || t.type == 'transfer'
          ? t.type
          : (t.amount > 0 ? 'income' : 'expense');
      _selectedTags = List.from(t.tags);
      _selectedAccountId = isPrefill && t.accountId.isEmpty ? null : t.accountId;
      _selectedToAccountId = t.toAccountId;
      _selectedInstallmentId = t.installmentId;
      _othersShare = t.othersShare;
      _reimbursesId = t.reimbursesId;
    }
    _openedWith = _typed;
    _autofocusAmount = widget.transaction == null &&
        !widget.triggerScan &&
        _amountController.text.isEmpty;
    // An existing row keeps its category; an inbox prefill that arrives with
    // one (learned, or picked on the card) is the owner's already.
    _categoryTouched = widget.transaction != null || _selectedCategory != null;
    _descriptionController.addListener(_onDescriptionChanged);
    _amountController.addListener(_clearMessage);
    _descriptionController.addListener(_clearMessage);

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

      if (_type != 'transfer') {
        final categories = ref.read(categoriesProvider).value ?? [];
        // A prefill's category may be gone by now (suggested at capture): default
        // it like an unset one, so the owner never saves a name the row doesn't
        // show. Never for an existing row — saving it untouched must not rewrite
        // its category, whatever kind or state that category is in (legacy rows
        // hold income categories on expenses, deleted names, or none).
        final stale = isPrefill &&
            !categories
                .any((c) => c.type == _type && c.name == _selectedCategory);
        final start = defaultCategoryFor(_type, categories, _history());
        if (start != null && (_selectedCategory == null || stale)) {
          _selectedCategory = start;
          setState(() {});
        }
      }

      if (widget.triggerScan) _scanReceipt();
    });
  }

  /// The ledger newest first, for [defaultCategoryFor]; empty while it loads.
  List<Transaction> _history() =>
      ref.read(transactionsProvider(null)).value ?? const [];

  void _say(String text, {bool error = true}) => setState(() {
        _message = text;
        _messageIsError = error;
      });

  /// Any edit makes the message stale.
  void _clearMessage() {
    if (_message != null) setState(() => _message = null);
  }

  void _onDescriptionChanged() {
    if (_categoryTouched || _type == 'transfer') return;
    _suggestTimer?.cancel();
    _suggestTimer = Timer(const Duration(milliseconds: 400), _suggestCategory);
  }

  /// Files a typed merchant where the owner filed it last time. Re-checks after
  /// the await: the owner may have picked a category, switched kind or kept
  /// typing while the ledger was read.
  Future<void> _suggestCategory() async {
    final typed = _descriptionController.text.trim();
    if (typed.isEmpty) return;
    final learned = await learnedCategory(
      ref.read(databaseProvider),
      typed,
      income: _type == 'income',
    );
    if (!mounted ||
        learned == null ||
        _categoryTouched ||
        _type == 'transfer' ||
        _descriptionController.text.trim() != typed) {
      return;
    }
    final categories = ref.read(categoriesProvider).value ?? const [];
    if (!categories.any((c) => c.type == _type && c.name == learned)) return;
    setState(() => _selectedCategory = learned);
  }

  @override
  void dispose() {
    _suggestTimer?.cancel();
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
      if (mounted) _say(context.l10n.txReceiptScanned, error: false);
    } catch (e) {
      if (mounted) _say(context.l10n.txOcrError(errorText(context, e)));
    } finally {
      if (mounted) setState(() => _isScanning = false);
    }
  }

  Future<void> _submit() async {
    if (_saving) return;
    _clearMessage();
    if (!_formKey.currentState!.validate()) return;
    if (_selectedAccountId == null) {
      _say(context.l10n.txPleaseSelectWallet);
      return;
    }
    if (_type == 'transfer' &&
        (_selectedToAccountId == null ||
            _selectedToAccountId == _selectedAccountId)) {
      _say(context.l10n.txPleaseSelectOtherWallet);
      return;
    }

    final amount = double.parse(_amountController.text.replaceAll(',', '.'));
    // The service would clamp an oversize share down without a word; the owner
    // lowered the amount under it, so say so instead.
    if (_type == 'expense' && _othersShare > amount.abs()) {
      _say(context.l10n.txShareTooMuch);
      return;
    }
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
      // Only an expense can be shared and only an income can pay one back;
      // switching type drops what the user set before switching. The service
      // guards it again.
      othersShare: _type == 'expense' ? _othersShare : 0,
      reimbursesId: _type == 'income' ? _reimbursesId : null,
    );

    final service = ref.read(financeServiceProvider);
    // Claim synchronously: without the flag a double-tap fires two awaits,
    // each inserting its own row.
    setState(() => _saving = true);
    try {
      if (widget.onSave != null) {
        await widget.onSave!(transaction);
      } else if (widget.transaction != null) {
        await service.updateTransaction(transaction);
      } else {
        await service.addTransaction(transaction);
      }
    } catch (e, st) {
      // Stay open, with what the owner typed, so the save can be retried.
      if (mounted) _say(context.l10n.txError(errorText(context, e, st)));
      return;
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
    showAppSheet(
      context,
      isScrollControlled: true,
      builder: (context) => WalletPickerSheet(
        title: isFrom
            ? context.l10n.txSelectFromWallet
            : context.l10n.txSelectToWallet,
        selectedWalletId: isFrom ? _selectedAccountId : _selectedToAccountId,
        onWalletSelected: (account) {
          if (account == null) return;
          setState(() {
            _message = null;
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
    showAppSheet(
      context,
      isScrollControlled: true,
      builder: (context) => CategoryPickerSheet(
        title: context.l10n.txSelectCategory,
        selectedCategoryName: _selectedCategory,
        type: _type == 'expense' ? 'expense' : 'income',
        onCategorySelected: (category) {
          setState(() {
            _selectedCategory = category.name;
            _categoryTouched = true;
          });
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
    final sharedExpenses =
        _type == 'income' ? _sharedExpenses : const <Transaction>[];

    return DiscardGuard(
      isDirty: () => _typed != _openedWith,
      child: RepaintBoundary(
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
                    autofocus: _autofocusAmount,
                  ),
                ),
                const SizedBox(height: 28),
                _staggered(
                  2,
                  TypeSelector(
                    selected: _type,
                    onChanged: (v) {
                      setState(() {
                        _message = null;
                        _type = v;
                        _selectedCategory = defaultCategoryFor(
                          _type,
                          ref.read(categoriesProvider).value ?? [],
                          _history(),
                        );
                        _categoryTouched = false;
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
                // Not in the inbox's edit-and-approve: a split and a link are
                // set after approval, from the editor of the saved row (#36).
                // An expense and an income never show together: one slot.
                if (_type == 'expense' && widget.prefill == null) ...[
                  _staggered(8, _buildSharedRow(currency)),
                  const LedgerDivider(),
                ],
                if (_type == 'income' &&
                    widget.prefill == null &&
                    (sharedExpenses.isNotEmpty || _reimbursesId != null)) ...[
                  _staggered(8, _buildPaysBackRow(sharedExpenses)),
                  const LedgerDivider(),
                ],
                _staggered(9, _buildTagsSection()),
                InlineSheetMessage(_message, isError: _messageIsError),
                const SizedBox(height: 28),
                Row(
                  children: [
                    Expanded(
                      child: SaveButton(
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
                const KeyboardSpacer(),
              ],
            ),
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
        // What the row shows is what a save writes. An existing transaction whose
        // category is not among the options (deleted, 'Uncategorized', the other
        // kind's) shows its stored name, muted, instead of the first option; a
        // new sheet keeps starting on the default.
        final selected = filtered
                .where((c) => c.name == _selectedCategory)
                .firstOrNull ??
            (widget.transaction == null ? filtered.firstOrNull : null);
        final icon = selected != null
            ? (icons[selected.name] ?? Icons.category_outlined)
            : Icons.category_outlined;
        final color = selected != null
            ? (colors[selected.name] ?? Theme.of(context).colorScheme.onSurfaceVariant)
            : Theme.of(context).colorScheme.onSurfaceVariant;

        return LedgerFieldRow(
          kicker: context.l10n.commonCategory.toUpperCase(),
          value: selected?.name ??
              (_selectedCategory == '' ? null : _selectedCategory),
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
    final currency = ref.read(currencyProvider);
    showAppSheet(
      context,
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

  Widget _buildSharedRow(NumberFormat currency) {
    return LedgerFieldRow(
      kicker: context.l10n.txShared.toUpperCase(),
      value: _othersShare > 0
          ? context.l10n.txOthersOwe(currency.format(_othersShare))
          : null,
      placeholder: context.l10n.txNotShared,
      leadingIcon: Icons.group_outlined,
      onTap: _showSharedSheet,
    );
  }

  /// Shared expenses this income may pay back: the newest 60 with something
  /// owed, minus the row being edited, plus whichever one [_reimbursesId]
  /// already names (so an old link stays visible and removable past the cap).
  ///
  /// ponytail: no amount/date matching, as the plan sheet's attach list; add a
  /// "still owed first" order if scrolling it gets annoying. The expense a link
  /// names is looked up here, not in the whole ledger, so one whose share was
  /// lowered to 0 reads "not there" too — the rare state is not worth watching
  /// every row for.
  List<Transaction> get _sharedExpenses {
    final all = _newestFirst([
      for (final t
          in ref.watch(shareTransactionsProvider).value ?? const <Transaction>[])
        if (t.isExpense &&
            t.othersShare > 0 &&
            t.id != widget.transaction?.id)
          t,
    ]);
    return [
      ...all.take(60),
      ...all.skip(60).where((t) => t.id == _reimbursesId),
    ];
  }

  Widget _buildPaysBackRow(List<Transaction> expenses) {
    final linked = expenses.where((t) => t.id == _reimbursesId).firstOrNull;
    return LedgerFieldRow(
      kicker: context.l10n.txPaysBack.toUpperCase(),
      value: linked != null
          ? _title(linked)
          : (_reimbursesId != null ? context.l10n.txLinkedMissing : null),
      placeholder: context.l10n.txNotAReimbursement,
      leadingIcon: Icons.undo,
      onTap: () => _showPaysBackPicker(expenses),
    );
  }

  /// "Not a reimbursement" first (also the way to drop a link to an expense
  /// that is not there), then one tile per shared expense with what is left to
  /// receive on it. Picking writes nothing until the form is saved.
  void _showPaysBackPicker(List<Transaction> expenses) {
    final l10n = context.l10n;
    final currency = ref.read(currencyProvider);
    final receivables = ref.read(receivablesProvider).value;
    showAppSheet(
      context,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            ListTile(
              leading: const Icon(Icons.block_outlined),
              title: Text(l10n.txNotAReimbursement),
              selected: _reimbursesId == null,
              onTap: () {
                setState(() => _reimbursesId = null);
                Navigator.pop(sheetContext);
              },
            ),
            for (final e in expenses)
              ListTile(
                leading: const Icon(Icons.undo),
                title: Text(_title(e), overflow: TextOverflow.ellipsis),
                subtitle: Text(
                  [
                    DateFormat.MMMd().format(e.date),
                    if (receivables?[e.id] case final r?)
                      receivableBadge(l10n, currency, r),
                  ].join(' · '),
                  overflow: TextOverflow.ellipsis,
                ),
                selected: _reimbursesId == e.id,
                onTap: () {
                  setState(() {
                    _reimbursesId = e.id;
                    // What is still owed is known — prefill it when the field
                    // is still empty, as a rate's amount is.
                    final owed = receivables?[e.id]?.outstanding ?? 0;
                    if (owed > 0 && _amountController.text.trim().isEmpty) {
                      _amountController.text = owed.toStringAsFixed(2);
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

  Future<void> _showSharedSheet() async {
    final share = await showAppSheet<double>(
      context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _SharedSheet(
        transaction: widget.transaction,
        initial: _othersShare,
        // The amount cannot change while the sheet is open, so it goes in as a
        // value; blank or unparseable is null.
        amount: double.tryParse(_amountController.text.replaceAll(',', '.'))
            ?.abs(),
        currencySymbol: ref.read(currencyProvider).currencySymbol,
      ),
    );
    if (share != null && mounted) setState(() => _othersShare = share);
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

/// "Shared — others owe": what the others owe on the expense being edited,
/// typed or from the "Split in N" shortcut (never stored, it only fills the
/// field). Pops the share, `0` meaning not shared, or null when dismissed; the
/// editor owns the value and applies it with the rest of the form.
///
/// Editing an existing expense, it also lists the reimbursements already linked
/// to it (Unlink) and attaches one more (choose, then Attach). Those are writes
/// to the OTHER rows and happen at once, not with the form's Save, as in the
/// plan sheet's linked payments.
class _SharedSheet extends ConsumerStatefulWidget {
  const _SharedSheet({
    required this.transaction,
    required this.initial,
    required this.amount,
    required this.currencySymbol,
  });

  /// The expense being edited, null for a new one (nothing to link to yet).
  final Transaction? transaction;
  final double initial;

  /// The editor's amount, null while blank or not a number.
  final double? amount;
  final String currencySymbol;

  @override
  ConsumerState<_SharedSheet> createState() => _SharedSheetState();
}

class _SharedSheetState extends ConsumerState<_SharedSheet> {
  late final _field = TextEditingController(
    text: widget.initial > 0 ? widget.initial.toStringAsFixed(2) : '',
  );
  String? _message;

  /// "Split in" goes back to empty after each pick: a new key rebuilds it.
  int _picks = 0;

  /// The income chosen in "Attach a reimbursement": choosing writes nothing, the
  /// Attach button does. A new key empties the dropdown once it has.
  String? _attachId;
  int _attached = 0;

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  void _say(String text) => setState(() => _message = text);

  void _split(int? n) {
    if (n == null) return;
    final amount = widget.amount ?? 0;
    setState(() {
      _picks++;
      if (amount > 0) {
        _field.text = splitShare(amount, n).toStringAsFixed(2);
        _message = null;
      } else {
        _message = context.l10n.txEnterAmountFirst;
      }
    });
  }

  void _apply() {
    final raw = _field.text.trim();
    final share = raw.isEmpty ? 0.0 : double.tryParse(raw.replaceAll(',', '.'));
    if (share == null || !share.isFinite || share < 0) {
      return _say(context.l10n.txShareInvalid);
    }
    // ponytail: a plain compare, as the web does (no cent tolerance).
    if (widget.amount != null && share > widget.amount!) {
      return _say(context.l10n.txShareTooMuch);
    }
    Navigator.pop(context, share <= 0 ? 0.0 : share);
  }

  /// Points [incomeId] at [expenseId] (null unlinks) right now. A failed write
  /// is said in the sheet, which stays open; true when it went through.
  Future<bool> _link(String incomeId, String? expenseId) async {
    setState(() => _message = null);
    try {
      await ref
          .read(financeServiceProvider)
          .linkReimbursement(incomeId, expenseId);
      return true;
    } catch (e, st) {
      if (mounted) _say(context.l10n.txError(errorText(context, e, st)));
      return false;
    }
  }

  Future<void> _attach(String incomeId, String expenseId) async {
    if (await _link(incomeId, expenseId) && mounted) {
      setState(() {
        _attachId = null;
        _attached++;
      });
    }
  }

  /// The reimbursements of the expense being edited, modelled on the plan
  /// sheet's `_LinkedPayments`. Offered while the stored row is shared; the
  /// linked list stays whenever there are links, even if the share was since
  /// lowered to 0.
  ///
  /// ponytail: the attach list is the unlinked incomes of the 12-month ledger,
  /// newest first, capped at 60 — a reimbursement comes soon after the expense.
  Widget _reimbursements(Transaction expense) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final currency = ref.watch(currencyProvider);
    final linked = _newestFirst([
      for (final t
          in ref.watch(shareTransactionsProvider).value ?? const <Transaction>[])
        if (t.isIncome && t.reimbursesId == expense.id) t,
    ]);
    final stored = expense.othersShare > 0;
    if (!stored && linked.isEmpty) return const SizedBox.shrink();

    // Only a row stored as shared has an entry.
    final status = ref.watch(receivablesProvider).value?[expense.id];
    final candidates = _newestFirst([
      for (final t
          in ref.watch(transactionsProvider(null)).value ?? const <Transaction>[])
        if (t.isIncome && (t.reimbursesId ?? '').isEmpty) t,
    ]).take(60).toList();
    String line(Transaction t) => '${DateFormat.yMMMd().format(t.date)} · '
        '${currency.format(t.amount)} · ${_title(t)}';

    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.txReimbursements.toUpperCase(),
            style: GoogleFonts.jetBrainsMono(
              color: scheme.onSurfaceVariant,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
          if (status != null) ...[
            const SizedBox(height: 4),
            Text(
              receivableBadge(l10n, currency, status),
              style: TextStyle(
                color: stillOwed(status)
                    ? incomeInk(scheme.brightness)
                    : scheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          ],
          const SizedBox(height: 8),
          for (final t in linked)
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(line(t), overflow: TextOverflow.ellipsis),
              trailing: IconButton(
                icon: const Icon(Icons.link_off, size: 18),
                tooltip: l10n.txUnlink,
                onPressed: () => _link(t.id, null),
              ),
            ),
          if (stored)
            candidates.isEmpty
                ? Text(
                    l10n.txNoUnlinkedIncomes,
                    style: TextStyle(
                        color: scheme.onSurfaceVariant, fontSize: 12),
                  )
                : Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          key: ValueKey(_attached),
                          isExpanded: true,
                          decoration: InputDecoration(
                              labelText: l10n.txAttachReimbursement),
                          items: [
                            for (final t in candidates)
                              DropdownMenuItem(
                                value: t.id,
                                child: Text(line(t),
                                    overflow: TextOverflow.ellipsis),
                              ),
                          ],
                          onChanged: (id) => setState(() => _attachId = id),
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: _attachId == null
                            ? null
                            : () => _attach(_attachId!, expense.id),
                        child: Text(l10n.txAttach),
                      ),
                    ],
                  ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 4),
            TextField(
              controller: _field,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) {
                if (_message != null) setState(() => _message = null);
              },
              decoration: InputDecoration(
                labelText: context.l10n.txSharedOthersOwe,
                prefixText: '${widget.currencySymbol} ',
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              key: ValueKey(_picks),
              isExpanded: true,
              decoration: InputDecoration(labelText: context.l10n.txSplitIn),
              items: [
                for (var n = 2; n <= 12; n++)
                  DropdownMenuItem(value: n, child: Text('$n')),
              ],
              onChanged: _split,
            ),
            if (widget.transaction != null) _reimbursements(widget.transaction!),
            InlineSheetMessage(_message),
            const SizedBox(height: 24),
            SaveButton(
              label: context.l10n.commonSave.toUpperCase(),
              color: scheme.primary,
              onColor: scheme.onPrimary,
              onTap: _apply,
            ),
            const SizedBox(height: 20),
            const KeyboardSpacer(),
          ],
        ),
      ),
    );
  }
}

List<Transaction> _newestFirst(Iterable<Transaction> txns) =>
    txns.toList()..sort((a, b) => b.date.compareTo(a.date));

/// How a row reads in a list: its description, else its category.
String _title(Transaction t) =>
    t.description.trim().isEmpty ? t.category : t.description;

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

/// FROM and TO, closed like every other row: a hairline under each (the one
/// under TO is the wallet section's own). This used to be a one-sided stub
/// between them, which read as a stray mark and left FROM without its line.
class _TransferPair extends StatelessWidget {
  final Widget from;
  final Widget to;

  const _TransferPair({required this.from, required this.to});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [from, const LedgerDivider(), to],
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

