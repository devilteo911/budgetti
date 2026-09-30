import 'package:budgetti/core/widgets/app_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A tall sheet (the add-transaction form) used to extend under the status bar,
/// drawing its drag handle in the row of the clock and the battery.
void main() {
  testWidgets('a scroll-controlled sheet stays below the status bar',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    tester.view.viewPadding = const FakeViewPadding(top: 144); // 48 dp
    tester.view.padding = const FakeViewPadding(top: 144);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.view.resetViewPadding();
      tester.view.resetPadding();
    });
    late BuildContext context;
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (c) {
        context = c;
        return const Scaffold();
      }),
    ));

    showAppSheet(
      context,
      isScrollControlled: true,
      showDragHandle: true,
      // Taller than the screen, so the sheet takes all the height it is given.
      builder: (_) => const SizedBox(height: 5000, child: Text('form')),
    );
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(find.byType(BottomSheet)).dy,
        greaterThanOrEqualTo(48));
  });
}
