import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:budgetti/core/database/database.dart';
import 'package:budgetti/core/services/backup_service.dart';
import 'package:budgetti/core/services/google_auth_service.dart';
import 'package:budgetti/core/services/google_drive_service.dart';
import 'package:drift/native.dart' show NativeDatabase;
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/open.dart' as sqlite3open;

void _ensureSqlite() {
  try {
    sqlite3open.open.overrideFor(
      sqlite3open.OperatingSystem.linux,
      () => DynamicLibrary.open('/lib/x86_64-linux-gnu/libsqlite3.so.0'),
    );
  } catch (_) {}
}

/// A backup produced by the web dashboard's "Pull as backup file" (verbatim
/// shape from an E2E run against PocketBase 0.39.6). The web and the phone
/// must agree on this format or backups stop round-tripping.
const _webExport = '''
{
  "generated_at": "2026-07-21T22:37:11.686Z",
  "categories": [{"id": "e2e-cat-1", "userId": "u", "name": "Groceries", "iconCode": 57954, "colorHex": 4283215696, "type": "expense", "description": "", "isDeleted": false, "lastUpdated": 1784673381901}],
  "tags": [{"id": "e2e-tag-1", "userId": "u", "name": "Work", "colorHex": 4282339765, "isDeleted": false, "lastUpdated": 1784673381901}],
  "accounts": [{"id": "e2e-acc-1", "userId": "u", "name": "Main", "balance": 100, "currency": "EUR", "providerName": "", "isDefault": false, "initialBalanceDate": null, "isDeleted": false, "lastUpdated": 1784673381901}],
  "transactions": [
    {"id": "e2e-tx-1", "userId": "u", "accountId": "e2e-acc-1", "toAccountId": "", "amount": -12.5, "description": "Lunch", "category": "Groceries", "type": "expense", "date": 1784673381901, "tags": ["Work"], "isDeleted": false, "lastUpdated": 1784673381901},
    {"id": "e2e-tx-2", "userId": "u", "accountId": "e2e-acc-1", "toAccountId": "", "amount": 1500, "description": "Salary", "category": "Salary", "type": "income", "date": 1784673381901, "tags": [], "isDeleted": false, "lastUpdated": 1784673381901}
  ],
  "budgets": [{"id": "e2e-bud-1", "userId": "u", "category": "Groceries", "limitAmount": 300, "period": "monthly", "isDeleted": false, "lastUpdated": 1784673381901}]
}
''';

/// The same export once the web writes the two Partita IVA collections too (the
/// shape agreed for budgetti-web: collection names as keys, dates in millis,
/// `incomeCategories` a string array or null, `declaredIncome` an object of
/// years (numbers or null, sorted keys, whole numbers as integers) or null,
/// every field present). The first profile has an integer `coefficient` and a
/// declared income, the second no categories, none declared, and was
/// soft-deleted; the first payment is unpaid with a key, the second has neither
/// a key nor a due date and a zero amount ("acconto non dovuto").
final _webExportWithPiva = jsonEncode({
  ...jsonDecode(_webExport) as Map<String, dynamic>,
  'piva_profile': jsonDecode('''
[
  {"id": "e2e-piva-1", "userId": "u", "atecoCode": "62.01.00", "coefficient": 67, "startYear": 2024, "startupRate": true, "fundType": "gestione_separata", "fundName": "", "subjectiveRate": 26.07, "integrativeRate": 0, "minSubjective": 0, "minIntegrative": 0, "inpsReduction": false, "incomeCategories": ["Compensi"], "declaredIncome": {"2024": null, "2025": 40000}, "isDeleted": false, "lastUpdated": 1784673381901},
  {"id": "e2e-piva-2", "userId": "u", "atecoCode": "", "coefficient": 78, "startYear": 0, "startupRate": false, "fundType": "cassa", "fundName": "Cassa di prova", "subjectiveRate": 10, "integrativeRate": 4, "minSubjective": 500, "minIntegrative": 50, "inpsReduction": false, "incomeCategories": null, "declaredIncome": null, "isDeleted": true, "lastUpdated": 1784673381901}
]'''),
  'piva_payments': jsonDecode('''
[
  {"id": "e2e-pay-1", "userId": "u", "key": "2026:imposta_saldo", "kind": "imposta", "label": "Saldo imposta", "dueDate": 1782817200000, "amount": 812.4, "paidDate": null, "note": "", "isDeleted": false, "lastUpdated": 1784673381901},
  {"id": "e2e-pay-2", "userId": "u", "key": "", "kind": "contributi", "label": "Contributi", "dueDate": null, "amount": 0, "paidDate": 1782817200000, "note": "acconto non dovuto", "isDeleted": false, "lastUpdated": 1784673381901}
]'''),
});

