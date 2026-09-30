import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:budgetti/core/database/database.dart';
import 'package:budgetti/core/services/backup_service.dart';
import 'package:budgetti/core/services/google_auth_service.dart';
import 'package:budgetti/core/services/google_drive_service.dart';
import 'package:budgetti/core/services/persistence_service.dart';
import 'package:drift/drift.dart' show Value;
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
