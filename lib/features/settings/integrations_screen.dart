import 'dart:async';
import 'dart:io';

import 'package:budgetti/core/l10n.dart';
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
          SnackBar(content: Text(context.l10n.setGoogleConnected)),
        );
      }
    } catch (e) {
      if (!mounted) return;
      String msg = context.l10n.setSignInFailed(e.toString());
      if (e.toString().contains('cancelled')) {
        msg = context.l10n.setSignInCancelled;
      }
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
          SnackBar(content: Text(context.l10n.setBackupDone)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.setBackupFailed(e.toString()))),
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
          SnackBar(content: Text(context.l10n.setNoBackups)),
        );
        return;
      }
      final selected = await showDialog<drive.File>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(ctx.l10n.setSelectBackup),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: backups.length,
              itemBuilder: (_, i) {
                final f = backups[i];
                return ListTile(
                  title: Text(f.name ?? ctx.l10n.setUnknown),
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
        // Then upload, the same chaser sync-setup's restore path runs:
        // without it the restore leaves the server holding whatever it had
        // while this device believes the backup's state — silent divergence.
        await performPocketBaseSync(ref, full: true, pull: false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.l10n.setRestoreDone)),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.setRestoreFailed(e.toString()))),
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
            content: Text(context.l10n.setSyncFailed(e.toString())),
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
        title: Text(ctx.l10n.setSheetsConfig),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: idCtrl,
              decoration: InputDecoration(
                labelText: ctx.l10n.setSpreadsheetId,
                hintText: ctx.l10n.setSpreadsheetIdHint,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nameCtrl,
              decoration: InputDecoration(
                labelText: ctx.l10n.setSheetName,
                hintText: ctx.l10n.setSheetNameHint,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(ctx.l10n.commonCancel),
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
            child: Text(ctx.l10n.commonSave),
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
          if (drafts > 0) context.l10n.setNewDrafts(drafts),
          if (skipped > 0) context.l10n.setUnreadEmails(skipped),
        ];
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(parts.isEmpty
                ? context.l10n.setNoNewTransactions
                : parts.join(' · ')),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.setEmailSyncFailed(e.toString())),
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
        title: Text(ctx.l10n.setSearchWindow),
        children: [
          for (final d in [7, 30, 90, 180, 365])
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, d),
              child: Text(ctx.l10n.setDaysCount(d)),
            ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, -1),
            child: Text(ctx.l10n.setCustom),
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
        title: Text(ctx.l10n.setDaysToScan),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(suffixText: ctx.l10n.setDaysUnit),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(ctx.l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () {
              final v = int.tryParse(ctrl.text.trim());
              Navigator.pop(ctx, (v != null && v > 0) ? v : null);
            },
            child: Text(ctx.l10n.commonOk),
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
        title: Text(ctx.l10n.setNotificationAccess),
        content: Text(
          ctx.l10n.setNotificationAccessBody,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(ctx.l10n.setLater),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(ctx.l10n.setOpenSettings),
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
          if (drafts > 0) context.l10n.setNewDrafts(drafts),
          if (skipped > 0) context.l10n.setUnreadNotifications(skipped),
        ];
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(parts.isEmpty
                ? _notificationAccess
                    ? context.l10n.setNoNewRevolutNotifications
                    : context.l10n.setNotificationAccessMissing
                : parts.join(' · ')),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.setNotificationReadFailed(e.toString())),
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
        if (r.drafts.isNotEmpty) context.l10n.setCountToReview(r.drafts.length),
        if (r.duplicates > 0) context.l10n.setCountAlreadyPresent(r.duplicates),
        if (r.unreadable > 0) context.l10n.setCountUnreadableRows(r.unreadable),
      ];
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(parts.isEmpty
              ? context.l10n.setNoTransactionsInFile
              : parts.join(' · ')),
          action: r.drafts.isEmpty
              ? null
              : SnackBarAction(
                  label: context.l10n.setReview,
                  onPressed: () => context.push('/review-inbox'),
                ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.setStatementImportFailed(e.toString())),
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
        title: Text(ctx.l10n.setImportBackupTitle),
        content: Text(
          ctx.l10n.setImportBackupBody,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(ctx.l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: scheme.error),
            child: Text(ctx.l10n.setImport),
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
            summary == null ? context.l10n.setConfigureServerFirst : summary.toString(),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.setSyncFailed(e.toString()))));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final persistence = ref.watch(persistenceServiceProvider);

    return SettingsScaffold(
      title: context.l10n.setIntegrations,
      children: [
        SettingsSection(
          title: context.l10n.setCloudSync,
          children: [
            SettingsTile(
              icon: Icons.dns_outlined,
              title: context.l10n.setServer,
              subtitle: persistence.getServerUrl().isEmpty
                  ? context.l10n.setNotConfigured
                  : persistence.getServerUrl(),
              onTap: _showPbServerDialog,
            ),
            SettingsTile(
              icon: Icons.sync,
              iconColor: scheme.primary,
              title: context.l10n.setSyncNow,
              subtitle: persistence.getLastSyncSummary(),
              onTap: _isLoading ? null : () => _syncPocketBase(),
            ),
            SettingsTile(
              icon: Icons.cloud_upload_outlined,
              title: context.l10n.setPushEverything,
              subtitle: context.l10n.setPushEverythingSubtitle,
              onTap: _isLoading
                  ? null
                  : () => _syncPocketBase(full: true, pull: false),
            ),
            SettingsTile(
              icon: Icons.cloud_download_outlined,
              title: context.l10n.setPullEverything,
              subtitle: context.l10n.setPullEverythingSubtitle,
              onTap: _isLoading
                  ? null
                  : () => _syncPocketBase(full: true, push: false),
            ),
          ],
        ),
        SettingsSection(
          title: context.l10n.setGoogleDrive,
          children: [
            if (_googleUser == null)
              SettingsTile(
                icon: Icons.cloud_off_outlined,
                title: context.l10n.setConnectDrive,
                subtitle: context.l10n.setConnectDriveSubtitle,
                onTap: _handleGoogleSignIn,
              )
            else ...[
              SettingsTile(
                icon: Icons.cloud_done_outlined,
                iconColor: scheme.primary,
                title: context.l10n.setDriveConnected,
                subtitle: _googleUser!.email,
                trailing: IconButton(
                  icon: Icon(Icons.logout, color: scheme.error),
                  onPressed: _handleGoogleSignOut,
                ),
              ),
              SettingsTile(
                icon: Icons.upload_outlined,
                title: context.l10n.setBackupNow,
                onTap: _isLoading ? null : _backupToDrive,
              ),
              SettingsTile(
                icon: Icons.download_outlined,
                title: context.l10n.setRestoreFromBackup,
                onTap: _isLoading ? null : _restoreFromDrive,
              ),
            ],
          ],
        ),
        if (_googleUser != null)
          SettingsSection(
            title: context.l10n.setGoogleSheets,
            children: [
              SettingsTile(
                icon: Icons.table_chart_outlined,
                iconColor: Colors.green,
                title: context.l10n.setSpreadsheet,
                subtitle: persistence.getSheetsSheetName(),
                onTap: _showSheetsConfigDialog,
              ),
              SettingsTile(
                icon: Icons.sync,
                iconColor: scheme.primary,
                title: context.l10n.setSyncNow,
                subtitle: _lastSyncLabel(
                    persistence.getSheetsLastSyncTimestamp()),
                onTap: _isLoading ? null : _syncSheets,
              ),
            ],
          ),
        if (_googleUser != null)
          SettingsSection(
            title: context.l10n.setBankEmailSync,
            children: [
              SettingsTile(
                icon: Icons.email_outlined,
                iconColor: scheme.primary,
                title: context.l10n.setSyncWidibaEmail,
                subtitle: context.l10n.setSyncWidibaEmailSubtitle,
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
                  title: context.l10n.setSearchWindow,
                  subtitle: context.l10n
                      .setDaysCount(persistence.getEmailSyncWindowDays()),
                  onTap: _pickEmailWindow,
                ),
                SettingsTile(
                  icon: Icons.sync,
                  iconColor: scheme.primary,
                  title: context.l10n.setSyncNow,
                  onTap: _isLoading ? null : _syncEmailsNow,
                ),
              ],
            ],
          ),
        // Outside the Google gate on purpose: reading Revolut's notifications
        // needs Android notification access, not a Google account.
        SettingsSection(
          title: context.l10n.setBankNotificationSync,
          children: [
            SettingsTile(
              icon: Icons.notifications_active_outlined,
              iconColor: scheme.primary,
              title: context.l10n.setSyncRevolutNotifications,
              subtitle: context.l10n.setSyncRevolutNotificationsSubtitle,
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
                title: context.l10n.setNotificationAccess,
                subtitle: _notificationAccess
                    ? context.l10n.setGranted
                    : context.l10n.setNotGranted,
                onTap: () =>
                    ref.read(notificationListenerProvider).openSettings(),
              ),
              SettingsTile(
                icon: Icons.sync,
                iconColor: scheme.primary,
                title: context.l10n.setReadNotificationsNow,
                onTap: _isLoading ? null : _syncRevolutNow,
              ),
            ],
            // Outside the switch: the CSV works with notification capture off,
            // and it's the only way to get movements from before it was on.
            SettingsTile(
              icon: Icons.upload_file_outlined,
              iconColor: scheme.primary,
              title: context.l10n.setImportRevolutStatement,
              subtitle: context.l10n.setImportRevolutStatementSubtitle,
              onTap: _isLoading ? null : _importRevolutStatement,
            ),
          ],
        ),
        SettingsSection(
          title: context.l10n.setAutoBackup,
          children: [
            SettingsTile(
              icon: Icons.schedule,
              title: context.l10n.setAutoBackupToggle,
              subtitle: context.l10n.setAutoBackupToggleSubtitle,
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
                title: context.l10n.setBackupTime,
                subtitle: persistence.getAutoBackupTime(),
                onTap: _pickAutoBackupTime,
              ),
              SettingsTile(
                icon: Icons.folder_open_outlined,
                title: context.l10n.setBackupFolder,
                subtitle: persistence.getCustomBackupPath() ??
                    context.l10n.setDefaultBackupFolder,
                onTap: _pickBackupFolder,
              ),
            ],
          ],
        ),
        SettingsSection(
          title: context.l10n.setDataManagement,
          children: [
            SettingsTile(
              icon: Icons.ios_share,
              title: context.l10n.setExportBackup,
              subtitle: context.l10n.setExportBackupSubtitle,
              onTap: _isLoading ? null : _exportJson,
            ),
            SettingsTile(
              icon: Icons.settings_backup_restore,
              title: context.l10n.setImportBackup,
              subtitle: context.l10n.setImportBackupSubtitle,
              onTap: _isLoading ? null : _importJson,
            ),
          ],
        ),
      ],
    );
  }

  String _lastSyncLabel(int timestamp) {
    if (timestamp == 0) return context.l10n.setNeverSynced;
    final d = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return context.l10n.setLastSync(
        '${d.day}/${d.month}/${d.year} '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}');
  }
}
