import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:budgetti/core/database/database.dart';
import 'package:budgetti/core/services/backup_service.dart';
import 'package:budgetti/core/services/google_auth_service.dart';
import 'package:budgetti/core/services/google_drive_service.dart';
import 'package:budgetti/core/services/persistence_service.dart';
import 'package:drift/drift.dart' show DataClass, Value;
import 'package:drift/native.dart' show NativeDatabase;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

/// A full profile (two income categories) and two payments: one paid, one with
/// no `paidDate` and an empty `key`. Made-up figures.
Future<void> _seedPiva(AppDatabase d) async {
  final t = DateTime(2026, 6, 23, 12);
  await d.into(d.pivaProfiles).insert(PivaProfilesCompanion.insert(
        id: 'piva1',
        userId: const Value('user-a'),
        atecoCode: const Value('62.01.00'),
        coefficient: const Value(67.0),
        startYear: const Value(2024),
        startupRate: const Value(true),
        fundType: const Value('gestione_separata'),
        fundName: const Value('Fondo di prova'),
        subjectiveRate: const Value(26.07),
        integrativeRate: const Value(4.0),
        minSubjective: const Value(1000.0),
        minIntegrative: const Value(50.0),
        inpsReduction: const Value(true),
        incomeCategories: const Value(['Compensi', 'Consulenze']),
        // A figure and an answered "from the ledger" (null): both must survive.
        declaredIncome: const Value({'2025': 40000.0, '2024': null}),
        lastUpdated: Value(t),
      ));
  await d.into(d.pivaPayments).insert(PivaPaymentsCompanion.insert(
        id: 'pay1',
        userId: const Value('user-a'),
        key: const Value('2026:imposta_saldo'),
        kind: const Value('imposta'),
        label: const Value('Saldo imposta'),
        dueDate: Value(DateTime(2026, 6, 30, 12)),
        amount: const Value(812.4),
        paidDate: Value(DateTime(2026, 6, 28, 12)),
        note: const Value('F24 dal commercialista'),
        lastUpdated: Value(t),
      ));
  await d.into(d.pivaPayments).insert(PivaPaymentsCompanion.insert(
        id: 'pay2',
        userId: const Value('user-a'),
        kind: const Value('contributi'),
        label: const Value('Contributi extra'),
        dueDate: Value(DateTime(2026, 11, 30, 12)),
        amount: const Value(250.0),
        lastUpdated: Value(t),
      ));
}

