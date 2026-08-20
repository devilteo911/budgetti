import 'package:budgetti/core/l10n.dart';
import 'package:budgetti/core/providers/providers.dart';
import 'package:budgetti/core/services/notification_logic.dart';
import 'package:budgetti/features/settings/widgets/settings_scaffold.dart';
import 'package:budgetti/features/settings/widgets/settings_section.dart';
import 'package:budgetti/features/settings/widgets/settings_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:budgetti/core/widgets/app_sheet.dart';

const _currencies = [
  {'code': 'EUR', 'symbol': '€'},
  {'code': 'USD', 'symbol': r'$'},
  {'code': 'GBP', 'symbol': '£'},
  {'code': 'JPY', 'symbol': '¥'},
];

String _currencyName(BuildContext context, String code) => switch (code) {
      'EUR' => context.l10n.setCurrencyEur,
      'USD' => context.l10n.setCurrencyUsd,
      'GBP' => context.l10n.setCurrencyGbp,
      'JPY' => context.l10n.setCurrencyJpy,
      _ => code,
    };

class PreferencesScreen extends ConsumerStatefulWidget {
  const PreferencesScreen({super.key});

  @override
  ConsumerState<PreferencesScreen> createState() => _PreferencesScreenState();
}

class _PreferencesScreenState extends ConsumerState<PreferencesScreen> {
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
    final enabledInSettings =
        ref.read(persistenceServiceProvider).getNotificationsEnabled();
    if (enabledInSettings && !granted && mounted) {
      setState(() => _permissionMissing = true);
    }
  }

  Future<void> _updateCurrency(String newCurrency) async {
    await ref.read(persistenceServiceProvider).setCurrency(newCurrency);
    ref.invalidate(userProfileProvider);
  }

  void _showCurrencyPicker(String current) {
    final scheme = Theme.of(context).colorScheme;
    showAppSheet(
      context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                ctx.l10n.setSelectCurrency,
                style: Theme.of(ctx).textTheme.titleLarge,
              ),
            ),
            for (final c in _currencies)
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: c['code'] == current
                      ? scheme.primaryContainer
                      : scheme.surfaceContainerHighest,
                  child: Text(
                    c['symbol']!,
                    style: TextStyle(
                      color: c['code'] == current
                          ? scheme.onPrimaryContainer
                          : scheme.onSurface,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Text(_currencyName(ctx, c['code']!)),
                subtitle: Text(c['code']!),
                trailing: c['code'] == current
                    ? Icon(Icons.check_circle, color: scheme.primary)
                    : null,
                onTap: () async {
                  Navigator.pop(ctx);
                  await _updateCurrency(c['code']!);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _pickReminderTime() async {
    final persistence = ref.read(persistenceServiceProvider);
    final timeStr = persistence.getDailyReminderTime();
    final bits = timeStr.split(':');
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.tryParse(bits[0]) ?? 20,
        minute: int.tryParse(bits[1]) ?? 0,
      ),
    );
    if (picked != null) {
      final s =
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      await persistence.setDailyReminderTime(s);
      await ref.read(notificationLogicProvider).updateDailyReminder();
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final persistence = ref.watch(persistenceServiceProvider);
    final currency =
        ref.watch(userProfileProvider).value?['currency'] as String? ?? 'EUR';

    return SettingsScaffold(
      title: context.l10n.setPreferences,
      children: [
        SettingsSection(
          title: context.l10n.setGeneral,
          children: [
            SettingsTile(
              icon: Icons.monetization_on_outlined,
              title: context.l10n.setCurrency,
              subtitle: currency,
              trailing: Icon(Icons.keyboard_arrow_down,
                  color: scheme.onSurface.withValues(alpha: 0.4)),
              onTap: () => _showCurrencyPicker(currency),
            ),
          ],
        ),
        SettingsSection(
          title: context.l10n.setNotifications,
          children: [
            if (_permissionMissing)
              SettingsTile(
                icon: Icons.warning_amber_rounded,
                iconColor: Colors.orange,
                title: context.l10n.setFixPermissions,
                subtitle: context.l10n.setFixPermissionsSubtitle,
                onTap: () async {
                  final granted = await ref
                      .read(notificationServiceProvider)
                      .requestPermissions();
                  if (granted && mounted) {
                    setState(() => _permissionMissing = false);
                  }
                },
              ),
            _toggleTile(
              icon: Icons.notifications_active_outlined,
              title: context.l10n.setPushNotifications,
              subtitle: context.l10n.setPushNotificationsSubtitle,
              value: persistence.getNotificationsEnabled(),
              onChanged: (v) async {
                if (v) {
                  final granted = await ref
                      .read(notificationServiceProvider)
                      .requestPermissions();
                  if (!granted) {
                    if (mounted) setState(() => _permissionMissing = true);
                    return;
                  }
                  if (mounted) setState(() => _permissionMissing = false);
                }
                await persistence.setNotificationsEnabled(v);
                await ref
                    .read(notificationLogicProvider)
                    .updateDailyReminder();
                if (mounted) setState(() {});
              },
            ),
            _toggleTile(
              icon: Icons.notification_important_outlined,
              title: context.l10n.setBudgetAlerts,
              subtitle: context.l10n.setBudgetAlertsSubtitle,
              value: persistence.getBudgetAlertsEnabled(),
              onChanged: (v) async {
                await persistence.setBudgetAlertsEnabled(v);
                if (mounted) setState(() {});
              },
            ),
            _toggleTile(
              icon: Icons.event_note_outlined,
              title: context.l10n.setDailyReminder,
              subtitle: context.l10n.setDailyReminderSubtitle,
              value: persistence.getDailyReminderEnabled(),
              onChanged: (v) async {
                await persistence.setDailyReminderEnabled(v);
                await ref
                    .read(notificationLogicProvider)
                    .updateDailyReminder();
                if (mounted) setState(() {});
              },
            ),
            if (persistence.getDailyReminderEnabled())
              SettingsTile(
                icon: Icons.access_time_filled,
                title: context.l10n.setReminderTime,
                subtitle: persistence.getDailyReminderTime(),
                trailing: Text(
                  persistence.getDailyReminderTime(),
                  style: TextStyle(
                    color: scheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onTap: _pickReminderTime,
              ),
          ],
        ),
      ],
    );
  }

  Widget _toggleTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SettingsTile(
      icon: icon,
      title: title,
      subtitle: subtitle,
      trailing: Switch(value: value, onChanged: onChanged),
    );
  }
}
