import 'package:budgetti/core/router/app_router.dart';
import 'package:budgetti/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // TODO: Replace with your actual Supabase URL and Anon Key
  await Supabase.initialize(
    url: 'https://weothkvnaixuhmrxyjoo.supabase.co',
    anonKey: 'sb_publishable_8OhKK0gBTYX3qu8ux4nrGw_NerMCfbc',
  );

  runApp(const ProviderScope(child: BudgettiApp()));
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
