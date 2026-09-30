import 'dart:ffi' show DynamicLibrary;

import 'package:budgetti/core/database/database.dart';
import 'package:budgetti/core/providers/providers.dart';
import 'package:budgetti/core/services/finance_service.dart';
import 'package:budgetti/features/settings/categories_screen.dart';
import 'package:budgetti/features/settings/tags_screen.dart';
import 'package:budgetti/l10n/app_localizations.dart';
import 'package:budgetti/l10n/app_localizations_en.dart';
import 'package:drift/native.dart' show NativeDatabase;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/open.dart' as sqlite3open;

import 'fixtures/seed_owner.dart';

// `flutter test` runs in the VM without sqlite3_flutter_libs' bundled native,
// so point the FFI loader at the system library (.so.0 — no -dev symlink here).
void _ensureSqlite() {
  try {
    sqlite3open.open.overrideFor(
      sqlite3open.OperatingSystem.linux,
      () => DynamicLibrary.open('/lib/x86_64-linux-gnu/libsqlite3.so.0'),
    );
  } catch (_) {}
}

/// Restore defaults answered "restored" even when it had nothing to bring back.
void main() {
  setUpAll(_ensureSqlite);
  final l10n = AppLocalizationsEn();

  Future<void> restoreFrom(WidgetTester tester, Widget screen,
      {required bool alreadyRestored}) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final db = AppDatabase.forExecutor(NativeDatabase.memory());
    addTearDown(db.close);
    final service = FinanceService(db, owner);
    await tester.runAsync(() async {
      await seedOwner(db, beforeTheBatch: false);
      if (alreadyRestored) {
        await service.restoreDefaultCategories();
        await service.restoreDefaultTags();
      }
    });
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        financeServiceProvider.overrideWithValue(service),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: screen,
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.setRestoreDefaults));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.setRestore));
    // The restore runs on the database, outside the test clock.
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.pump();
  }

  /// Unmounting closes drift's stream queries, which schedules a zero timer.
  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 10));
  }

  testWidgets('categories: says what came back', (tester) async {
    await restoreFrom(tester, const CategoriesScreen(), alreadyRestored: false);
    expect(find.text(l10n.setCategoriesRestored), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('categories: says there was nothing to restore', (tester) async {
    await restoreFrom(tester, const CategoriesScreen(), alreadyRestored: true);
    expect(find.text(l10n.setNothingToRestore), findsOneWidget);
    expect(find.text(l10n.setCategoriesRestored), findsNothing);
    await unmount(tester);
  });

  testWidgets('tags: says there was nothing to restore', (tester) async {
    // Every default tag still has a live copy, so there is never anything to revive.
    await restoreFrom(tester, const TagsScreen(), alreadyRestored: false);
    expect(find.text(l10n.setNothingToRestore), findsOneWidget);
    expect(find.text(l10n.setTagsRestored), findsNothing);
    await unmount(tester);
  });
}
