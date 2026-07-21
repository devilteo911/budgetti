import 'package:budgetti/core/providers/providers.dart';
import 'package:budgetti/core/widgets/pb_server_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketbase/pocketbase.dart' as pb;

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _submit() async {
    setState(() => _isLoading = true);
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    try {
      // Account is pre-created in PocketBase; this is the only login per
      // device. The router redirect (refreshed by the auth notifier) takes
      // over navigation to onboarding/dashboard on success.
      await ref.read(authServiceProvider).login(email, password);
    } on pb.ClientException catch (e) {
      final msg = (e.response['message'] as String?) ?? 'Login failed';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } catch (e, st) {
      debugPrint('login: unexpected error: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cannot reach server. Check the URL in Settings > Integrations.'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final serverUrl = ref.watch(persistenceServiceProvider).getServerUrl();
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(Icons.wallet, size: 64, color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 24),
                Text(
                  "Budgetti",
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  "Manage your finances like a pro",
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),

                // Email
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: "Email",
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                ),
                const SizedBox(height: 16),

                // Password
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: "Password",
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                ),
                const SizedBox(height: 32),

                // Action Button
                ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  child: _isLoading
                      ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Theme.of(context).colorScheme.onPrimary),
                        )
                      : const Text("Log In"),
                ),

                // Reachable before login on purpose: with no server stored,
                // every login attempt fails, and Settings > Integrations is
                // behind the gate this would open.
                TextButton(
                  onPressed: _isLoading
                      ? null
                      : () async {
                          if (await showPbServerDialog(context, ref) &&
                              mounted) {
                            setState(() {});
                          }
                        },
                  child: Text(
                    serverUrl.isEmpty ? 'Set server' : serverUrl,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
