import 'package:budgetti/core/providers/providers.dart';
import 'package:budgetti/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _usernameController = TextEditingController();
  bool _isLoading = false;

  Future<void> _submit() async {
    final username = _usernameController.text.trim();
    if (username.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Username must be at least 3 characters')),
      );
      return;
    }

    setState(() => _isLoading = true);
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      // Insert profile into Supabase
      await Supabase.instance.client.from('profiles').insert({
        'id': user.id,
        'username': username,
        'updated_at': DateTime.now().toIso8601String(),
      });

      // Invalidate the provider so Dashboard refetches it
      ref.invalidate(userProfileProvider);

      if (mounted) {
        context.go('/dashboard');
      }
    } catch (e) {
      // Check if duplicate key error
      if (e.toString().contains('duplicate key')) {
         // If duplicate key, it means we already succeeded before but got stuck.
         // Just proceed.
         ref.invalidate(userProfileProvider);
         if (mounted) context.go('/dashboard');
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Who are you?")),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.person_pin, size: 64, color: AppTheme.primaryGreen),
            const SizedBox(height: 24),
            Text(
              "Choose a Username",
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              "Tell us what to call you in the app.",
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textGrey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(
                labelText: "Username",
                prefixIcon: Icon(Icons.alternate_email),
              ),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                child: _isLoading
                    ? const SizedBox(
                        height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text("Get Started"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
