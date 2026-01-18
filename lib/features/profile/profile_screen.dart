import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;

import 'package:budgetti/core/providers/providers.dart';
import 'package:budgetti/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:budgetti/features/settings/categories_screen.dart';
import 'package:budgetti/features/settings/tags_screen.dart';
import 'package:budgetti/features/settings/wallets_screen.dart';
import 'package:budgetti/features/import/import_transactions_screen.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:budgetti/core/services/notification_logic.dart';
import 'package:budgetti/core/services/persistence_service.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _isLoading = false;
  bool _permissionMissing = false;
  GoogleSignInAccount? _googleUser;
  StreamSubscription<GoogleSignInAccount?>? _googleUserSubscription;

  @override
  void initState() {
    super.initState();
    _checkPermissionStatus();
    _initializeGoogleDriveState();
  }

  void _initializeGoogleDriveState() {
    final driveService = ref.read(googleDriveServiceProvider);

    // CRITICAL FIX: Set initial state from current user (if already signed in)
    _googleUser = driveService.currentUser;

    // Listen to future changes
    _googleUserSubscription = driveService.onCurrentUserChanged.listen((user) {
      if (mounted) {
        setState(() {
          _googleUser = user;
        });
        debugPrint('Google Drive user state changed: ${user?.email ?? "signed out"}');
      }
    });

    // Attempt silent sign-in if not already signed in
    if (_googleUser == null) {
      driveService.signInSilently();
    }
  }

  @override
  void dispose() {
    _googleUserSubscription?.cancel();
    super.dispose();
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

  Future<void> _handleGoogleSignIn() async {
    try {
      final driveService = ref.read(googleDriveServiceProvider);
      await driveService.signIn();

      // CRITICAL FIX: Immediately update local state after successful sign-in
      // This ensures the UI updates right away, even if the stream hasn't emitted yet
      if (mounted) {
        setState(() {
          _googleUser = driveService.currentUser;
        });

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(
          const SnackBar(
            content: Text('Successfully connected to Google Drive'),
            backgroundColor: AppTheme.primaryGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = 'Sign in failed';
        final errorString = e.toString();

        if (errorString.contains('apiException: 10') ||
            errorString.contains('DEVELOPER_ERROR')) {
          errorMessage =
              'Google Sign-In is not configured. Please check the setup guide (GOOGLE_DRIVE_SETUP.md) for instructions.';
        } else if (errorString.contains('cancelled')) {
          errorMessage = 'Sign-in was cancelled';
        } else if (errorString.contains('network')) {
          errorMessage = 'Network error. Check your internet connection.';
        } else {
          errorMessage = 'Sign in failed: ${e.toString()}';
        }

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
            action: errorString.contains('apiException: 10')
                ? SnackBarAction(
                    label: 'Help',
                    textColor: Colors.white,
                    onPressed: () {
                      // Could open the setup documentation or show a dialog
                    },
                  )
                : null,
          ),
        );
      }
    }
  }

  Future<void> _handleGoogleSignOut() async {
    await ref.read(googleDriveServiceProvider).signOut();

    // Update local state immediately after sign-out
    if (mounted) {
      setState(() {
        _googleUser = null;
      });
    }
  }

  Future<void> _backupToDrive() async {
    setState(() => _isLoading = true);
    try {
      await ref.read(backupServiceProvider).backupToDrive();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Backup successful')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Backup failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _restoreFromDrive() async {
    setState(() => _isLoading = true);
    try {
      final driveService = ref.read(googleDriveServiceProvider);
      final backups = await driveService.listBackups();

      if (!mounted) return;

      if (backups.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('No backups found')));
        return;
      }

      // Show dialog to pick backup
      final selectedFile = await showDialog<drive.File>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppTheme.surfaceGrey,
          title: const Text(
            'Select Backup',
            style: TextStyle(color: Colors.white),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: backups.length,
              itemBuilder: (context, index) {
                final file = backups[index];
                return ListTile(
                  title: Text(
                    file.name ?? 'Unknown',
                    style: const TextStyle(color: Colors.white),
                  ),
                  subtitle: Text(
                    file.createdTime?.toString() ?? '',
                    style: const TextStyle(color: AppTheme.textGrey),
                  ),
                  onTap: () => Navigator.pop(context, file),
                );
              },
            ),
          ),
        ),
      );

      if (selectedFile != null && selectedFile.id != null) {
        await ref
            .read(backupServiceProvider)
            .restoreFromDrive(selectedFile.id!);
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Restore successful')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Restore failed: $e')));
      }
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

  Widget _buildOcrSettings(PersistenceService persistence) {
    final currentEngine = persistence.getOcrEngine();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () {
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
                        "Receipt Scanning Engine",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ListTile(
                        title: const Text(
                          "Google MLKit (Default)",
                          style: TextStyle(color: Colors.white),
                        ),
                        subtitle: const Text(
                          "Fast, reliable, standard accuracy",
                          style: TextStyle(color: AppTheme.textGrey),
                        ),
                        trailing: currentEngine == 'google_mlkit'
                            ? const Icon(
                                Icons.check_circle,
                                color: AppTheme.primaryGreen,
                              )
                            : null,
                        onTap: () async {
                          await persistence.setOcrEngine('google_mlkit');
                          if (mounted) {
                            Navigator.pop(context);
                            setState(() {});
                          }
                        },
                      ),
                      ListTile(
                        title: const Text(
                          "Ente Mobile OCR",
                          style: TextStyle(color: Colors.white),
                        ),
                        subtitle: const Text(
                          "Advanced (Experimental), higher accuracy",
                          style: TextStyle(color: AppTheme.textGrey),
                        ),
                        trailing: currentEngine == 'mobile_ocr'
                            ? const Icon(
                                Icons.check_circle,
                                color: AppTheme.primaryGreen,
                              )
                            : null,
                        onTap: () async {
                          await persistence.setOcrEngine('mobile_ocr');
                          if (mounted) {
                            Navigator.pop(context);
                            setState(() {});
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                );
              },
            );
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: AppTheme.surfaceGrey,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Receipt Scanner",
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
                Row(
                  children: [
                    Text(
                      currentEngine == 'mobile_ocr'
                          ? "Ente Mobile OCR"
                          : "Google MLKit",
                      style: TextStyle(
                        color: currentEngine == 'mobile_ocr'
                            ? Colors.orangeAccent
                            : AppTheme.primaryGreen,
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
      ],
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
                    const SizedBox(height: 16),

                    // Receipt Scanning Engine Helper
                    _buildOcrSettings(persistence),

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

                    // Google Drive Backup
                    Text(
                      "Google Drive Backup",
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppTheme.textGrey,
                      ),
                    ),
                    const SizedBox(height: 16),

                    if (_googleUser == null)
                      InkWell(
                        onTap: _handleGoogleSignIn,
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
                                "Connect Google Drive",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                ),
                              ),
                              Icon(
                                Icons.add_to_drive,
                                color: AppTheme.primaryGreen,
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      )
                    else ...[
                      // User Info & Disconnect
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceGrey,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.primaryGreen),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.check_circle,
                              color: AppTheme.primaryGreen,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "Connected",
                                    style: TextStyle(
                                      color: AppTheme.primaryGreen,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  if (_googleUser!.email.isNotEmpty)
                                    Text(
                                      _googleUser!.email,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: _handleGoogleSignOut,
                              icon: const Icon(Icons.logout, color: Colors.red),
                              tooltip: 'Disconnect',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Backup & Restore Actions
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: _isLoading ? null : _backupToDrive,
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.surfaceGrey,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  children: [
                                    const Icon(
                                      Icons.cloud_upload,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(height: 8),
                                    const Text(
                                      "Backup",
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: InkWell(
                              onTap: _isLoading ? null : _restoreFromDrive,
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.surfaceGrey,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  children: [
                                    const Icon(
                                      Icons.cloud_download,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(height: 8),
                                    const Text(
                                      "Restore",
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
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
                    const SizedBox(height: 16),

                    // Import Backup
                    InkWell(
                      onTap: _isLoading
                          ? null
                          : () async {
                              try {
                                final result = await FilePicker.platform
                                    .pickFiles(
                                      type: FileType.custom,
                                      allowedExtensions: ['json'],
                                    );

                                if (result != null && context.mounted) {
                                  final file = File(result.files.single.path!);

                                  // Confirm
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      backgroundColor: AppTheme.surfaceGrey,
                                      title: const Text(
                                        "Import Backup",
                                        style: TextStyle(color: Colors.white),
                                      ),
                                      content: const Text(
                                        "This will REPLACE all your current data with the backup. This action cannot be undone.\n\nAre you sure?",
                                        style: TextStyle(color: Colors.white70),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context, false),
                                          child: const Text("Cancel"),
                                        ),
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context, true),
                                          child: const Text(
                                            "Import",
                                            style: TextStyle(color: Colors.red),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );

                                  if (confirm == true) {
                                    setState(() => _isLoading = true);
                                    await ref
                                        .read(backupServiceProvider)
                                        .importDatabase(file);

                                    // Invalidate providers to refresh UI
                                    ref.invalidate(transactionsProvider);
                                    ref.invalidate(categoriesProvider);
                                    ref.invalidate(tagsProvider);
                                    ref.invalidate(accountsProvider);
                                    ref.invalidate(budgetsProvider);

                                    if (context.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            "Backup imported successfully",
                                          ),
                                        ),
                                      );
                                    }
                                  }
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
                              "Import Backup (JSON)",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                            ),
                            Icon(
                              Icons.restore,
                              color: AppTheme.primaryGreen,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Import Quicken (QIF)
                    InkWell(
                      onTap: _isLoading
                          ? null
                          : () async {
                              try {
                                final result = await FilePicker.platform
                                    .pickFiles(type: FileType.any);

                                if (result != null && context.mounted) {
                                  final file = File(result.files.single.path!);

                                  // Basic extension check
                                  if (!file.path.toLowerCase().endsWith(
                                    '.qif',
                                  )) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          "Please select a .qif file",
                                        ),
                                      ),
                                    );
                                    return;
                                  }

                                  setState(() => _isLoading = true);

                                  try {
                                    final transactions = await ref
                                        .read(importServiceProvider)
                                        .parseQifFile(file);

                                    if (context.mounted) {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              ImportTransactionsScreen(
                                                transactions: transactions,
                                              ),
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            "Error parsing file: $e",
                                          ),
                                        ),
                                      );
                                    }
                                  } finally {
                                    if (mounted) {
                                      setState(() => _isLoading = false);
                                    }
                                  }
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text("Error picking file: $e"),
                                    ),
                                  );
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
                              "Import Quicken (QIF)",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                            ),
                            Icon(
                              Icons.file_upload,
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
            activeThumbColor: AppTheme.primaryGreen,
            activeTrackColor: AppTheme.primaryGreen.withValues(alpha: 0.3),
            inactiveThumbColor: AppTheme.textGrey,
            inactiveTrackColor: AppTheme.surfaceGreyLight,
          ),
        ],
      ),
    );
  }
}
