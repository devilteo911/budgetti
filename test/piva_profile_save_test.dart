import 'dart:ffi';

import 'package:budgetti/core/database/database.dart';
import 'package:budgetti/core/services/finance_service.dart';
import 'package:budgetti/core/services/pocketbase_sync_service.dart'
    show PocketBaseAutoSync;
import 'package:budgetti/models/piva.dart' show PivaProfileInput;
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart' show NativeDatabase;
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/open.dart' as sqlite3open;

// See finance_service_seed_test.dart for why the FFI loader is overridden.
void _ensureSqlite() {
  try {
    sqlite3open.open.overrideFor(
      sqlite3open.OperatingSystem.linux,
      () => DynamicLibrary.open('/lib/x86_64-linux-gnu/libsqlite3.so.0'),
    );
  } catch (_) {
    // Already overridden or not on Linux — ignore.
  }
}

/// Saving the Partita IVA profile keeps exactly one live row: the newest is
/// updated, the others are retired (stamped, so the delete syncs). The reads
/// are `finance_service_piva_test.dart`'s; here only the write.
void main() {
  setUpAll(_ensureSqlite);

  late AppDatabase db;
  late FinanceService service;
  // Drift stores dates in whole seconds: the start of the test is cut the same way.
  late DateTime start;

  /// Twelve distinct values, so a swapped column shows.
  PivaProfileInput input({
    String ateco = '62.01.00',
    List<String> categories = const ['Consulenze', 'Corsi'],
    Map<String, double?> declaredIncome = const {},
  }) => PivaProfileInput(
        atecoCode: ateco,
        coefficient: 78.5,
        startYear: 2023,
        startupRate: true,
        fundType: 'cassa',
        fundName: 'Cassa di prova',
        subjectiveRate: 10.25,
        integrativeRate: 4.5,
        minSubjective: 501.5,
        minIntegrative: 250.75,
        inpsReduction: false,
        incomeCategories: categories,
        declaredIncome: declaredIncome,
      );

  Future<void> row(
    String id, {
    DateTime? updated,
    bool deleted = false,
    String user = 'user-a',
    String ateco = '',
  }) => db.into(db.pivaProfiles).insert(PivaProfilesCompanion.insert(
        id: id,
        userId: Value(user),
        atecoCode: Value(ateco),
        isDeleted: Value(deleted),
        lastUpdated: Value(updated),
      ));

  Future<PivaProfile> byId(String id) =>
      (db.select(db.pivaProfiles)..where((t) => t.id.equals(id))).getSingle();

  setUp(() {
    db = AppDatabase.forExecutor(NativeDatabase.memory());
    service = FinanceService(db, 'user-a');
    start = DateTime.fromMillisecondsSinceEpoch(
        DateTime.now().millisecondsSinceEpoch ~/ 1000 * 1000);
  });
  tearDown(() => db.close());

  test('the first save leaves one live, stamped row of the service user',
      () async {
    await service.savePivaProfile(input());

    final r = (await db.select(db.pivaProfiles).get()).single;
    expect(r.userId, 'user-a');
    expect(r.isDeleted, isFalse);
    expect(r.lastUpdated, isNotNull);
    expect(r.lastUpdated!.isBefore(start), isFalse);
    expect(r.id, isNotEmpty);
    expect(r.atecoCode, '62.01.00');
    expect(r.coefficient, 78.5);
    expect(r.startYear, 2023);
    expect(r.startupRate, isTrue);
    expect(r.fundType, 'cassa');
    expect(r.fundName, 'Cassa di prova');
    expect(r.subjectiveRate, 10.25);
    expect(r.integrativeRate, 4.5);
    expect(r.minSubjective, 501.5);
    expect(r.minIntegrative, 250.75);
    expect(r.inpsReduction, isFalse);
    expect(r.incomeCategories, ['Consulenze', 'Corsi']);
    // an empty map is written as given, not left NULL
    expect(r.declaredIncome, <String, double?>{});
  });

  test('a declared income is saved as given, the null entry included',
      () async {
    await service.savePivaProfile(
        input(declaredIncome: {'2025': 40000.0, '2024': null}));

    final r = (await db.select(db.pivaProfiles).get()).single;
    expect(r.declaredIncome, {'2025': 40000.0, '2024': null});
    expect(r.declaredIncome!.containsKey('2024'), isTrue);
    expect(r.declaredIncome!['2024'], isNull);
    expect(r.declaredIncome!.containsKey('2023'), isFalse);
  });

  test('two saves in a row leave one row, the same id, the second values',
      () async {
    await service.savePivaProfile(input());
    final first = (await db.select(db.pivaProfiles).get()).single;

    await service.savePivaProfile(input(ateco: '73.11.00', categories: ['Libri']));

    final r = (await db.select(db.pivaProfiles).get()).single;
    expect(r.id, first.id);
    expect(r.isDeleted, isFalse);
    expect(r.atecoCode, '73.11.00');
    expect(r.incomeCategories, ['Libri']);
  });

  test('two live rows: the newest is updated, the older one is retired',
      () async {
    await row('a', updated: DateTime(2020, 1, 1), ateco: 'old');
    await row('b', updated: DateTime(2020, 3, 1), ateco: 'new');

    await service.savePivaProfile(input(ateco: '73.11.00'));

    final b = await byId('b');
    expect(b.isDeleted, isFalse);
    expect(b.atecoCode, '73.11.00');
    expect(b.lastUpdated!.isBefore(start), isFalse);
    final a = await byId('a');
    expect(a.isDeleted, isTrue);
    expect(a.atecoCode, 'old');
    expect(a.lastUpdated!.isBefore(start), isFalse);
    expect((await service.getPivaProfile())!.atecoCode, '73.11.00');
  });

  test('a deleted row and another user\'s row are left alone', () async {
    await row('mine', updated: DateTime(2020, 1, 1));
    await row('gone', updated: DateTime(2020, 5, 1), deleted: true);
    await row('theirs', updated: DateTime(2020, 6, 1), user: 'user-b');

    await service.savePivaProfile(input());

    expect((await byId('mine')).atecoCode, '62.01.00');
    expect((await byId('gone')).lastUpdated, DateTime(2020, 5, 1));
    final theirs = await byId('theirs');
    expect(theirs.isDeleted, isFalse);
    expect(theirs.atecoCode, '');
    expect(theirs.lastUpdated, DateTime(2020, 6, 1));
  });

  test('a live row with no lastUpdated loses against a stamped one', () async {
    await row('unstamped');
    await row('stamped', updated: DateTime(2020, 1, 1));

    await service.savePivaProfile(input());

    expect((await byId('stamped')).atecoCode, '62.01.00');
    expect((await byId('unstamped')).isDeleted, isTrue);
  });

  test('with only a deleted row in the table a new one is created', () async {
    await row('gone', updated: DateTime(2020, 5, 1), deleted: true);

    await service.savePivaProfile(input());

    final rows = await db.select(db.pivaProfiles).get();
    expect(rows, hasLength(2));
    final gone = rows.singleWhere((r) => r.id == 'gone');
    expect(gone.isDeleted, isTrue);
    expect(gone.atecoCode, '');
    final live = rows.singleWhere((r) => r.id != 'gone');
    expect(live.isDeleted, isFalse);
    expect(live.atecoCode, '62.01.00');
  });

  test('a save wakes the auto-sync once', () async {
    var syncs = 0;
    final auto = PocketBaseAutoSync(
      db: db,
      isEnabled: () => true,
      debounce: const Duration(milliseconds: 10),
      runSync: () async => syncs++,
    );

    await service.savePivaProfile(input());
    for (var i = 0; i < 300 && syncs == 0; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    // A second run, if there were one, would have fired by now.
    await Future<void>.delayed(const Duration(milliseconds: 100));
    auto.dispose();

    expect(syncs, 1);
  });
}
