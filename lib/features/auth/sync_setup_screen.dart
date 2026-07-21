import 'dart:io';

import 'package:budgetti/core/providers/providers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Post-login crossroads: with both a local ledger and a server in play,
/// the user decides which side is the truth before any sync runs —
/// pull the server's data, push this device's data, restore a backup file,
/// or just continue with what's here.
class SyncSetupScreen extends ConsumerStatefulWidget {
  const SyncSetupScreen({super.key});

  @override
  ConsumerState<SyncSetupScreen> createState() => _SyncSetupScreenState();
}

class _SyncSetupScreenState extends ConsumerState<SyncSetupScreen> {
  Map<String, int>? _serverCounts; // null = still loading
  String? _serverError;
  int _localTxCount = 0;
  String? _busy; // label of the action in flight, null = idle

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _serverCounts = null;
      _serverError = null;
    });
    final db = ref.read(databaseProvider);
    final local = await db
        .customSelect('SELECT COUNT(*) AS c FROM transactions WHERE is_deleted = 0')
        .getSingle();
    try {
      final counts = await ref.read(pocketbaseClientProvider).counts();
      if (!mounted) return;
      setState(() {
        _localTxCount = local.read<int>('c');
        _serverCounts = counts;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _localTxCount = local.read<int>('c');
        _serverError = e.toString();
      });
    }
  }

  void _finish() {
    final hasUsername =
        ref.read(persistenceServiceProvider).getUsername().isNotEmpty;
    context.go(hasUsername ? '/dashboard' : '/onboarding');
  }

  void _invalidateFinance() {
    ref.invalidate(transactionsProvider);
    ref.invalidate(categoriesProvider);
    ref.invalidate(tagsProvider);
    ref.invalidate(accountsProvider);
    ref.invalidate(budgetsProvider);
  }

  Future<void> _run(String label, Future<void> Function() action) async {
    setState(() => _busy = label);
    try {
      await action();
      _invalidateFinance();
      if (mounted) _finish();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$label failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<void> _pullServer() => _run('Download', () async {
        final s = await ref
            .read(pocketBaseSyncServiceProvider)
            .sync(full: true, push: false);
        if (s.error != null) throw Exception(s.error);
      });

  Future<void> _pushDevice() => _run('Upload', () async {
        final s = await ref
            .read(pocketBaseSyncServiceProvider)
            .sync(full: true, pull: false);
        if (s.error != null) throw Exception(s.error);
      });

  Future<void> _restoreBackup() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (result == null || !mounted) return;
    final file = File(result.files.single.path!);
    await _run('Restore', () async {
      await ref.read(backupServiceProvider).importDatabase(file);
      // Claim restored rows for this user + re-arm the cursor, then upload.
      await ref.read(authServiceProvider).adoptLocalData();
      final s = await ref
          .read(pocketBaseSyncServiceProvider)
          .sync(full: true, pull: false);
      if (s.error != null) throw Exception(s.error);
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final counts = _serverCounts;
    final serverTx = counts?['transactions'] ?? 0;
    final serverTotal =
        counts?.values.fold<int>(0, (sum, v) => sum + v) ?? 0;
    final loading = counts == null && _serverError == null;

    return Scaffold(
      appBar: AppBar(title: const Text('Set up sync'), automaticallyImplyLeading: false),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Icon(Icons.sync, size: 56, color: scheme.primary),
            const SizedBox(height: 16),
            Text(
              'How should this device and the server line up?',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              loading
                  ? 'Checking the server…'
                  : _serverError != null
                      ? 'Could not reach the server.'
                      : serverTotal > 0
                          ? 'The server already has data for this account '
                              '($serverTx transactions).'
                          : 'The server has no data for this account yet.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            if (loading)
              const Center(child: CircularProgressIndicator())
            else ...[
              if (_serverError != null)
                _ActionCard(
                  icon: Icons.refresh,
                  title: 'Retry',
                  subtitle: 'Check the server connection again',
                  onTap: _busy == null ? _load : null,
                ),
              if (_serverError == null && serverTotal > 0)
                _ActionCard(
                  icon: Icons.cloud_download_outlined,
                  title: 'Use the server\'s data',
                  subtitle: 'Download everything to this device '
                      '($serverTx transactions)',
                  busy: _busy == 'Download',
                  onTap: _busy == null ? _pullServer : null,
                ),
              if (_serverError == null)
                _ActionCard(
                  icon: Icons.cloud_upload_outlined,
                  title: 'Upload this device\'s data',
                  subtitle:
                      'Push all local data to the server ($_localTxCount transactions)',
                  busy: _busy == 'Upload',
                  onTap: _busy == null ? _pushDevice : null,
                ),
              if (_serverError == null)
                _ActionCard(
                  icon: Icons.settings_backup_restore,
                  title: 'Restore a backup file',
                  subtitle: 'Load a Budgetti JSON backup, then upload it',
                  busy: _busy == 'Restore',
                  onTap: _busy == null ? _restoreBackup : null,
                ),
              _ActionCard(
                icon: Icons.arrow_forward,
                title: 'Continue without syncing',
                subtitle: 'Keep local and server data as they are for now',
                onTap: _busy == null ? _finish : null,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool busy;
  final VoidCallback? onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.busy = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: busy
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(icon, color: scheme.primary),
        title: Text(title),
        subtitle: Text(subtitle),
        enabled: onTap != null,
        onTap: onTap,
      ),
    );
  }
}
