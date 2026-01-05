import 'package:budgetti/core/providers/providers.dart';
import 'package:budgetti/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:budgetti/features/settings/categories_screen.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _isLoading = false;

  final List<Map<String, String>> _currencies = [
    {'code': 'EUR', 'symbol': '€', 'name': 'Euro'},
    {'code': 'USD', 'symbol': '\$', 'name': 'US Dollar'},
    {'code': 'GBP', 'symbol': '£', 'name': 'British Pound'},
    {'code': 'JPY', 'symbol': '¥', 'name': 'Japanese Yen'},
  ];

  Future<void> _updateCurrency(String? newCurrency) async {
    if (newCurrency == null) return;
    
    setState(() => _isLoading = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      await Supabase.instance.client.from('profiles').update({
        'currency': newCurrency,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', user.id);

      ref.invalidate(userProfileProvider);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content: Text("Currency updated")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text("Error: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signOut() async {
    setState(() => _isLoading = true);
    await Supabase.instance.client.auth.signOut();
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(userProfileProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Profile & Settings"),
        backgroundColor: AppTheme.backgroundBlack,
      ),
      body: SafeArea(
        child: profileAsync.when(
          loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen)),
          error: (err, stack) => Center(child: Text('Error: $err')),
          data: (profile) {
            final username = profile?['username'] as String? ?? 'User';
            final currency = profile?['currency'] as String? ?? 'EUR';

            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Profile Header
                  Center(
                    child: Column(
                      children: [
                        const CircleAvatar(
                          radius: 50,
                          backgroundColor: AppTheme.surfaceGrey,
                          child: Icon(Icons.person, size: 50, color: AppTheme.primaryGreen),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          username,
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 48),

                  // Settings
                  Text("Settings", style: Theme.of(context).textTheme.titleLarge?.copyWith(color: AppTheme.textGrey)),
                  const SizedBox(height: 16),

                  // Manage Categories
                  InkWell(
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CategoriesScreen())),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceGrey,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("Manage Categories", style: TextStyle(color: Colors.white, fontSize: 16)),
                          Icon(Icons.arrow_forward_ios, color: AppTheme.textGrey, size: 16),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Currency Dropdown
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceGrey,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Currency", style: TextStyle(color: Colors.white, fontSize: 16)),
                        DropdownButton<String>(
                          value: currency,
                          dropdownColor: AppTheme.surfaceGrey,
                          underline: const SizedBox(),
                          icon: const Icon(Icons.arrow_drop_down, color: AppTheme.primaryGreen),
                          style: const TextStyle(color: Colors.white, fontSize: 16),
                          items: _currencies.map((c) {
                            return DropdownMenuItem(
                              value: c['code'],
                              child: Text("${c['symbol']}  ${c['code']} (${c['name']})"),
                            );
                          }).toList(),
                          onChanged: _isLoading ? null : _updateCurrency,
                        ),
                      ],
                    ),
                  ),

                  const Spacer(),
                  
                  // Sign Out
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _isLoading ? null : _signOut,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text("Sign Out", style: TextStyle(color: Colors.red, fontSize: 16)),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
