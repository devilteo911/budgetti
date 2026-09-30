import 'package:budgetti/core/theme/app_theme.dart';
import 'package:budgetti/features/settings/widgets/appearance_selectors.dart';
import 'package:budgetti/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

/// The Aspetto selectors broke "Sistema" into "Sistem/a" on a phone: each of the
/// three equal segments was too narrow for a check mark, an icon and the word.
/// A label must never wrap, at any phone width, in either language.
void main() {
  // Real metrics: the app's own theme and its bundled Manrope, not the test
  // harness's square placeholder font, which is far wider than any real label.
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  // The width the selector gets: phone width − list margins − card padding.
  const widths = {'360dp phone': 296.0, '320dp phone': 256.0, '411dp phone': 344.0};

  Future<void> pump(WidgetTester tester, Widget selector, double width,
      {required String locale}) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.buildTheme(
          palette: AppPalette.values.first, brightness: Brightness.dark),
      locale: Locale(locale),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Center(child: SizedBox(width: width, child: selector)),
      ),
    ));
    await tester.runAsync(GoogleFonts.pendingFonts);
    await tester.pumpAndSettle();
  }

  /// Lines a label is laid out in: how many distinct rows its glyph boxes sit on.
  int lines(WidgetTester tester, String label) {
    final render = tester.renderObject<RenderParagraph>(find.text(label));
    final boxes = render.getBoxesForSelection(
        TextSelection(baseOffset: 0, extentOffset: render.text.toPlainText().length));
    return {for (final b in boxes) b.top.round()}.length;
  }

  for (final entry in widths.entries) {
    for (final locale in ['it', 'en']) {
      testWidgets('language selector keeps every label on one line '
          '(${entry.key}, $locale)', (tester) async {
        await pump(
          tester,
          LanguageSelector(value: 'system', onChanged: (_) {}),
          entry.value,
          locale: locale,
        );
        final system = locale == 'it' ? 'Sistema' : 'System';
        for (final label in [system, 'Italiano', 'English']) {
          expect(lines(tester, label), 1, reason: '"$label" wraps');
        }
        expect(tester.takeException(), isNull);
      });

      testWidgets('theme selector keeps every label on one line '
          '(${entry.key}, $locale)', (tester) async {
        await pump(
          tester,
          ThemeModeSelector(value: ThemeMode.system, onChanged: (_) {}),
          entry.value,
          locale: locale,
        );
        final labels = locale == 'it'
            ? ['Sistema', 'Chiaro', 'Scuro']
            : ['System', 'Light', 'Dark'];
        for (final label in labels) {
          expect(lines(tester, label), 1, reason: '"$label" wraps');
        }
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('the theme selector keeps its icons where they fit',
      (tester) async {
    await pump(tester, ThemeModeSelector(value: ThemeMode.dark, onChanged: (_) {}),
        344, locale: 'it');
    expect(find.byIcon(Icons.light_mode), findsOneWidget);
    expect(find.byIcon(Icons.dark_mode), findsOneWidget);
    expect(find.byIcon(Icons.brightness_auto), findsOneWidget);
  });

  testWidgets('it drops them, not the words, where they do not',
      (tester) async {
    await pump(tester, ThemeModeSelector(value: ThemeMode.dark, onChanged: (_) {}),
        256, locale: 'it');
    expect(find.byIcon(Icons.light_mode), findsNothing);
    expect(find.text('Sistema'), findsOneWidget);
  });

  testWidgets('selecting a segment reports it', (tester) async {
    ThemeMode? picked;
    await pump(
        tester,
        ThemeModeSelector(value: ThemeMode.system, onChanged: (m) => picked = m),
        344,
        locale: 'en');
    await tester.tap(find.text('Dark'));
    await tester.pump();
    expect(picked, ThemeMode.dark);
  });

  // Control for the measurement: the old layout (check mark + icon + word in an
  // equal third) really wraps the word at 360dp, so the tests above do bite.
  testWidgets('control: the old SegmentedButton wraps "Sistema" at 360dp',
      (tester) async {
    await pump(
      tester,
      SegmentedButton<ThemeMode>(
        segments: const [
          ButtonSegment(
              value: ThemeMode.system,
              label: Text('Sistema'),
              icon: Icon(Icons.brightness_auto)),
          ButtonSegment(
              value: ThemeMode.light,
              label: Text('Chiaro'),
              icon: Icon(Icons.light_mode)),
          ButtonSegment(
              value: ThemeMode.dark,
              label: Text('Scuro'),
              icon: Icon(Icons.dark_mode)),
        ],
        selected: const {ThemeMode.system},
        onSelectionChanged: (_) {},
      ),
      296,
      locale: 'it',
    );
    expect(lines(tester, 'Sistema'), greaterThan(1));
  });
}
