import 'package:budgetti/core/providers/providers.dart';
import 'package:budgetti/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class AuthCheckScreen extends ConsumerWidget {
  const AuthCheckScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider);

    return Scaffold(
      body: Center(
        child: profileAsync.when(
          loading: () => const CircularProgressIndicator(color: AppTheme.primaryGreen),
          data: (profile) {
            // Schedule navigation to avoid "Cannot update during build"
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (profile == null) {
                context.go('/onboarding');
              } else {
                context.go('/dashboard');
              }
            });
            return const CircularProgressIndicator(color: AppTheme.primaryGreen);
          },
          error: (err, stack) => Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cloud_off, size: 64, color: AppTheme.textGrey),
              const SizedBox(height: 16),
              const Text(
                "Connection Error",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                err.toString().contains('PGRST116') ? "Profile missing (Error)" : "Detailed error: $err",
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.textGrey),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => ref.invalidate(userProfileProvider),
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGreen),
                child: const Text("Retry", style: TextStyle(color: Colors.black)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
