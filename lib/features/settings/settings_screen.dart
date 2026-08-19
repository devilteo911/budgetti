import 'dart:io';

import 'package:budgetti/core/l10n.dart';
import 'package:budgetti/core/providers/providers.dart';
import 'package:budgetti/features/import/import_transactions_screen.dart';
import 'package:budgetti/features/settings/widgets/settings_scaffold.dart';
import 'package:budgetti/features/settings/widgets/settings_section.dart';
import 'package:budgetti/features/settings/widgets/settings_tile.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final email = ref.watch(authServiceProvider).email;

    return SettingsScaffold(
      title: context.l10n.setSettings,
      showBackButton: false,
      children: [
        SettingsSection(
          title: context.l10n.setAccount,
          children: [
            SettingsTile(
              icon: Icons.person_outline,
              title: context.l10n.setProfile,
              subtitle: email,
              onTap: () => context.push('/settings/profile'),
            ),
            SettingsTile(
              icon: Icons.palette_outlined,
              iconColor: scheme.tertiary,
              title: context.l10n.setAppearance,
              subtitle: context.l10n.setAppearanceSubtitle,
              onTap: () => context.push('/settings/appearance'),
            ),
            SettingsTile(
              icon: Icons.tune,
              title: context.l10n.setPreferences,
              subtitle: context.l10n.setPreferencesSubtitle,
              onTap: () => context.push('/settings/preferences'),
            ),
            SettingsTile(
              icon: Icons.sync_alt,
              iconColor: Colors.blueAccent,
              title: context.l10n.setIntegrationsBackup,
              subtitle: context.l10n.setIntegrationsBackupSubtitle,
              onTap: () => context.push('/settings/integrations'),
            ),
          ],
        ),
        SettingsSection(
          title: context.l10n.setData,
          children: [
            SettingsTile(
              icon: Icons.category_outlined,
              title: context.l10n.setCategories,
              onTap: () => context.push('/settings/categories'),
            ),
            SettingsTile(
              icon: Icons.label_outline,
              iconColor: scheme.secondary,
              title: context.l10n.setTags,
              onTap: () => context.push('/settings/tags'),
            ),
            SettingsTile(
              icon: Icons.account_balance_wallet_outlined,
              iconColor: scheme.tertiary,
              title: context.l10n.setWallets,
              onTap: () => context.push('/settings/wallets'),
            ),
            SettingsTile(
              icon: Icons.file_upload_outlined,
              iconColor: Colors.orangeAccent,
              title: context.l10n.setImportQuicken,
              subtitle: context.l10n.setImportQuickenSubtitle,
              onTap: () => _importQif(context, ref),
            ),
          ],
        ),
        SettingsSection(
          title: context.l10n.setAbout,
          children: [
            SettingsTile(
              icon: Icons.code,
              iconColor: Colors.blueAccent,
              title: context.l10n.setSourceCode,
              subtitle: 'github.com/devilteo911/budgetti',
              onTap: () => launchUrl(
                Uri.parse('https://github.com/devilteo911/budgetti'),
                mode: LaunchMode.externalApplication,
              ),
            ),
            SettingsTile(
              icon: Icons.logout,
              iconColor: Colors.redAccent,
              title: context.l10n.setSignOut,
              onTap: () => ref.read(authServiceProvider).logout(),
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
        SnackBar(content: Text(context.l10n.setSelectQifFile)),
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
