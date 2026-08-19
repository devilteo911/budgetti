import 'package:budgetti/core/l10n.dart';
import 'package:budgetti/core/router/app_router.dart';
import 'package:budgetti/core/theme/app_theme.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:budgetti/l10n/app_localizations.dart';
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
import 'package:budgetti/core/services/bank_sync_service.dart';
import 'package:budgetti/core/services/pocketbase_sync_service.dart';
import 'package:google_fonts/google_fonts.dart';
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

        final l10n = await backgroundL10n();
        await notificationService.showBackupNotification(
          success: success,
          message: success ? l10n.notifBackupDone : l10n.notifBackupFailed,
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
      final emailEnabled = persistence.getEmailSyncEnabled();
      final revolutEnabled = persistence.getRevolutSyncEnabled();
      if (!emailEnabled && !revolutEnabled) return Future.value(true);

      final db = AppDatabase();
      final authService = GoogleAuthService();
      final notificationService = NotificationService();

      try {
        await notificationService.init();

        final gmail = GmailService(authService);
        // Drafts must carry the userId the foreground filters by: 'local'
        // pre-login, the PB id after adoptLocalData re-stamps everything —
        // a hardcoded 'local' made bg-captured drafts invisible and broke
        // category matching post-login.
        final uid = persistence.getLocalUserId();
        final sync = BankSyncService(db, gmail, uid.isEmpty ? 'local' : uid);
        final newDrafts = <PendingTransaction>[];

        // The two halves are independent: a Gmail auth failure must not stop
        // the (offline, local) notification drain.
        if (emailEnabled) {
          try {
            await authService.signInSilently();
            newDrafts.addAll(
                await sync.sync(days: persistence.getEmailSyncWindowDays()));
          } catch (e) {
            debugPrint('Error in background gmail sync: $e');
          }
        }
        if (revolutEnabled) {
          try {
            newDrafts.addAll(await sync.syncNotifications());
          } catch (e) {
            debugPrint('Error in background revolut drain: $e');
          }
        }

        // 'skipped' rows are surfaced in the review inbox, not notified.
        for (final draft in newDrafts.where((d) => d.status == 'pending')) {
          await notificationService.showEmailTransactionNotification(
            pendingId: draft.id,
            amount: draft.parsedAmount,
            description: draft.parsedDescription,
            type: draft.suggestedType,
          );
        }
        debugPrint('Bank sync (bg): ${newDrafts.length} new drafts');
      } catch (e) {
        debugPrint('Error in background bank sync: $e');
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
  for (final t in [
    'transactions',
    'accounts',
    'categories',
    'tags',
    'budgets',
    'installments',
  ]) {
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

  // Fonts are bundled in assets/google_fonts — never fetch (or flash a
  // Roboto fallback) at runtime, including first launch offline.
  GoogleFonts.config.allowRuntimeFetching = false;

  // Italian month/day names for DateFormat once the locale is 'it'.
  await initializeDateFormatting();

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

  // Drift only notifies streams about writes made in their own isolate, and the
  // workmanager tasks (bank capture, PocketBase sync) run in another one. So on
  // a warm resume the review inbox and the ledger still showed whatever was
  // there when the app was backgrounded — a Revolut spend captured meanwhile
  // was in the database but invisible until the process was killed and
  // relaunched. Re-run every open query instead.
  // (The listener registers itself with WidgetsBinding, which keeps it alive.)
  AppLifecycleListener(onResume: () => db.markTablesUpdated(db.allTables));

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
    await container.read(notificationLogicProvider).updateBankSyncSchedule();
    await container.read(notificationLogicProvider).updatePocketBaseSyncSchedule();
    // Start the live push: sync to PocketBase on every local data change.
    container.read(pocketBaseAutoSyncProvider);

    // Deep-link notification taps to the review inbox.
    final router = container.read(routerProvider);
    notificationService.onNotificationTap = (_) => router.push('/review-inbox');
    final launchPayload = await notificationService.getLaunchPayload();
    if (launchPayload != null) router.push('/review-inbox');

    // Foreground sync on launch: silently refresh the review inbox (the
    // background task is what fires notifications when the app is closed).
    final persistence = container.read(persistenceServiceProvider);
    if (persistence.getEmailSyncEnabled()) {
      try {
        await container
            .read(bankSyncServiceProvider)
            .sync(days: persistence.getEmailSyncWindowDays());
      } catch (e) {
        debugPrint('Foreground gmail sync failed: $e');
      }
    }
    if (persistence.getRevolutSyncEnabled()) {
      try {
        await container.read(bankSyncServiceProvider).syncNotifications();
      } catch (e) {
        debugPrint('Foreground revolut drain failed: $e');
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
    final localeSettings = ref.watch(localeSettingsProvider);

    // Keep intl (DateFormat) in step with the UI locale. In 'system' mode
    // MaterialApp resolves the platform locale itself; mirror that here.
    final intlLocale = localeSettings.resolve() ??
        (WidgetsBinding.instance.platformDispatcher.locale.languageCode == 'it'
            ? const Locale('it')
            : const Locale('en'));
    Intl.defaultLocale = intlLocale.toString();

    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        // Monet: use the wallpaper-derived scheme when available
        // (Android 12+); other palettes and unsupported platforms
        // fall back to the seed scheme.
        final dynamic = settings.palette == AppPalette.dynamic;
        return MaterialApp.router(
          title: 'Budgetti',
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: localeSettings.resolve(),
          theme: AppTheme.buildTheme(
            palette: settings.palette,
            brightness: Brightness.light,
            dynamicScheme: dynamic ? lightDynamic : null,
          ),
          darkTheme: AppTheme.buildTheme(
            palette: settings.palette,
            brightness: Brightness.dark,
            amoled: settings.amoled,
            dynamicScheme: dynamic ? darkDynamic : null,
          ),
          themeMode: settings.mode,
          routerConfig: router,
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}