/// The same export once the web marks splits (budgetti-web#14): `toBackupRow`
/// always writes `othersShare` as a number (0 when unset) and `reimbursesId` as
/// `null` when empty. `e2e-tx-1` is a 100 dinner the others owe 75 of,
/// `e2e-tx-3` the income that pays it back, `e2e-tx-4` a plain income whose
/// `reimbursesId` is an empty string (PocketBase's unset text).
final _webExportWithSplit = jsonEncode({
  ...jsonDecode(_webExport) as Map<String, dynamic>,
  'transactions': jsonDecode('''
[
  {"id": "e2e-tx-1", "userId": "u", "accountId": "e2e-acc-1", "toAccountId": "", "amount": -100, "description": "Dinner", "category": "Groceries", "type": "expense", "date": 1784673381901, "tags": [], "othersShare": 75, "reimbursesId": null, "isDeleted": false, "lastUpdated": 1784673381901},
  {"id": "e2e-tx-3", "userId": "u", "accountId": "e2e-acc-1", "toAccountId": "", "amount": 75, "description": "Paid back", "category": "Groceries", "type": "income", "date": 1784673381901, "tags": [], "othersShare": 0, "reimbursesId": "e2e-tx-1", "isDeleted": false, "lastUpdated": 1784673381901},
  {"id": "e2e-tx-4", "userId": "u", "accountId": "e2e-acc-1", "toAccountId": "", "amount": 20, "description": "Gift", "category": "Salary", "type": "income", "date": 1784673381901, "tags": [], "othersShare": 0, "reimbursesId": "", "isDeleted": false, "lastUpdated": 1784673381901}
]'''),
});

