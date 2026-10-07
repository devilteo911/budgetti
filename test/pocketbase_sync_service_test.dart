import 'dart:async';
import 'dart:ffi';

import 'package:budgetti/core/database/database.dart';
import 'package:budgetti/core/services/color_slots.dart';
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

/// In-memory PocketBase stand-in: mirrors what the real client + server do —
/// every write restamps `updated` (the autodate), pulls filter on it, the LWW
/// guard rejects stale bodies, pushes go through `batchPush`.
class _FakeClient extends SyncClient {
  @override
  final String userId;
  final Map<String, Map<String, Map<String, dynamic>>> _store = {};

  _FakeClient(this.userId);

  /// Deterministic server clock: strictly increasing, so `updated` filters
  /// behave like PB's autodate without wall-clock flakiness. Based after the
  /// dates tests use for lastUpdated, so pushed rows' server stamps advance
  /// the pull cursor.
  int _clockMs = 1790000000000;
  DateTime _tick() =>
      DateTime.fromMillisecondsSinceEpoch(_clockMs += 1000, isUtc: true);

  /// Test seam: collections the server doesn't serve at all — a 404 before
  /// their migration has run, or a permissions/outage failure.
  final Set<String> failCollections = {};

  /// Simulates the server-side LWW guard (pb_hooks/lww_guard.pb.js): a pushed
  /// body whose lastUpdated is older than the stored row's is rejected.
  bool enforceLww = false;

  /// Simulates an expired/revoked token: every call throws [SyncAuthExpired].
  bool authExpired = false;

  @override
  Future<void> ensureAuthenticated() async {
    if (authExpired) throw const SyncAuthExpired();
  }

  /// Held by tests that need a sync to pause mid-flight (lock testing).
  Future<void>? gate;

  /// How many bulk pushes were issued (the service must batch, not loop).
  int batchPushCalls = 0;

  /// Per-id push attempt counts (dead-letter observability).
  final Map<String, int> pushAttempts = {};

  @override
  Future<List<Map<String, dynamic>>> listChanges(
      String c, DateTime since) async {
    if (gate != null) await gate;
    if (authExpired) throw const SyncAuthExpired();
    if (failCollections.contains(c)) throw Exception('404: no collection $c');
    final entries = _store[c]?.entries.toList() ?? const [];
    return entries.where((e) {
      final up = e.value['updated'] as String?;
      if (up == null) return false;
      return DateTime.parse(up).isAfter(since);
    }).map((e) => {...e.value, 'id': e.key}).toList();
  }

  /// Test seam: ids the server refuses (bad id pattern, validation, outage).
  final Set<String> reject = {};

  /// Fires before each upsert — lets a test play "another device wrote during
  /// our push", the exact window the server guard exists for.
  void Function(String c, String id)? onBeforeUpsert;

  /// Test seam: fields the server has no column for — a PocketBase that has not
  /// run the migration that adds them. PB ignores unknown fields on write.
  final Set<String> unknownFields = {};

  void _write(String c, String id, Map<String, dynamic> body) {
    // An update only touches the fields it sends, as on PocketBase: a key the
    // body omits keeps its stored value.
    final merged = {...?_store[c]?[id], ...Map<String, dynamic>.from(body)};
    for (final f in unknownFields) {
      merged.remove(f);
    }
    _store.putIfAbsent(c, () => {})[id] = {
      ...merged,
      'updated': _tick().toUtc().toIso8601String(),
    };
  }

  @override
  Future<Map<String, dynamic>> upsert(
      String c, String id, Map<String, dynamic> body) async {
    if (authExpired) throw const SyncAuthExpired();
    pushAttempts[id] = (pushAttempts[id] ?? 0) + 1;
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
    _write(c, id, body);
    return {..._store[c]![id]!, 'id': id};
  }

  @override
  Future<Map<String, dynamic>> getRecord(String c, String id) async {
    if (authExpired) throw const SyncAuthExpired();
    final row = _store[c]?[id];
    if (row == null) throw Exception('404: $c/$id');
    return {...row, 'id': id};
  }

  @override
  Future<List<PushOutcome>> batchPush(
      String collection, List<(String, Map<String, dynamic>)> rows) {
    batchPushCalls++;
    return super.batchPush(collection, rows);
  }

  /// Test seam: mutate a stored row the way another device would.
  void edit(String c, String id, Map<String, dynamic> patch) {
    final row = _store[c]?[id];
    if (row != null) _write(c, id, {...row, ...patch});
  }
}

