import 'package:budgetti/core/router/app_router.dart';
import 'package:budgetti/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:budgetti/core/services/notification_service.dart';
import 'package:budgetti/core/providers/providers.dart';
import 'package:budgetti/core/services/notification_logic.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // TODO: Replace with your actual Supabase URL and Anon Key
  await Supabase.initialize(
    url: 'https://weothkvnaixuhmrxyjoo.supabase.co',
    anonKey: 'sb_publishable_8OhKK0gBTYX3qu8ux4nrGw_NerMCfbc',
  );
  
  final prefs = await SharedPreferences.getInstance();
  
  final notificationService = NotificationService();
  await notificationService.init();


  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      notificationServiceProvider.overrideWithValue(notificationService),
    ],
  );

  // Schedule daily reminder on startup
  await container.read(notificationLogicProvider).updateDailyReminder();

  runApp(
    UncontrolledProviderScope(container: container,
      child: const BudgettiApp(),
    ),
  );
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
