import 'package:budgetti/core/router/app_router.dart';
import 'package:budgetti/core/theme/app_theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:budgetti/core/services/notification_service.dart';
import 'package:budgetti/core/providers/providers.dart';
import 'package:budgetti/core/services/notification_logic.dart';
import 'package:workmanager/workmanager.dart';
import 'package:budgetti/core/database/database.dart';
import 'package:budgetti/core/services/backup_service.dart';
import 'package:budgetti/core/services/google_auth_service.dart';
import 'package:budgetti/core/services/google_drive_service.dart';
import 'package:budgetti/core/services/persistence_service.dart';
import 'package:budgetti/core/services/gmail_service.dart';
import 'package:budgetti/core/services/email_sync_service.dart';
import 'package:budgetti/core/services/pocketbase_sync_service.dart';
import 'package:pocketbase/pocketbase.dart' as pb;

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task == NotificationLogic.AUTO_BACKUP_TASK) {
      final prefs = await SharedPreferences.getInstance();
      final persistence = PersistenceService(prefs);
      final db = AppDatabase();
      final authService = GoogleAuthService();
      final driveService = GoogleDriveService(authService);
      final backupService = BackupService(db, driveService, authService);
      final notificationService = NotificationService();
      
      try {
        await notificationService.init();
        await notificationService.showBackupNotification(success: true, isProgress: true);

        final success = await backupService.performAutoBackup(persistence);
        
        await notificationService.showBackupNotification(
          success: success, 
          message: success ? "Auto-backup completed successfully." : "Auto-backup failed. Check settings.",
        );
      } catch (e) {
        debugPrint('Error in background backup task: $e');
        await notificationService.showBackupNotification(success: false, message: "Error: $e");
      } finally {
        await db.close();
      }
    }

    if (task == NotificationLogic.GMAIL_SYNC_TASK) {
      final prefs = await SharedPreferences.getInstance();
      final persistence = PersistenceService(prefs);
      if (!persistence.getEmailSyncEnabled()) return Future.value(true);

      final db = AppDatabase();
      final authService = GoogleAuthService();
      final notificationService = NotificationService();

      try {
        await authService.signInSilently();
        await notificationService.init();

        final gmail = GmailService(authService);
        // Background isolate has no auth session; approval re-stamps userId.
        final sync = EmailSyncService(db, gmail, 'local');

        final newDrafts =
            await sync.sync(days: persistence.getEmailSyncWindowDays());

        // 'skipped' rows are surfaced in the review inbox, not notified.
        for (final draft in newDrafts.where((d) => d.status == 'pending')) {
          await notificationService.showEmailTransactionNotification(
            pendingId: draft.id,
            amount: draft.parsedAmount,
            description: draft.parsedDescription,
            type: draft.suggestedType,
          );
        }
        debugPrint('Gmail sync (bg): ${newDrafts.length} new drafts');
      } catch (e) {
        debugPrint('Error in background gmail sync: $e');
      } finally {
        await db.close();
      }
    }

    if (task == NotificationLogic.PB_SYNC_TASK) {
      final prefs = await SharedPreferences.getInstance();
      final persistence = PersistenceService(prefs);
      if (persistence.getServerUrl().isEmpty) return Future.value(true);

      final db = AppDatabase();
      try {
        final store = pb.AsyncAuthStore(
          save: persistence.setPbAuth,
          initial: persistence.getPbAuth(),
        );
        final client = PocketBaseSyncClient(
          pb.PocketBase(persistence.getServerUrl(), authStore: store),
        );
        final service =
            PocketBaseSyncService(client, db, persistence, client.userId);
        final summary = await service.sync();
        debugPrint('PocketBase sync (bg): $summary');
      } catch (e) {
        debugPrint('Error in background pb sync: $e');
      } finally {
        await db.close();
      }
    }
    return Future.value(true);
  });
}

/// Resolve the per-install local user id before the UI renders, so the Drift
/// `userId` filter (used by FinanceService) is never empty. On first Phase-3
/// launch this adopts the userId already present on existing (legacy) rows; a
/// later PocketBase login unifies everything to the PB auth id.
Future<void> _resolveLocalUserId(
    AppDatabase db, PersistenceService persistence) async {
  if (persistence.getLocalUserId().isNotEmpty) return;
  for (final t
      in ['transactions', 'accounts', 'categories', 'tags', 'budgets']) {
    final rows = await db.customSelect(
      'SELECT DISTINCT user_id FROM $t WHERE user_id IS NOT NULL LIMIT 1',
    ).get();
    if (rows.isNotEmpty) {
      await persistence.setLocalUserId(rows.first.read<String>('user_id'));
      return;
    }
  }
  await persistence.setLocalUserId('local');
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();

  // Must run before runApp: loads timezone data synchronously (tz.initializeTimeZones).
  // Placing it here keeps that blocking work outside the frame measurement window.
  final notificationService = NotificationService();
  await notificationService.init();

  final db = AppDatabase();
  final persistence = PersistenceService(prefs);
  await _resolveLocalUserId(db, persistence);

  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      notificationServiceProvider.overrideWithValue(notificationService),
      databaseProvider.overrideWithValue(db),
    ],
  );

  runApp(
    UncontrolledProviderScope(container: container,
      child: const BudgettiApp(),
    ),
  );

  // Defer all non-critical post-init work to after first frame
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    final granted = await notificationService.isPermissionGranted();
    if (!granted && prefs.getBool('notifications_enabled') != false) {
      await notificationService.requestPermissions();
    }

    // Run reminder update and workmanager init concurrently
    await Future.wait([
      container.read(notificationLogicProvider).updateDailyReminder(),
      Workmanager().initialize(callbackDispatcher, isInDebugMode: kDebugMode),
    ]);
    await container.read(notificationLogicProvider).updateAutoBackupSchedule();
    await container.read(notificationLogicProvider).updateGmailSyncSchedule();
    await container.read(notificationLogicProvider).updatePocketBaseSyncSchedule();

    // Deep-link notification taps to the review inbox.
    final router = container.read(routerProvider);
    notificationService.onNotificationTap = (_) => router.push('/review-inbox');
    final launchPayload = await notificationService.getLaunchPayload();
    if (launchPayload != null) router.push('/review-inbox');

    // Foreground sync on launch: silently refresh the review inbox (the
    // background task is what fires notifications when the app is closed).
    if (prefs.getBool('email_sync_enabled') == true) {
      try {
        await container.read(emailSyncServiceProvider).sync(
              days: container
                  .read(persistenceServiceProvider)
                  .getEmailSyncWindowDays(),
            );
      } catch (e) {
        debugPrint('Foreground gmail sync failed: $e');
      }
    }

    // Foreground PocketBase sync on launch (silently; background handles the
    // daily cadence). Only when a server is configured.
    if (container.read(persistenceServiceProvider).getServerUrl().isNotEmpty) {
      debugPrint('main: starting foreground PocketBase sync');
      try {
        final summary = await container.read(pocketBaseSyncServiceProvider).sync();
        debugPrint('main: foreground sync -> $summary');
      } catch (e) {
        debugPrint('Foreground PocketBase sync failed: $e');
      }
    }
  });
}

class BudgettiApp extends ConsumerWidget {
  const BudgettiApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final settings = ref.watch(themeSettingsProvider);

    return MaterialApp.router(
      title: 'Budgetti',
      theme: AppTheme.buildTheme(
        palette: settings.palette,
        brightness: Brightness.light,
      ),
      darkTheme: AppTheme.buildTheme(
        palette: settings.palette,
        brightness: Brightness.dark,
        amoled: settings.amoled,
      ),
      themeMode: settings.mode,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