Future<(AppDatabase, PersistenceService, _FakeClient, PocketBaseSyncService)>
    _harness({
  String userId = 'u1',
  Map<String, dynamic>? initialStore,
  bool backfillColors = false,
}) async {
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
  final service = PocketBaseSyncService(client, db, persistence, userId,
      afterCategoriesPull:
          backfillColors ? () => backfillColorSlots(db, userId) : null);
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
    // A push-only run advances the push cursor to exactly what it confirmed
    // pushed (the stranded row's ts) — that's safe now that pull has its own
    // cursor; re-pushing a confirmed row would be a no-op, and the pull
    // cursor is untouched by a push-only pass.
    expect(persistence.getLastSyncAt(), t1);
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
    final (db, _, _, service) = await _harness(initialStore: {
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
          // Every server row carries the autodate now — pulls filter on it.
          'updated': t1.toUtc().toIso8601String(),
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

  test('a permanently-rejected row is dead-lettered and the cursor passes',
      () async {
    final (db, persistence, client, service) = await _harness();
    final t1 = DateTime(2026, 7, 1, 10);
    final t2 = DateTime(2026, 7, 1, 11);
    for (final (id, ts) in [('c1', t1), ('c2', t2)]) {
      await db.into(db.categories).insert(CategoriesCompanion.insert(
            id: id,
            name: id,
            iconCode: 1,
            colorHex: 2,
            type: 'expense',
            userId: const Value('u1'),
            lastUpdated: Value(ts),
          ));
    }
    client.reject.add('c1');

    // Five full attempts: the row fails each time, pinning the cursor…
    for (var i = 0; i < 4; i++) {
      final s = await service.sync();
      expect(s.skipped, 1);
      expect(s.deadLettered, 0);
      expect(persistence.getLastSyncAt().isBefore(t1), isTrue,
          reason: 'still retriable, the cursor stays behind it');
    }
    // …the fifth crossing dead-letters it and lets the cursor pass.
    final fifth = await service.sync();
    expect(fifth.skipped, 1);
    expect(fifth.deadLettered, 1);
    expect(persistence.getLastSyncAt(), t2,
        reason: 'the cursor must pass the dead-lettered row');

    // No longer selected: further syncs neither retry it nor count it.
    final after = await service.sync();
    expect(after.skipped, 0);
    expect(client.pushAttempts['c1'], 5);

    // Editing the row (new lastUpdated) clears the slate — it retries. The
    // edit also fixes whatever the server objected to, hence reject.clear.
    client.reject.clear();
    await (db.update(db.categories)..where((t) => t.id.equals('c1'))).write(
        CategoriesCompanion(
            name: const Value('Fixed'),
            lastUpdated: Value(DateTime(2026, 7, 1, 12))));
    final retried = await service.sync();
    expect(retried.pushed, 1);
    expect(client._store['categories']!['c1']!['name'], 'Fixed');
  });

  test('pull and push each advance only their own cursor', () async {
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
          'updated': t1.toUtc().toIso8601String(),
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
          lastUpdated: Value(t1.add(const Duration(hours: 2))),
        ));

    final pullOnly = await service.sync(full: true, push: false);
    expect(pullOnly.pulled, 1);
    // Pull confirmed the server up to its stamp — but the local row newer
    // than the (epoch) push cursor is still unpushed.
    expect(persistence.getPullSyncAt(), t1);
    expect(client._store['categories']!.containsKey('local1'), isFalse);

    final pushOnly = await service.sync(full: true, pull: false);
    expect(pushOnly.pushed, greaterThanOrEqualTo(1));
    expect(persistence.getLastSyncAt(), t1.add(const Duration(hours: 2)));
    // The push itself stamped a server `updated` for local1 — the pull cursor
    // learns it from the push outcome, so the next pull skips our own writes.
    expect(persistence.getPullSyncAt().isAfter(t1), isTrue);

    // Neither direction re-does its work.
    final noop = await service.sync();
    expect(noop.pushed, 0);
    expect(noop.pulled, 0);
  });

  test('pushes go through batchPush, not a per-row upsert loop', () async {
    final (db, _, client, service) = await _harness();
    for (final id in ['c1', 'c2', 'c3']) {
      await db.into(db.categories).insert(CategoriesCompanion.insert(
            id: id,
            name: id,
            iconCode: 1,
            colorHex: 2,
            type: 'expense',
            userId: const Value('u1'),
            lastUpdated: Value(DateTime(2026, 7, 1, 10)),
          ));
    }
    await service.sync();
    expect(client.batchPushCalls, greaterThan(0));
    expect(client._store['categories']?.length, 3);
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
          'updated': t1.toUtc().toIso8601String(),
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

  // PB compares date filters as raw strings against its stored
  // `YYYY-MM-DD HH:MM:SS.sssZ` form. Verified against a live 0.39.6:
  // `updated > "2026-08-20T00:00:00.000Z"` returned 0 rows for a record
  // stamped `2026-08-20 09:37:40.528Z`, the space-separated literal returned
  // it — 'T' sorts after ' ', so a `T` cursor hid every same-day change.
  test('pull filter literal is space-separated, so it sorts before same-day '
      'server stamps', () {
    final lit = pbDateLiteral(DateTime.utc(2026, 8, 20, 0, 0, 0));
    expect(lit, '2026-08-20 00:00:00.000Z');
    expect('2026-08-20 09:37:40.528Z'.compareTo(lit) > 0, isTrue);
  });

  // ── categories.colorSlot ─────────────────────────────────────────────────
  // The slot rides the wire as slot + 1, 0 meaning unset (PocketBase number
  // fields have no null); an unset local slot is simply not sent, because PB
  // keeps a field an update omits and sending 0 would wipe another device's slot.
  group('category colour slot', () {
    Future<void> category(AppDatabase db, String id,
        {int? slot, DateTime? at, String name = 'Food'}) =>
        db.into(db.categories).insert(CategoriesCompanion.insert(
              id: id,
              name: name,
              iconCode: 1,
              colorHex: 2,
              type: 'expense',
              userId: const Value('u1'),
              colorSlot: Value(slot),
              lastUpdated: Value(at ?? DateTime(2026, 7, 1, 10)),
            ));

    Map<String, dynamic> remote(String name, {Object? slot, bool withSlot = true, DateTime? at}) {
      final t = (at ?? DateTime(2026, 7, 3, 10)).toUtc().toIso8601String();
      return {
        'owner': 'u1',
        'name': name,
        'iconCode': 1,
        'colorHex': 2,
        'type': 'expense',
        'isDeleted': false,
        'lastUpdated': t,
        'updated': t,
        if (withSlot) 'colorSlot': slot,
      };
    }

    test('a stored slot is pushed as slot + 1', () async {
      final (db, _, client, service) = await _harness();
      await category(db, 'c1', slot: 3);

      await service.sync();

      expect(client._store['categories']!['c1']!['colorSlot'], 4);
    });

    test('slot 0 is pushed as 1, never as the "unset" 0', () async {
      final (db, _, client, service) = await _harness();
      await category(db, 'c1', slot: 0);

      await service.sync();

      expect(client._store['categories']!['c1']!['colorSlot'], 1);
    });

    test('a category with no slot sends no colorSlot at all', () async {
      final (db, _, client, service) = await _harness();
      await category(db, 'c1');

      await service.sync();

      expect(client._store['categories']!['c1']!.containsKey('colorSlot'), isFalse);
    });

    test('an unset local slot does not wipe the slot another device stored',
        () async {
      final (db, _, client, service) = await _harness(initialStore: {
        'categories': {'c1': remote('Food', slot: 6, at: DateTime(2026, 7, 1, 9))},
      });
      // Local edit, newer than the stored row, made before the slot was learned.
      await category(db, 'c1', at: DateTime(2026, 7, 1, 11));

      await service.sync(pull: false); // push only: the pull has not happened yet

      expect(client._store['categories']!['c1']!['colorSlot'], 6);
    });

    test('pull decodes the wire form', () async {
      final (db, _, client, service) = await _harness(initialStore: {
        'categories': {'c1': remote('Food', slot: 5)},
      });

      await service.sync();

      expect((await _category(db, 'c1'))!.colorSlot, 4);
    });

    test('pull: unset (0) or absent keeps the slot this device has', () async {
      final (db, _, client, service) = await _harness();
      await category(db, 'c1', slot: 2);
      await category(db, 'c2', slot: 7, name: 'Other');
      await service.sync();

      // Newer remote edits that carry no opinion about the slot.
      client.edit('categories', 'c1', {
        'name': 'Renamed',
        'colorSlot': 0,
        'lastUpdated': DateTime(2026, 7, 5, 10).toUtc().toIso8601String(),
      });
      client._store['categories']!['c2']!
        ..['name'] = 'Renamed2'
        ..['lastUpdated'] = DateTime(2026, 7, 5, 10).toUtc().toIso8601String()
        ..['updated'] = client._tick().toUtc().toIso8601String()
        ..remove('colorSlot');
      await service.sync();

      final c1 = (await _category(db, 'c1'))!, c2 = (await _category(db, 'c2'))!;
      expect((c1.name, c1.colorSlot), ('Renamed', 2));
      expect((c2.name, c2.colorSlot), ('Renamed2', 7));
    });

    test('a server that has not run the migration ignores the field, and our '
        'own rows coming back do not lose their slot', () async {
      final (db, persistence, client, service) = await _harness();
      client.unknownFields.add('colorSlot'); // the old server
      await category(db, 'c1', slot: 3);

      final first = await service.sync();
      expect(first.skipped, 0, reason: 'an unknown field must not break the push');
      expect(client._store['categories']!['c1']!.containsKey('colorSlot'), isFalse);

      // The server now returns the row without the field: a full pull must not
      // null the local slot.
      await service.sync(full: true);
      expect((await _category(db, 'c1'))!.colorSlot, 3);
    });

    test('a slot round-trips from one device to another', () async {
      final (dbA, _, clientA, serviceA) = await _harness();
      await category(dbA, 'c1', slot: 5);
      await serviceA.sync();

      final (dbB, _, _, serviceB) =
          await _harness(initialStore: {'categories': clientA._store['categories']!});
      await serviceB.sync();

      expect((await _category(dbB, 'c1'))!.colorSlot, 5);
    });

    test('the backfill runs after the pull, so a slot another device gave is '
        'learned first, and its result is pushed in the same sync', () async {
      final (db, _, client, service) = await _harness(
        backfillColors: true,
        initialStore: {
          'categories': {'c1': remote('Food', slot: 7, at: DateTime(2026, 7, 4))},
        },
      );
      await category(db, 'c1', at: DateTime(2026, 7, 1)); // same row, no slot here
      await category(db, 'c2', name: 'Other', at: DateTime(2026, 7, 1));

      await service.sync();

      expect((await _category(db, 'c1'))!.colorSlot, 6, reason: 'learned, not re-assigned');
      final c2 = (await _category(db, 'c2'))!.colorSlot;
      expect(c2, isNotNull);
      expect(c2, isNot(6), reason: 'backfill counted the slot it learned');
      expect(client._store['categories']!['c2']!['colorSlot'], c2! + 1,
          reason: 'pushed in the same sync');
    });

    test('a category pulled and then given a slot in the same sync is still '
        'pushed in it (a pulled row is normally skipped by the push)', () async {
      final (db, _, client, service) = await _harness(
        backfillColors: true,
        initialStore: {
          'categories': {'c1': remote('Food', withSlot: false, at: DateTime(2026, 7, 4))},
        },
      );

      await service.sync();

      final slot = (await _category(db, 'c1'))!.colorSlot;
      expect(slot, isNotNull, reason: 'pulled with no slot, then backfilled');
      expect(client._store['categories']!['c1']!['colorSlot'], slot! + 1,
          reason: 'the backfill re-stamped the row, so the push must not skip it');
    });
  });

  // ── Partita IVA: piva_profile + piva_payments ───────────────────────────
  // The installment-plan cases above, replayed on the two collections the web
  // Ledger writes. Nothing here is special to the pair: the point is that they
  // behave like every other synced collection. The Drift tables are
  // `piva_profiles` / `piva_payments`; the collections are `piva_profile` (sic)
  // / `piva_payments`, and the fake server's store is keyed by collection.
  group('partita iva', () {
    final t1 = DateTime(2026, 7, 1, 10);
    String iso(DateTime d) => d.toUtc().toIso8601String();

    Future<void> profile(AppDatabase db, String id,
            {String fundName = 'Fondo Prova',
            DateTime? at,
            Map<String, double?>? declaredIncome}) =>
        db.into(db.pivaProfiles).insert(PivaProfilesCompanion.insert(
              id: id,
              userId: const Value('u1'),
              fundName: Value(fundName),
              declaredIncome: Value(declaredIncome),
              lastUpdated: Value(at ?? t1),
            ));

    Future<void> payment(AppDatabase db, String id,
            {String label = 'Saldo imposta', DateTime? at}) =>
        db.into(db.pivaPayments).insert(PivaPaymentsCompanion.insert(
              id: id,
              userId: const Value('u1'),
              kind: const Value('imposta'),
              label: Value(label),
              lastUpdated: Value(at ?? t1),
            ));

    Future<PivaProfile?> profileRow(AppDatabase db, String id) =>
        (db.select(db.pivaProfiles)..where((t) => t.id.equals(id)))
            .getSingleOrNull();

    Future<PivaPayment?> paymentRow(AppDatabase db, String id) =>
        (db.select(db.pivaPayments)..where((t) => t.id.equals(id)))
            .getSingleOrNull();

    /// Another device: an empty database, fresh cursors, the same server.
    Future<(AppDatabase, PocketBaseSyncService)> otherDevice(
        _FakeClient client) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final db = AppDatabase.forExecutor(NativeDatabase.memory());
      await db.delete(db.categories).go(); // the seeds, as _harness clears them
      await db.delete(db.tags).go();
      await db.delete(db.accounts).go();
      return (
        db,
        PocketBaseSyncService(client, db, PersistenceService(prefs), 'u1')
      );
    }

    // serverProfile's `declared` when the caller says nothing: no key at all.
    const notGiven = Object();

    /// A profile as PocketBase returns it: the `owner` relation and the
    /// `updated` autodate on it, numbers that may be plain integers, unset text
    /// as '' and an unset json field as null. `owner` is never read — the row's
    /// userId comes from the service — so it is deliberately not the user's id.
    ///
    /// `declared` is written as `declaredIncome` only when given, because a
    /// record without the key is a different thing from one holding null: the
    /// first is a server that never ran 1751000013_piva_declared_income.js, the
    /// second the field never set. PocketBase hands a stored object back with
    /// sorted keys and a whole number as an integer.
    Map<String, dynamic> serverProfile(
        {Object? categories, DateTime? at, Object? declared = notGiven}) {
      final stamp = iso(at ?? t1);
      return {
        'owner': 'server-side-owner',
        'atecoCode': '62.20.10',
        'coefficient': 67,
        'startYear': 2023,
        'startupRate': true,
        'fundType': 'gestione_separata',
        'fundName': '',
        'subjectiveRate': 26.07,
        'integrativeRate': 0,
        'minSubjective': 0,
        'minIntegrative': 0,
        'inpsReduction': false,
        'incomeCategories': categories,
        if (!identical(declared, notGiven)) 'declaredIncome': declared,
        'isDeleted': false,
        'lastUpdated': stamp,
        'updated': stamp,
      };
    }

    /// A payment as PocketBase returns it: an unset `key`, `paidDate` and note
    /// are '', a zero amount is a real answer, and dates use PB's stored
    /// `YYYY-MM-DD HH:MM:SS.sssZ` form (space separator).
    Map<String, dynamic> serverPayment({DateTime? at}) {
      final stamp = iso(at ?? t1);
      return {
        'owner': 'server-side-owner',
        'key': '',
        'kind': 'imposta',
        'label': 'Acconto',
        'dueDate': '2026-06-30 10:00:00.000Z',
        'amount': 0,
        'paidDate': '',
        'note': '',
        'isDeleted': false,
        'lastUpdated': stamp,
        'updated': stamp,
      };
    }

    test('a profile round-trips push → pull with every field', () async {
      final (db, _, client, service) = await _harness();
      await db.into(db.pivaProfiles).insert(PivaProfilesCompanion.insert(
            id: 'pro1',
            userId: const Value('u1'),
            atecoCode: const Value('62.20.10'),
            coefficient: const Value(78.0),
            startYear: const Value(2023),
            startupRate: const Value(true),
            fundType: const Value('gestione_separata'),
            fundName: const Value('Fondo Prova'),
            subjectiveRate: const Value(26.07),
            integrativeRate: const Value(4.0),
            minSubjective: const Value(4208.5),
            minIntegrative: const Value(840.25),
            inpsReduction: const Value(true),
            incomeCategories:
                const Value<List<String>?>(['Consulenza', 'Corsi']),
            // A figure and an answered "from the ledger" (null entry).
            declaredIncome: const Value<Map<String, double?>?>(
                {'2025': 40000.0, '2024': null}),
            lastUpdated: Value(t1),
          ));

      await service.sync();

      // Exactly the fourteen fields of pb_migrations/1751000012_piva.js plus
      // `declaredIncome` from 1751000013_piva_declared_income.js — a typo here
      // syncs silently wrong data — and no `owner`: the client adds that on the
      // wire. (`updated` is the autodate the fake server stamps.)
      final pushed = client._store['piva_profile']!['pro1']!;
      expect(
          pushed.keys.where((k) => k != 'updated'),
          unorderedEquals([
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
      expect(pushed['atecoCode'], '62.20.10');
      expect(pushed['coefficient'], 78);
      expect(pushed['startYear'], 2023);
      expect(pushed['startupRate'], true);
      expect(pushed['fundType'], 'gestione_separata');
      expect(pushed['fundName'], 'Fondo Prova');
      expect(pushed['subjectiveRate'], 26.07);
      expect(pushed['integrativeRate'], 4);
      expect(pushed['minSubjective'], 4208.5);
      expect(pushed['minIntegrative'], 840.25);
      expect(pushed['inpsReduction'], true);
      expect(pushed['incomeCategories'], ['Consulenza', 'Corsi']);
      expect(pushed['declaredIncome'], {'2025': 40000.0, '2024': null},
          reason: 'a non-empty map goes whole, its null entry as JSON null');
      expect(pushed['isDeleted'], false);
      expect(pushed['lastUpdated'], iso(t1));

      // A fresh device pulls it back into Drift unchanged.
      final (db2, service2) = await otherDevice(client);
      await service2.sync();

      final row = await profileRow(db2, 'pro1');
      expect(row, isNotNull);
      expect(row!.userId, 'u1');
      expect(row.atecoCode, '62.20.10');
      expect(row.coefficient, 78);
      expect(row.startYear, 2023);
      expect(row.startupRate, true);
      expect(row.fundType, 'gestione_separata');
      expect(row.fundName, 'Fondo Prova');
      expect(row.subjectiveRate, 26.07);
      expect(row.integrativeRate, 4);
      expect(row.minSubjective, 4208.5);
      expect(row.minIntegrative, 840.25);
      expect(row.inpsReduction, true);
      expect(row.incomeCategories, ['Consulenza', 'Corsi'],
          reason: 'the json field comes back as a list, not a string');
      expect(row.declaredIncome, {'2025': 40000.0, '2024': null},
          reason: 'the json field comes back as a map, not a string');
      expect(row.declaredIncome!.containsKey('2024'), isTrue,
          reason: 'a null entry is an answer, it is not dropped');
      expect(row.isDeleted, false);
      expect(row.lastUpdated, t1);
    });

    test('a payment round-trips push → pull, and a paid date set later reaches '
        'the server on the next sync', () async {
      final (db, _, client, service) = await _harness();
      await db.into(db.pivaPayments).insert(PivaPaymentsCompanion.insert(
            id: 'pay1',
            userId: const Value('u1'),
            key: const Value('2026:imposta_saldo'),
            kind: const Value('imposta'),
            label: const Value('Saldo imposta 2025'),
            dueDate: Value(DateTime(2026, 6, 30, 12)),
            amount: const Value(1234.56),
            note: const Value('importo della commercialista'),
            lastUpdated: Value(t1),
          ));

      await service.sync();

      final pushed = client._store['piva_payments']!['pay1']!;
      expect(
          pushed.keys.where((k) => k != 'updated'),
          unorderedEquals([
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
      expect(pushed['key'], '2026:imposta_saldo');
      expect(pushed['kind'], 'imposta');
      expect(pushed['label'], 'Saldo imposta 2025');
      expect(pushed['dueDate'], iso(DateTime(2026, 6, 30, 12)),
          reason: 'dates travel as ISO UTC');
      expect(pushed['amount'], 1234.56);
      expect(pushed['paidDate'], isNull,
          reason: 'an unpaid deadline sends null, which clears the field');
      expect(pushed['note'], 'importo della commercialista');

      // A fresh device pulls it back, still unpaid.
      final (db2, service2) = await otherDevice(client);
      await service2.sync();

      final row = await paymentRow(db2, 'pay1');
      expect(row, isNotNull);
      expect(row!.userId, 'u1');
      expect(row.key, '2026:imposta_saldo');
      expect(row.kind, 'imposta');
      expect(row.label, 'Saldo imposta 2025');
      expect(row.dueDate?.toUtc(), DateTime(2026, 6, 30, 12).toUtc());
      expect(row.amount, 1234.56);
      expect(row.paidDate, isNull);
      expect(row.note, 'importo della commercialista');

      // Marked paid locally (a new lastUpdated, as the editor would stamp it):
      // the paid date rides the next push.
      await (db.update(db.pivaPayments)..where((t) => t.id.equals('pay1')))
          .write(PivaPaymentsCompanion(
              paidDate: Value(DateTime(2026, 7, 2, 12)),
              lastUpdated: Value(DateTime(2026, 7, 2, 12))));
      final second = await service.sync();

      expect(second.skipped, 0);
      expect(client._store['piva_payments']!['pay1']!['paidDate'],
          iso(DateTime(2026, 7, 2, 12)));
    });

    test('rows in the shape the server really returns land without errors',
        () async {
      final (db, _, _, service) = await _harness(initialStore: {
        'piva_profile': {'pro-web': serverProfile()},
        'piva_payments': {'pay-web': serverPayment()},
      });

      final summary = await service.sync(full: true, push: false);

      expect(summary.skipped, 0);
      expect(summary.error, isNull);
      expect(summary.pulled, 2);

      final p = await profileRow(db, 'pro-web');
      expect(p, isNotNull);
      expect(p!.userId, 'u1', reason: 'the service\'s user, not the body\'s owner');
      expect(p.atecoCode, '62.20.10');
      expect(p.coefficient, 67.0, reason: 'a whole number reads as a double');
      expect(p.startYear, 2023);
      expect(p.startupRate, true);
      expect(p.fundType, 'gestione_separata');
      expect(p.fundName, '');
      expect(p.subjectiveRate, 26.07);
      expect(p.integrativeRate, 0.0);
      expect(p.minSubjective, 0.0);
      expect(p.minIntegrative, 0.0);
      expect(p.inpsReduction, false);
      expect(p.incomeCategories, isNull,
          reason: 'a json field never set stays null, not an empty list');
      expect(p.lastUpdated, t1);

      final pay = await paymentRow(db, 'pay-web');
      expect(pay, isNotNull);
      expect(pay!.userId, 'u1');
      expect(pay.key, '');
      expect(pay.kind, 'imposta');
      expect(pay.label, 'Acconto');
      expect(pay.dueDate?.toUtc(), DateTime.utc(2026, 6, 30, 10),
          reason: 'PB\'s space-separated date parses');
      expect(pay.amount, 0.0, reason: 'a zero amount is a real answer');
      expect(pay.paidDate, isNull, reason: 'PB\'s empty date is no date');
      expect(pay.note, '');

      // A payment points at no profile: with none on either side it lands too.
      final (db2, _, _, service2) = await _harness(initialStore: {
        'piva_payments': {'pay-web': serverPayment()},
      });
      final alone = await service2.sync(full: true, push: false);
      expect(alone.skipped, 0);
      expect(alone.pulled, 1);
      expect(await db2.select(db2.pivaProfiles).get(), isEmpty);
      expect(await paymentRow(db2, 'pay-web'), isNotNull);
    });

    test('incomeCategories that is not a list reads null and does not fail the '
        'collection', () async {
      // A PocketBase json field holds anything. A cast that threw here would
      // mark the whole collection failed and freeze both cursors for good.
      final (db, persistence, _, service) = await _harness(initialStore: {
        'piva_profile': {
          'pro-string': serverProfile(categories: 'Consulenza'),
          'pro-map': serverProfile(categories: {'Consulenza': true}),
        },
      });

      final summary = await service.sync(full: true, push: false);

      expect(summary.skipped, 0, reason: 'the collection did not fail');
      expect(summary.error, isNull);
      expect(summary.pulled, 2);
      expect((await profileRow(db, 'pro-string'))!.incomeCategories, isNull);
      expect((await profileRow(db, 'pro-map'))!.incomeCategories, isNull);
      expect(persistence.getPullSyncAt(), t1,
          reason: 'the pull cursor advanced past both rows');
    });

    test('declaredIncome is read through num as PocketBase hands it back, and '
        'what is not an object reads NULL without failing the collection',
        () async {
      // Sorted keys and a whole number as an integer (`40000`, not `40000.0`);
      // a json field never set is null, and it holds anything.
      final (db, persistence, _, service) = await _harness(initialStore: {
        'piva_profile': {
          'pro-map':
              serverProfile(declared: {'2024': null, '2025': 40000}),
          'pro-null': serverProfile(declared: null),
          'pro-string': serverProfile(declared: 'x'),
        },
      });

      final summary = await service.sync(full: true, push: false);

      expect(summary.skipped, 0, reason: 'the collection did not fail');
      expect(summary.error, isNull);
      expect(summary.pulled, 3);
      final map = (await profileRow(db, 'pro-map'))!.declaredIncome;
      expect(map, {'2025': 40000.0, '2024': null});
      expect(map!.containsKey('2024'), isTrue,
          reason: 'a null entry is an answer, it is not dropped');
      expect((await profileRow(db, 'pro-null'))!.declaredIncome, isNull);
      expect((await profileRow(db, 'pro-string'))!.declaredIncome, isNull);
      expect(persistence.getPullSyncAt(), t1,
          reason: 'the pull cursor advanced past the three rows');
    });

    test('a newer remote record without the declaredIncome key updates the '
        'other fields and keeps the local map', () async {
      // A server that never ran 1751000013_piva_declared_income.js says nothing
      // about the field; the row is replaced whole, so the pull has to write the
      // local value back or every pull would reset it.
      final t2 = t1.add(const Duration(hours: 1));
      final (db, _, _, service) = await _harness(initialStore: {
        'piva_profile': {'pro1': serverProfile(at: t2)},
      });
      await profile(db, 'pro1',
          fundName: 'Locale', at: t1, declaredIncome: {'2025': 40000.0});

      final summary = await service.sync(push: false);

      expect(summary.pulled, 1);
      final row = (await profileRow(db, 'pro1'))!;
      expect(row.fundName, '', reason: 'the remote record was applied');
      expect(row.atecoCode, '62.20.10');
      expect(row.lastUpdated, t2);
      expect(row.declaredIncome, {'2025': 40000.0});
    });

    test('a NULL or empty declaredIncome is pushed without the key, so the '
        'server keeps the figure it holds', () async {
      // The server holds a figure the web declared and this phone never learned
      // (a profile edited here before its first sync after the upgrade): its
      // newer row wins whole, and neither null nor {} may erase the figure.
      final (db, _, client, service) = await _harness(initialStore: {
        'piva_profile': {
          'pro-null': serverProfile(declared: {'2025': 40000}),
          'pro-empty': serverProfile(declared: {'2025': 40000}),
        },
      });
      final later = t1.add(const Duration(hours: 1));
      await profile(db, 'pro-null', fundName: 'Locale', at: later);
      await profile(db, 'pro-empty',
          fundName: 'Locale', at: later, declaredIncome: const {});
      // A profile the server has not seen yet is created without the key too.
      await profile(db, 'pro-new', at: later);

      final summary = await service.sync(pull: false);

      expect(summary.skipped, 0);
      expect(summary.pushed, 3);
      final store = client._store['piva_profile']!;
      for (final id in ['pro-null', 'pro-empty']) {
        expect(store[id]!['fundName'], 'Locale', reason: '$id: the push landed');
        expect(store[id]!['declaredIncome'], {'2025': 40000},
            reason: '$id: an omitted field keeps the stored value');
      }
      expect(store['pro-new']!.containsKey('declaredIncome'), isFalse);

      // The write's answer carries the figure the server kept; an incremental
      // pull would never bring it back (the row's new `updated` is behind the
      // cursor), so the phone learns it from the answer — only that column, no
      // new `lastUpdated`, and nothing is pushed again.
      for (final id in ['pro-null', 'pro-empty']) {
        final row = (await profileRow(db, id))!;
        expect(row.declaredIncome, {'2025': 40000.0},
            reason: '$id: learned back from the answer to its own push');
        expect(row.lastUpdated, later, reason: '$id: lastUpdated untouched');
        expect(row.fundName, 'Locale');
      }
      expect((await profileRow(db, 'pro-new'))!.declaredIncome, isNull,
          reason: 'the server had no figure: nothing to learn');
      final again = await service.sync();
      expect(again.pushed, 0, reason: 'learning the figure is not a local edit');
      expect(again.skipped, 0);
    });

    test('a profile pushed with its own declaredIncome keeps it whatever the '
        'answer holds', () async {
      final (db, _, client, service) = await _harness(initialStore: {
        'piva_profile': {'pro1': serverProfile(declared: {'2025': 40000})},
      });
      await profile(db, 'pro1',
          at: t1.add(const Duration(hours: 1)),
          declaredIncome: {'2025': 50000.0, '2024': null});

      final summary = await service.sync(pull: false);

      expect(summary.pushed, 1);
      expect(client._store['piva_profile']!['pro1']!['declaredIncome'],
          {'2025': 50000.0, '2024': null}, reason: 'sent whole, null entry too');
      expect((await profileRow(db, 'pro1'))!.declaredIncome,
          {'2025': 50000.0, '2024': null});
    });

    // The server migration that adds declaredIncome leaves `updated` alone on
    // the rows it finds, so a phone whose pull cursor is already past the
    // profile (v0.7 after the upgrade) would never receive a figure the web
    // declared. `pb_piva_profile_repulled` makes its first sync pull that one
    // collection from epoch.
    group('the one-shot re-pull of piva_profile', () {
      /// A v0.7 phone after the upgrade: it synced everything long ago (both
      /// cursors past the profile), its row has the same `lastUpdated` as the
      /// server's and no declared income, and the server row holds one but its
      /// `updated` predates the pull cursor.
      Future<(AppDatabase, PersistenceService, _FakeClient,
              PocketBaseSyncService)>
          upgradedPhone() async {
        final h = await _harness(initialStore: {
          'piva_profile': {'pro1': serverProfile(declared: {'2025': 40000})},
        });
        final (db, persistence, _, _) = h;
        await persistence.setPullSyncAt(DateTime(2026, 7, 10));
        await persistence.setLastSyncAt(DateTime(2026, 7, 10));
        await profile(db, 'pro1', at: t1);
        return h;
      }

      test('with the flag unset the first sync gets the figure and sets it, the '
          'second does not pull again', () async {
        final (db, persistence, client, service) = await upgradedPhone();
        expect(persistence.getPivaProfileRepulled(), isFalse);

        final first = await service.sync();

        expect(first.skipped, 0);
        expect(first.pulled, 1);
        expect((await profileRow(db, 'pro1'))!.declaredIncome, {'2025': 40000.0});
        expect(persistence.getPivaProfileRepulled(), isTrue);

        // The server map changes without moving `updated`: a normal pull
        // cannot see it, and the re-pull does not run twice.
        client._store['piva_profile']!['pro1']!['declaredIncome'] = {
          '2025': 50000
        };
        final second = await service.sync();
        expect(second.pulled, 0);
        expect((await profileRow(db, 'pro1'))!.declaredIncome, {'2025': 40000.0});
      });

      test('with the flag already set the first sync does not see the figure — '
          'what the re-pull is for', () async {
        final (db, persistence, _, service) = await upgradedPhone();
        await persistence.setPivaProfileRepulled(true);

        final first = await service.sync();

        expect(first.pulled, 0, reason: 'behind the pull cursor');
        expect((await profileRow(db, 'pro1'))!.declaredIncome, isNull);
      });

      test('a push-only run, an expired session and a failed collection leave '
          'the flag unset', () async {
        final (db, persistence, client, service) = await upgradedPhone();

        await service.sync(pull: false);
        expect(persistence.getPivaProfileRepulled(), isFalse,
            reason: 'push-only: the collection was not pulled');

        client.authExpired = true;
        await service.sync();
        expect(persistence.getPivaProfileRepulled(), isFalse,
            reason: 'auth expiry aborts before any collection is pulled');
        client.authExpired = false;

        client.failCollections.add('piva_profile');
        await service.sync();
        expect(persistence.getPivaProfileRepulled(), isFalse,
            reason: 'the collection failed, so the next sync tries again');
        client.failCollections.clear();

        await service.sync();
        expect(persistence.getPivaProfileRepulled(), isTrue);
        expect((await profileRow(db, 'pro1'))!.declaredIncome, {'2025': 40000.0});
      });
    });

    test('LWW in pull, both ways on piva_payments: a newer remote row '
        'overwrites the local one, a newer local row wins and is pushed',
        () async {
      final (db, _, client, service) = await _harness();
      await payment(db, 'pay-remote', label: 'Old', at: t1);
      await payment(db, 'pay-local', label: 'Local', at: t1);
      await service.sync(); // push both

      // pay-remote: another device edits it newer than ours.
      client.edit('piva_payments', 'pay-remote',
          {'label': 'New', 'lastUpdated': iso(DateTime(2026, 7, 2, 10))});
      // pay-local: the remote edit is at 11:00, ours at 12:00.
      client.edit('piva_payments', 'pay-local', {
        'label': 'RemoteWins?',
        'lastUpdated': iso(DateTime(2026, 7, 1, 11))
      });
      await (db.update(db.pivaPayments)..where((t) => t.id.equals('pay-local')))
          .write(PivaPaymentsCompanion(
              label: const Value('LocalWins'),
              lastUpdated: Value(DateTime(2026, 7, 1, 12))));

      final summary = await service.sync();

      expect(summary.pulled, 1, reason: 'only pay-remote was applied');
      expect(summary.conflicts, 1, reason: 'pay-local won against the pull');
      expect((await paymentRow(db, 'pay-remote'))?.label, 'New');
      expect((await paymentRow(db, 'pay-local'))?.label, 'LocalWins');
      // The local winner reached the server.
      expect(client._store['piva_payments']!['pay-local']!['label'], 'LocalWins');
    });

    test('the server guard rejecting a push adopts the remote profile (remote '
        'wins)', () async {
      final (db, persistence, client, service) = await _harness();
      client.enforceLww = true;
      await profile(db, 'pro1', fundName: 'Base', at: t1);
      await service.sync(); // push, cursor = 10:00

      // The pull has already passed; another device writes a *newer* row while
      // our (stale) local edit is being pushed — the window the guard is for.
      await (db.update(db.pivaProfiles)..where((t) => t.id.equals('pro1')))
          .write(PivaProfilesCompanion(
              fundName: const Value('StaleLocal'),
              lastUpdated: Value(DateTime(2026, 7, 1, 11))));
      client.onBeforeUpsert = (c, id) {
        client.onBeforeUpsert = null; // fire once, on the stale push itself
        client.edit('piva_profile', 'pro1', {
          'fundName': 'FreshRemote',
          'lastUpdated': iso(DateTime(2026, 7, 1, 12)),
        });
      };

      final summary = await service.sync();

      expect(summary.pulled, 0, reason: 'the remote edit lands after the pull');
      expect(summary.remoteWins, 1);
      expect(summary.skipped, 0, reason: 'remote-wins is not a skip');
      final row = await profileRow(db, 'pro1');
      expect(row?.fundName, 'FreshRemote', reason: 'local adopted the remote body');
      expect(row?.lastUpdated, DateTime(2026, 7, 1, 12));
      // The cursor advanced past the row — no rewind, no re-pick of the fight.
      expect(persistence.getLastSyncAt(), DateTime(2026, 7, 1, 12));
    });

    test('a soft-deleted payment propagates as a tombstone to a fresh device',
        () async {
      final (db, _, client, service) = await _harness();
      await payment(db, 'pay1', at: t1);
      // Device A deletes it (soft delete + stamp).
      await (db.update(db.pivaPayments)..where((t) => t.id.equals('pay1')))
          .write(PivaPaymentsCompanion(
              isDeleted: const Value(true),
              lastUpdated: Value(DateTime(2026, 7, 2, 10))));
      await service.sync();
      expect(client._store['piva_payments']!['pay1']!['isDeleted'], true);

      // Device B: fresh DB + fresh cursor, same server, pulls the tombstone.
      final (db2, service2) = await otherDevice(client);
      final summary = await service2.sync();

      expect(summary.pulled, greaterThanOrEqualTo(1));
      final row = await paymentRow(db2, 'pay1');
      expect(row, isNotNull);
      expect(row!.isDeleted, true);
    });

    test('a NULL lastUpdated row (a restored backup) is pushed, stamped only '
        'once the server accepted it, and not pushed again', () async {
      final (db, _, client, service) = await _harness();
      // lastUpdated omitted → null: how a restored backup lands.
      await db.into(db.pivaProfiles).insert(PivaProfilesCompanion.insert(
          id: 'pro1', userId: const Value('u1')));
      await db.into(db.pivaPayments).insert(PivaPaymentsCompanion.insert(
          id: 'pay1', userId: const Value('u1')));
      client.reject.add('pay1');

      final first = await service.sync();

      expect(first.pushed, 1, reason: 'the profile');
      expect(first.skipped, 1, reason: 'the payment the server refused');
      expect((await profileRow(db, 'pro1'))!.lastUpdated, isNotNull,
          reason: 'accepted → stamped');
      expect((await paymentRow(db, 'pay1'))!.lastUpdated, isNull,
          reason: 'refused → still NULL, so the next sync selects it again');

      client.reject.clear();
      final second = await service.sync();

      expect(second.pushed, 1, reason: 'only the payment, now accepted');
      expect(client._store['piva_payments']!.containsKey('pay1'), isTrue);
      expect((await paymentRow(db, 'pay1'))!.lastUpdated, isNotNull);

      // Both are stamped now: nothing is pushed a third time.
      final third = await service.sync();
      expect(third.pushed, 0);
    });

    test('a payment the server always rejects is dead-lettered on the fifth '
        'attempt and the cursor passes it', () async {
      final (db, persistence, client, service) = await _harness();
      final t2 = DateTime(2026, 7, 1, 11);
      await payment(db, 'pay-bad', at: t1);
      await payment(db, 'pay-ok', at: t2);
      client.reject.add('pay-bad');

      // Four attempts: the row fails each time, pinning the cursor…
      for (var i = 0; i < 4; i++) {
        final s = await service.sync();
        expect(s.skipped, 1);
        expect(s.deadLettered, 0);
        expect(persistence.getLastSyncAt().isBefore(t1), isTrue,
            reason: 'still retriable, the cursor stays behind it');
      }
      // …the fifth dead-letters it and lets the cursor pass.
      final fifth = await service.sync();
      expect(fifth.skipped, 1);
      expect(fifth.deadLettered, 1);
      expect(persistence.getLastSyncAt(), t2,
          reason: 'the cursor must pass the dead-lettered row');

      // The ledger names the collection, not the Drift table.
      final failure = (await db.select(db.syncFailures).get()).single;
      expect(failure.collection, 'piva_payments');
      expect(failure.recordId, 'pay-bad');
      expect(failure.attempts, 5);

      // No longer selected: further syncs neither retry it nor count it.
      final after = await service.sync();
      expect(after.skipped, 0);
      expect(client.pushAttempts['pay-bad'], 5);

      // Editing the row (new lastUpdated) clears the slate — it retries. The
      // edit also fixes whatever the server objected to, hence reject.clear.
      client.reject.clear();
      await (db.update(db.pivaPayments)..where((t) => t.id.equals('pay-bad')))
          .write(PivaPaymentsCompanion(
              label: const Value('Fixed'),
              lastUpdated: Value(DateTime(2026, 7, 1, 12))));
      final retried = await service.sync();
      expect(retried.pushed, 1);
      expect(client._store['piva_payments']!['pay-bad']!['label'], 'Fixed');
    });

    test('a full sync from the epoch rescues a profile behind an advanced '
        'push cursor and one behind an advanced pull cursor', () async {
      // Push side: a local row stranded behind a poisoned push cursor.
      final (db, persistence, client, service) = await _harness();
      await profile(db, 'pro1', at: t1);
      await persistence.setLastSyncAt(DateTime(2026, 7, 10));

      final incremental = await service.sync();
      expect(incremental.pushed, 0, reason: 'incremental cannot see it');

      final fullPush = await service.sync(full: true, pull: false);
      expect(fullPush.pushed, 1);
      expect(client._store['piva_profile']!['pro1']!['fundName'], 'Fondo Prova');

      // Pull side: a server row stamped before the pull cursor.
      final (db2, persistence2, _, service2) = await _harness(initialStore: {
        'piva_profile': {'pro-srv': serverProfile()},
      });
      await persistence2.setPullSyncAt(DateTime(2026, 7, 10));
      // An install that already re-pulled the profile once (the one-shot below
      // would otherwise pull it from epoch, whatever the cursor says).
      await persistence2.setPivaProfileRepulled(true);

      final incremental2 = await service2.sync(push: false);
      expect(incremental2.pulled, 0, reason: 'behind the pull cursor');
      expect(await profileRow(db2, 'pro-srv'), isNull);

      final fullPull = await service2.sync(full: true, push: false);
      expect(fullPull.pulled, 1);
      expect(await profileRow(db2, 'pro-srv'), isNotNull);
    });

    test('pull and push each advance only their own cursor, and a third sync '
        'does nothing', () async {
      final (db, persistence, client, service) = await _harness(initialStore: {
        'piva_profile': {'pro-srv': serverProfile(at: t1)},
      });
      await profile(db, 'pro-loc', at: t1.add(const Duration(hours: 2)));

      final pullOnly = await service.sync(full: true, push: false);
      expect(pullOnly.pulled, 1);
      // Pull confirmed the server up to its stamp — the push cursor did not
      // move, and the local row newer than it is still unpushed.
      expect(persistence.getPullSyncAt(), t1);
      expect(persistence.getLastSyncAt(), DateTime.fromMillisecondsSinceEpoch(0));
      expect(client._store['piva_profile']!.containsKey('pro-loc'), isFalse);

      final pushOnly = await service.sync(full: true, pull: false);
      expect(pushOnly.pushed, greaterThanOrEqualTo(1));
      expect(client._store['piva_profile']!.containsKey('pro-loc'), isTrue);
      expect(persistence.getLastSyncAt(), t1.add(const Duration(hours: 2)));
      // The push itself stamped a server `updated` — the pull cursor learns it
      // from the push outcome, so the next pull skips our own writes.
      expect(persistence.getPullSyncAt().isAfter(t1), isTrue);

      // Neither direction re-does its work.
      final noop = await service.sync();
      expect(noop.pushed, 0);
      expect(noop.pulled, 0);
    });

    test('a server without the two collections yet cannot break the others, '
        'and catches up once it has them', () async {
      final (db, persistence, client, service) = await _harness();
      client.failCollections.addAll(['piva_profile', 'piva_payments']);
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
      expect(summary.skipped, 2, reason: 'both failures are reported');
      expect(summary.error, isNull, reason: 'the run is partial, not failed');
      // The cursor is global — advancing it would strand the profile forever.
      expect(persistence.getLastSyncAt(), DateTime.fromMillisecondsSinceEpoch(0));

      // Once the server catches up, the frozen cursor lets everything through.
      client.failCollections.clear();
      await profile(db, 'pro1', at: t1);
      final second = await service.sync();
      expect(second.skipped, 0);
      expect(client._store['piva_profile']!.containsKey('pro1'), isTrue);
      expect(persistence.getLastSyncAt(), t1);
    });

    test('a write to piva_payments triggers the auto-sync', () async {
      final (db, _, _, _) = await _harness();
      final fired = Completer<void>();
      var runs = 0;
      final auto = PocketBaseAutoSync(
        db: db,
        isEnabled: () => true,
        runSync: () async {
          runs++;
          if (!fired.isCompleted) fired.complete();
        },
        debounce: const Duration(milliseconds: 20),
      );
      addTearDown(auto.dispose);

      await db.into(db.pivaPayments).insert(
          PivaPaymentsCompanion.insert(id: 'pay1', userId: const Value('u1')));

      await fired.future.timeout(const Duration(seconds: 2));
      // Let a second, unwanted run show itself before counting.
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(runs, 1, reason: 'one write, one debounced sync');
    });
  });
}
