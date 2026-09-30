import 'package:budgetti/features/stats/widgets/stats_hero.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// The hero's three secondary values must sit on one baseline. Each used to be
/// scaled to fit its own column (FittedBox), so a long value shrank more than a
/// short one and, with the columns bottom-aligned, its baseline rode lower — by
/// about 5 px on the phone (node bottoms identical, glyphs not). Measured here on
/// the rendered paragraphs, not by eye.
void main() {
  Future<void> pumpRow(
    WidgetTester tester,
    List<StatsSecondaryItem> items, {
    double width = 360,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: width,
              child: StatsSecondaryRow(items: items),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  // What the phone showed on 2026-09-30: a short, a signed long and a long value.
  const items = [
    StatsSecondaryItem(
      label: 'MEDIA GIORNALIERA',
      value: '79,43 €',
      color: Colors.white,
    ),
    StatsSecondaryItem(
      label: 'FLUSSO NETTO',
      value: '-2.383,05 €',
      color: Colors.red,
    ),
    StatsSecondaryItem(
      label: 'PREVISTO',
      value: '2.383,05 €',
      color: Colors.blue,
    ),
  ];

  /// (rendered font size, baseline y) of each value's paragraph, through every
  /// transform above it — including the scale a FittedBox applies.
  List<(double, double)> valueBaselines(WidgetTester tester) {
    final out = <(double, double)>[];
    for (final item in items) {
      final render = tester.renderObject<RenderParagraph>(
        find.text(item.value),
      );
      final scale = render.getTransformTo(null).getMaxScaleOnAxis();
      // The paragraph's own baseline, measured on a painter laid out like it.
      final painter = TextPainter(
        text: render.text,
        textDirection: render.textDirection,
        textScaler: render.textScaler,
      )..layout();
      final baseline = render
          .localToGlobal(
            Offset(
              0,
              painter.computeDistanceToActualBaseline(TextBaseline.alphabetic),
            ),
          )
          .dy;
      out.add((render.text.style!.fontSize! * scale, baseline));
    }
    return out;
  }

  testWidgets('the three values share one size and one baseline', (
    tester,
  ) async {
    await pumpRow(tester, items);

    final b = valueBaselines(tester);
    expect(b[1].$1, closeTo(b[0].$1, 0.01), reason: 'same rendered size');
    expect(b[2].$1, closeTo(b[0].$1, 0.01), reason: 'same rendered size');
    expect(b[1].$2, closeTo(b[0].$2, 0.5), reason: 'baseline of value 2');
    expect(b[2].$2, closeTo(b[0].$2, 0.5), reason: 'baseline of value 3');
  });

  testWidgets('a narrower screen shrinks all three alike, none overflows', (
    tester,
  ) async {
    await pumpRow(tester, items, width: 300);

    final b = valueBaselines(tester);
    expect(b[1].$1, closeTo(b[0].$1, 0.01));
    expect(b[2].$1, closeTo(b[0].$1, 0.01));
    expect(b[1].$2, closeTo(b[0].$2, 0.5));
    expect(tester.takeException(), isNull);
  });

  // Control for the measurement itself: the old layout — each value in its own
  // FittedBox, columns bottom-aligned — really puts the baselines apart, so the
  // assertions above would have failed on it.
  testWidgets('control: a FittedBox per value leaves the baselines apart', (
    tester,
  ) async {
    Widget column(StatsSecondaryItem i) => Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            i.value,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 360,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [for (final i in items) column(i)],
              ),
            ),
          ),
        ),
      ),
    );

    final b = valueBaselines(tester);
    final spread =
        [for (final v in b) v.$2].reduce((a, c) => a > c ? a : c) -
        [for (final v in b) v.$2].reduce((a, c) => a < c ? a : c);
    expect(spread, greaterThan(1.5));
  });
}
