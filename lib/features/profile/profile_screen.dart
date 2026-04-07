import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
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
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _isLoading = false;
  bool _isBankSyncing = false;
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
    final authService = ref.read(googleAuthServiceProvider);

    // CRITICAL FIX: Set initial state from current user (if already signed in)
    _googleUser = authService.currentUser;

    // Listen to future changes
    _googleUserSubscription = authService.onCurrentUserChanged.listen((user) {
      if (mounted) {
        setState(() {
          _googleUser = user;
        });
        debugPrint('Google user state changed: ${user?.email ?? "signed out"}');
      }
    });

    // Attempt silent sign-in if not already signed in
    if (_googleUser == null) {
      authService.signInSilently();
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

  Future<void> _pickAndUploadAvatar() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 75,
    );

    if (image == null) return;

    setState(() => _isLoading = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final file = File(image.path);
      final fileExt = image.path.split('.').last;
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.$fileExt';
      final filePath = '${user.id}/$fileName';

      // 1. Upload new avatar
      await Supabase.instance.client.storage
          .from('avatars')
          .upload(filePath, file);

      // 2. Get public URL
      final avatarUrl = Supabase.instance.client.storage
          .from('avatars')
          .getPublicUrl(filePath);

      // 3. Update profile record
      await Supabase.instance.client
          .from('profiles')
          .update({
            'avatar_url': avatarUrl,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', user.id);

      // 4. Invalidate provider to refresh UI everywhere
      ref.invalidate(userProfileProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Profile picture updated")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error uploading image: $e")));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGoogleSignIn() async {
    try {
      final authService = ref.read(googleAuthServiceProvider);
      await authService.signIn();

      if (mounted) {
        setState(() {
          _googleUser = authService.currentUser;
        });

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(
          const SnackBar(
            content: Text('Successfully connected to Google'),
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
    await ref.read(googleAuthServiceProvider).signOut();

    if (mounted) {
      setState(() {
        _googleUser = null;
      });
    }
  }

  Future<void> _connectBank() async {
    setState(() => _isLoading = true);
    try {
      final ebService = ref.read(enableBankingServiceProvider);
      final persistence = ref.read(persistenceServiceProvider);

      // Create session for Widiba
      final session = await ebService.createSession(
        bankName: 'Banca Widiba',
        country: 'IT',
      );

      final sessionId = session['session_id'] as String?;
      final authUrl = session['url'] as String?;

      if (sessionId == null || authUrl == null) {
        throw Exception('Invalid session response');
      }

      await persistence.setEbSessionId(sessionId);
      await persistence.setEbBankName('Widiba');

      // Open bank auth in browser
      if (mounted) {
        final uri = Uri.parse(authUrl);
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Connection failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _syncBank() async {
    setState(() => _isBankSyncing = true);
    try {
      final imported = await performBankSync(ref);

      if (mounted) {
        ref.invalidate(accountsProvider);
        ref.invalidate(paginatedTransactionsProvider);
        ref.invalidate(transactionsProvider(null));

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(imported > 0 ? '$imported transactions imported' : 'Already up to date'),
            backgroundColor: AppTheme.primaryGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Bank sync failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isBankSyncing = false);
    }
  }

  Future<void> _disconnectBank() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceGrey,
        title: const Text('Disconnect Bank?'),
        content: const Text(
          'This will remove the bank connection. Your imported transactions will not be deleted.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Disconnect', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final persistence = ref.read(persistenceServiceProvider);
      await persistence.setEbIsLinked(false);
      await persistence.setEbSessionId(null);
      await persistence.setEbAccountIds([]);
      await persistence.setEbBankName(null);
      if (mounted) setState(() {});
    }
  }

  Future<void> _syncSheets() async {
    setState(() => _isLoading = true);
    try {
      final result = await performSheetsSync(ref);

      if (mounted) {
        // Refresh UI data after sync
        ref.invalidate(accountsProvider);
        ref.invalidate(paginatedTransactionsProvider);
        ref.invalidate(transactionsProvider(null));

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.toString()),
            backgroundColor: AppTheme.primaryGreen,
          ),
        );
        setState(() {}); // refresh last sync timestamp
      }
    } catch (e, s) {
      debugPrint('Sheets sync error: $e\n$s');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sync failed: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 8),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSheetsConfigDialog() {
    final persistence = ref.read(persistenceServiceProvider);
    final idController = TextEditingController(text: persistence.getSheetsSpreadsheetId());
    final nameController = TextEditingController(text: persistence.getSheetsSheetName());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Google Sheets Config'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: idController,
              decoration: const InputDecoration(
                labelText: 'Spreadsheet ID',
                hintText: 'From the Google Sheets URL',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Sheet Name',
                hintText: 'e.g., Spese',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              await persistence.setSheetsSpreadsheetId(idController.text.trim());
              await persistence.setSheetsSheetName(nameController.text.trim());
              if (mounted) {
                Navigator.pop(context);
                setState(() {});
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
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
                  color: AppTheme.textGrey.withOpacity(0.3),
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
                      color: isSelected ? AppTheme.primaryGreen.withOpacity(0.1) : AppTheme.surfaceGreyLight,
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
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  // Profile Header
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppTheme.primaryGreen.withOpacity(0.15),
                          AppTheme.primaryGreen.withOpacity(0.05),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: AppTheme.primaryGreen.withOpacity(0.2),
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      children: [
                        GestureDetector(
                          onTap: _isLoading ? null : _pickAndUploadAvatar,
                          child: Stack(
                            children: [
                              Container(
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppTheme.surfaceGrey,
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppTheme.primaryGreen.withOpacity(
                                        0.2,
                                      ),
                                      blurRadius: 20,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: ClipOval(
                                  child: profile?['avatar_url'] != null
                                      ? CachedNetworkImage(
                                          imageUrl: profile!['avatar_url'],
                                          fit: BoxFit.cover,
                                          placeholder: (context, url) =>
                                              const Center(
                                                child:
                                                    CircularProgressIndicator(
                                                      color:
                                                          AppTheme.primaryGreen,
                                                      strokeWidth: 2,
                                                    ),
                                              ),
                                          errorWidget: (context, url, error) =>
                                              const Icon(
                                                Icons.person,
                                                size: 50,
                                                color: AppTheme.primaryGreen,
                                              ),
                                        )
                                      : const Icon(
                                          Icons.person,
                                          size: 50,
                                          color: AppTheme.primaryGreen,
                                        ),
                                ),
                              ),
                              if (_isLoading)
                                Positioned.fill(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.5),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Center(
                                      child: CircularProgressIndicator(
                                        color: AppTheme.primaryGreen,
                                      ),
                                    ),
                                  ),
                                ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: const BoxDecoration(
                                    color: AppTheme.primaryGreen,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.add_a_photo,
                                    size: 14,
                                    color: AppTheme.backgroundBlack,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          username,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Account Section
                  _SettingsSection(
                    title: "Account",
                    children: [
                      _SettingsTile(
                        title: "Manage Wallets",
                        subtitle: "Setup and edit your accounts",
                        icon: Icons.account_balance_wallet_rounded,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const WalletsScreen(),
                          ),
                        ),
                      ),
                      _SettingsTile(
                        title: "Categories",
                        subtitle: "Customize your spending groups",
                        icon: Icons.category_rounded,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const CategoriesScreen(),
                          ),
                        ),
                      ),
                      _SettingsTile(
                        title: "Tags",
                        subtitle: "Manage labels for transactions",
                        icon: Icons.label_rounded,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const TagsScreen()),
                        ),
                      ),
                    ],
                  ),

                  // Preferences Section
                  _SettingsSection(
                    title: "Preferences",
                    children: [
                      _SettingsTile(
                        title: "Currency",
                        subtitle: currency,
                        icon: Icons.monetization_on_rounded,
                        trailing: Row(
                          children: [
                            Text(
                              currency,
                              style: const TextStyle(
                                color: AppTheme.primaryGreen,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              Icons.keyboard_arrow_down,
                              color: Colors.white.withOpacity(0.2),
                              size: 14,
                            ),
                          ],
                        ),
                        onTap: () => _showCurrencyPicker(currency),
                      ),
                      _SettingsTile(
                        title: "Receipt Scanner",
                        subtitle: persistence.getOcrEngine() == 'mobile_ocr'
                            ? "Ente Mobile OCR"
                            : "Google MLKit",
                        icon: Icons.document_scanner_rounded,
                        trailing: Row(
                          children: [
                            Text(
                              persistence.getOcrEngine() == 'mobile_ocr'
                                  ? "Mobile OCR"
                                  : "MLKit",
                              style: TextStyle(
                                color:
                                    persistence.getOcrEngine() == 'mobile_ocr'
                                    ? Colors.orangeAccent
                                    : AppTheme.primaryGreen,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              Icons.keyboard_arrow_down,
                              color: Colors.white.withOpacity(0.2),
                              size: 14,
                            ),
                          ],
                        ),
                        onTap: () {
                          // Show bottom sheet inline using _buildOcrSettings logic
                          showModalBottomSheet(
                            context: context,
                            backgroundColor: AppTheme.surfaceGrey,
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(24),
                              ),
                            ),
                            builder: (context) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 24,
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 40,
                                      height: 4,
                                      decoration: BoxDecoration(
                                        color: AppTheme.textGrey.withOpacity(
                                          0.3,
                                        ),
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    const Text(
                                      "Scanning Engine",
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    ListTile(
                                      title: const Text(
                                        "Google MLKit",
                                        style: TextStyle(color: Colors.white),
                                      ),
                                      subtitle: const Text(
                                        "Fast and reliable (Default)",
                                        style: TextStyle(
                                          color: AppTheme.textGrey,
                                        ),
                                      ),
                                      trailing:
                                          persistence.getOcrEngine() ==
                                              'google_mlkit'
                                          ? const Icon(
                                              Icons.check_circle,
                                              color: AppTheme.primaryGreen,
                                            )
                                          : null,
                                      onTap: () async {
                                        await persistence.setOcrEngine(
                                          'google_mlkit',
                                        );
                                        if (context.mounted) {
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
                                        "Advanced accuracy (Experimental)",
                                        style: TextStyle(
                                          color: AppTheme.textGrey,
                                        ),
                                      ),
                                      trailing:
                                          persistence.getOcrEngine() ==
                                              'mobile_ocr'
                                          ? const Icon(
                                              Icons.check_circle,
                                              color: AppTheme.primaryGreen,
                                            )
                                          : null,
                                      onTap: () async {
                                        await persistence.setOcrEngine(
                                          'mobile_ocr',
                                        );
                                        if (context.mounted) {
                                          Navigator.pop(context);
                                          setState(() {});
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ],
                  ),

                  // Notifications Section
                  _SettingsSection(
                    title: "Notifications",
                    children: [
                      if (_permissionMissing)
                        _SettingsTile(
                          title: "Fix Permissions",
                          subtitle: "Tap to enable notifications",
                          icon: Icons.warning_amber_rounded,
                          iconColor: Colors.orange,
                          onTap: () async {
                            final granted = await ref
                                .read(notificationServiceProvider)
                                .requestPermissions();
                            if (granted) {
                              setState(() => _permissionMissing = false);
                            }
                          },
                        ),
                      _buildNotificationToggle(
                        "Push Notifications",
                        "Main system alerts",
                        Icons.notifications_active_rounded,
                        persistence.getNotificationsEnabled(),
                        (value) async {
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
                          await ref.read(notificationLogicProvider).updateDailyReminder();
                          if (mounted) setState(() {});
                        },
                      ),
                      _buildNotificationToggle(
                        "Budget Alerts",
                        "Limit thresholds",
                        Icons.notification_important_rounded,
                        persistence.getBudgetAlertsEnabled(),
                        (value) async {
                          await persistence.setBudgetAlertsEnabled(value);
                          if (mounted) setState(() {});
                        },
                      ),
                      _buildNotificationToggle(
                        "Daily Reminder",
                        "Manual logging",
                        Icons.event_note_rounded,
                        persistence.getDailyReminderEnabled(),
                        (value) async {
                          await persistence.setDailyReminderEnabled(value);
                          await ref
                              .read(notificationLogicProvider)
                              .updateDailyReminder();
                          if (mounted) setState(() {});
                        },
                      ),
                      if (persistence.getDailyReminderEnabled())
                        _SettingsTile(
                          title: "Reminder Time",
                          subtitle: persistence.getDailyReminderTime(),
                          icon: Icons.access_time_filled_rounded,
                          trailing: Text(
                            persistence.getDailyReminderTime(),
                            style: const TextStyle(
                              color: AppTheme.primaryGreen,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
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
                              await persistence.setDailyReminderTime(
                                newTimeStr,
                              );
                              await ref
                                  .read(notificationLogicProvider)
                                  .updateDailyReminder();
                              if (mounted) setState(() {});
                            }
                          },
                        ),
                    ],
                  ),

                  // Sync & Backup Section
                  _SettingsSection(
                    title: "Sync & Cloud",
                    children: [
                      if (_googleUser == null)
                        _SettingsTile(
                          title: "Google Drive",
                          subtitle: "Connect for cloud storage",
                          icon: Icons.cloud_off_rounded,
                          onTap: _handleGoogleSignIn,
                        )
                      else ...[
                        _SettingsTile(
                          title: "Drive Connected",
                          subtitle: _googleUser!.email,
                          icon: Icons.cloud_done_rounded,
                          iconColor: AppTheme.primaryGreen,
                          trailing: IconButton(
                            onPressed: _handleGoogleSignOut,
                            icon: const Icon(Icons.logout, color: Colors.red),
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: _SettingsTile(
                                title: "Backup",
                                subtitle: "Upload now",
                                icon: Icons.upload_rounded,
                                onTap: _isLoading ? null : _backupToDrive,
                              ),
                            ),
                            Expanded(
                              child: _SettingsTile(
                                title: "Restore",
                                subtitle: "Download",
                                icon: Icons.download_rounded,
                                onTap: _isLoading ? null : _restoreFromDrive,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),

                  // Google Sheets Sync Section
                  if (_googleUser != null)
                    _SettingsSection(
                      title: "Google Sheets",
                      children: [
                        _SettingsTile(
                          title: "Spreadsheet",
                          subtitle: ref.read(persistenceServiceProvider).getSheetsSheetName(),
                          icon: Icons.table_chart_rounded,
                          iconColor: Colors.green,
                          onTap: () => _showSheetsConfigDialog(),
                        ),
                        _SettingsTile(
                          title: "Sync Now",
                          subtitle: "Bidirectional sync",
                          icon: Icons.sync_rounded,
                          iconColor: AppTheme.primaryGreen,
                          onTap: _isLoading ? null : _syncSheets,
                        ),
                        Builder(
                          builder: (context) {
                            final lastSync = ref.read(persistenceServiceProvider).getSheetsLastSyncTimestamp();
                            if (lastSync == 0) return const SizedBox.shrink();
                            final date = DateTime.fromMillisecondsSinceEpoch(lastSync);
                            final formatted = '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                              child: Text(
                                'Last sync: $formatted',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[500],
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),

                  // Bank Connection Section
                  _SettingsSection(
                    title: "Bank Connection",
                    children: [
                      if (!ref.read(persistenceServiceProvider).getEbIsLinked()) ...[
                        _SettingsTile(
                          title: "Connect Bank",
                          subtitle: "Auto-import transactions from your bank",
                          icon: Icons.account_balance_rounded,
                          iconColor: Colors.blue,
                          onTap: _isLoading ? null : _connectBank,
                        ),
                      ] else ...[
                        _SettingsTile(
                          title: ref.read(persistenceServiceProvider).getEbBankName() ?? 'Bank',
                          subtitle: "Connected",
                          icon: Icons.account_balance_rounded,
                          iconColor: AppTheme.primaryGreen,
                          trailing: IconButton(
                            onPressed: _disconnectBank,
                            icon: const Icon(Icons.link_off, color: Colors.red),
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                        _SettingsTile(
                          title: "Sync Transactions",
                          subtitle: _isBankSyncing ? "Syncing..." : "Fetch latest from bank",
                          icon: Icons.sync_rounded,
                          iconColor: AppTheme.primaryGreen,
                          onTap: (_isLoading || _isBankSyncing) ? null : _syncBank,
                        ),
                        Builder(
                          builder: (context) {
                            final lastSync = ref.read(persistenceServiceProvider).getEbLastSyncTimestamp();
                            if (lastSync == 0) return const SizedBox.shrink();
                            final date = DateTime.fromMillisecondsSinceEpoch(lastSync);
                            final formatted = '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                              child: Text(
                                'Last sync: $formatted',
                                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                              ),
                            );
                          },
                        ),
                      ],
                    ],
                  ),

                  // Auto Backup Section (independent of Google Drive)
                  _SettingsSection(
                    title: "Auto Backup",
                    children: [
                      _buildNotificationToggle(
                        "Automatic Backup",
                        "Daily local backup (cloud upload if connected)",
                        Icons.sync_rounded,
                        persistence.getAutoBackupEnabled(),
                        (value) async {
                          await persistence.setAutoBackupEnabled(value);
                          await ref
                              .read(notificationLogicProvider)
                              .updateAutoBackupSchedule();
                          if (mounted) setState(() {});
                        },
                      ),
                      if (persistence.getAutoBackupEnabled()) ...[
                        _SettingsTile(
                          title: "Backup Time",
                          subtitle: persistence.getAutoBackupTime(),
                          icon: Icons.access_time_rounded,
                          trailing: Text(
                            persistence.getAutoBackupTime(),
                            style: const TextStyle(
                              color: AppTheme.primaryGreen,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          onTap: () async {
                            final timeStr = persistence.getAutoBackupTime();
                            final bits = timeStr.split(":");
                            final initialTime = TimeOfDay(
                              hour: int.tryParse(bits[0]) ?? 2,
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
                              await persistence.setAutoBackupTime(newTimeStr);
                              await ref
                                  .read(notificationLogicProvider)
                                  .updateAutoBackupSchedule();
                              if (mounted) setState(() {});
                            }
                          },
                        ),
                        _SettingsTile(
                          title: "Backup Folder",
                          subtitle: persistence.getCustomBackupPath() ?? "Default (Internal)",
                          icon: Icons.folder_open_rounded,
                          trailing: Icon(
                            Icons.keyboard_arrow_right,
                            color: Colors.white.withOpacity(0.2),
                            size: 14,
                          ),
                          onTap: () async {
                            final String? selectedPath = await FilePicker.platform.getDirectoryPath();
                            if (selectedPath != null) {
                              await persistence.setCustomBackupPath(selectedPath);
                              if (mounted) setState(() {});
                            }
                          },
                        ),
                      ],
                    ],
                  ),

                  // Data Management
                  _SettingsSection(
                    title: "Data Management",
                    children: [
                      _SettingsTile(
                        title: "Export Backup (JSON)",
                        subtitle: "Local backup file",
                        icon: Icons.share_rounded,
                        onTap: _isLoading
                            ? null
                            : () async {
                                setState(() => _isLoading = true);
                                try {
                                  await ref
                                      .read(backupServiceProvider)
                                      .exportDatabase();
                                } finally {
                                  if (mounted) {
                                    setState(() => _isLoading = false);
                                  }
                                }
                              },
                      ),
                      _SettingsTile(
                        title: "Import Backup (JSON)",
                        subtitle: "Restore from local",
                        icon: Icons.settings_backup_restore_rounded,
                        onTap: _isLoading
                            ? null
                            : () async {
                                final result = await FilePicker.platform
                                    .pickFiles(
                                      type: FileType.custom,
                                      allowedExtensions: ['json'],
                                    );

                                if (result != null && context.mounted) {
                                  final file = File(result.files.single.path!);
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      backgroundColor: AppTheme.surfaceGrey,
                                      title: const Text("Import Backup"),
                                      content: const Text(
                                        "This will REPLACE all your current data. This action cannot be undone.",
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
                                    ref.invalidate(transactionsProvider);
                                    ref.invalidate(categoriesProvider);
                                    ref.invalidate(tagsProvider);
                                    ref.invalidate(accountsProvider);
                                    ref.invalidate(budgetsProvider);
                                    if (mounted) {
                                      setState(() => _isLoading = false);
                                    }
                                  }
                                }
                              },
                      ),
                      _SettingsTile(
                        title: "Import Quicken (QIF)",
                        subtitle: "External bank data",
                        icon: Icons.file_present_rounded,
                        onTap: _isLoading
                            ? null
                            : () async {
                                final result = await FilePicker.platform
                                    .pickFiles(type: FileType.any);

                                if (result != null && context.mounted) {
                                  final file = File(result.files.single.path!);
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
                                  } finally {
                                    if (mounted) {
                                      setState(() => _isLoading = false);
                                    }
                                  }
                                }
                              },
                      ),
                    ],
                  ),

                  const SizedBox(height: 48),

                  // Sign Out
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 24),
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _signOut,
                      icon: const Icon(Icons.logout_rounded, size: 20),
                      label: const Text(
                        "Sign Out",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.withOpacity(0.1),
                        foregroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(color: Colors.red.withOpacity(0.3)),
                        ),
                        elevation: 0,
                      ),
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

  Widget _buildNotificationToggle(
    String title,
    String subtitle,
    IconData icon,
    bool value,
    Function(bool) onChanged,
  ) {
    return _SettingsTile(
      title: title,
      subtitle: subtitle,
      icon: icon,
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeThumbColor: AppTheme.primaryGreen,
        activeTrackColor: AppTheme.primaryGreen.withOpacity(0.3),
        inactiveThumbColor: AppTheme.textGrey,
        inactiveTrackColor: AppTheme.surfaceGreyLight,
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SettingsSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12, top: 24),
          child: Text(
            title.toUpperCase(),
            style: TextStyle(
              color: Colors.white.withOpacity(0.4),
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.surfaceGrey.withOpacity(0.5),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? iconColor;

  const _SettingsTile({
    required this.title,
    this.subtitle,
    required this.icon,
    this.trailing,
    this.onTap,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (iconColor ?? AppTheme.primaryGreen).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: iconColor ?? AppTheme.primaryGreen,
                size: 20,
              ),
            ),
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
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
            if (trailing != null)
              trailing!
            else if (onTap != null)
              Icon(
                Icons.arrow_forward_ios,
                color: Colors.white.withOpacity(0.2),
                size: 14,
              ),
          ],
        ),
      ),
    );
  }
}
