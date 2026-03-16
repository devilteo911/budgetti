import 'package:budgetti/core/providers/providers.dart';
import 'package:budgetti/core/theme/app_theme.dart';
import 'package:budgetti/models/transaction.dart';
import 'package:budgetti/models/tag.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:image_picker/image_picker.dart';
import 'package:budgetti/core/services/notification_logic.dart';
import 'package:budgetti/core/widgets/wallet_picker_sheet.dart';
import 'package:budgetti/core/widgets/category_picker_sheet.dart';

class AddTransactionModal extends ConsumerStatefulWidget {
  final Transaction? transaction;
  final bool triggerScan;
  
  const AddTransactionModal({super.key, this.transaction, this.triggerScan = false});

  @override
  ConsumerState<AddTransactionModal> createState() => _AddTransactionModalState();
}

class _AddTransactionModalState extends ConsumerState<AddTransactionModal> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late List<Animation<double>> _itemAnimations;
  final _picker = ImagePicker();
  bool _isScanning = false;
  
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  String _type = 'expense'; // 'expense', 'income', 'transfer'
  String? _selectedCategory;
  DateTime _selectedDate = DateTime.now();
  List<String> _selectedTags = [];
  String? _selectedAccountId;
  String? _selectedToAccountId;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    // Pre-calculate animations for items
    _itemAnimations = List.generate(7, (index) {
      const double interval = 0.1;
      final double start = (index * interval).clamp(0.0, 1.0);
      final double end = (start + 0.4).clamp(0.0, 1.0);
      return CurvedAnimation(
        parent: _animationController,
        curve: Interval(start, end, curve: Curves.easeOutCubic),
      );
    });
    
    // If editing, populate fields
    if (widget.transaction != null) {
      final t = widget.transaction!;
      _amountController.text = t.amount.abs().toString();
      _descriptionController.text = t.description;
      _selectedCategory = t.category;
      _selectedDate = t.date;
      _type = t.type;
      _selectedDate = t.date;
      _type = t.type;
      _selectedTags = List.from(t.tags);
      _selectedAccountId = t.accountId;
      _selectedToAccountId = t.toAccountId;
    }
    
    // Initialize defaults immediately if possible
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final accounts = ref.read(accountsProvider).value ?? [];
      if (_selectedAccountId == null) {
        _initializeDefaultAccount(accounts);
        if (mounted) setState(() {});
      }

      // Initialize category if not set
      if (_type != 'transfer' && _selectedCategory == null) {
        final categories = ref.read(categoriesProvider).value ?? [];
        final filtered = categories.where((c) => c.type == _type).toList();
        if (filtered.isNotEmpty) {
          _selectedCategory = filtered.first.name;
          if (mounted) setState(() {});
        }
      }
    });

    _animationController.forward();

    if (widget.triggerScan) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scanReceipt();
      });
    }
  }
  
  void _initializeDefaultAccount(List<dynamic> accounts) {
    if (_selectedAccountId != null || accounts.isEmpty) return;
    
    try {
      final defaultAccount = accounts.firstWhere((a) => a.isDefault, orElse: () => accounts.first);
      _selectedAccountId = defaultAccount.id;
    } catch (_) {
      _selectedAccountId = accounts.first.id;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _scanReceipt() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.camera);
    if (image == null) return;

    setState(() => _isScanning = true);
    try {
      final ocrService = ref.read(ocrServiceProvider);
      final result = await ocrService.recognizeReceipt(image.path);
      
      if (result.amount != null) {
        _amountController.text = result.amount!.toStringAsFixed(2);
      }
      if (result.merchant != null) {
        _descriptionController.text = result.merchant!;
      }
      if (result.date != null) {
        _selectedDate = result.date!;
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Receipt scanned successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('OCR Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isScanning = false);
    }
  }

  void _submit() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedAccountId == null) {
        // Should not happen if accounts are loaded, but just in case
         ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a wallet')),
        );
        return;
      }

      final amount = double.parse(_amountController.text.replaceAll(',', '.'));

      if (_type == 'transfer' &&
          (_selectedToAccountId == null ||
              _selectedToAccountId == _selectedAccountId)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select a different destination wallet'),
          ),
        );
        return;
      }

      final transaction = Transaction(
        id: widget.transaction?.id ?? const Uuid().v4(),
        accountId: _selectedAccountId!, 
        toAccountId: _type == 'transfer' ? _selectedToAccountId : null,
        amount:
            _type == 'expense' ? -amount.abs() : amount.abs(),
        date: _selectedDate,
        description: _descriptionController.text,
        category: _type == 'transfer'
            ? 'Transfer'
            : (_selectedCategory ?? 'Uncategorized'),
        type: _type,
        tags: _selectedTags,
      );

      final service = ref.read(financeServiceProvider);
      if (widget.transaction != null) {
        await service.updateTransaction(transaction);
      } else {
        await service.addTransaction(transaction);
      }

      // Check for budget alerts
      ref.read(notificationLogicProvider).checkBudgetAlerts(transaction);

      // Targeted refresh strategy - only refresh what changed
      // 1. Refresh accounts (balance changed)
      ref.invalidate(accountsProvider);

      // 2. Refresh transactions and paginated list
      ref.invalidate(transactionsProvider(null));
      ref.invalidate(transactionsProvider(_selectedAccountId));
      if (_type == 'transfer' && _selectedToAccountId != null) {
        ref.invalidate(transactionsProvider(_selectedToAccountId));
      }
      ref.invalidate(paginatedTransactionsProvider);

      // 3. Only invalidate budgets if it's an expense/income (not transfer)
      if (_type != 'transfer') {
        ref.invalidate(budgetsProvider);
      }

      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.transaction != null ? 'Transaction updated' : 'Transaction added')),
        );
      }
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate.isAfter(DateTime.now()) ? DateTime.now() : _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppTheme.primaryGreen,
              onPrimary: AppTheme.backgroundBlack,
              surface: AppTheme.surfaceGrey,
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      if (mounted) setState(() => _selectedDate = picked);
    }
  }

  void _showWalletPicker(bool isFrom) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceGrey,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return WalletPickerSheet(
          title: isFrom ? "Select From Wallet" : "Select To Wallet",
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
        );
      },
    );
  }

  void _showCategoryPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceGrey,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return CategoryPickerSheet(
          title: "Select Category",
          selectedCategoryName: _selectedCategory,
          type: _type == 'expense' ? 'expense' : 'income',
          onCategorySelected: (category) {
            setState(() => _selectedCategory = category.name);
          },
        );
      },
    );
  }

  Widget _buildAnimatedItem(int index, Widget child) {
    return AnimatedBuilder(
      animation: _itemAnimations[index],
      builder: (context, child) {
        final double curveValue = _itemAnimations[index].value;

        return Opacity(
          opacity: curveValue,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - curveValue)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Get currency symbol
    final formatter = ref.watch(currencyProvider);
    final currencySymbol = formatter.currencySymbol;

    return RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.only(
          left: 16,
          right: 16,
          top: 8,
        ),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),

                // Big Amount Hero Display
                _buildAnimatedItem(
                  0,
                  _AmountHero(
                    controller: _amountController,
                    currencySymbol: currencySymbol,
                    type: _type,
                  ),
                ),

                const SizedBox(height: 32),

              
              // Type Selector
              _buildAnimatedItem(1, 
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                        value: 'expense',
                        label: Text(
                          "Expense",
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        icon: Icon(Icons.arrow_downward, size: 18),
                      ),
                      ButtonSegment(
                        value: 'income',
                        label: Text(
                          "Income",
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        icon: Icon(Icons.arrow_upward, size: 18),
                      ),
                      ButtonSegment(
                        value: 'transfer',
                        label: Text(
                          "Transfer",
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        icon: Icon(Icons.swap_horiz, size: 18),
                      ),
                    ],
                    showSelectedIcon: false,
                    selected: {_type},
                    onSelectionChanged: (Set<String> newSelection) {
                      setState(() {
                        _type = newSelection.first;
                        final categories =
                            ref.read(categoriesProvider).value ?? [];
                        final filtered = categories
                            .where((c) => c.type == _type)
                            .toList();
                        _selectedCategory = filtered.isNotEmpty
                            ? filtered.first.name
                            : null;
                      });
                    },
                    style: SegmentedButton.styleFrom(
                      backgroundColor: AppTheme.surfaceGrey,
                      selectedBackgroundColor: _type == 'expense'
                          ? AppTheme.darkTheme.colorScheme.error
                          : (_type == 'income'
                                ? AppTheme.primaryGreen
                                : Colors.blue),
                      selectedForegroundColor: AppTheme.backgroundBlack,
                      foregroundColor: AppTheme.textGrey,
                      side: BorderSide(
                        color: AppTheme.textGrey.withOpacity(0.2),
                        width: 1.5,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
              ),
                const SizedBox(height: 16),

                // Description & Wallet Row
                _buildAnimatedItem(
                  3,
                  Column(
                    children: [
                      _DescriptionField(controller: _descriptionController),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Consumer(
                              // existing wallet builder logic (I'll replace the whole block)
                            builder: (context, ref, child) {
                              final accountsAsync = ref.watch(accountsProvider);

                              return accountsAsync.when(
                                data: (accounts) {
                                  final selectedAccount = accounts
                                      .where((a) => a.id == _selectedAccountId)
                                      .firstOrNull;

                                  return InkWell(
                                    onTap: () => _showWalletPicker(true),
                                      borderRadius: BorderRadius.circular(16),
                                    child: Container(
                                        padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: AppTheme.surfaceGrey,
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        border: Border.all(
                                            color:
                                                (_type == 'transfer' &&
                                                    _selectedAccountId == null)
                                              ? Colors.red.withOpacity(0.5)
                                                : AppTheme.textGrey.withOpacity(
                                                    0.2,
                                                  ),
                                            width: 1.5,
                                        ),
                                      ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              "Source",
                                              style: TextStyle(
                                                color: AppTheme.textGrey,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Row(
                                              children: [
                                                const Icon(
                                                  Icons
                                                      .account_balance_wallet_outlined,
                                                  color: AppTheme.primaryGreen,
                                                  size: 20,
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    selectedAccount?.name ??
                                                        "Select Wallet",
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 15,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                                loading: () => Container(
                                    padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: AppTheme.surfaceGrey,
                                      borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                        color: AppTheme.textGrey.withOpacity(
                                          0.2,
                                        ),
                                        width: 1.5,
                                    ),
                                  ),
                                  child: const Center(
                                    child: SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppTheme.primaryGreen,
                                      ),
                                    ),
                                  ),
                                ),
                                error: (_, __) => Container(
                                    padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: AppTheme.surfaceGrey,
                                      borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: Colors.red.withOpacity(0.3),
                                        width: 1.5,
                                    ),
                                  ),
                                  child: const Center(
                                    child: Icon(
                                        Icons.error_outline,
                                      color: Colors.red,
                                      size: 20,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (_type == 'transfer') const SizedBox(height: 12),
                if (_type == 'transfer')
                  _buildAnimatedItem(
                    4,
                    Consumer(
                      builder: (context, ref, child) {
                        final accountsAsync = ref.watch(accountsProvider);
                        return accountsAsync.when(
                          data: (accounts) {
                            final selectedToAccount = accounts
                                .where((a) => a.id == _selectedToAccountId)
                                .firstOrNull;
                            return InkWell(
                              onTap: () => _showWalletPicker(false),
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: AppTheme.surfaceGrey,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: (_selectedToAccountId == null)
                                        ? Colors.red.withOpacity(0.5)
                                        : AppTheme.textGrey.withOpacity(0.2),
                                    width: 1.5,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      "Destination",
                                      style: TextStyle(
                                        color: AppTheme.textGrey,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.account_balance_wallet_outlined,
                                          color: Colors.blue,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            selectedToAccount?.name ??
                                                "Select Destination",
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 15,
                                              fontWeight: FontWeight.w600,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                          loading: () => const SizedBox.shrink(),
                          error: (_, __) => const SizedBox.shrink(),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 12),
          
                // Date and Category Picker Row (Inline)
                _buildAnimatedItem(
                  4, 
                  Row(
                    children: [
                      // Date Picker
                      Expanded(
                        child: InkWell(
                          onTap: _pickDate,
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceGrey,
                              border: Border.all(
                                color: AppTheme.textGrey.withOpacity(0.2),
                                width: 1.5,
                              ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Date",
                                  style: TextStyle(
                                    color: AppTheme.textGrey,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.calendar_today_outlined,
                                      color: AppTheme.textGrey,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        DateFormat.yMMMd().format(
                                          _selectedDate,
                                        ),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Category Picker
                      if (_type != 'transfer')
                        Expanded(
                        child: Consumer(
                          builder: (context, ref, child) {
                            final categoriesAsync = ref.watch(
                              categoriesProvider,
                            );
                            final categoryColors = ref.watch(categoryColorCacheProvider);
                            final categoryIcons = ref.watch(categoryIconCacheProvider);

                            return categoriesAsync.when(
                              data: (categories) {
                                final filtered = categories
                                    .where(
                                      (c) =>
                                          c.type ==
                                            (_type == 'expense'
                                                ? 'expense'
                                                : 'income'),
                                    )
                                    .toList();

                                  final selectedCat =
                                      filtered
                                          .where(
                                            (c) => c.name == _selectedCategory,
                                          )
                                          .firstOrNull ??
                                      filtered.firstOrNull;

                                return InkWell(
                                  onTap: _showCategoryPicker,
                                    borderRadius: BorderRadius.circular(16),
                                  child: Container(
                                      padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: AppTheme.surfaceGrey,
                                      border: Border.all(
                                          color: AppTheme.textGrey.withOpacity(
                                            0.2,
                                          ),
                                          width: 1.5,
                                      ),
                                        borderRadius: BorderRadius.circular(16),
                                    ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            "Category",
                                            style: TextStyle(
                                              color: AppTheme.textGrey,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              Icon(
                                                selectedCat != null
                                                    ? (categoryIcons[selectedCat
                                                              .name] ??
                                                          Icons
                                                              .category_outlined)
                                                    : Icons.category_outlined,
                                                color: selectedCat != null
                                                    ? (categoryColors[selectedCat
                                                              .name] ??
                                                          AppTheme.textGrey)
                                                    : AppTheme.textGrey,
                                                size: 20,
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  _selectedCategory ??
                                                      "Uncategorized",
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                              loading: () => Container(
                                  padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: AppTheme.surfaceGrey,
                                  border: Border.all(
                                      color: AppTheme.textGrey.withOpacity(0.2),
                                      width: 1.5,
                                  ),
                                    borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Center(
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppTheme.primaryGreen,
                                    ),
                                  ),
                                ),
                              ),
                              error: (_, __) => Container(
                                  padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: AppTheme.surfaceGrey,
                                  border: Border.all(
                                    color: Colors.red.withOpacity(0.3),
                                      width: 1.5,
                                  ),
                                    borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Center(
                                  child: Icon(
                                      Icons.error_outline,
                                    color: Colors.red,
                                    size: 20,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                ),
              ),
          
                const SizedBox(height: 12),
 
              // Tags Selector
                _buildAnimatedItem(
                  5,
                  RepaintBoundary(
                    child: Consumer(
                  builder: (context, ref, child) {
                    final tagsAsync = ref.watch(tagsProvider);
                    final tagColors = ref.watch(tagColorCacheProvider);
                    return tagsAsync.when(
                      data: (tags) {
                        if (tags.isEmpty) return const SizedBox.shrink();
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Tags", style: TextStyle(color: AppTheme.textGrey, fontSize: 14)),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              children: tags.map((Tag tag) {
                                final isSelected = _selectedTags.contains(tag.name);
                                final tagColor = tagColors[tag.name] ?? Colors.grey;
                                return FilterChip(
                                  label: Text(tag.name),
                                  selected: isSelected,
                                  onSelected: (selected) {
                                    setState(() {
                                      if (selected) {
                                        _selectedTags.add(tag.name);
                                      } else {
                                        _selectedTags.remove(tag.name);
                                      }
                                    });
                                  },
                                  backgroundColor: AppTheme.surfaceGrey,
                                  selectedColor: tagColor.withOpacity(0.3),
                                  checkmarkColor: tagColor,
                                  labelStyle: TextStyle(
                                    color: isSelected ? tagColor : Colors.white,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                    side: BorderSide(
                                      color: isSelected ? tagColor : Colors.transparent,
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        );
                      },
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                    );
                  },
                ),
              ),
                ),
                const SizedBox(height: 16),
                _buildAnimatedItem(
                  6,
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: _isScanning ? null : _submit,
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            height: 60,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppTheme.primaryGreen,
                                  AppTheme.primaryGreen.withOpacity(0.8),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.primaryGreen.withOpacity(0.3),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                widget.transaction != null
                                    ? "Update Transaction"
                                    : "Add Transaction",
                                style: const TextStyle(
                                  color: AppTheme.backgroundBlack,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      if (_isScanning)
                        const SizedBox(
                          width: 60,
                          height: 60,
                          child: Center(
                            child: CircularProgressIndicator(
                              color: AppTheme.primaryGreen,
                              strokeWidth: 3,
                            ),
                          ),
                        )
                      else
                        InkWell(
                          onTap: _scanReceipt,
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            height: 60,
                            width: 60,
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceGrey,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: AppTheme.primaryGreen.withOpacity(0.5),
                                width: 1.5,
                              ),
                            ),
                            child: const Icon(
                              Icons.document_scanner_outlined,
                              color: AppTheme.primaryGreen,
                              size: 24,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const _KeyboardSpacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AmountHero extends StatelessWidget {
  final TextEditingController controller;
  final String currencySymbol;
  final String type;

  const _AmountHero({
    required this.controller,
    required this.currencySymbol,
    required this.type,
  });

  @override
  Widget build(BuildContext context) {
    final color = type == 'expense'
        ? AppTheme.darkTheme.colorScheme.error
        : (type == 'income' ? AppTheme.primaryGreen : Colors.blue);

    return Column(
      children: [
        Text(
          type == 'expense'
              ? "You Spent"
              : (type == 'income' ? "You Received" : "You Transferred"),
          style: const TextStyle(
            color: AppTheme.textGrey,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        IntrinsicWidth(
          child: TextFormField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.bold,
              color: color,
              letterSpacing: -1,
            ),
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              prefixText: currencySymbol,
              prefixStyle: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: color.withOpacity(0.5),
              ),
              hintText: "0.00",
              hintStyle: TextStyle(color: color.withOpacity(0.2)),
              border: InputBorder.none,
              focusedBorder: InputBorder.none,
              enabledBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
              contentPadding: EdgeInsets.zero,
              filled: false,
            ),
            validator: (value) {
              if (value == null || value.isEmpty) return 'Enter amount';
              final sanitized = value.replaceAll(',', '.');
              if (double.tryParse(sanitized) == null) return 'Invalid';
              return null;
            },
          ),
        ),
      ],
    );
  }
}

class _DescriptionField extends StatelessWidget {
  final TextEditingController controller;

  const _DescriptionField({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceGrey,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.textGrey.withOpacity(0.2),
          width: 1.5,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          const Icon(
            Icons.description_outlined,
            color: AppTheme.textGrey,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextFormField(
              controller: controller,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              decoration: const InputDecoration(
                hintText: "What was this for?",
                hintStyle: TextStyle(color: AppTheme.textGrey, fontSize: 16),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 16),
                isDense: true,
                filled: false,
              ),
              validator: (value) {
                if (value == null || value.isEmpty) return 'Enter description';
                return null;
              },
            ),
          ),
        ],
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
