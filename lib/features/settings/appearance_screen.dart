import 'package:budgetti/core/l10n.dart';
import 'package:budgetti/core/providers/providers.dart';
import 'package:budgetti/core/theme/app_theme.dart';
import 'package:dynamic_color/dynamic_color.dart';
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
      title: context.l10n.setAppearance,
      children: [
        SettingsSection(
          title: context.l10n.setLanguage,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: SegmentedButton<String>(
                  segments: [
                    ButtonSegment(
                      value: 'system',
                      label: Text(context.l10n.commonSystem),
                      icon: const Icon(Icons.language),
                    ),
                    ButtonSegment(value: 'it', label: Text('Italiano')),
                    ButtonSegment(value: 'en', label: Text('English')),
                  ],
                  selected: {ref.watch(localeSettingsProvider).language},
                  onSelectionChanged: (s) =>
                      ref.read(localeSettingsProvider.notifier).setLanguage(s.first),
                ),
              ),
            ),
          ],
        ),
        SettingsSection(
          title: context.l10n.setPalette,
          children: [
            DynamicColorBuilder(
              builder: (lightDynamic, darkDynamic) {
                // Monet only exists where the OS exposes wallpaper colors.
                final palettes = darkDynamic == null
                    ? AppPalette.values.where((p) => p != AppPalette.dynamic)
                    : AppPalette.values;
                Color swatchOf(AppPalette p) => p == AppPalette.dynamic
                    ? (Theme.of(context).brightness == Brightness.dark
                        ? darkDynamic!.primary
                        : lightDynamic!.primary)
                    : p.swatch;
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: palettes.map((p) {
                      final selected = settings.palette == p;
                      final color = swatchOf(p);
                      return GestureDetector(
                        onTap: () => notifier.setPalette(p),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              // Hairline outline keeps pale swatches
                              // (Monet on light wallpapers) visible.
                              color: selected
                                  ? scheme.onSurface
                                  : scheme.outlineVariant,
                              width: selected ? 3 : 1,
                            ),
                            boxShadow: selected
                                ? [
                                    BoxShadow(
                                      color: color.withValues(alpha: 0.5),
                                      blurRadius: 12,
                                    ),
                                  ]
                                : null,
                          ),
                          child: selected
                              ? Icon(Icons.check,
                                  size: 22, color: scheme.surface)
                              : p == AppPalette.dynamic
                                  ? Icon(Icons.wallpaper,
                                      size: 22, color: scheme.onSurface)
                                  : null,
                        ),
                      );
                    }).toList(),
                  ),
                );
              },
            ),
          ],
        ),
        SettingsSection(
          title: context.l10n.setBrightness,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: SegmentedButton<ThemeMode>(
                  segments: [
                    ButtonSegment(
                      value: ThemeMode.system,
                      label: Text(context.l10n.commonSystem),
                      icon: const Icon(Icons.brightness_auto),
                    ),
                    ButtonSegment(
                      value: ThemeMode.light,
                      label: Text(context.l10n.setThemeLight),
                      icon: const Icon(Icons.light_mode),
                    ),
                    ButtonSegment(
                      value: ThemeMode.dark,
                      label: Text(context.l10n.setThemeDark),
                      icon: const Icon(Icons.dark_mode),
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
          title: context.l10n.setEffects,
          children: [
            SwitchListTile(
              title: Text(context.l10n.setAmoledBlack),
              subtitle: Text(context.l10n.setAmoledBlackSubtitle),
              value: settings.amoled,
              onChanged: notifier.setAmoled,
            ),
            SwitchListTile(
              title: Text(context.l10n.setLiquidGlass),
              subtitle: Text(context.l10n.setLiquidGlassSubtitle),
              value: settings.glass,
              onChanged: notifier.setGlass,
            ),
          ],
        ),
      ],
    );
  }
}
