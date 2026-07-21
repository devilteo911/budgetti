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

    expect((await db.select(db.categories).get()).single.name, 'Groceries');
    expect((await db.select(db.accounts).get()).single.balance, 100);
    expect((await db.select(db.tags).get()).single.name, 'Work');
    expect((await db.select(db.budgets).get()).single.limitAmount, 300);

    // sanity: the parsed JSON really is the wire shape (millis, list tags)
    final decoded = jsonDecode(_webExport) as Map<String, dynamic>;
    expect((decoded['transactions'] as List).first['date'], isA<int>());
  });
}
