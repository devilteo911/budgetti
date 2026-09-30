import 'package:budgetti/core/providers/providers.dart';
import 'package:budgetti/features/home/scaffold_with_nav_bar.dart';
import 'package:budgetti/features/settings/categories_screen.dart';
import 'package:budgetti/features/settings/tags_screen.dart';
import 'package:budgetti/features/settings/widgets/settings_scaffold.dart';
import 'package:budgetti/l10n/app_localizations.dart';
import 'package:budgetti/l10n/app_localizations_en.dart';
import 'package:budgetti/models/category.dart';
import 'package:budgetti/models/tag.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The floating dock covers the bottom of every screen in the shell. A list has
/// to be able to scroll its last row clear of it — at the end of the scroll the
/// last row's bottom edge sits above the dock's top edge, with or without a
/// gesture-bar inset.
void main() {
  Future<void> pumpUnderDock(
    WidgetTester tester,
    Widget screen, {
    List<Override> overrides = const [],
    double insetBottom = 0,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    tester.view.viewPadding = FakeViewPadding(bottom: insetBottom * 3);
    tester.view.padding = FakeViewPadding(bottom: insetBottom * 3);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.view.resetViewPadding();
      tester.view.resetPadding();
    });
    final l10n = AppLocalizationsEn();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        ...overrides,
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            extendBody: true,
            body: Stack(children: [
              Positioned.fill(child: screen),
              // Placed exactly as ScaffoldWithNavBar places it.
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
    ));
    await tester.pumpAndSettle();
  }

  Future<void> expectLastRowClearsDock(
      WidgetTester tester, Finder lastRow) async {
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -20000));
    await tester.pumpAndSettle();
    final dockTop = tester.getTopLeft(find.byType(FloatingPillNav)).dy;
    expect(tester.getBottomLeft(lastRow).dy, lessThanOrEqualTo(dockTop),
        reason: 'the last row is still under the dock');
  }

  testWidgets('DockMetrics.height is the pill\'s rendered height', (tester) async {
    await pumpUnderDock(tester, const SizedBox());
    expect(tester.getSize(find.byType(FloatingPillNav)).height, DockMetrics.height);
  });

  for (final inset in [0.0, 24.0]) {
    group('with a ${inset.toInt()}dp gesture-bar inset', () {
      testWidgets('SettingsScaffold (Settings, Appearance, Preferences, Integrations)',
          (tester) async {
        await pumpUnderDock(
          tester,
          SettingsScaffold(
            title: 'T',
            children: [
              for (var i = 0; i < 30; i++)
                SizedBox(height: 80, child: Text('row $i', key: Key('row$i'))),
            ],
          ),
          insetBottom: inset,
        );
        await expectLastRowClearsDock(tester, find.byKey(const Key('row29')));
      });

      testWidgets('Categories', (tester) async {
        await pumpUnderDock(
          tester,
          const CategoriesScreen(),
          overrides: [
            categoriesProvider.overrideWith((ref) => Stream.value([
                  for (var i = 0; i < 25; i++)
                    Category(
                      id: 'c$i',
                      userId: 'u',
                      name: 'Cat ${i.toString().padLeft(2, '0')}',
                      iconCode: Icons.star.codePoint,
                      colorHex: 0xFF000000,
                      type: 'expense',
                    ),
                ])),
          ],
          insetBottom: inset,
        );
        await expectLastRowClearsDock(tester, find.text('Cat 24'));
      });

      testWidgets('Tags', (tester) async {
        await pumpUnderDock(
          tester,
          const TagsScreen(),
          overrides: [
            tagsProvider.overrideWith((ref) => Stream.value([
                  for (var i = 0; i < 25; i++)
                    Tag(
                      id: 't$i',
                      userId: 'u',
                      name: 'Tag ${i.toString().padLeft(2, '0')}',
                      colorHex: 0xFF000000,
                    ),
                ])),
          ],
          insetBottom: inset,
        );
        await expectLastRowClearsDock(tester, find.text('Tag 24'));
      });
    });
  }
}
