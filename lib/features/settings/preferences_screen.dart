import 'package:budgetti/core/providers/providers.dart';
import 'package:budgetti/core/services/notification_logic.dart';
import 'package:budgetti/features/settings/widgets/settings_scaffold.dart';
import 'package:budgetti/features/settings/widgets/settings_section.dart';
import 'package:budgetti/features/settings/widgets/settings_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _currencies = [
  {'code': 'EUR', 'symbol': '€', 'name': 'Euro'},
  {'code': 'USD', 'symbol': r'$', 'name': 'US Dollar'},
  {'code': 'GBP', 'symbol': '£', 'name': 'British Pound'},
  {'code': 'JPY', 'symbol': '¥', 'name': 'Japanese Yen'},
];

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
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    await Supabase.instance.client.from('profiles').update({
      'currency': newCurrency,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', user.id);
    ref.invalidate(userProfileProvider);
  }

  void _showCurrencyPicker(String current) {
    final scheme = Theme.of(context).colorScheme;
    showModalBottomSheet(
      useRootNavigator: true,
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Select Currency',
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
                title: Text(c['name']!),
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

  void _showOcrPicker() {
    final persistence = ref.read(persistenceServiceProvider);
    final scheme = Theme.of(context).colorScheme;
    showModalBottomSheet(
      useRootNavigator: true,
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Scanning Engine',
                style: Theme.of(ctx).textTheme.titleLarge,
              ),
            ),
            ListTile(
              title: const Text('Google MLKit'),
              subtitle: const Text('Fast and reliable (Default)'),
              trailing: persistence.getOcrEngine() == 'google_mlkit'
                  ? Icon(Icons.check_circle, color: scheme.primary)
                  : null,
              onTap: () async {
                await persistence.setOcrEngine('google_mlkit');
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) setState(() {});
              },
            ),
            ListTile(
              title: const Text('Ente Mobile OCR'),
              subtitle: const Text('Advanced accuracy (Experimental)'),
              trailing: persistence.getOcrEngine() == 'mobile_ocr'
                  ? Icon(Icons.check_circle, color: scheme.primary)
                  : null,
              onTap: () async {
                await persistence.setOcrEngine('mobile_ocr');
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) setState(() {});
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
    final profileAsync = ref.watch(userProfileProvider);
    final currency =
        profileAsync.asData?.value?['currency'] as String? ?? 'EUR';
    final ocr = persistence.getOcrEngine();

    return SettingsScaffold(
      title: 'Preferences',
      children: [
        SettingsSection(
          title: 'General',
          children: [
            SettingsTile(
              icon: Icons.monetization_on_outlined,
              title: 'Currency',
              subtitle: currency,
              trailing: Icon(Icons.keyboard_arrow_down,
                  color: scheme.onSurface.withValues(alpha: 0.4)),
              onTap: () => _showCurrencyPicker(currency),
            ),
            SettingsTile(
              icon: Icons.document_scanner_outlined,
              iconColor: scheme.secondary,
              title: 'Receipt Scanner',
              subtitle: ocr == 'mobile_ocr' ? 'Ente Mobile OCR' : 'Google MLKit',
              trailing: Icon(Icons.keyboard_arrow_down,
                  color: scheme.onSurface.withValues(alpha: 0.4)),
              onTap: _showOcrPicker,
            ),
          ],
        ),
        SettingsSection(
          title: 'Notifications',
          children: [
            if (_permissionMissing)
              SettingsTile(
                icon: Icons.warning_amber_rounded,
                iconColor: Colors.orange,
                title: 'Fix Permissions',
                subtitle: 'Tap to enable notifications',
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
              title: 'Push Notifications',
              subtitle: 'Main system alerts',
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
              title: 'Budget Alerts',
              subtitle: 'Limit thresholds',
              value: persistence.getBudgetAlertsEnabled(),
              onChanged: (v) async {
                await persistence.setBudgetAlertsEnabled(v);
                if (mounted) setState(() {});
              },
            ),
            _toggleTile(
              icon: Icons.event_note_outlined,
              title: 'Daily Reminder',
              subtitle: 'Manual logging',
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
                title: 'Reminder Time',
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
