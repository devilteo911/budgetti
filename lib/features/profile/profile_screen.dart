import 'package:budgetti/core/providers/providers.dart';
import 'package:budgetti/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:budgetti/features/settings/categories_screen.dart';
import 'package:budgetti/features/settings/tags_screen.dart';
import 'package:budgetti/features/settings/wallets_screen.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:budgetti/core/services/notification_logic.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _isLoading = false;
  bool _permissionMissing = false;

  @override
  void initState() {
    super.initState();
    _checkPermissionStatus();
  }

  Future<void> _checkPermissionStatus() async {
    final granted = await ref
        .read(notificationServiceProvider)
        .isPermissionGranted();
    final enabledInSettings = ref
        .read(persistenceServiceProvider)
        .getNotificationsEnabled();

    if (enabledInSettings && !granted) {
      if (mounted) {
        setState(() => _permissionMissing = true);
      }
    }
  }

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
      
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Currency updated")));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signOut() async {
    setState(() => _isLoading = true);
    await Supabase.instance.client.auth.signOut();
    if (!mounted) return;
    context.go('/login');
  }

  void _showCurrencyPicker(String currentCurrency) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceGrey,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.textGrey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                "Select Currency",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 16),
              ..._currencies.map((c) {
                final isSelected = c['code'] == currentCurrency;
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isSelected ? AppTheme.primaryGreen.withValues(alpha: 0.1) : AppTheme.surfaceGreyLight,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        c['symbol']!,
                        style: TextStyle(
                          color: isSelected ? AppTheme.primaryGreen : Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  title: Text(
                    c['name']!,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  subtitle: Text(c['code']!, style: const TextStyle(color: AppTheme.textGrey)),
                  trailing: isSelected ? const Icon(Icons.check_circle, color: AppTheme.primaryGreen) : null,
                  onTap: () {
                    Navigator.pop(context);
                    _updateCurrency(c['code']);
                  },
                );
              }),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(userProfileProvider);
    final persistence = ref.watch(persistenceServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Profile & Settings"),
      ),
      body: SafeArea(
        child: profileAsync.when(
          loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen)),
          error: (err, stack) => Center(child: Text('Error: $err')),
          data: (profile) {
            final username = profile?['username'] as String? ?? 'User';
            final currency = profile?['currency'] as String? ?? 'EUR';

            return SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Profile Header
                    Center(
                      child: Column(
                        children: [
                          Hero(
                            tag: 'profile-image',
                            child: const CircleAvatar(
                              radius: 50,
                              backgroundColor: AppTheme.surfaceGrey,
                              child: Icon(
                                Icons.person,
                                size: 50,
                                color: AppTheme.primaryGreen,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            username,
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 48),

                    // Settings
                    Text(
                      "Settings",
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppTheme.textGrey,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Manage Accounts
                    InkWell(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const WalletsScreen(),
                        ),
                      ),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceGrey,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Manage Accounts",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                            ),
                            Icon(
                              Icons.arrow_forward_ios,
                              color: AppTheme.textGrey,
                              size: 16,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Manage Categories
                    InkWell(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const CategoriesScreen(),
                        ),
                      ),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceGrey,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Manage Categories",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                            ),
                            Icon(
                              Icons.arrow_forward_ios,
                              color: AppTheme.textGrey,
                              size: 16,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Manage Tags
                    InkWell(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const TagsScreen()),
                      ),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceGrey,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Manage Tags",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                            ),
                            Icon(
                              Icons.arrow_forward_ios,
                              color: AppTheme.textGrey,
                              size: 16,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Currency Selector
                    InkWell(
                      onTap: () => _showCurrencyPicker(currency),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceGrey,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "Currency",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                            ),
                            Row(
                              children: [
                                Text(
                                  currency,
                                  style: const TextStyle(
                                    color: AppTheme.primaryGreen,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(
                                  Icons.keyboard_arrow_down,
                                  color: AppTheme.textGrey,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Notifications Settings
                    Text(
                      "Notifications",
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppTheme.textGrey,
                      ),
                    ),
                    const SizedBox(height: 16),

                    if (_permissionMissing)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: InkWell(
                          onTap: () async {
                            final granted = await ref
                                .read(notificationServiceProvider)
                                .requestPermissions();
                            if (granted) {
                              setState(() => _permissionMissing = false);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.orange.withValues(alpha: 0.5),
                              ),
                            ),
                            child: const Row(
                              children: [
                                Icon(
                                  Icons.warning_amber_rounded,
                                  color: Colors.orange,
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    "Notification permissions are not granted. Tap to fix.",
                                    style: TextStyle(
                                      color: Colors.orange,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                    _buildNotificationToggle(
                      "Push Notifications",
                      "Enable or disable all notifications",
                      Icons.notifications,
                      persistence.getNotificationsEnabled(),
                      (value) async {
                        try {
                          if (value) {
                            final granted = await ref
                                .read(notificationServiceProvider)
                                .requestPermissions();
                            if (!granted) {
                              setState(() => _permissionMissing = true);
                              return;
                            }
                            setState(() => _permissionMissing = false);
                          }
                          await persistence.setNotificationsEnabled(value);
                          if (mounted) setState(() {});
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text("Error: $e")),
                            );
                          }
                        }
                      },
                    ),
                    const SizedBox(height: 12),

                    _buildNotificationToggle(
                      "Budget Alerts",
                      "Notify when reaching budget limits",
                      Icons.account_balance,
                      persistence.getBudgetAlertsEnabled(),
                      (value) async {
                        try {
                          await persistence.setBudgetAlertsEnabled(value);
                          if (mounted) setState(() {});
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text("Error: $e")),
                            );
                          }
                        }
                      },
                    ),
                    const SizedBox(height: 12),

                    _buildNotificationToggle(
                      "Daily Reminder",
                      "Remind me to log expenses daily",
                      Icons.today,
                      persistence.getDailyReminderEnabled(),
                      (value) async {
                        try {
                          await persistence.setDailyReminderEnabled(value);
                          await ref
                              .read(notificationLogicProvider)
                              .updateDailyReminder();
                          if (mounted) setState(() {});
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text("Error: $e")),
                            );
                          }
                        }
                      },
                    ),

                    if (persistence.getDailyReminderEnabled()) ...[
                      const SizedBox(height: 12),
                      InkWell(
                        onTap: () async {
                          final timeStr = persistence.getDailyReminderTime();
                          final bits = timeStr.split(":");
                          final initialTime = TimeOfDay(
                            hour: int.tryParse(bits[0]) ?? 20,
                            minute: int.tryParse(bits[1]) ?? 0,
                          );

                          final pickedTime = await showTimePicker(
                            context: context,
                            initialTime: initialTime,
                            builder: (context, child) {
                              return Theme(
                                data: Theme.of(context).copyWith(
                                  colorScheme: const ColorScheme.dark(
                                    primary: AppTheme.primaryGreen,
                                    onPrimary: AppTheme.backgroundBlack,
                                    surface: AppTheme.surfaceGrey,
                                    onSurface: Colors.white,
                                  ),
                                ),
                                child: child!,
                              );
                            },
                          );

                          if (pickedTime != null) {
                            final newTimeStr =
                                "${pickedTime.hour.toString().padLeft(2, '0')}:${pickedTime.minute.toString().padLeft(2, '0')}";
                            try {
                              await persistence.setDailyReminderTime(
                                newTimeStr,
                              );
                              await ref
                                  .read(notificationLogicProvider)
                                  .updateDailyReminder();
                              if (mounted) setState(() {});
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      "Error updating reminder: $e",
                                    ),
                                  ),
                                );
                              }
                            }
                          }
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceGrey,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                "Reminder Time",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                persistence.getDailyReminderTime(),
                                style: const TextStyle(
                                  color: AppTheme.primaryGreen,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 32),

                    // Data Management
                    Text(
                      "Data Management",
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppTheme.textGrey,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Sync with Supabase
                    // Import from Cloud
                    InkWell(
                      onTap: _isLoading
                          ? null
                          : () async {
                              setState(() => _isLoading = true);
                              try {
                                await ref
                                    .read(syncServiceProvider)
                                    .importFromCloud();
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        "Import completed successfully",
                                      ),
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text("Import failed: $e"),
                                    ),
                                  );
                                }
                              } finally {
                                if (context.mounted) {
                                  setState(() => _isLoading = false);
                                }
                              }
                            },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceGrey,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Import from Cloud",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                            ),
                            Icon(
                              Icons.cloud_download,
                              color: AppTheme.primaryGreen,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Export to Cloud
                    InkWell(
                      onTap: _isLoading
                          ? null
                          : () async {
                              setState(() => _isLoading = true);
                              try {
                                await ref
                                    .read(syncServiceProvider)
                                    .exportToCloud();
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        "Export completed successfully",
                                      ),
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text("Export failed: $e"),
                                    ),
                                  );
                                }
                              } finally {
                                if (context.mounted) {
                                  setState(() => _isLoading = false);
                                }
                              }
                            },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceGrey,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Export to Cloud",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                            ),
                            Icon(
                              Icons.cloud_upload,
                              color: AppTheme.primaryGreen,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Export Backup
                    InkWell(
                      onTap: _isLoading
                          ? null
                          : () async {
                              setState(() => _isLoading = true);
                              try {
                                await ref
                                    .read(backupServiceProvider)
                                    .exportDatabase();
                              } catch (e) {
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text("Backup failed: $e")),
                                );
                              } finally {
                                if (mounted) setState(() => _isLoading = false);
                              }
                            },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceGrey,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Export Backup (JSON)",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                            ),
                            Icon(
                              Icons.download,
                              color: AppTheme.primaryGreen,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 48),

                    // Sign Out
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: _isLoading ? null : _signOut,
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.red),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text(
                          "Sign Out",
                          style: TextStyle(color: Colors.red, fontSize: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildNotificationToggle(
    String title,
    String subtitle,
    IconData icon,
    bool value,
    Function(bool) onChanged,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceGrey,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.primaryGreen, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppTheme.textGrey,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppTheme.primaryGreen,
            activeTrackColor: AppTheme.primaryGreen.withValues(alpha: 0.3),
            inactiveThumbColor: AppTheme.textGrey,
            inactiveTrackColor: AppTheme.surfaceGreyLight,
          ),
        ],
      ),
    );
  }
}
