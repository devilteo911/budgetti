import 'package:budgetti/core/providers/providers.dart';
import 'package:budgetti/core/theme/app_theme.dart';
import 'package:budgetti/features/settings/widgets/settings_scaffold.dart';
import 'package:budgetti/features/settings/widgets/settings_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AppearanceScreen extends ConsumerWidget {
  const AppearanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(themeSettingsProvider);
    final notifier = ref.read(themeSettingsProvider.notifier);
    final scheme = Theme.of(context).colorScheme;

    return SettingsScaffold(
      title: 'Appearance',
      children: [
        SettingsSection(
          title: 'Palette',
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: AppPalette.values.map((p) {
                  final selected = settings.palette == p;
                  return GestureDetector(
                    onTap: () => notifier.setPalette(p),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: p.swatch,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selected
                              ? scheme.onSurface
                              : Colors.transparent,
                          width: 3,
                        ),
                        boxShadow: selected
                            ? [
                                BoxShadow(
                                  color: p.swatch.withValues(alpha: 0.5),
                                  blurRadius: 12,
                                ),
                              ]
                            : null,
                      ),
                      child: selected
                          ? Icon(Icons.check,
                              size: 22, color: scheme.surface)
                          : null,
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
        SettingsSection(
          title: 'Brightness',
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment(
                      value: ThemeMode.system,
                      label: Text('System'),
                      icon: Icon(Icons.brightness_auto),
                    ),
                    ButtonSegment(
                      value: ThemeMode.light,
                      label: Text('Light'),
                      icon: Icon(Icons.light_mode),
                    ),
                    ButtonSegment(
                      value: ThemeMode.dark,
                      label: Text('Dark'),
                      icon: Icon(Icons.dark_mode),
                    ),
                  ],
                  selected: {settings.mode},
                  onSelectionChanged: (s) => notifier.setMode(s.first),
                ),
              ),
            ),
          ],
        ),
        SettingsSection(
          title: 'Effects',
          children: [
            SwitchListTile(
              title: const Text('AMOLED black'),
              subtitle: const Text('Pure black background in dark mode'),
              value: settings.amoled,
              onChanged: notifier.setAmoled,
            ),
            SwitchListTile(
              title: const Text('Liquid glass'),
              subtitle: const Text('Frosted blur on nav bar and sheets'),
              value: settings.glass,
              onChanged: notifier.setGlass,
            ),
          ],
        ),
      ],
    );
  }
}
