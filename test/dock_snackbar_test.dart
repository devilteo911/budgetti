import 'package:budgetti/core/providers/providers.dart';
import 'package:budgetti/features/home/scaffold_with_nav_bar.dart';
import 'package:budgetti/l10n/app_localizations.dart';
import 'package:budgetti/l10n/app_localizations_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A snackbar used to be painted over the floating dock, hiding half the pill.
/// Inside the shell the dock's scaffold shows it, so it has to float above.
void main() {
  for (final inset in [0.0, 24.0]) {
    testWidgets('a snackbar sits above the dock (${inset.toInt()}dp inset)',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3;
      tester.view.viewPadding = FakeViewPadding(bottom: inset * 3);
      tester.view.padding = FakeViewPadding(bottom: inset * 3);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.view.resetViewPadding();
        tester.view.resetPadding();
      });
      final l10n = AppLocalizationsEn();
      await tester.pumpWidget(ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: DockSnackBarTheme(
            child: Builder(
              // Shaped like ScaffoldWithNavBar: a body-only scaffold whose body
              // paints the dock itself.
              builder: (context) => Scaffold(
                extendBody: true,
                body: Stack(children: [
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: MediaQuery.of(context).viewPadding.bottom +
                        DockMetrics.bottomGap,
                    child: Center(
                      child: FloatingPillNav(
                        slots: buildNavSlots(l10n, reviewCount: 0, onAdd: () {}),
                        currentBranchIndex: 0,
                        onBranchSelected: (_) {},
                      ),
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ));

      final context = tester.element(find.byType(Scaffold));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Default categories restored')),
      );
      await tester.pumpAndSettle();

      // The SnackBar widget's box includes its outer margin; the visible card is
      // its Material.
      final card = find
          .descendant(of: find.byType(SnackBar), matching: find.byType(Material))
          .first;
      final snackBottom = tester.getBottomLeft(card).dy;
      final dockTop = tester.getTopLeft(find.byType(FloatingPillNav)).dy;
      expect(snackBottom, lessThanOrEqualTo(dockTop),
          reason: 'the snackbar covers the dock');
      // …and not floating half-way up the screen either.
      expect(dockTop - snackBottom, lessThan(32));
    });
  }
}
