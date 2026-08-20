import 'dart:async';
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

  /// Test seam: collections the server doesn't serve at all — a 404 before
  /// their migration has run, or a permissions/outage failure.
  final Set<String> failCollections = {};

  /// Simulates the server-side LWW guard (pb_hooks/lww_guard.pb.js): a pushed
  /// body whose lastUpdated is older than the stored row's is rejected.
  bool enforceLww = false;

  /// Simulates an expired/revoked token: every call throws [SyncAuthExpired].
  bool authExpired = false;

  /// Held by tests that need a sync to pause mid-flight (lock testing).
  Future<void>? gate;

  @override
  Future<List<Map<String, dynamic>>> listChanges(
      String c, DateTime since) async {
    if (gate != null) await gate;
    if (authExpired) throw const SyncAuthExpired();
    if (failCollections.contains(c)) throw Exception('404: no collection $c');
    final entries = _store[c]?.entries.toList() ?? const [];
    return entries.where((e) {
      final lu = e.value['lastUpdated'] as String?;
      if (lu == null) return false;
      return DateTime.parse(lu).isAfter(since);
    }).map((e) => {...e.value, 'id': e.key}).toList();
  }

  /// Test seam: ids the server refuses (bad id pattern, validation, outage).
  final Set<String> reject = {};

  /// Fires before each upsert — lets a test play "another device wrote during
  /// our push", the exact window the server guard exists for.
  void Function(String c, String id)? onBeforeUpsert;

  @override
  Future<Map<String, dynamic>> upsert(
      String c, String id, Map<String, dynamic> body) async {
    if (authExpired) throw const SyncAuthExpired();
    if (reject.contains(id)) throw Exception('rejected: $id');
    if (onBeforeUpsert != null) onBeforeUpsert!(c, id);
    final stored = _store[c]?[id];
    if (enforceLww && stored != null) {
      final current = stored['lastUpdated'] as String?;
      final incoming = body['lastUpdated'] as String?;
      if (current != null &&
          incoming != null &&
          incoming.compareTo(current) < 0) {
        throw LwwStaleWrite(c, id);
      }
    }
    _store.putIfAbsent(c, () => {})[id] = Map<String, dynamic>.from(body);
    return {..._store[c]![id]!, 'id': id};
  }

  @override
  Future<Map<String, dynamic>> getRecord(String c, String id) async {
    if (authExpired) throw const SyncAuthExpired();
    final row = _store[c]?[id];
    if (row == null) throw Exception('404: $c/$id');
    return {...row, 'id': id};
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
  await db.delete(db.installments).go();
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
  test('a row the server rejects is retried on the next sync', () async {
    final (db, persistence, client, service) = await _harness();
    // NULL lastUpdated = the seed / restored-backup path, which is how a
    // restored ledger arrives. These are the rows that got stamped-then-lost.
    for (final id in ['c1', 'c2']) {
      await db.into(db.categories).insert(CategoriesCompanion.insert(
            id: id,
            name: id,
            iconCode: 1,
            colorHex: 2,
            type: 'expense',
            userId: const Value('u1'),
          ));
    }
    client.reject.add('c2');

    final first = await service.sync();
    expect(first.pushed, 1);
    expect(first.skipped, 1);

    // Whatever made the server refuse it is gone (outage over, id fixed).
    client.reject.clear();
    final second = await service.sync();

    expect(second.pushed, 1,
        reason: 'c2 must be retried, not silently dropped forever');
    expect(client._store['categories']!.containsKey('c2'), isTrue);
  });

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

  test('full push rescues rows stranded behind a poisoned cursor', () async {
    final (db, persistence, client, service) = await _harness();
    final t1 = DateTime(2026, 7, 1, 10);
    await db.into(db.categories).insert(CategoriesCompanion.insert(
          id: 'c1',
          name: 'Stranded',
          iconCode: 1,
          colorHex: 2,
          type: 'expense',
          userId: const Value('u1'),
          lastUpdated: Value(t1),
        ));
    // The historical bug: cursor advanced past the row without it ever
    // reaching the server.
    await persistence.setLastSyncAt(DateTime(2026, 7, 10));

    final incremental = await service.sync();
    expect(incremental.pushed, 0, reason: 'incremental cannot see it');

    final fullPush = await service.sync(full: true, pull: false);
    expect(fullPush.pushed, 1);
    expect(client._store['categories']!['c1']!['name'], 'Stranded');
    // One-way runs must not move the cursor.
    expect(persistence.getLastSyncAt(), DateTime(2026, 7, 10));
  });

  test('a rejected timestamped row rewinds the cursor and is retried',
      () async {
    final (db, persistence, client, service) = await _harness();
    final t1 = DateTime(2026, 7, 1, 10);
    final t2 = DateTime(2026, 7, 1, 11);
    await db.into(db.categories).insert(CategoriesCompanion.insert(
          id: 'c1',
          name: 'Rejected',
          iconCode: 1,
          colorHex: 2,
          type: 'expense',
          userId: const Value('u1'),
          lastUpdated: Value(t1),
        ));
    await db.into(db.categories).insert(CategoriesCompanion.insert(
          id: 'c2',
          name: 'Accepted',
          iconCode: 1,
          colorHex: 2,
          type: 'expense',
          userId: const Value('u1'),
          lastUpdated: Value(t2),
        ));
    client.reject.add('c1');

    final first = await service.sync();
    expect(first.pushed, 1);
    expect(first.skipped, 1);
    // Cursor must stay behind the rejected row, not jump to t2.
    expect(persistence.getLastSyncAt().isBefore(t1), isTrue);

    client.reject.clear();
    final second = await service.sync();
    expect(client._store['categories']!.containsKey('c1'), isTrue,
        reason: 'c1 must be retried once the server accepts it again');
    expect(second.skipped, 0);
  });

  test('an installment plan round-trips push → pull with every field', () async {
    final (db, _, client, service) = await _harness();
    final t1 = DateTime(2026, 7, 1, 10);
    await db.into(db.installments).insert(InstallmentsCompanion.insert(
          id: 'ins1',
          userId: const Value('u1'),
          description: 'Divano',
          totalAmount: 2400,
          installmentCount: 24,
          startDate: DateTime(2026, 2, 15),
          category: const Value('Shopping'),
          accountId: const Value('acc1'),
          lastUpdated: Value(t1),
        ));
    // A charge attached to the plan: the link rides on the transaction.
    await db.into(db.transactions).insert(TransactionsCompanion.insert(
          id: 'tx1',
          userId: const Value('u1'),
          amount: -100,
          description: 'Rata divano',
          category: 'Shopping',
          date: t1,
          installmentId: const Value('ins1'),
          lastUpdated: Value(t1),
        ));

    await service.sync();

    expect(client._store['transactions']!['tx1']!['installmentId'], 'ins1');

    // The pushed body must use exactly the PocketBase field names from
    // pb_migrations/1751000007_installments.js — a typo here syncs silently
    // wrong data.
    final pushed = client._store['installments']!['ins1']!;
    expect(pushed['description'], 'Divano');
    expect(pushed['totalAmount'], 2400);
    expect(pushed['installmentCount'], 24);
    expect(pushed['startDate'], DateTime(2026, 2, 15).toUtc().toIso8601String());
    expect(pushed['category'], 'Shopping');
    expect(pushed['accountId'], 'acc1');
    expect(pushed['isDeleted'], false);

    // A fresh device pulls it back into Drift unchanged.
    SharedPreferences.setMockInitialValues({});
    final prefs2 = await SharedPreferences.getInstance();
    final db2 = AppDatabase.forExecutor(NativeDatabase.memory());
    await db2.delete(db2.installments).go();
    await db2.delete(db2.transactions).go();
    final service2 = PocketBaseSyncService(
        client, db2, PersistenceService(prefs2), 'u1');

    await service2.sync();

    final row = await (db2.select(db2.installments)
          ..where((t) => t.id.equals('ins1')))
        .getSingleOrNull();
    expect(row, isNotNull);
    expect(row!.description, 'Divano');
    expect(row.totalAmount, 2400);
    expect(row.installmentCount, 24);
    expect(row.startDate.toUtc(), DateTime(2026, 2, 15).toUtc());
    expect(row.category, 'Shopping');
    expect(row.accountId, 'acc1');

    // The link survives the round-trip too, so the other device shows the same
    // rate attached to the same plan.
    final tx = await (db2.select(db2.transactions)
          ..where((t) => t.id.equals('tx1')))
        .getSingleOrNull();
    expect(tx?.installmentId, 'ins1');
  });

  test('an unlinked transaction stays unlinked through PocketBase', () async {
    // PB stores an unset text field as '', not null — pulled back naively that
    // becomes an empty plan id, which reads as "linked to nothing".
    final t1 = DateTime(2026, 7, 1, 10);
    final (db, _, __, service) = await _harness(initialStore: {
      'transactions': {
        'tx-plain': {
          'accountId': 'acc1',
          'amount': -20.0,
          'description': 'Coffee',
          'category': 'Dining',
          'type': 'expense',
          'date': t1.toUtc().toIso8601String(),
          'tags': <String>[],
          'installmentId': '', // PB's empty text
          'isDeleted': false,
          'lastUpdated': t1.toUtc().toIso8601String(),
        },
      },
    });

    await service.sync(full: true, push: false);

    final tx = await (db.select(db.transactions)
          ..where((t) => t.id.equals('tx-plain')))
        .getSingleOrNull();
    expect(tx, isNotNull);
    expect(tx!.installmentId, isNull);
  });

  test('a collection the server does not have yet cannot break the others',
      () async {
    // The upgrade window: a phone on the new build syncing against a server
    // whose installments migration has not run. That 404 used to abort the
    // whole sync, taking the ledger down with it.
    final (db, persistence, client, service) = await _harness();
    final t1 = DateTime(2026, 7, 1, 10);
    client.failCollections.add('installments');
    await db.into(db.categories).insert(CategoriesCompanion.insert(
          id: 'c1',
          name: 'Food',
          iconCode: 1,
          colorHex: 2,
          type: 'expense',
          userId: const Value('u1'),
          lastUpdated: Value(t1),
        ));

    final summary = await service.sync();

    expect(summary.pushed, 1, reason: 'categories still sync');
    expect(summary.skipped, 1, reason: 'the failure is reported, not hidden');
    expect(summary.error, isNull, reason: 'the run is partial, not failed');
    // The cursor is global — advancing it would strand installments forever.
    expect(persistence.getLastSyncAt(),
        DateTime.fromMillisecondsSinceEpoch(0));

    // Once the server catches up, the frozen cursor lets everything through.
    client.failCollections.clear();
    await db.into(db.installments).insert(InstallmentsCompanion.insert(
          id: 'ins1',
          userId: const Value('u1'),
          description: 'Divano',
          totalAmount: 1200,
          installmentCount: 12,
          startDate: DateTime(2026, 6, 1),
          lastUpdated: Value(t1),
        ));
    final second = await service.sync();
    expect(second.skipped, 0);
    expect(client._store['installments']!.containsKey('ins1'), isTrue);
    expect(persistence.getLastSyncAt(), t1);
  });

  test('server LWW rejection adopts the remote row (remote wins)', () async {
    final (db, persistence, client, service) = await _harness();
    client.enforceLww = true;
    final t1 = DateTime(2026, 7, 1, 10);
    await db.into(db.categories).insert(CategoriesCompanion.insert(
          id: 'c1',
          name: 'Base',
          iconCode: 1,
          colorHex: 2,
          type: 'expense',
          userId: const Value('u1'),
          lastUpdated: Value(t1),
        ));
    await service.sync(); // push, cursor = 10:00

    // The pull has already passed; another device writes a *newer* row while
    // our (stale) local edit is being pushed — the exact window the server
    // guard exists for.
    await (db.update(db.categories)..where((t) => t.id.equals('c1'))).write(
        CategoriesCompanion(
            name: const Value('StaleLocal'),
            lastUpdated: Value(DateTime(2026, 7, 1, 11))));
    client.onBeforeUpsert = (c, id) {
      client.onBeforeUpsert = null; // fire once, on the stale push itself
      client.edit('categories', 'c1', {
        'name': 'FreshRemote',
        'lastUpdated': DateTime(2026, 7, 1, 12).toUtc().toIso8601String(),
      });
    };

    final summary = await service.sync();

    expect(summary.pulled, 0, reason: 'the remote edit lands after the pull');
    expect(summary.remoteWins, 1);
    expect(summary.skipped, 0, reason: 'remote-wins is not a skip');
    final row = await _category(db, 'c1');
    expect(row?.name, 'FreshRemote', reason: 'local adopted the remote body');
    expect(row?.lastUpdated, DateTime(2026, 7, 1, 12));
    // The cursor advanced past the row — no rewind, no re-pick of the fight.
    expect(persistence.getLastSyncAt(), DateTime(2026, 7, 1, 12));
  });

  test('an expired token aborts the sync and freezes the cursor', () async {
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
    await service.sync();
    expect(persistence.getLastSyncAt(), t1);

    client.authExpired = true;
    final summary = await service.sync();

    expect(summary.authExpired, isTrue);
    expect(summary.pushed, 0);
    expect(service.sessionExpired.value, isTrue);
    // Cursor frozen: the aborted run must not pretend both sides agreed.
    expect(persistence.getLastSyncAt(), t1);
  });

  test('a second service instance bows out while a sync holds the lock',
      () async {
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

    final gate = Completer<void>();
    client.gate = gate.future;
    final first = service.sync(); // claims the lock, parks in listChanges
    await Future<void>.delayed(const Duration(milliseconds: 100));

    // A fresh instance over the same DB — the workmanager task's shape.
    final service2 = PocketBaseSyncService(client, db, persistence, 'u1');
    final second = await service2.sync();
    expect(second.hasChanges, isFalse,
        reason: 'the second run must bow out, not interleave');
    expect(service2.isSyncing, isFalse);

    gate.complete();
    final s1 = await first;
    expect(s1.pushed, 1);

    // Lock released in finally: a follow-up run syncs normally.
    client.gate = null;
    final third = await service2.sync();
    expect(third.error, isNull);
  });

  test('a stale lock holder is taken over after the timeout', () async {
    final (db, _, client, service) = await _harness();
    // A crashed bg task's claim, 20 minutes old.
    await db.into(db.syncLocks).insert(SyncLocksCompanion.insert(
          id: 'pb_sync',
          running: const Value(true),
          acquiredAt: Value(DateTime.now().subtract(
            const Duration(minutes: 20),
          )),
        ));
    await db.into(db.categories).insert(CategoriesCompanion.insert(
          id: 'c1',
          name: 'Food',
          iconCode: 1,
          colorHex: 2,
          type: 'expense',
          userId: const Value('u1'),
          lastUpdated: Value(DateTime(2026, 7, 1, 10)),
        ));

    final summary = await service.sync();
    expect(summary.pushed, 1, reason: 'stale claim must not deadlock sync');
  });

  test('pull-only does not push, push-only does not pull', () async {
    final t1 = DateTime(2026, 7, 1, 10);
    final (db, persistence, client, service) = await _harness(initialStore: {
      'categories': {
        'remote1': {
          'name': 'Remote',
          'iconCode': 1,
          'colorHex': 2,
          'type': 'expense',
          'isDeleted': false,
          'lastUpdated': t1.toUtc().toIso8601String(),
        },
      },
    });
    await db.into(db.categories).insert(CategoriesCompanion.insert(
          id: 'local1',
          name: 'Local',
          iconCode: 1,
          colorHex: 2,
          type: 'expense',
          userId: const Value('u1'),
          lastUpdated: Value(t1),
        ));

    final pullOnly = await service.sync(full: true, push: false);
    expect(pullOnly.pulled, 1);
    expect(pullOnly.pushed, 0);
    expect(client._store['categories']!.containsKey('local1'), isFalse);
    expect(await _category(db, 'remote1'), isNotNull);

    final pushOnly = await service.sync(full: true, pull: false);
    expect(pushOnly.pushed, greaterThanOrEqualTo(1));
    expect(client._store['categories']!.containsKey('local1'), isTrue);
  });
}
