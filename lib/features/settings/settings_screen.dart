import 'dart:io';

import 'package:budgetti/core/providers/providers.dart';
import 'package:budgetti/features/import/import_transactions_screen.dart';
import 'package:budgetti/features/settings/widgets/settings_scaffold.dart';
import 'package:budgetti/features/settings/widgets/settings_section.dart';
import 'package:budgetti/features/settings/widgets/settings_tile.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final user = Supabase.instance.client.auth.currentUser;

    return SettingsScaffold(
      title: 'Settings',
      showBackButton: false,
      children: [
        SettingsSection(
          title: 'Account',
          children: [
            SettingsTile(
              icon: Icons.person_outline,
              title: 'Profile',
              subtitle: user?.email,
              onTap: () => context.push('/settings/profile'),
            ),
            SettingsTile(
              icon: Icons.palette_outlined,
              iconColor: scheme.tertiary,
              title: 'Appearance',
              subtitle: 'Palette, theme, effects',
              onTap: () => context.push('/settings/appearance'),
            ),
            SettingsTile(
              icon: Icons.tune,
              title: 'Preferences',
              subtitle: 'Currency, scanner, notifications',
              onTap: () => context.push('/settings/preferences'),
            ),
            SettingsTile(
              icon: Icons.sync_alt,
              iconColor: Colors.blueAccent,
              title: 'Integrations & Backup',
              subtitle: 'Drive, Sheets, bank sync, auto backup',
              onTap: () => context.push('/settings/integrations'),
            ),
          ],
        ),
        SettingsSection(
          title: 'Data',
          children: [
            SettingsTile(
              icon: Icons.category_outlined,
              title: 'Categories',
              onTap: () => context.push('/settings/categories'),
            ),
            SettingsTile(
              icon: Icons.label_outline,
              iconColor: scheme.secondary,
              title: 'Tags',
              onTap: () => context.push('/settings/tags'),
            ),
            SettingsTile(
              icon: Icons.account_balance_wallet_outlined,
              iconColor: scheme.tertiary,
              title: 'Wallets',
              onTap: () => context.push('/settings/wallets'),
            ),
            SettingsTile(
              icon: Icons.file_upload_outlined,
              iconColor: Colors.orangeAccent,
              title: 'Import Quicken (QIF)',
              subtitle: 'Load transactions from a .qif file',
              onTap: () => _importQif(context, ref),
            ),
          ],
        ),
        SettingsSection(
          title: 'About',
          children: [
            SettingsTile(
              icon: Icons.code,
              iconColor: Colors.blueAccent,
              title: 'Source code',
              subtitle: 'github.com/devilteo911/budgetti',
              onTap: () => launchUrl(
                Uri.parse('https://github.com/devilteo911/budgetti'),
                mode: LaunchMode.externalApplication,
              ),
            ),
            SettingsTile(
              icon: Icons.logout,
              iconColor: Colors.redAccent,
              title: 'Sign out',
              onTap: () async {
                await Supabase.instance.client.auth.signOut();
              },
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _importQif(BuildContext context, WidgetRef ref) async {
    final result = await FilePicker.platform.pickFiles(type: FileType.any);
    if (result == null || !context.mounted) return;

    final file = File(result.files.single.path!);
    if (!file.path.toLowerCase().endsWith('.qif')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a .qif file')),
      );
      return;
    }

    final transactions =
        await ref.read(importServiceProvider).parseQifFile(file);
    if (!context.mounted) return;

    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (_) =>
            ImportTransactionsScreen(transactions: transactions),
      ),
    );
  }
}
