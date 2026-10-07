import 'package:budgetti/features/stats/widgets/section_label.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  Future<void> pump(WidgetTester tester, String text, {double scale = 1, int? count}) async {
    tester.view.physicalSize = const Size(390, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: const Size(390, 800), textScaler: TextScaler.linear(scale)),
        child: Scaffold(body: SectionLabel(text: text, count: count)),
      ),
    ));
    await tester.runAsync(GoogleFonts.pendingFonts);
    await tester.pump();
  }

  final rule = find.byWidgetPredicate((w) => w is Container && w.constraints?.maxHeight == 1);

  testWidgets('a short label keeps its rule and its count at scale 1', (tester) async {
    await pump(tester, 'ESTIMATE · TAX YEAR 2026', count: 7);
    expect(tester.takeException(), isNull);
    expect(rule, findsOneWidget);
    expect(find.text('7'), findsOneWidget);
  });

  testWidgets("a long label wraps instead of overflowing at scale 2 (it and en, with a count)", (tester) async {
    for (final text in ["STIMA · ANNO D'IMPOSTA 2026", 'ESTIMATE · TAX YEAR 2026']) {
      await pump(tester, text, scale: 2, count: 12);
      expect(tester.takeException(), isNull, reason: text);
      final label = tester.getRect(find.text(text));
      expect(label.right, lessThanOrEqualTo(390 - 20), reason: text);
      expect(find.text('12'), findsOneWidget);
    }
  });

  testWidgets('the same label at scale 1 is unchanged: one line, with its rule', (tester) async {
    await pump(tester, "STIMA · ANNO D'IMPOSTA 2026");
    expect(rule, findsOneWidget);
    expect(tester.getRect(find.text("STIMA · ANNO D'IMPOSTA 2026")).height, lessThan(20));
  });
}
