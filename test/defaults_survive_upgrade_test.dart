import 'dart:ffi';
import 'dart:io';

import 'package:budgetti/core/database/database.dart';
import 'package:budgetti/core/services/finance_service.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart' show NativeDatabase;
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/open.dart' as sqlite3open;
import 'package:sqlite3/sqlite3.dart' as sqlite;

import 'fixtures/owner_defaults_fixture.dart';

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

const owner = 'owner';
const beforeStamp = 1784585637; // what the five rows still carried before the batch

DateTime _at(int seconds) => DateTime.fromMillisecondsSinceEpoch(seconds * 1000);

/// The owner's defaults as they stood just BEFORE the batch: every row the
/// batch stamped is still live, stamped with its old date. [exportedCategories]
/// is the state after it.
Future<void> seedBeforeTheBatch(AppDatabase db) async {
  for (final (id, name, type, icon, color, deleted, sec) in exportedCategories) {
    final hit = sec == theBatchSecond;
    await db.into(db.categories).insert(CategoriesCompanion.insert(
          id: id,
          name: name,
          iconCode: icon,
          colorHex: color,
          type: type,
          userId: const Value(owner),
          isDeleted: Value(hit ? false : deleted),
          lastUpdated: Value(_at(hit ? beforeStamp : sec)),
        ));
  }
  for (final (id, name, color, deleted, sec) in exportedTags) {
    final hit = sec == theBatchSecond;
    await db.into(db.tags).insert(TagsCompanion.insert(
          id: id,
          name: name,
          colorHex: color,
          userId: const Value(owner),
          isDeleted: Value(hit ? false : deleted),
          lastUpdated: Value(_at(hit ? beforeStamp : sec)),
        ));
  }
  // Live spending that names the five, as the owner's ledger does.
  await db.into(db.accounts).insert(AccountsCompanion.insert(
      id: 'acc', name: 'Wallet', userId: const Value(owner)));
  var n = 0;
  for (final name in vanishedDefaults) {
    await db.into(db.transactions).insert(TransactionsCompanion.insert(
          id: 't${n++}',
          userId: const Value(owner),
          accountId: const Value('acc'),
          amount: -10,
          description: 'spent on $name',
          category: name,
          date: DateTime(2026, 9, 1),
        ));
  }
}

/// Every row's (id, is_deleted, last_updated) — what a migration must not touch.
Future<List<String>> _stamps(AppDatabase db) async {
  final out = <String>[];
  for (final table in ['categories', 'tags']) {
    final rows = await db
        .customSelect('SELECT id, is_deleted, last_updated FROM $table ORDER BY id')
        .get();
    for (final r in rows) {
      out.add('$table ${r.read<String>('id')} del=${r.read<int>('is_deleted')} '
          'at=${r.read<int?>('last_updated')}');
    }
  }
  return out;
}

void main() {
  setUpAll(_ensureSqlite);

  // The five defaults disappeared in one second, on the first launch after an
  // upgrade from an older build. Nothing an upgrade does may hide a row: it
  // soft-deletes under a fresh stamp, that stamp wins last-write-wins, and the
  // deletion then travels to every device. Duplicated defaults are cosmetic;
  // a hidden row is data loss.
  group('an upgrade from an older build leaves every category and tag as it was',
      () {
    for (final from in [1, 5, 9, 11]) {
      test('from user_version $from', () async {
        final dir = Directory.systemTemp.createTempSync('upgrade');
        addTearDown(() => dir.deleteSync(recursive: true));
        final file = File('${dir.path}/db.sqlite');

        var db = AppDatabase.forExecutor(NativeDatabase(file));
        await seedBeforeTheBatch(db);
        final before = await _stamps(db);
        await db.close();

        // An older build opened this database and rewrote user_version.
        final raw = sqlite.sqlite3.open(file.path);
        raw.execute('PRAGMA user_version = $from');
        raw.dispose();

        db = AppDatabase.forExecutor(NativeDatabase(file));
        addTearDown(db.close);
        await db.select(db.accounts).get(); // opens it: the upgrade runs here

        expect(await _stamps(db), before);
      });
    }
  });

  // The first launch after the upgrade runs more than the migration: seeding,
  // the icon repair, the owner's first reads. None of it may hide a row either.
  test('first launch reads and repairs defaults without hiding any', () async {
    final db = AppDatabase.forExecutor(NativeDatabase.memory());
    addTearDown(db.close);
    await seedBeforeTheBatch(db);
    final before = await _stamps(db);

    // uidA_… is the family the icon repair looks for when the user id is uidA.
    for (final uid in [owner, 'uidA', 'local']) {
      final service = FinanceService(db, uid);
      await service.getAccounts();
      await service.getCategories();
      await service.getTags();
    }

    final after = await _stamps(db);
    // The repair may re-stamp an icon; it must never flip is_deleted.
    expect([for (final s in after) s.replaceAll(RegExp(r' at=\S+'), '')],
        [for (final s in before) s.replaceAll(RegExp(r' at=\S+'), '')]);
  });

  // Without the migration's dedupe the duplicates stay live, so the lists
  // collapse them: one row per (name, type), the oldest copy, as the dedupe kept.
  test('the category and tag lists show each default once', () async {
    final db = AppDatabase.forExecutor(NativeDatabase.memory());
    addTearDown(db.close);
    await seedBeforeTheBatch(db);
    final service = FinanceService(db, owner);

    final cats = await service.getCategories();
    final names = [for (final c in cats) '${c.name}/${c.type}'];
    expect(names.toSet(), hasLength(names.length), reason: 'no duplicates: $names');
    for (final name in vanishedDefaults) {
      expect(names, contains('$name/expense'));
    }
    // The oldest live copy wins: uidA's, not the later seed families'.
    expect([for (final c in cats) c.id],
        containsAll(['uidA_cat_Groceries', 'uidA_cat_Bills']));

    final tags = [for (final t in await service.getTags()) t.name];
    expect(tags.toSet(), hasLength(tags.length), reason: 'no duplicates: $tags');

    // The same holds for the stream the screens watch.
    final watched = await service.watchCategories().first;
    expect([for (final c in watched) '${c.name}/${c.type}'], names);
  });
}
