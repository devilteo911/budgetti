import 'dart:async';
import 'dart:io';

import 'package:budgetti/core/providers/providers.dart';
import 'package:budgetti/core/services/notification_logic.dart';
import 'package:budgetti/core/widgets/pb_server_dialog.dart';
import 'package:budgetti/features/settings/widgets/settings_scaffold.dart';
import 'package:budgetti/features/settings/widgets/settings_section.dart';
import 'package:budgetti/features/settings/widgets/settings_tile.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;

class IntegrationsScreen extends ConsumerStatefulWidget {
  const IntegrationsScreen({super.key});

  @override
  ConsumerState<IntegrationsScreen> createState() => _IntegrationsScreenState();
}

class _IntegrationsScreenState extends ConsumerState<IntegrationsScreen>
    with WidgetsBindingObserver {
  bool _isLoading = false;
  bool _notificationAccess = false;
  GoogleSignInAccount? _googleUser;
  StreamSubscription<GoogleSignInAccount?>? _googleUserSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeGoogleDriveState();
    _refreshNotificationAccess();
  }

  /// Notification access is granted on a system screen, so the only way to know
  /// it changed is to re-read it when the user comes back to the app.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshNotificationAccess();
  }

  void _initializeGoogleDriveState() {
    final authService = ref.read(googleAuthServiceProvider);
    _googleUser = authService.currentUser;
    _googleUserSubscription =
        authService.onCurrentUserChanged.listen((user) {
      if (mounted) setState(() => _googleUser = user);
    });
    if (_googleUser == null) {
      authService.signInSilently();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _googleUserSubscription?.cancel();
    super.dispose();
  }

  // ---------- Google Drive ----------

  Future<void> _handleGoogleSignIn() async {
    try {
      await ref.read(googleAuthServiceProvider).signIn();
      if (mounted) {
        setState(() {
          _googleUser = ref.read(googleAuthServiceProvider).currentUser;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Successfully connected to Google')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      String msg = 'Sign in failed: $e';
      if (e.toString().contains('cancelled')) msg = 'Sign-in was cancelled';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _handleGoogleSignOut() async {
    await ref.read(googleAuthServiceProvider).signOut();
    if (mounted) setState(() => _googleUser = null);
  }

  Future<void> _backupToDrive() async {
    setState(() => _isLoading = true);
    try {
      await ref.read(backupServiceProvider).backupToDrive();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Backup successful')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Backup failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _restoreFromDrive() async {
    setState(() => _isLoading = true);
    try {
      final driveService = ref.read(googleDriveServiceProvider);
      final backups = await driveService.listBackups();
      if (!mounted) return;
      if (backups.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No backups found')),
        );
        return;
      }
      final selected = await showDialog<drive.File>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Select Backup'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: backups.length,
              itemBuilder: (_, i) {
                final f = backups[i];
                return ListTile(
                  title: Text(f.name ?? 'Unknown'),
                  subtitle: Text(f.createdTime?.toString() ?? ''),
                  onTap: () => Navigator.pop(ctx, f),
                );
              },
            ),
          ),
        ),
      );
      if (selected != null && selected.id != null) {
        await ref
            .read(backupServiceProvider)
            .restoreFromDrive(selected.id!);
        // Restored rows carry the backup's userId/lastUpdated — claim them
        // for this user and re-arm the sync cursor or they never sync.
        await ref.read(authServiceProvider).adoptLocalData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Restore successful')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Restore failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ---------- Google Sheets ----------

  Future<void> _syncSheets() async {
    setState(() => _isLoading = true);
    try {
      final result = await performSheetsSync(ref);
      if (mounted) {
        ref.invalidate(accountsProvider);
        ref.invalidate(paginatedTransactionsProvider);
        ref.invalidate(transactionsProvider(null));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.toString())),
        );
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sync failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSheetsConfigDialog() {
    final persistence = ref.read(persistenceServiceProvider);
    final idCtrl =
        TextEditingController(text: persistence.getSheetsSpreadsheetId());
    final nameCtrl =
        TextEditingController(text: persistence.getSheetsSheetName());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Google Sheets Config'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: idCtrl,
              decoration: const InputDecoration(
                labelText: 'Spreadsheet ID',
                hintText: 'From the Google Sheets URL',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Sheet Name',
                hintText: 'e.g., Spese',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              await persistence
                  .setSheetsSpreadsheetId(idCtrl.text.trim());
              await persistence.setSheetsSheetName(nameCtrl.text.trim());
              if (!mounted) return;
              if (ctx.mounted) Navigator.pop(ctx);
              setState(() {});
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  // ---------- Bank email sync (Widiba) ----------

  Future<void> _syncEmailsNow() async {
    setState(() => _isLoading = true);
    try {
      final persistence = ref.read(persistenceServiceProvider);
      final rows = await ref
          .read(bankSyncServiceProvider)
          .sync(days: persistence.getEmailSyncWindowDays());
      final drafts = rows.where((r) => r.status == 'pending').length;
      final skipped = rows.where((r) => r.status == 'skipped').length;
      if (mounted) {
        final parts = [
          if (drafts > 0) '$drafts nuove transazioni da rivedere',
          if (skipped > 0) '$skipped email non riconosciute',
        ];
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(parts.isEmpty
                ? 'Nessuna nuova transazione'
                : parts.join(' · ')),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sync email fallita: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickEmailWindow() async {
    final persistence = ref.read(persistenceServiceProvider);
    final current = persistence.getEmailSyncWindowDays();

    final selected = await showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Finestra di ricerca'),
        children: [
          for (final d in [7, 30, 90, 180, 365])
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, d),
              child: Text('$d giorni'),
            ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, -1),
            child: const Text('Personalizzato…'),
          ),
        ],
      ),
    );
    if (selected == null) return;

    var days = selected;
    if (selected == -1) {
      if (!mounted) return;
      final custom = await _promptCustomDays(current);
      if (custom == null) return;
      days = custom;
    }

    await persistence.setEmailSyncWindowDays(days);
    if (mounted) setState(() {});
  }

  Future<int?> _promptCustomDays(int current) {
    final ctrl = TextEditingController(text: current.toString());
    return showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Giorni da scansionare'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(suffixText: 'giorni'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () {
              final v = int.tryParse(ctrl.text.trim());
              Navigator.pop(ctx, (v != null && v > 0) ? v : null);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // ---------- Bank notification capture (Revolut) ----------

  Future<void> _refreshNotificationAccess() async {
    final granted =
        await ref.read(notificationListenerProvider).isAccessEnabled();
    if (mounted) setState(() => _notificationAccess = granted);
  }

  /// Turning the switch on is useless without Android's notification access, so
  /// send the user straight to the system screen that grants it. The switch
  /// itself is still stored — [didChangeAppLifecycleState] re-reads the real
  /// permission when they come back.
  Future<void> _toggleRevolutSync(bool enabled) async {
    final persistence = ref.read(persistenceServiceProvider);
    await persistence.setRevolutSyncEnabled(enabled);
    await ref.read(notificationLogicProvider).updateBankSyncSchedule();
    if (mounted) setState(() {});

    if (!enabled) return;
    await _refreshNotificationAccess();
    if (!mounted || _notificationAccess) return;

    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Accesso alle notifiche'),
        content: const Text(
          'Per leggere le notifiche di Revolut, Budgetti ha bisogno '
          'dell\'accesso alle notifiche di sistema. Aprire le impostazioni?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Più tardi'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Apri impostazioni'),
          ),
        ],
      ),
    );
    if (go == true) {
      await ref.read(notificationListenerProvider).openSettings();
    }
  }

  Future<void> _syncRevolutNow() async {
    setState(() => _isLoading = true);
    try {
      await _refreshNotificationAccess();
      final rows =
          await ref.read(bankSyncServiceProvider).syncNotifications();
      final drafts = rows.where((r) => r.status == 'pending').length;
      final skipped = rows.where((r) => r.status == 'skipped').length;
      if (mounted) {
        final parts = [
          if (drafts > 0) '$drafts nuove transazioni da rivedere',
          if (skipped > 0) '$skipped notifiche non riconosciute',
        ];
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(parts.isEmpty
                ? _notificationAccess
                    ? 'Nessuna nuova notifica Revolut'
                    : 'Accesso alle notifiche non concesso'
                : parts.join(' · ')),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lettura notifiche fallita: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Revolut's own CSV export, picked from storage. The phone is the only place
  /// that file can be produced, which is why this lives here and not only on the
  /// web dashboard. Rows land in the same review inbox as the notifications —
  /// nothing is written to the ledger until the user approves it.
  Future<void> _importRevolutStatement() async {
    // FileType.any, not a 'csv' extension filter: Android's document picker
    // hands CSVs over as text/comma-separated-values or octet-stream depending
    // on the provider, and the filtered picker then greys the file out.
    final result = await FilePicker.platform.pickFiles(type: FileType.any);
    final path = result?.files.single.path;
    if (path == null || !mounted) return;

    setState(() => _isLoading = true);
    try {
      final csv = await File(path).readAsString();
      final r = await ref.read(bankSyncServiceProvider).importStatement(csv);
      if (!mounted) return;
      final parts = [
        if (r.drafts.isNotEmpty) '${r.drafts.length} da rivedere',
        if (r.duplicates > 0) '${r.duplicates} già presenti',
        if (r.unreadable > 0) '${r.unreadable} righe illeggibili',
      ];
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(parts.isEmpty
              ? 'Nessuna transazione trovata nel file'
              : parts.join(' · ')),
          action: r.drafts.isEmpty
              ? null
              : SnackBarAction(
                  label: 'Rivedi',
                  onPressed: () => context.push('/review-inbox'),
                ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Import estratto conto fallito: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ---------- Auto backup ----------

  Future<void> _pickAutoBackupTime() async {
    final persistence = ref.read(persistenceServiceProvider);
    final bits = persistence.getAutoBackupTime().split(':');
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.tryParse(bits[0]) ?? 2,
        minute: int.tryParse(bits[1]) ?? 0,
      ),
    );
    if (picked != null) {
      final s =
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      await persistence.setAutoBackupTime(s);
      await ref
          .read(notificationLogicProvider)
          .updateAutoBackupSchedule();
      if (mounted) setState(() {});
    }
  }

  Future<void> _pickBackupFolder() async {
    final path = await FilePicker.platform.getDirectoryPath();
    if (path != null) {
      await ref.read(persistenceServiceProvider).setCustomBackupPath(path);
      if (mounted) setState(() {});
    }
  }

  // ---------- Data management ----------

  Future<void> _exportJson() async {
    setState(() => _isLoading = true);
    try {
      await ref.read(backupServiceProvider).exportDatabase();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _importJson() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (result == null || !mounted) return;
    final file = File(result.files.single.path!);
    final scheme = Theme.of(context).colorScheme;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Import Backup'),
        content: const Text(
          'This will REPLACE all your current data. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: scheme.error),
            child: const Text('Import'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        await ref.read(backupServiceProvider).importDatabase(file);
        // Restored rows carry the backup's userId/lastUpdated — claim them
        // for this user and re-arm the sync cursor or they never sync.
        await ref.read(authServiceProvider).adoptLocalData();
        ref.invalidate(transactionsProvider);
        ref.invalidate(categoriesProvider);
        ref.invalidate(tagsProvider);
        ref.invalidate(accountsProvider);
        ref.invalidate(budgetsProvider);
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  // ---------- Build ----------

  // ---------- PocketBase sync ----------

  Future<void> _showPbServerDialog() async {
    if (!await showPbServerDialog(context, ref)) return;
    await ref.read(notificationLogicProvider).updatePocketBaseSyncSchedule();
    if (mounted) setState(() {});
  }

  Future<void> _syncPocketBase({
    bool full = false,
    bool pull = true,
    bool push = true,
  }) async {
    setState(() => _isLoading = true);
    try {
      final summary =
          await performPocketBaseSync(ref, full: full, pull: pull, push: push);
      if (!mounted) return;
      if (summary != null && summary.pulled > 0) {
        ref.invalidate(transactionsProvider);
        ref.invalidate(categoriesProvider);
        ref.invalidate(tagsProvider);
        ref.invalidate(accountsProvider);
        ref.invalidate(budgetsProvider);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            summary == null ? 'Configure the server URL first' : summary.toString(),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Sync failed: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final persistence = ref.watch(persistenceServiceProvider);

    return SettingsScaffold(
      title: 'Integrations',
      children: [
        SettingsSection(
          title: 'Cloud sync',
          children: [
            SettingsTile(
              icon: Icons.dns_outlined,
              title: 'Server',
              subtitle: persistence.getServerUrl().isEmpty
                  ? 'Not configured'
                  : persistence.getServerUrl(),
              onTap: _showPbServerDialog,
            ),
            SettingsTile(
              icon: Icons.sync,
              iconColor: scheme.primary,
              title: 'Sync now',
              subtitle: persistence.getLastSyncSummary(),
              onTap: _isLoading ? null : () => _syncPocketBase(),
            ),
            SettingsTile(
              icon: Icons.cloud_upload_outlined,
              title: 'Push everything',
              subtitle: 'Upload all local data (categories, tags, wallets, '
                  'transactions, budgets) to the server',
              onTap: _isLoading
                  ? null
                  : () => _syncPocketBase(full: true, pull: false),
            ),
            SettingsTile(
              icon: Icons.cloud_download_outlined,
              title: 'Pull everything',
              subtitle: 'Download all server data to this device',
              onTap: _isLoading
                  ? null
                  : () => _syncPocketBase(full: true, push: false),
            ),
          ],
        ),
        SettingsSection(
          title: 'Google Drive',
          children: [
            if (_googleUser == null)
              SettingsTile(
                icon: Icons.cloud_off_outlined,
                title: 'Connect Google Drive',
                subtitle: 'Cloud backup & restore',
                onTap: _handleGoogleSignIn,
              )
            else ...[
              SettingsTile(
                icon: Icons.cloud_done_outlined,
                iconColor: scheme.primary,
                title: 'Drive Connected',
                subtitle: _googleUser!.email,
                trailing: IconButton(
                  icon: Icon(Icons.logout, color: scheme.error),
                  onPressed: _handleGoogleSignOut,
                ),
              ),
              SettingsTile(
                icon: Icons.upload_outlined,
                title: 'Backup now',
                onTap: _isLoading ? null : _backupToDrive,
              ),
              SettingsTile(
                icon: Icons.download_outlined,
                title: 'Restore from backup',
                onTap: _isLoading ? null : _restoreFromDrive,
              ),
            ],
          ],
        ),
        if (_googleUser != null)
          SettingsSection(
            title: 'Google Sheets',
            children: [
              SettingsTile(
                icon: Icons.table_chart_outlined,
                iconColor: Colors.green,
                title: 'Spreadsheet',
                subtitle: persistence.getSheetsSheetName(),
                onTap: _showSheetsConfigDialog,
              ),
              SettingsTile(
                icon: Icons.sync,
                iconColor: scheme.primary,
                title: 'Sync now',
                subtitle: _lastSyncLabel(
                    persistence.getSheetsLastSyncTimestamp()),
                onTap: _isLoading ? null : _syncSheets,
              ),
            ],
          ),
        if (_googleUser != null)
          SettingsSection(
            title: 'Sincronizzazione email banca',
            children: [
              SettingsTile(
                icon: Icons.email_outlined,
                iconColor: scheme.primary,
                title: 'Sincronizza email Widiba',
                subtitle: 'Crea bozze dalle email di widiba@widiba.it',
                trailing: Switch(
                  value: persistence.getEmailSyncEnabled(),
                  onChanged: (v) async {
                    await persistence.setEmailSyncEnabled(v);
                    await ref
                        .read(notificationLogicProvider)
                        .updateBankSyncSchedule();
                    if (mounted) setState(() {});
                  },
                ),
              ),
              if (persistence.getEmailSyncEnabled()) ...[
                SettingsTile(
                  icon: Icons.date_range_outlined,
                  title: 'Finestra di ricerca',
                  subtitle: '${persistence.getEmailSyncWindowDays()} giorni',
                  onTap: _pickEmailWindow,
                ),
                SettingsTile(
                  icon: Icons.sync,
                  iconColor: scheme.primary,
                  title: 'Sincronizza ora',
                  onTap: _isLoading ? null : _syncEmailsNow,
                ),
              ],
            ],
          ),
        // Outside the Google gate on purpose: reading Revolut's notifications
        // needs Android notification access, not a Google account.
        SettingsSection(
          title: 'Sincronizzazione notifiche banca',
          children: [
            SettingsTile(
              icon: Icons.notifications_active_outlined,
              iconColor: scheme.primary,
              title: 'Sincronizza notifiche Revolut',
              subtitle: 'Crea bozze dalle notifiche push di Revolut',
              trailing: Switch(
                value: persistence.getRevolutSyncEnabled(),
                onChanged: _toggleRevolutSync,
              ),
            ),
            if (persistence.getRevolutSyncEnabled()) ...[
              SettingsTile(
                icon: _notificationAccess
                    ? Icons.verified_user_outlined
                    : Icons.error_outline,
                iconColor: _notificationAccess ? scheme.primary : scheme.error,
                title: 'Accesso alle notifiche',
                subtitle: _notificationAccess
                    ? 'Concesso'
                    : 'Non concesso — tocca per aprire le impostazioni',
                onTap: () =>
                    ref.read(notificationListenerProvider).openSettings(),
              ),
              SettingsTile(
                icon: Icons.sync,
                iconColor: scheme.primary,
                title: 'Leggi notifiche ora',
                onTap: _isLoading ? null : _syncRevolutNow,
              ),
            ],
            // Outside the switch: the CSV works with notification capture off,
            // and it's the only way to get movements from before it was on.
            SettingsTile(
              icon: Icons.upload_file_outlined,
              iconColor: scheme.primary,
              title: 'Importa estratto conto Revolut',
              subtitle: 'Da CSV — crea bozze da rivedere, salta i doppioni',
              onTap: _isLoading ? null : _importRevolutStatement,
            ),
          ],
        ),
        SettingsSection(
          title: 'Auto Backup',
          children: [
            SettingsTile(
              icon: Icons.schedule,
              title: 'Automatic backup',
              subtitle: 'Daily local backup (cloud if connected)',
              trailing: Switch(
                value: persistence.getAutoBackupEnabled(),
                onChanged: (v) async {
                  await persistence.setAutoBackupEnabled(v);
                  await ref
                      .read(notificationLogicProvider)
                      .updateAutoBackupSchedule();
                  if (mounted) setState(() {});
                },
              ),
            ),
            if (persistence.getAutoBackupEnabled()) ...[
              SettingsTile(
                icon: Icons.access_time,
                title: 'Backup time',
                subtitle: persistence.getAutoBackupTime(),
                onTap: _pickAutoBackupTime,
              ),
              SettingsTile(
                icon: Icons.folder_open_outlined,
                title: 'Backup folder',
                subtitle:
                    persistence.getCustomBackupPath() ?? 'Default (Internal)',
                onTap: _pickBackupFolder,
              ),
            ],
          ],
        ),
        SettingsSection(
          title: 'Data Management',
          children: [
            SettingsTile(
              icon: Icons.ios_share,
              title: 'Export backup (JSON)',
              subtitle: 'Local backup file',
              onTap: _isLoading ? null : _exportJson,
            ),
            SettingsTile(
              icon: Icons.settings_backup_restore,
              title: 'Import backup (JSON)',
              subtitle: 'Restore from local file',
              onTap: _isLoading ? null : _importJson,
            ),
          ],
        ),
      ],
    );
  }

  String _lastSyncLabel(int timestamp) {
    if (timestamp == 0) return 'Never synced';
    final d = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return 'Last sync: ${d.day}/${d.month}/${d.year} '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }
}
