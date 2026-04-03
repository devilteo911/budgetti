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
  });
}

class BudgettiApp extends ConsumerWidget {
  const BudgettiApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Budgetti',
      theme: AppTheme.darkTheme,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
