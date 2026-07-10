import 'dart:ffi';

import 'package:budgetti/core/database/database.dart';
import 'package:budgetti/core/services/persistence_service.dart';
import 'package:budgetti/core/services/pocketbase_sync_service.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart' show NativeDatabase;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/open.dart' as sqlite3open;

// `flutter test` runs in the VM without sqlite3_flutter_libs' bundled native,
// so point the FFI loader at the system library (.so.0 — no -dev symlink here).
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

/// In-memory PocketBase stand-in: mirrors what the real client does —
/// `listChanges` filters by `lastUpdated > since`, `upsert` stores by id.
class _FakeClient implements SyncClient {
  @override
  final String userId;
  final Map<String, Map<String, Map<String, dynamic>>> _store = {};

  _FakeClient(this.userId);

  @override
  Future<List<Map<String, dynamic>>> listChanges(
      String c, DateTime since) async {
    final entries = _store[c]?.entries.toList() ?? const [];
    return entries.where((e) {
      final lu = e.value['lastUpdated'] as String?;
      if (lu == null) return false;
      return DateTime.parse(lu).isAfter(since);
    }).map((e) => {...e.value, 'id': e.key}).toList();
  }

  @override
  Future<void> upsert(String c, String id, Map<String, dynamic> body) async {
    _store.putIfAbsent(c, () => {})[id] = Map<String, dynamic>.from(body);
  }

  /// Test seam: mutate a stored row the way another device would.
  void edit(String c, String id, Map<String, dynamic> patch) {
    final row = _store[c]?[id];
    if (row != null) _store[c]![id] = {...row, ...patch};
  }
}

Future<(AppDatabase, PersistenceService, _FakeClient, PocketBaseSyncService)>
    _harness({String userId = 'u1', Map<String, dynamic>? initialStore}) async {
  _ensureSqlite();
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final persistence = PersistenceService(prefs);
  final db = AppDatabase.forExecutor(NativeDatabase.memory());
  // onCreate/beforeOpen seed default categories/tags/account with NULL
  // lastUpdated. Clear them so each test controls exactly what it syncs.
  await db.delete(db.categories).go();
  await db.delete(db.tags).go();
  await db.delete(db.accounts).go();
  await db.delete(db.transactions).go();
  await db.delete(db.budgets).go();
  final client = _FakeClient(userId);
  if (initialStore != null) {
    for (final entry in initialStore.entries) {
      client._store[entry.key] =
          Map<String, Map<String, dynamic>>.from(entry.value);
    }
  }
  final service =
      PocketBaseSyncService(client, db, persistence, userId);
  return (db, persistence, client, service);
}

Future<Category?> _category(AppDatabase db, String id) =>
    (db.select(db.categories)..where((t) => t.id.equals(id))).getSingleOrNull();

