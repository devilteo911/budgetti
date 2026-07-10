import 'dart:async';
import 'dart:io';

import 'package:budgetti/core/providers/providers.dart';
import 'package:budgetti/core/services/notification_logic.dart';
import 'package:budgetti/features/settings/widgets/settings_scaffold.dart';
import 'package:budgetti/features/settings/widgets/settings_section.dart';
import 'package:budgetti/features/settings/widgets/settings_tile.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;

class IntegrationsScreen extends ConsumerStatefulWidget {
  const IntegrationsScreen({super.key});

  @override
  ConsumerState<IntegrationsScreen> createState() => _IntegrationsScreenState();
}

class _IntegrationsScreenState extends ConsumerState<IntegrationsScreen> {
  bool _isLoading = false;
  GoogleSignInAccount? _googleUser;
  StreamSubscription<GoogleSignInAccount?>? _googleUserSubscription;

  @override
  void initState() {
    super.initState();
    _initializeGoogleDriveState();
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
          .read(emailSyncServiceProvider)
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
    final persistence = ref.read(persistenceServiceProvider);
    final ctrl = TextEditingController(text: persistence.getServerUrl());
    final url = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('PocketBase server'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
              hintText: 'http://100.64.0.1:8090'),
          keyboardType: TextInputType.url,
          autocorrect: false,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (url != null) {
      await persistence.setServerUrl(url);
      await ref
          .read(notificationLogicProvider)
          .updatePocketBaseSyncSchedule();
      if (mounted) setState(() {});
    }
  }

  Future<void> _syncPocketBase() async {
    setState(() => _isLoading = true);
    try {
      final summary = await performPocketBaseSync(ref);
      if (!mounted) return;
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
              onTap: _isLoading ? null : _syncPocketBase,
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
                        .updateGmailSyncSchedule();
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
