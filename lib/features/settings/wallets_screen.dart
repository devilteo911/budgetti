import 'package:budgetti/core/providers/providers.dart';
import 'package:budgetti/core/widgets/skeleton.dart';
import 'package:budgetti/features/settings/widgets/wallet_skeleton.dart';
import 'package:budgetti/models/account.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

class WalletsScreen extends ConsumerWidget {
  const WalletsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final accountsAsync = ref.watch(accountsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Wallets',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: scheme.onSurface,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              HapticFeedback.heavyImpact();
              _showWalletEditor(context, ref, null);
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(accountsProvider);
          await ref.read(accountsProvider.future);
        },
        child: accountsAsync.when(
          skipLoadingOnRefresh: true,
          data: (accounts) {
            if (accounts.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.account_balance_wallet_outlined,
                      size: 64,
                      color: scheme.onSurface.withValues(alpha: 0.3),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No wallets yet',
                      style: TextStyle(
                        color: scheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              );
            }
            final formatter = ref.watch(currencyProvider);
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              itemCount: accounts.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, index) {
                final w = accounts[index];
                return _WalletTile(
                  wallet: w,
                  formattedBalance: formatter.format(w.balance),
                  onTap: () => _showWalletEditor(context, ref, w),
                  onSetDefault: () => _setAsDefault(ref, w),
                  onDelete: () => _deleteWallet(context, ref, w),
                );
              },
            );
          },
          loading: () => ShimmerLoading(
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              itemCount: 5,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, __) => const WalletItemSkeleton(),
            ),
          ),
          error: (e, _) => Center(child: Text('Error: $e')),
        ),
      ),
    );
  }

  void _showWalletEditor(
      BuildContext context, WidgetRef ref, Account? wallet) {
    showModalBottomSheet(
      useRootNavigator: true,
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
      builder: (_) => _WalletEditorModal(wallet: wallet),
    );
  }

  Future<void> _setAsDefault(WidgetRef ref, Account wallet) async {
    final updated = wallet.copyWith(isDefault: true);
    await ref.read(financeServiceProvider).updateAccount(updated);
    ref.invalidate(accountsProvider);
  }

  Future<void> _deleteWallet(
      BuildContext context, WidgetRef ref, Account wallet) async {
    final scheme = Theme.of(context).colorScheme;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Account'),
        content: Text(
          "Delete '${wallet.name}'? This won't delete transactions but they might become unassigned.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: scheme.error),
            child: const Text('Delete'),
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

class _WalletTile extends StatelessWidget {
  final Account wallet;
  final String formattedBalance;
  final VoidCallback onTap;
  final VoidCallback onSetDefault;
  final VoidCallback onDelete;

  const _WalletTile({
    required this.wallet,
    required this.formattedBalance,
    required this.onTap,
    required this.onSetDefault,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: scheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.account_balance_wallet_outlined,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            wallet.name,
                            style: TextStyle(
                              color: scheme.onSurface,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (wallet.isDefault) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.star, color: Colors.amber, size: 16),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      formattedBalance,
                      style: TextStyle(
                        color: scheme.onSurface.withValues(alpha: 0.6),
                        fontSize: 12,
                      ),
                    ),
                    if (wallet.initialBalanceDate != null)
                      Text(
                        'From ${DateFormat('MMM d, yyyy').format(wallet.initialBalanceDate!)}',
                        style: TextStyle(
                          color: scheme.onSurface.withValues(alpha: 0.4),
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
              ),
              if (!wallet.isDefault)
                IconButton(
                  icon: Icon(
                    Icons.star_border,
                    color: scheme.onSurface.withValues(alpha: 0.4),
                    size: 20,
                  ),
                  onPressed: onSetDefault,
                  tooltip: 'Set as default',
                ),
              IconButton(
                icon: Icon(
                  Icons.delete_outline,
                  color: scheme.error,
                  size: 20,
                ),
                onPressed: onDelete,
              ),
            ],
          ),
        ),
      ),
    );
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
    final scheme = Theme.of(context).colorScheme;
    return Consumer(
      builder: (context, ref, _) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 20,
          right: 20,
          top: 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.wallet != null ? 'Edit Account' : 'New Account',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Account Name (e.g. PayPal, Bank)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _amountController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Initial Amount',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Starting Date'),
              subtitle: Text(
                _initialBalanceDate == null
                    ? 'All transactions'
                    : DateFormat('MMM d, yyyy').format(_initialBalanceDate!),
              ),
              trailing: Icon(Icons.calendar_today, color: scheme.primary),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _initialBalanceDate ?? DateTime.now(),
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                );
                if (picked != null) {
                  setState(() => _initialBalanceDate = picked);
                }
              },
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Set as Default'),
              value: _isDefault,
              onChanged: (v) => setState(() => _isDefault = v),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () async {
                final name = _nameController.text.trim();
                final amount =
                    double.tryParse(_amountController.text) ?? 0.0;
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
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: Text(
                widget.wallet != null ? 'Update Account' : 'Create Account',
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