void main() {
  setUpAll(_ensureSqlite);

  late PersistenceService persistence;
  late Directory dir;
  late AppDatabase db;
  late GoogleAuthService auth;

  BackupService serviceFor(AppDatabase d) =>
      BackupService(d, GoogleDriveService(auth), auth);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    persistence = PersistenceService(await SharedPreferences.getInstance());
    await persistence.setAutoBackupEnabled(true);
    dir = await Directory.systemTemp.createTemp('budgetti_backup_');
    // A custom folder keeps the auto-backup path clear of path_provider.
    await persistence.setCustomBackupPath(dir.path);

    db = AppDatabase.forExecutor(NativeDatabase.memory());
    await db.into(db.accounts).insert(AccountsCompanion.insert(
          id: 'acc1',
          userId: const Value('user-a'),
          name: 'Widiba',
        ));
    await db.into(db.transactions).insert(TransactionsCompanion.insert(
          id: 'tx1',
          userId: const Value('user-a'),
          accountId: const Value('acc1'),
          amount: -12.5,
          description: 'Conad',
          category: 'Groceries',
          date: DateTime(2026, 6, 23),
        ));
    auth = GoogleAuthService();
  });

  tearDown(() async {
    await db.close();
    await dir.delete(recursive: true);
  });

  // Both `Isolate.run(() => jsonEncode(data))` in _createBackupFile and the
  // decode in importDatabase shared their async method's closure Context,
  // which holds `this` -> AppDatabase -> live Futures/finalizers, so
  // Isolate.run threw "object is unsendable". Export, Drive backup, auto-backup
  // and restore all went through them; the real Isolate.run is exercised here.
  test('a live database exports to a backup file (real Isolate.run)', () async {
    expect(await serviceFor(db).performAutoBackup(persistence), isTrue,
        reason: 'performAutoBackup answers false when the export throws');

    final file = dir.listSync().whereType<File>().single;
    final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    expect((json['transactions'] as List).single['description'], 'Conad');
  });

  test('a backup file restores into a fresh database (real Isolate.run)',
      () async {
    // Built here, not by BackupService, so this fails on the decode alone.
    final file = File('${dir.path}/handmade.json');
    await file.writeAsString(jsonEncode({
      'accounts': [for (final r in await db.select(db.accounts).get()) r.toJson()],
      'transactions': [
        for (final r in await db.select(db.transactions).get()) r.toJson()
      ],
      'categories': const [],
      'tags': const [],
      'budgets': const [],
    }));

    final fresh = AppDatabase.forExecutor(NativeDatabase.memory());
    addTearDown(fresh.close);
    await serviceFor(fresh).importDatabase(file);

    final restored = await fresh.select(fresh.transactions).get();
    expect(restored.single.description, 'Conad');
    expect(restored.single.amount, -12.5);
  });

  // The owner's real safety net is export -> restore: every table the exporter
  // writes must come back field for field, not just the ones a handmade file has.
  test('export then restore returns every table field for field', () async {
    final t = DateTime(2026, 6, 23, 12);
    await db.into(db.accounts).insert(AccountsCompanion.insert(
          id: 'acc2',
          userId: const Value('user-a'),
          name: 'Revolut',
          balance: const Value(100.5),
          providerName: const Value('revolut'),
          isDefault: const Value(true),
          initialBalanceDate: Value(DateTime(2026, 1, 1)),
          lastUpdated: Value(t),
        ));
    await db.into(db.categories).insert(CategoriesCompanion.insert(
          id: 'cat1',
          userId: const Value('user-a'),
          name: 'Groceries',
          iconCode: 57415,
          colorHex: 0xFF0B7A5E,
          type: 'expense',
          description: const Value('weekly shop'),
        ));
    await db.into(db.tags).insert(TagsCompanion.insert(
        id: 'tag1', userId: const Value('user-a'), name: 'eating out', colorHex: 0xFFC2542F));
    await db.into(db.budgets).insert(BudgetsCompanion.insert(
        id: 'bud1',
        userId: const Value('user-a'),
        category: 'Groceries',
        limitAmount: 300,
        period: 'monthly'));
    await db.into(db.installments).insert(InstallmentsCompanion.insert(
          id: 'inst1',
          userId: const Value('user-a'),
          description: 'Sofa',
          totalAmount: 1200,
          installmentCount: 12,
          startDate: DateTime(2026, 1, 15),
          category: const Value('Shopping'),
          accountId: const Value('acc1'),
        ));
    await _seedPiva(db);
    // A transfer with a destination, and a soft-deleted rate-linked charge with tags.
    await db.into(db.transactions).insert(TransactionsCompanion.insert(
          id: 'tx-transfer',
          userId: const Value('user-a'),
          accountId: const Value('acc1'),
          toAccountId: const Value('acc2'),
          amount: 200,
          description: 'Top up',
          category: 'Transfer',
          type: const Value('transfer'),
          date: t,
        ));
    await db.into(db.transactions).insert(TransactionsCompanion.insert(
          id: 'tx-rate',
          userId: const Value('user-a'),
          accountId: const Value('acc1'),
          amount: -100,
          description: 'Sofa rata',
          category: 'Shopping',
          date: t,
          tags: const Value(['eating out', 'x']),
          installmentId: const Value('inst1'),
          isDeleted: const Value(true),
          lastUpdated: Value(t),
        ));

    Future<Map<String, List<Map<String, dynamic>>>> snapshot(AppDatabase d) async {
      Future<List<Map<String, dynamic>>> js(Future<List<DataClass>> rows) async =>
          [for (final r in await rows) r.toJson()]
            ..sort((a, b) => '${a['id']}'.compareTo('${b['id']}'));
      return {
        'accounts': await js(d.select(d.accounts).get()),
        'transactions': await js(d.select(d.transactions).get()),
        'categories': await js(d.select(d.categories).get()),
        'tags': await js(d.select(d.tags).get()),
        'budgets': await js(d.select(d.budgets).get()),
        'installments': await js(d.select(d.installments).get()),
        'piva_profile': await js(d.select(d.pivaProfiles).get()),
        'piva_payments': await js(d.select(d.pivaPayments).get()),
      };
    }

    final before = await snapshot(db);
    // Not vacuous: every table the exporter writes holds at least one row.
    for (final e in before.entries) {
      expect(e.value, isNotEmpty, reason: '${e.key} was not seeded');
    }

    await serviceFor(db).performAutoBackup(persistence);
    final fresh = AppDatabase.forExecutor(NativeDatabase.memory());
    addTearDown(fresh.close);
    await serviceFor(fresh).importDatabase(dir.listSync().whereType<File>().single);

    expect(await snapshot(fresh), before);
    final tx = (await fresh.select(fresh.transactions).get())
        .firstWhere((r) => r.id == 'tx-rate');
    expect(tx.tags, ['eating out', 'x']);
    expect(tx.installmentId, 'inst1');
    expect(tx.isDeleted, isTrue);
  });

  // The web (budgetti-web) reads and writes this shape: collection names as
  // keys, dates in millis, income categories as a JSON array.
  test('the exported file names the Partita IVA collections in the web shape',
      () async {
    await _seedPiva(db);
    await serviceFor(db).performAutoBackup(persistence);
    final file = dir.listSync().whereType<File>().single;
    final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;

    final profile =
        (json['piva_profile'] as List).single as Map<String, dynamic>;
    expect(
        profile.keys,
        unorderedEquals([
          'id',
          'userId',
          'atecoCode',
          'coefficient',
          'startYear',
          'startupRate',
          'fundType',
          'fundName',
          'subjectiveRate',
          'integrativeRate',
          'minSubjective',
          'minIntegrative',
          'inpsReduction',
          'incomeCategories',
          'declaredIncome',
          'isDeleted',
          'lastUpdated',
        ]));
    expect(profile['id'], 'piva1');
    expect(profile['userId'], 'user-a');
    expect(profile['incomeCategories'], ['Compensi', 'Consulenze']);
    expect(profile['declaredIncome'], {'2025': 40000.0, '2024': null},
        reason: 'an object, its null entry kept — what the web writes too');
    expect(profile['lastUpdated'], isA<int>());

    final payments =
        (json['piva_payments'] as List).cast<Map<String, dynamic>>();
    expect(payments, hasLength(2));
    for (final p in payments) {
      expect(
          p.keys,
          unorderedEquals([
            'id',
            'userId',
            'key',
            'kind',
            'label',
            'dueDate',
            'amount',
            'paidDate',
            'note',
            'isDeleted',
            'lastUpdated',
          ]));
      expect(p['userId'], 'user-a');
      expect(p['dueDate'], isA<int>());
    }
    final unpaid = payments.singleWhere((p) => p['id'] == 'pay2');
    expect(unpaid['paidDate'], isNull);
    expect(unpaid['key'], '');
    expect(
        payments.singleWhere((p) => p['id'] == 'pay1')['paidDate'], isA<int>());
  });

  // A backup written by v0.7 predates `declaredIncome`: the key is absent from
  // its piva_profile rows, which must still import (the generated fromJson alone
  // would not coerce it) and read the column as NULL.
  test('a piva_profile row without declaredIncome (a v0.7 backup) imports as '
      'NULL', () async {
    await _seedPiva(db);
    final row = (await db.select(db.pivaProfiles).get()).single.toJson()
      ..remove('declaredIncome');
    final file = File('${dir.path}/v07.json');
    await file.writeAsString(jsonEncode({
      'accounts': const [],
      'transactions': const [],
      'categories': const [],
      'tags': const [],
      'budgets': const [],
      'piva_profile': [row],
    }));

    final fresh = AppDatabase.forExecutor(NativeDatabase.memory());
    addTearDown(fresh.close);
    await serviceFor(fresh).importDatabase(file);

    final restored = (await fresh.select(fresh.pivaProfiles).get()).single;
    expect(restored.id, 'piva1');
    expect(restored.incomeCategories, ['Compensi', 'Consulenze']);
    expect(restored.declaredIncome, isNull);
  });

  // An absent key says nothing about the Partita IVA, so the tables stay; a key
  // that is present replaces its table, even with `[]`. (Installments differ:
  // they are cleared whether or not the file names them.)
  test('a backup without the Partita IVA keys leaves them; present keys replace',
      () async {
    await _seedPiva(db);
    final tx = (await db.select(db.transactions).get()).single.toJson()
      ..['id'] = 'tx-restored'
      ..['description'] = 'Esselunga';

    Future<void> restore(Map<String, dynamic> pivaKeys) async {
      final file = File('${dir.path}/restore.json');
      await file.writeAsString(jsonEncode({
        'accounts': const [],
        'transactions': [tx],
        'categories': const [],
        'tags': const [],
        'budgets': const [],
        ...pivaKeys,
      }));
      await serviceFor(db).importDatabase(file);
    }

    Future<Map<String, List<String>>> pivaIds() async => {
          'profiles': [
            for (final r in await db.select(db.pivaProfiles).get()) r.id
          ]..sort(),
          'payments': [
            for (final r in await db.select(db.pivaPayments).get()) r.id
          ]..sort(),
        };

    await restore({});
    expect((await db.select(db.transactions).get()).map((r) => r.id),
        ['tx-restored']);
    expect(await pivaIds(), {
      'profiles': ['piva1'],
      'payments': ['pay1', 'pay2'],
    });

    // Each key is judged on its own.
    await restore({'piva_payments': const []});
    expect(await pivaIds(), {
      'profiles': ['piva1'],
      'payments': <String>[],
    });

    await restore({'piva_profile': const [], 'piva_payments': const []});
    expect(await pivaIds(), {
      'profiles': <String>[],
      'payments': <String>[],
    });
  });

  test('a failed auto-backup records why, and the next success clears it',
      () async {
    await persistence.setCustomBackupPath('/proc/budgetti-nope/backups');
    final backup = serviceFor(db);

    expect(await backup.performAutoBackup(persistence), isFalse);
    expect(persistence.getLastAutoBackupError(), isNotEmpty);

    await persistence.setCustomBackupPath(dir.path);
    expect(await backup.performAutoBackup(persistence), isTrue);
    expect(persistence.getLastAutoBackupError(), isNull);
  });
}
