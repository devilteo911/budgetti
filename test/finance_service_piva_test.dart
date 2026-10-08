import 'dart:ffi';

import 'package:budgetti/core/database/database.dart';
import 'package:budgetti/core/services/finance_service.dart';
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

/// The Partita IVA reads: Drift rows → the engine's classes, with the filters
/// the screens rely on. A second live profile (sync can bring one) must not
/// flip the figures, and the engine needs the *whole* income history — the
/// acconti of a year look at the years before it.
void main() {
  setUpAll(_ensureSqlite);

  late AppDatabase db;
  late FinanceService service;

  Future<void> profile(
    String id, {
    String user = 'user-a',
    DateTime? updated,
    bool deleted = false,
    String ateco = '',
    List<String>? categories,
  }) => db.into(db.pivaProfiles).insert(PivaProfilesCompanion.insert(
        id: id,
        userId: Value(user),
        atecoCode: Value(ateco),
        incomeCategories: Value(categories),
        isDeleted: Value(deleted),
        lastUpdated: Value(updated),
      ));

  Future<void> payment(
    String id, {
    String user = 'user-a',
    DateTime? due,
    bool deleted = false,
  }) => db.into(db.pivaPayments).insert(PivaPaymentsCompanion.insert(
        id: id,
        userId: Value(user),
        dueDate: Value(due),
        isDeleted: Value(deleted),
      ));

  Future<void> txn(
    String id,
    double amount,
    String type,
    DateTime date, {
    String user = 'user-a',
    bool deleted = false,
  }) => db.into(db.transactions).insert(TransactionsCompanion.insert(
        id: id,
        userId: Value(user),
        accountId: const Value('a1'),
        amount: amount,
        description: id,
        category: 'Consulenze',
        type: Value(type),
        date: date,
        isDeleted: Value(deleted),
      ));

  setUp(() {
    db = AppDatabase.forExecutor(NativeDatabase.memory());
    service = FinanceService(db, 'user-a');
  });
  tearDown(() => db.close());

  group('profile', () {
    test('no row is null, not an error', () async {
      expect(await service.getPivaProfile(), isNull);
      expect(await service.watchPivaProfile().first, isNull);
    });

    test('two live rows: the newest lastUpdated wins, an unstamped row is last',
        () async {
      await profile('unstamped', ateco: '47.11.00');
      await profile('old', ateco: '62.01.00', updated: DateTime(2026, 1, 1));
      await profile('new', ateco: '73.11.00', updated: DateTime(2026, 3, 1));

      expect((await service.getPivaProfile())!.atecoCode, '73.11.00');
      expect((await service.watchPivaProfile().first)!.atecoCode, '73.11.00');
    });

    test('a deleted row and another user\'s row are never read', () async {
      await profile('mine', ateco: 'mine', updated: DateTime(2026, 1, 1));
      await profile('gone',
          ateco: 'gone', updated: DateTime(2026, 5, 1), deleted: true);
      await profile('theirs',
          ateco: 'theirs', updated: DateTime(2026, 6, 1), user: 'user-b');

      expect((await service.getPivaProfile())!.atecoCode, 'mine');
    });

    test('only dead or foreign rows is no profile', () async {
      await profile('gone', deleted: true);
      await profile('theirs', user: 'user-b');

      expect(await service.getPivaProfile(), isNull);
    });

    test('a NULL incomeCategories is an empty list, a stored one is kept',
        () async {
      await profile('p', updated: DateTime(2026, 1, 1));
      expect((await service.getPivaProfile())!.incomeCategories, isEmpty);

      await (db.update(db.pivaProfiles)..where((t) => t.id.equals('p')))
          .write(PivaProfilesCompanion(
        incomeCategories: Value(['Consulenze', 'Corsi']),
        lastUpdated: Value(DateTime(2026, 2, 1)),
      ));
      expect((await service.getPivaProfile())!.incomeCategories,
          ['Consulenze', 'Corsi']);
    });

    test('a NULL declaredIncome is an empty map, a stored one keeps its null entry',
        () async {
      await profile('p', updated: DateTime(2026, 1, 1));
      expect((await service.getPivaProfile())!.declaredIncome, isEmpty);

      await (db.update(db.pivaProfiles)..where((t) => t.id.equals('p')))
          .write(PivaProfilesCompanion(
        declaredIncome: Value({'2025': 40000.0, '2024': null}),
        lastUpdated: Value(DateTime(2026, 2, 1)),
      ));
      final declared = (await service.getPivaProfile())!.declaredIncome;
      expect(declared, {'2025': 40000.0, '2024': null});
      expect(declared.containsKey('2024'), isTrue);
      expect(declared['2024'], isNull);
      expect(declared.containsKey('2023'), isFalse);
    });

    test('every column lands in its own field', () async {
      await db.into(db.pivaProfiles).insert(PivaProfilesCompanion.insert(
            id: 'p',
            userId: const Value('user-a'),
            atecoCode: const Value('62.01.00'),
            coefficient: const Value(78.5),
            startYear: const Value(2023),
            startupRate: const Value(true),
            fundType: const Value('cassa'),
            fundName: const Value('Cassa di prova'),
            subjectiveRate: const Value(10.25),
            integrativeRate: const Value(4.5),
            minSubjective: const Value(501.5),
            minIntegrative: const Value(250.75),
            inpsReduction: const Value(true),
            incomeCategories: Value(['Consulenze']),
            lastUpdated: Value(DateTime(2026, 1, 1)),
          ));

      final p = (await service.getPivaProfile())!;
      expect(p.atecoCode, '62.01.00');
      expect(p.coefficient, 78.5);
      expect(p.startYear, 2023);
      expect(p.startupRate, isTrue);
      expect(p.fundType, 'cassa');
      expect(p.fundName, 'Cassa di prova');
      expect(p.subjectiveRate, 10.25);
      expect(p.integrativeRate, 4.5);
      expect(p.minSubjective, 501.5);
      expect(p.minIntegrative, 250.75);
      expect(p.inpsReduction, isTrue);
      expect(p.incomeCategories, ['Consulenze']);
    });
  });

  group('payments', () {
    test('dead and foreign rows stay out; dueDate order, undated rows last',
        () async {
      await payment('late', due: DateTime(2026, 11, 30, 12));
      await payment('undated');
      await payment('early', due: DateTime(2026, 6, 30, 12));
      await payment('gone', due: DateTime(2026, 1, 1, 12), deleted: true);
      await payment('theirs', due: DateTime(2026, 2, 1, 12), user: 'user-b');

      final got = await service.getPivaPayments();
      expect(got.map((p) => p.id).toList(), ['early', 'late', 'undated']);
      expect(got.last.dueDate, isNull);
      expect(got.first.dueDate, DateTime(2026, 6, 30, 12));
      expect(
        (await service.watchPivaPayments().first).map((p) => p.id).toList(),
        ['early', 'late', 'undated'],
      );
    });

    test('no rows is an empty list', () async {
      expect(await service.getPivaPayments(), isEmpty);
      expect(await service.watchPivaPayments().first, isEmpty);
    });

    test('every column lands in its own field', () async {
      await db.into(db.pivaPayments).insert(PivaPaymentsCompanion.insert(
            id: 'x',
            userId: const Value('user-a'),
            key: const Value('2026:imposta_saldo'),
            kind: const Value('imposta'),
            label: const Value('Saldo 2025'),
            dueDate: Value(DateTime(2026, 6, 30, 12)),
            amount: const Value(1234.56),
            paidDate: Value(DateTime(2026, 6, 20, 12)),
            note: const Value('in anticipo'),
          ));

      final p = (await service.getPivaPayments()).single;
      expect(p.id, 'x');
      expect(p.key, '2026:imposta_saldo');
      expect(p.kind, 'imposta');
      expect(p.label, 'Saldo 2025');
      expect(p.dueDate, DateTime(2026, 6, 30, 12));
      expect(p.amount, 1234.56);
      expect(p.paidDate, DateTime(2026, 6, 20, 12));
      expect(p.note, 'in anticipo');
      expect(p.isDeleted, isFalse);
    });
  });

  group('income', () {
    // Newest first. 'legacy' is typed expense but positive: the sign decides,
    // like Transaction.isIncome. 'old' is six years back: no date window.
    const wanted = ['recent', 'legacy', 'mid', 'old'];

    Future<void> seed() async {
      await txn('old', 50, 'income', DateTime(2020, 5, 10));
      await txn('recent', 100, 'income', DateTime(2026, 8, 1));
      await txn('mid', 70, 'income', DateTime(2025, 3, 1));
      await txn('legacy', 40, 'expense', DateTime(2026, 2, 1));
      await txn('out', -30, 'expense', DateTime(2026, 4, 1));
      await txn('badtype', -10, 'income', DateTime(2026, 4, 2));
      await txn('move', 500, 'transfer', DateTime(2026, 4, 3));
      await txn('gone', 60, 'income', DateTime(2026, 4, 4), deleted: true);
      await txn('theirs', 80, 'income', DateTime(2026, 4, 5), user: 'user-b');
    }

    test('only live, own, positive non-transfers, whatever the date', () async {
      await seed();

      final rows = await service.watchPivaIncome().first;
      expect(rows.map((t) => t.id).toList(), wanted);
      expect(rows.first.amount, 100);
      expect(rows.first.category, 'Consulenze');
    });

    test('getPivaIncome is the first watch value, in the same order', () async {
      await seed();

      final once = await service.getPivaIncome();
      final watched = await service.watchPivaIncome().first;
      expect(once.map((t) => t.id).toList(), wanted);
      expect(once.map((t) => t.id).toList(),
          watched.map((t) => t.id).toList());
    });

    test('a row inserted after listening makes the stream emit again',
        () async {
      await txn('first', 10, 'income', DateTime(2026, 1, 1));

      final seen = <int>[];
      final sub = service.watchPivaIncome().listen((r) => seen.add(r.length));
      addTearDown(sub.cancel);

      Future<void> until(int n) async {
        for (var i = 0; i < 300 && seen.length < n; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
        if (seen.length < n) fail('never emitted $n times: $seen');
      }

      await until(1);
      await txn('second', 20, 'income', DateTime(2026, 2, 1));
      await until(2);

      expect(seen, [1, 2]);
    });
  });

  // The start of the ledger is the first live row of the user, any type: the
  // income rows alone (`getPivaIncome`) would put it too late.
  group('ledger start', () {
    test('an empty ledger has no start', () async {
      expect(await service.getLedgerStart(), isNull);
      expect(await service.watchLedgerStart().first, isNull);
    });

    test('the earliest row wins, whatever its type', () async {
      await txn('income', 100, 'income', DateTime(2025, 6, 1));
      expect(await service.getLedgerStart(), DateTime(2025, 6, 1));

      await txn('out', -30, 'expense', DateTime(2025, 3, 1));
      expect(await service.getLedgerStart(), DateTime(2025, 3, 1),
          reason: 'an expense moves it');

      await txn('move', 500, 'transfer', DateTime(2024, 11, 1));
      expect(await service.getLedgerStart(), DateTime(2024, 11, 1),
          reason: 'a transfer moves it');

      await txn('badtype', -10, 'income', DateTime(2024, 2, 1));
      expect(await service.getLedgerStart(), DateTime(2024, 2, 1),
          reason: 'a negative "income" moves it');
    });

    test('a deleted row and another user\'s row never move it', () async {
      await txn('mine', 100, 'income', DateTime(2025, 6, 1));
      await txn('gone', -5, 'expense', DateTime(2020, 1, 1), deleted: true);
      await txn('theirs', 80, 'income', DateTime(2021, 1, 1), user: 'user-b');

      expect(await service.getLedgerStart(), DateTime(2025, 6, 1));
      expect(await service.watchLedgerStart().first, DateTime(2025, 6, 1));
    });

    test('the stream emits again when an earlier row is inserted; getLedgerStart is its first value',
        () async {
      await txn('first', 10, 'income', DateTime(2026, 1, 1));

      final seen = <DateTime?>[];
      final sub = service.watchLedgerStart().listen(seen.add);
      addTearDown(sub.cancel);

      Future<void> until(int n) async {
        for (var i = 0; i < 300 && seen.length < n; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
        if (seen.length < n) fail('never emitted $n times: $seen');
      }

      await until(1);
      expect(await service.getLedgerStart(), seen.first);

      await txn('earlier', -20, 'expense', DateTime(2025, 12, 1));
      await until(2);

      expect(seen, [DateTime(2026, 1, 1), DateTime(2025, 12, 1)]);
    });
  });
}
