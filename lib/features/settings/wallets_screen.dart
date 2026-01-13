import 'package:budgetti/core/providers/providers.dart';
import 'package:budgetti/core/theme/app_theme.dart';
import 'package:budgetti/models/account.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:budgetti/features/settings/widgets/wallet_skeleton.dart';
import 'package:budgetti/core/widgets/skeleton.dart';

class WalletsScreen extends ConsumerWidget {
  const WalletsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountsAsync = ref.watch(accountsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Manage Wallets",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppTheme.backgroundBlack,
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: AppTheme.primaryGreen),
            onPressed: () {
              HapticFeedback.heavyImpact();
              _showWalletEditor(context, ref, null);
            },
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(accountsProvider);
            await ref.read(accountsProvider.future);
          },
          color: AppTheme.primaryGreen,
          backgroundColor: AppTheme.surfaceGrey,
          child: accountsAsync.when(
            skipLoadingOnRefresh: true,
            data: (accounts) => ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: accounts.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final wallet = accounts[index];
                final currencyFormatter = ref.watch(currencyProvider);

                return ListTile(
                  tileColor: AppTheme.surfaceGrey,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.account_balance_wallet,
                      color: AppTheme.primaryGreen,
                    ),
                  ),
                  title: Text(
                    wallet.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "${currencyFormatter.format(wallet.balance)} (${wallet.isDefault ? 'Default Account' : 'Account'})",
                        style: const TextStyle(color: AppTheme.textGrey),
                      ),
                      if (wallet.initialBalanceDate != null)
                        Text(
                          "Starting from: ${DateFormat('MMM d, yyyy').format(wallet.initialBalanceDate!)}",
                          style: const TextStyle(
                            color: AppTheme.textGrey,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!wallet.isDefault)
                        IconButton(
                          icon: const Icon(
                            Icons.star_border,
                            color: AppTheme.textGrey,
                          ),
                          onPressed: () => _setAsDefault(ref, wallet),
                          tooltip: "Set as default",
                        )
                      else
                        const Icon(Icons.star, color: Colors.amber, size: 24),
                      IconButton(
                        icon: const Icon(Icons.edit, color: AppTheme.textGrey),
                        onPressed: () =>
                            _showWalletEditor(context, ref, wallet),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.redAccent),
                        onPressed: () => _deleteWallet(context, ref, wallet),
                      ),
                    ],
                  ),
                );
              },
            ),
            loading: () => ShimmerLoading(
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                itemCount: 5,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 12),
                itemBuilder: (context, index) => const WalletItemSkeleton(),
              ),
            ),
            error: (err, stack) => Center(child: Text('Error: $err')),
          ),
        ),
      ),
    );
  }

  void _showWalletEditor(BuildContext context, WidgetRef ref, Account? wallet) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceGrey,
      builder: (context) => _WalletEditorModal(wallet: wallet),
    );
  }

  Future<void> _setAsDefault(WidgetRef ref, Account wallet) async {
    final updated = wallet.copyWith(isDefault: true);
    await ref.read(financeServiceProvider).updateAccount(updated);
    ref.invalidate(accountsProvider);
  }

  Future<void> _deleteWallet(BuildContext context, WidgetRef ref, Account wallet) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceGrey,
        title: const Text("Delete Account", style: TextStyle(color: Colors.white)),
        content: Text("Delete '${wallet.name}'? This won't delete transactions but they might become unassigned.", 
          style: const TextStyle(color: AppTheme.textGrey)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(financeServiceProvider).deleteAccount(wallet.id);
      ref.invalidate(accountsProvider);
    }
  }
}

class _WalletEditorModal extends StatefulWidget {
  final Account? wallet;
  const _WalletEditorModal({this.wallet});

  @override
  State<_WalletEditorModal> createState() => _WalletEditorModalState();
}

class _WalletEditorModalState extends State<_WalletEditorModal> {
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  bool _isDefault = false;
  DateTime? _initialBalanceDate;

  @override
  void initState() {
    super.initState();
    if (widget.wallet != null) {
      _nameController.text = widget.wallet!.name;
      _amountController.text = widget.wallet!.initialBalance.toString();
      _isDefault = widget.wallet!.isDefault;
      _initialBalanceDate = widget.wallet!.initialBalanceDate;
    } else {
      _initialBalanceDate = DateTime.now();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 16, right: 16, top: 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.wallet != null ? "Edit Account" : "New Account",
              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _nameController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: "Account Name (e.g. PayPal, Bank)",
                border: OutlineInputBorder(),
                labelStyle: TextStyle(color: AppTheme.textGrey),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _amountController,
              style: const TextStyle(color: Colors.white),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: "Initial Amount",
                border: OutlineInputBorder(),
                labelStyle: TextStyle(color: AppTheme.textGrey),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                "Starting Date",
                style: TextStyle(color: Colors.white),
              ),
              subtitle: Text(
                _initialBalanceDate == null
                    ? "All transactions"
                    : DateFormat('MMM d, yyyy').format(_initialBalanceDate!),
                style: const TextStyle(color: AppTheme.textGrey),
              ),
              trailing: const Icon(
                Icons.calendar_today,
                color: AppTheme.primaryGreen,
              ),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _initialBalanceDate ?? DateTime.now(),
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
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
                  setState(() => _initialBalanceDate = picked);
                }
              },
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text("Set as Default", style: TextStyle(color: Colors.white)),
              value: _isDefault,
              onChanged: (val) => setState(() => _isDefault = val),
              activeThumbColor: AppTheme.primaryGreen,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () async {
                final name = _nameController.text.trim();
                final amount = double.tryParse(_amountController.text) ?? 0.0;
                if (name.isEmpty) return;

                final service = ref.read(financeServiceProvider);
                final navigator = Navigator.of(context);

                if (widget.wallet != null) {
                  await service.updateAccount(widget.wallet!.copyWith(
                    name: name,
                    initialBalance: amount,
                    isDefault: _isDefault,
                      initialBalanceDate: _initialBalanceDate,
                  ));
                } else {
                  final profile = ref.read(userProfileProvider).value;
                  await service.addAccount(Account(
                    id: const Uuid().v4(),
                    name: name,
                    initialBalance: amount,
                      balance: amount,
                    isDefault: _isDefault,
                      initialBalanceDate: _initialBalanceDate,
                    currency: profile?['currency'] ?? 'EUR',
                      providerName: 'Local',
                  ));
                }
                ref.invalidate(accountsProvider);
                navigator.pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGreen,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                widget.wallet != null ? "Update Account" : "Create Account",
                style: const TextStyle(color: AppTheme.backgroundBlack, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