void main() {
  test('a backup exported by the web dashboard imports into the app', () async {
    _ensureSqlite();
    final db = AppDatabase.forExecutor(NativeDatabase.memory());
    final backupService =
        BackupService(db, GoogleDriveService(GoogleAuthService()), GoogleAuthService());

    final file = File(
        '${Directory.systemTemp.path}/web_backup_${DateTime.now().microsecondsSinceEpoch}.json');
    await file.writeAsString(_webExport);
    addTearDown(() => file.delete());

    await backupService.importDatabase(file);

    final txs = await db.select(db.transactions).get();
    expect(txs.length, 2);
    final lunch = txs.singleWhere((t) => t.id == 'e2e-tx-1');
    expect(lunch.amount, -12.5);
    expect(lunch.tags, ['Work']);
    // Drift stores DateTime at second precision — sub-second millis truncate.
    expect(lunch.date.millisecondsSinceEpoch, 1784673381000);
    // No split keys at all (an old backup, or the web's omitted ones).
    expect(lunch.othersShare, 0.0);
    expect(lunch.reimbursesId, isNull);

    expect((await db.select(db.categories).get()).single.name, 'Groceries');
    expect((await db.select(db.accounts).get()).single.balance, 100);
    expect((await db.select(db.tags).get()).single.name, 'Work');
    expect((await db.select(db.budgets).get()).single.limitAmount, 300);

    // sanity: the parsed JSON really is the wire shape (millis, list tags)
    final decoded = jsonDecode(_webExport) as Map<String, dynamic>;
    expect((decoded['transactions'] as List).first['date'], isA<int>());
  });

  test('a web backup with the Partita IVA collections imports into the app',
      () async {
    _ensureSqlite();
    final db = AppDatabase.forExecutor(NativeDatabase.memory());
    addTearDown(db.close);
    final backupService =
        BackupService(db, GoogleDriveService(GoogleAuthService()), GoogleAuthService());

    final file = File(
        '${Directory.systemTemp.path}/web_backup_piva_${DateTime.now().microsecondsSinceEpoch}.json');
    await file.writeAsString(_webExportWithPiva);
    addTearDown(() => file.delete());

    await backupService.importDatabase(file);

    // The rest of the backup still lands.
    expect((await db.select(db.transactions).get()).length, 2);

    final profiles = await db.select(db.pivaProfiles).get();
    expect(profiles.length, 2);
    final live = profiles.singleWhere((p) => p.id == 'e2e-piva-1');
    expect(live.userId, 'u');
    expect(live.atecoCode, '62.01.00');
    expect(live.coefficient, 67.0);
    expect(live.startYear, 2024);
    expect(live.startupRate, isTrue);
    expect(live.fundType, 'gestione_separata');
    expect(live.subjectiveRate, 26.07);
    expect(live.incomeCategories, ['Compensi']);
    expect(live.declaredIncome, {'2025': 40000.0, '2024': null},
        reason: 'the integer reads as a double, the null entry is kept');
    expect(live.declaredIncome!.containsKey('2024'), isTrue);
    expect(live.isDeleted, isFalse);
    // Drift stores DateTime at second precision — sub-second millis truncate.
    expect(live.lastUpdated!.millisecondsSinceEpoch, 1784673381000);
    final retired = profiles.singleWhere((p) => p.id == 'e2e-piva-2');
    expect(retired.coefficient, 78.0);
    expect(retired.fundType, 'cassa');
    expect(retired.integrativeRate, 4.0);
    expect(retired.incomeCategories, isNull);
    expect(retired.declaredIncome, isNull);
    expect(retired.isDeleted, isTrue);

    final payments = await db.select(db.pivaPayments).get();
    expect(payments.length, 2);
    final saldo = payments.singleWhere((p) => p.id == 'e2e-pay-1');
    expect(saldo.key, '2026:imposta_saldo');
    expect(saldo.kind, 'imposta');
    expect(saldo.dueDate!.millisecondsSinceEpoch, 1782817200000);
    expect(saldo.amount, 812.4);
    expect(saldo.paidDate, isNull);
    final zero = payments.singleWhere((p) => p.id == 'e2e-pay-2');
    expect(zero.key, '');
    expect(zero.dueDate, isNull);
    expect(zero.amount, 0.0);
    expect(zero.paidDate!.millisecondsSinceEpoch, 1782817200000);
    expect(zero.note, 'acconto non dovuto');
  });

  test('a web backup with a shared expense and its reimbursement imports into '
      'the app', () async {
    _ensureSqlite();
    final db = AppDatabase.forExecutor(NativeDatabase.memory());
    addTearDown(db.close);
    final backupService =
        BackupService(db, GoogleDriveService(GoogleAuthService()), GoogleAuthService());

    final file = File(
        '${Directory.systemTemp.path}/web_backup_split_${DateTime.now().microsecondsSinceEpoch}.json');
    await file.writeAsString(_webExportWithSplit);
    addTearDown(() => file.delete());

    await backupService.importDatabase(file);

    final txs = {
      for (final t in await db.select(db.transactions).get()) t.id: t
    };
    expect(txs.length, 3);
    // An integer 75 reads as 75.0, and the web's null as no link.
    expect(txs['e2e-tx-1']!.amount, -100.0);
    expect(txs['e2e-tx-1']!.othersShare, 75.0);
    expect(txs['e2e-tx-1']!.reimbursesId, isNull);
    expect(txs['e2e-tx-3']!.othersShare, 0.0);
    expect(txs['e2e-tx-3']!.reimbursesId, 'e2e-tx-1');
    expect(txs['e2e-tx-4']!.othersShare, 0.0);
    expect(txs['e2e-tx-4']!.reimbursesId, isNull,
        reason: "an empty string is not a link to ''");
  });
}
