import 'package:budgetti/core/l10n.dart';
import 'package:flutter/material.dart';

/// Three equal segments, words never broken. A SegmentedButton gives each segment
/// an equal share of the width and wraps a label that does not fit — 'Sistema'
/// came out as 'Sistem/a' once a check mark and an icon sat beside it. So the
/// decoration yields, not the word: the check mark is off (the filled segment
/// already says which one is chosen) and the icons appear only when the widest
/// segment can hold icon + label.
class _Selector<T> extends StatelessWidget {
  final List<({T value, String label, IconData? icon})> options;
  final T value;
  final ValueChanged<T> onChanged;

  const _Selector({
    required this.options,
    required this.value,
    required this.onChanged,
  });

  // Material's segment: 12 dp each side, 8 dp between icon (18) and label.
  static const double _padding = 24;
  static const double _iconAndGap = 18 + 8;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelLarge;
    final scaler = MediaQuery.textScalerOf(context);

    return LayoutBuilder(builder: (context, constraints) {
      final perSegment = constraints.maxWidth / options.length;
      var widest = 0.0;
      for (final o in options) {
        final painter = TextPainter(
          text: TextSpan(text: o.label, style: style),
          textDirection: Directionality.of(context),
          textScaler: scaler,
        )..layout();
        if (painter.width > widest) widest = painter.width;
      }
      final iconsFit = perSegment >= widest + _iconAndGap + _padding;

      return SizedBox(
        width: double.infinity,
        child: SegmentedButton<T>(
          showSelectedIcon: false,
          segments: [
            for (final o in options)
              ButtonSegment(
                value: o.value,
                label: Text(o.label, softWrap: false),
                icon: iconsFit && o.icon != null ? Icon(o.icon) : null,
              ),
          ],
          selected: {value},
          onSelectionChanged: (s) => onChanged(s.first),
        ),
      );
    });
  }
}

/// Language: System / Italiano / English.
class LanguageSelector extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const LanguageSelector({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) => _Selector<String>(
        options: [
          (value: 'system', label: context.l10n.commonSystem, icon: null),
          (value: 'it', label: 'Italiano', icon: null),
          (value: 'en', label: 'English', icon: null),
        ],
        value: value,
        onChanged: onChanged,
      );
}

/// Brightness: System / Light / Dark.
class ThemeModeSelector extends StatelessWidget {
  final ThemeMode value;
  final ValueChanged<ThemeMode> onChanged;
  const ThemeModeSelector({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) => _Selector<ThemeMode>(
        options: [
          (value: ThemeMode.system, label: context.l10n.commonSystem, icon: Icons.brightness_auto),
          (value: ThemeMode.light, label: context.l10n.setThemeLight, icon: Icons.light_mode),
          (value: ThemeMode.dark, label: context.l10n.setThemeDark, icon: Icons.dark_mode),
        ],
        value: value,
        onChanged: onChanged,
      );
}
