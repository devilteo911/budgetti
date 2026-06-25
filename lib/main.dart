import 'package:budgetti/core/router/app_router.dart';
import 'package:budgetti/core/theme/app_theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
        // Background isolate has no Supabase session; approval re-stamps userId.
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
    return Future.value(true);
  });
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // TODO: Replace with your actual Supabase URL and Anon Key
  await Supabase.initialize(
    url: 'https://weothkvnaixuhmrxyjoo.supabase.co',
    anonKey: 'sb_publishable_8OhKK0gBTYX3qu8ux4nrGw_NerMCfbc',
  );
  
  final prefs = await SharedPreferences.getInstance();
  
  // Must run before runApp: loads timezone data synchronously (tz.initializeTimeZones).
  // Placing it here keeps that blocking work outside the frame measurement window.
  final notificationService = NotificationService();
  await notificationService.init();

  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      notificationServiceProvider.overrideWithValue(notificationService),
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
