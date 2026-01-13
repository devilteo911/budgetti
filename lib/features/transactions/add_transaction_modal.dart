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

class AddTransactionModal extends ConsumerStatefulWidget {
  final Transaction? transaction;
  final bool triggerScan;
  
  const AddTransactionModal({super.key, this.transaction, this.triggerScan = false});

  @override
  ConsumerState<AddTransactionModal> createState() => _AddTransactionModalState();
}

class _AddTransactionModalState extends ConsumerState<AddTransactionModal> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  final _picker = ImagePicker();
  bool _isScanning = false;
  
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  bool _isExpense = true;
  String? _selectedCategory;
  DateTime _selectedDate = DateTime.now();
  List<String> _selectedTags = [];
  String? _selectedAccountId;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    
    // If editing, populate fields
    if (widget.transaction != null) {
      final t = widget.transaction!;
      _amountController.text = t.amount.abs().toString();
      _descriptionController.text = t.description;
      _selectedCategory = t.category;
      _selectedDate = t.date;
      _isExpense = t.amount < 0;
      _selectedTags = List.from(t.tags);
      _selectedAccountId = t.accountId;
    }
    
    _animationController.forward();

    if (widget.triggerScan) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scanReceipt();
      });
    }
  }
  
  // Helper to find default account if _selectedAccountId is null
  void _initializeDefaultAccount(List<dynamic> accounts) {
    if (_selectedAccountId != null) return;
    if (accounts.isEmpty) {
      _selectedAccountId = '1'; // Fallback
      return;
    }
    
    try {
      final defaultAccount = accounts.firstWhere((a) => a.isDefault, orElse: () => accounts.first);
      _selectedAccountId = defaultAccount.id;
    } catch (_) {
      _selectedAccountId = '1';
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
      final finalAmount = _isExpense ? -amount : amount;

      final transaction = Transaction(
        id: widget.transaction?.id ?? const Uuid().v4(),
        accountId: _selectedAccountId!, 
        amount: finalAmount,
        date: _selectedDate,
        description: _descriptionController.text,
        category: _selectedCategory ?? 'Uncategorized',
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

      // Refresh providers to update UI across the app
      ref.invalidate(accountsProvider);
      ref.invalidate(transactionsProvider(_selectedAccountId!));
      ref.invalidate(
        transactionsProvider(null),
      ); // Refresh ALL transactions (Dashboard, Stats)
      ref.invalidate(budgetsProvider); // Refresh budgets state
      
      if (widget.transaction != null && widget.transaction!.accountId != _selectedAccountId) {
         // Also invalidate the old account if it changed
         ref.invalidate(transactionsProvider(widget.transaction!.accountId));
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
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
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

  void _showCategoryPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceGrey,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Consumer(
          builder: (context, ref, child) {
            final categoriesAsync = ref.watch(categoriesProvider);
            
            return Padding(
              padding: const EdgeInsets.only(top: 24, bottom: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.textGrey.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "Select Category",
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  Flexible(
                    child: categoriesAsync.when(
                      data: (categories) {
                         // Filter by type
                         final filtered = categories.where((c) => c.type == (_isExpense ? 'expense' : 'income')).toList();
                        if (filtered.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 32),
                            child: Center(
                              child: Text(
                                "No categories found",
                                style: TextStyle(color: AppTheme.textGrey),
                              ),
                            ),
                          );
                        }

                        return ListView.builder(
                          shrinkWrap: true,
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final cat = filtered[index];
                            final isSelected = _selectedCategory == cat.name;
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 4,
                              ),
                              title: Text(
                                cat.name,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                              leading: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Color(cat.colorHex).withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  IconData(cat.iconCode, fontFamily: 'MaterialIcons'),
                                  color: Color(cat.colorHex),
                                  size: 20,
                                ),
                              ),
                              onTap: () {
                                setState(() => _selectedCategory = cat.name);
                                Navigator.of(context).pop();
                              },
                              trailing: isSelected
                                  ? const Icon(
                                      Icons.check_circle,
                                      color: AppTheme.primaryGreen,
                                    )
                                  : null,
                            );
                          },
                        );
                      },
                      loading: () => const Padding(
                        padding: EdgeInsets.symmetric(vertical: 32),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: AppTheme.primaryGreen,
                          ),
                        ),
                      ),
                      error: (e, s) => Padding(
                        padding: const EdgeInsets.all(24),
                        child: Center(
                          child: Text(
                            "Error: $e",
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showWalletPicker(List<dynamic> accounts) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceGrey,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.only(top: 24, bottom: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.textGrey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                "Select Wallet",
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: accounts.map((account) {
                    final isSelected = account.id == _selectedAccountId;
                    final currencyFormatter = ref.watch(currencyProvider);

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isSelected ? AppTheme.primaryGreen.withValues(alpha: 0.1) : AppTheme.surfaceGreyLight,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.account_balance_wallet,
                          color: isSelected ? AppTheme.primaryGreen : AppTheme.textGrey,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        account.name,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      subtitle: Text(
                        currencyFormatter.format(account.balance),
                        style: TextStyle(color: isSelected ? AppTheme.primaryGreen : AppTheme.textGrey),
                      ),
                      trailing: isSelected ? const Icon(Icons.check_circle, color: AppTheme.primaryGreen) : null,
                      onTap: () {
                        setState(() => _selectedAccountId = account.id);
                        Navigator.of(context).pop();
                      },
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAnimatedItem(int index, Widget child) {
    const double interval = 0.1;
    final double start = (index * interval).clamp(0.0, 1.0);
    final double end = (start + 0.4).clamp(0.0, 1.0);

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        final double curveValue = CurvedAnimation(
          parent: _animationController,
          curve: Interval(start, end, curve: Curves.easeOutBack),
        ).value;

        return Opacity(
          opacity: curveValue.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, 30 * (1 - curveValue)),
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
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 16,
          right: 16,
          top: 16,
        ),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [

              
              // Type Selector
              _buildAnimatedItem(1, 
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: true, label: Text("Expense"), icon: Icon(Icons.arrow_downward)),
                    ButtonSegment(value: false, label: Text("Income"), icon: Icon(Icons.arrow_upward)),
                  ],
                  selected: {_isExpense},
                  onSelectionChanged: (Set<bool> newSelection) {
                    setState(() {
                      _isExpense = newSelection.first;
                        _selectedCategory = null; 
                    });
                  },
                  style: ButtonStyle(
                    backgroundColor: WidgetStateProperty.resolveWith<Color>((Set<WidgetState> states) {
                      if (states.contains(WidgetState.selected)) {
                        return _isExpense ? Theme.of(context).colorScheme.error : AppTheme.primaryGreen;
                      }
                      return AppTheme.surfaceGreyLight;
                    }),
                    foregroundColor: WidgetStateProperty.resolveWith<Color>((Set<WidgetState> states) {
                      if (states.contains(WidgetState.selected)) {
                         return AppTheme.backgroundBlack;
                      }
                      return AppTheme.textWhite;
                    }),
                  ),
                ),
              ),
                const SizedBox(height: 16),

                // Description
                _buildAnimatedItem(
                  2,
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceGrey,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppTheme.textGrey.withValues(alpha: 0.3),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.edit,
                          color: AppTheme.textGrey,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _descriptionController,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                            decoration: const InputDecoration(
                              hintText: "Description",
                              hintStyle: TextStyle(
                                color: AppTheme.textGrey,
                                fontSize: 16,
                              ),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(
                                vertical: 12,
                              ),
                              isDense: true,
                              filled: false,
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Enter description';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
          
                // Wallet & Amount Row
                _buildAnimatedItem(
                  3, 
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Wallet Selector
                        Expanded(
                          child: Consumer(
                            builder: (context, ref, child) {
                              final accountsAsync = ref.watch(accountsProvider);

                              return accountsAsync.when(
                                data: (accounts) {
                                  if (accounts.isNotEmpty) {
                                    if (_selectedAccountId == null) {
                                      WidgetsBinding.instance
                                          .addPostFrameCallback((_) {
                                            if (mounted) {
                                              setState(
                                                () => _initializeDefaultAccount(
                                                  accounts,
                                                ),
                                              );
                                            }
                                          });
                                    } else if (!accounts.any(
                                      (a) => a.id == _selectedAccountId,
                                    )) {
                                      WidgetsBinding.instance
                                          .addPostFrameCallback((_) {
                                            if (mounted) {
                                              setState(
                                                () => _selectedAccountId =
                                                    accounts.first.id,
                                              );
                                            }
                                          });
                                    }
                                  }

                                  final selectedAccount = accounts
                                      .where((a) => a.id == _selectedAccountId)
                                      .firstOrNull;

                                  return InkWell(
                                    onTap: () => _showWalletPicker(accounts),
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: AppTheme.surfaceGrey,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: AppTheme.textGrey.withValues(
                                            alpha: 0.3,
                                          ),
                                        ),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.account_balance_wallet,
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
                                                fontSize: 14,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const Icon(
                                            Icons.keyboard_arrow_down,
                                            color: AppTheme.textGrey,
                                            size: 16,
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                                loading: () => Container(
                                  decoration: BoxDecoration(
                                    color: AppTheme.surfaceGrey,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: AppTheme.textGrey.withValues(
                                        alpha: 0.3,
                                      ),
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
                                  decoration: BoxDecoration(
                                    color: AppTheme.surfaceGrey,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.red.withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: const Center(
                                    child: Icon(
                                      Icons.error,
                                      color: Colors.red,
                                      size: 20,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Amount Input
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceGrey,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppTheme.textGrey.withValues(alpha: 0.3),
                              ),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Row(
                              children: [
                                // Currency indicator
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryGreen.withValues(
                                      alpha: 0.2,
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      currencySymbol,
                                      style: const TextStyle(
                                        color: AppTheme.primaryGreen,
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                // Input area
                                Expanded(
                                  child: TextFormField(
                                    controller: _amountController,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                    textAlign: TextAlign.right,
                                    decoration: InputDecoration(
                                      hintText: "0.00",
                                      hintStyle: TextStyle(
                                        color: AppTheme.textGrey.withValues(
                                          alpha: 0.5,
                                        ),
                                      ),
                                      border: InputBorder.none,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 12,
                                          ),
                                      filled: false,
                                    ),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Enter amount';
                                      }
                                      final sanitized = value.replaceAll(
                                        ',',
                                        '.',
                                      );
                                      if (double.tryParse(sanitized) == null) {
                                        return 'Invalid';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                              ],
                            ),
                        ),
                      ),
                    ],
                  ),
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
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceGrey,
                              border: Border.all(
                                color: AppTheme.textGrey.withValues(alpha: 0.3),
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.calendar_today,
                                  color: AppTheme.textGrey,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    DateFormat.yMMMd().format(_selectedDate),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Category Picker
                      Expanded(
                        child: Consumer(
                          builder: (context, ref, child) {
                            final categoriesAsync = ref.watch(
                              categoriesProvider,
                            );

                            return categoriesAsync.when(
                              data: (categories) {
                                final filtered = categories
                                    .where(
                                      (c) =>
                                          c.type ==
                                          (_isExpense ? 'expense' : 'income'),
                                    )
                                    .toList();

                                if (filtered.isNotEmpty &&
                                    _selectedCategory == null) {
                                  WidgetsBinding.instance.addPostFrameCallback((
                                    _,
                                  ) {
                                    if (mounted) {
                                      setState(
                                        () => _selectedCategory =
                                            filtered.first.name,
                                      );
                                    }
                                  });
                                }

                                final selectedCat =
                                    filtered
                                        .where(
                                          (c) => c.name == _selectedCategory,
                                        )
                                        .firstOrNull ??
                                    filtered.firstOrNull;

                                return InkWell(
                                  onTap: _showCategoryPicker,
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 14,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppTheme.surfaceGrey,
                                      border: Border.all(
                                        color: AppTheme.textGrey.withValues(
                                          alpha: 0.3,
                                        ),
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          selectedCat != null
                                              ? IconData(
                                                  selectedCat.iconCode,
                                                  fontFamily: 'MaterialIcons',
                                                )
                                              : Icons.category,
                                          color: selectedCat != null
                                              ? Color(selectedCat.colorHex)
                                              : AppTheme.textGrey,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            _selectedCategory ??
                                                (filtered.isNotEmpty
                                                    ? filtered.first.name
                                                    : "Category"),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 14,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const Icon(
                                          Icons.keyboard_arrow_down,
                                          color: AppTheme.textGrey,
                                          size: 16,
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                              loading: () => Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 14,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.surfaceGrey,
                                  border: Border.all(
                                    color: AppTheme.textGrey.withValues(
                                      alpha: 0.3,
                                    ),
                                  ),
                                  borderRadius: BorderRadius.circular(12),
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
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 14,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.surfaceGrey,
                                  border: Border.all(
                                    color: Colors.red.withValues(alpha: 0.3),
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Center(
                                  child: Icon(
                                    Icons.error,
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
                Consumer(
                  builder: (context, ref, child) {
                    final tagsAsync = ref.watch(tagsProvider);
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
                                  selectedColor: Color(tag.colorHex).withValues(alpha: 0.3),
                                  checkmarkColor: Color(tag.colorHex),
                                  labelStyle: TextStyle(
                                    color: isSelected ? Color(tag.colorHex) : Colors.white,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                    side: BorderSide(
                                      color: isSelected ? Color(tag.colorHex) : Colors.transparent,
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
                const SizedBox(height: 16),
          
              // Submit
                _buildAnimatedItem(
                  6, 
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isScanning ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryGreen,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          widget.transaction != null
                              ? "Update Transaction"
                              : "Add Transaction",
                          style: const TextStyle(
                            color: AppTheme.backgroundBlack,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (_isScanning)
                      const SizedBox(
                        width: 56,
                        height: 56,
                        child: Center(
                          child: CircularProgressIndicator(
                            color: AppTheme.primaryGreen,
                            strokeWidth: 3,
                          ),
                        ),
                      )
                    else
                      Container(
                        height: 56,
                        width: 56,
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceGreyLight,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: IconButton(
                          onPressed: _scanReceipt,
                          icon: const Icon(
                            Icons.document_scanner,
                            color: AppTheme.primaryGreen,
                          ),
                          tooltip: "Scan Receipt",
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
      ),
    );
  }
}