void main() {
  test('first sync: pushes all local rows, advances the cursor', () async {
    final (db, persistence, client, service) = await _harness();
    final t1 = DateTime(2026, 7, 1, 10);
    await db.into(db.categories).insert(CategoriesCompanion.insert(
          id: 'c1',
          name: 'Food',
          iconCode: 1,
          colorHex: 2,
          type: 'expense',
          userId: const Value('u1'),
          lastUpdated: Value(t1),
        ));
    await db.into(db.transactions).insert(TransactionsCompanion.insert(
          id: 'tx1',
          userId: const Value('u1'),
          amount: -12.5,
          description: 'Lunch',
          category: 'Food',
          date: t1,
          lastUpdated: Value(t1.add(const Duration(hours: 1))),
        ));

    final summary = await service.sync();

    expect(summary.pushed, 2);
    expect(summary.pulled, 0);
    expect(client._store['categories']?['c1'], isNotNull);
    expect(client._store['transactions']?['tx1'], isNotNull);
    expect(client._store['categories']!['c1']!['name'], 'Food');
    // Cursor = max lastUpdated seen (tx1's 11:00).
    expect(persistence.getLastSyncAt(), t1.add(const Duration(hours: 1)));
  });

  test('second sync with no changes is a no-op', () async {
    final (db, persistence, client, service) = await _harness();
    await db.into(db.categories).insert(CategoriesCompanion.insert(
          id: 'c1',
          name: 'Food',
          iconCode: 1,
          colorHex: 2,
          type: 'expense',
          userId: const Value('u1'),
          lastUpdated: Value(DateTime(2026, 7, 1, 10)),
        ));
    await service.sync();
    final cursor = persistence.getLastSyncAt();

    final summary = await service.sync();

    expect(summary.pushed, 0);
    expect(summary.pulled, 0);
    expect(persistence.getLastSyncAt(), cursor);
  });

  test('LWW: newer remote row overwrites local', () async {
    final (db, persistence, client, service) = await _harness();
    await db.into(db.categories).insert(CategoriesCompanion.insert(
          id: 'c1',
          name: 'Old',
          iconCode: 1,
          colorHex: 2,
          type: 'expense',
          userId: const Value('u1'),
          lastUpdated: Value(DateTime(2026, 7, 1, 10)),
        ));
    await service.sync(); // push local, cursor = 10:00

    // Another device edits the same row newer.
    client.edit('categories', 'c1', {
      'name': 'New',
      'lastUpdated': DateTime(2026, 7, 2, 10).toUtc().toIso8601String(),
    });

    final summary = await service.sync();
    expect(summary.pulled, 1);
    final row = await _category(db, 'c1');
    expect(row?.name, 'New');
  });

  test('LWW conflict: newer local row wins and is pushed', () async {
    final (db, persistence, client, service) = await _harness();
    await db.into(db.categories).insert(CategoriesCompanion.insert(
          id: 'c1',
          name: 'Local',
          iconCode: 1,
          colorHex: 2,
          type: 'expense',
          userId: const Value('u1'),
          lastUpdated: Value(DateTime(2026, 7, 1, 10)),
        ));
    await service.sync();

    // Remote changes to 11:00, local changes to 12:00 (same sync cycle).
    client.edit('categories', 'c1', {
      'name': 'RemoteWins?',
      'lastUpdated': DateTime(2026, 7, 1, 11).toUtc().toIso8601String(),
    });
    await (db.update(db.categories)..where((t) => t.id.equals('c1'))).write(
        CategoriesCompanion(
            name: const Value('LocalWins'),
            lastUpdated: Value(DateTime(2026, 7, 1, 12))));

    final summary = await service.sync();
    expect(summary.conflicts, 1);
    expect(summary.pulled, 0); // local won, remote not applied
    // Remote now reflects the local winner.
    expect(client._store['categories']!['c1']!['name'], 'LocalWins');
    final row = await _category(db, 'c1');
    expect(row?.name, 'LocalWins');
  });

  test('deletes propagate as tombstones to a fresh device', () async {
    final (db, persistence, client, service) = await _harness();
    await db.into(db.categories).insert(CategoriesCompanion.insert(
          id: 'c1',
          name: 'Food',
          iconCode: 1,
          colorHex: 2,
          type: 'expense',
          userId: const Value('u1'),
          lastUpdated: Value(DateTime(2026, 7, 1, 10)),
        ));
    // Device A deletes it (soft delete + stamp).
    await (db.update(db.categories)..where((t) => t.id.equals('c1'))).write(
        CategoriesCompanion(
            isDeleted: const Value(true),
            lastUpdated: Value(DateTime(2026, 7, 2, 10))));
    await service.sync();
    expect(client._store['categories']!['c1']!['isDeleted'], true);

    // Device B: fresh DB + fresh cursor (reset the process-wide mock), same
    // server, pulls the tombstone.
    SharedPreferences.setMockInitialValues({});
    final prefs2 = await SharedPreferences.getInstance();
    final persistence2 = PersistenceService(prefs2);
    final db2 = AppDatabase.forExecutor(NativeDatabase.memory());
    await db2.delete(db2.categories).go();
    final service2 =
        PocketBaseSyncService(client, db2, persistence2, 'u1');

    final summary = await service2.sync();
    expect(summary.pulled, greaterThanOrEqualTo(1));
    final row = await _category(db2, 'c1');
    expect(row, isNotNull);
    expect(row!.isDeleted, true);
  });

  test('NULL lastUpdated (seed/restore) is stamped then not re-pushed',
      () async {
    final (db, persistence, client, service) = await _harness();
    await db.into(db.categories).insert(CategoriesCompanion.insert(
          id: 'c1',
          name: 'Food',
          iconCode: 1,
          colorHex: 2,
          type: 'expense',
          userId: const Value('u1'),
          // lastUpdated omitted → null (a seed or restored row).
        ));

    final first = await service.sync();
    expect(first.pushed, 1);
    // Stamp written back to Drift.
    final row = await _category(db, 'c1');
    expect(row?.lastUpdated, isNotNull);
    expect(client._store['categories']!['c1'], isNotNull);

    // Second sync must not re-push the now-stamped seed.
    final second = await service.sync();
    expect(second.pushed, 0);
  });
}
