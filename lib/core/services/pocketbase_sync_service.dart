import 'dart:async';

import 'package:budgetti/core/database/database.dart';
import 'package:budgetti/core/services/persistence_service.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:pocketbase/pocketbase.dart' as pb;

/// Per-sync result, surfaced in Settings.
class SyncSummary {
  final int pushed;
  final int pulled;
  final int conflicts;
  final int skipped;
  final DateTime? lastSyncAt;
  final String? error;

  const SyncSummary({
    this.pushed = 0,
    this.pulled = 0,
    this.conflicts = 0,
    this.skipped = 0,
    this.lastSyncAt,
    this.error,
  });

  bool get hasChanges => pushed + pulled + conflicts > 0;

  @override
  String toString() {
    if (error != null) return 'Sync failed';
    if (!hasChanges && skipped == 0) return 'Already in sync';
    final parts = <String>[];
    if (pushed > 0) parts.add('↑$pushed pushed');
    if (pulled > 0) parts.add('↓$pulled pulled');
    if (conflicts > 0) parts.add('$conflicts conflicts (local won)');
    if (skipped > 0) parts.add('$skipped skipped');
    return parts.isEmpty ? 'Already in sync' : parts.join(' · ');
  }
}

/// The only IO seam in sync: reads remote changes and upserts rows by id.
/// Faked in tests; [PocketBaseSyncClient] wraps the real SDK.
abstract class SyncClient {
  String get userId;

  /// Rows in [collection] whose `lastUpdated` is after [since] (ISO filter).
  Future<List<Map<String, dynamic>>> listChanges(
      String collection, DateTime since);

  /// Update [id], or create it (with `id` + `owner`) when missing.
  Future<void> upsert(
      String collection, String id, Map<String, dynamic> body);
}

/// [SyncClient] over a live PocketBase instance. `owner` on create is the
/// authed user; the API rules (`owner = @request.auth.id`) require it.
class PocketBaseSyncClient implements SyncClient {
  final pb.PocketBase client;
  PocketBaseSyncClient(this.client);

  @override
  String get userId => client.authStore.record?.id ?? '';

  @override
  Future<List<Map<String, dynamic>>> listChanges(
      String collection, DateTime since) async {
    final rows = await client.collection(collection).getFullList(
          batch: 500,
          filter: 'lastUpdated > "${since.toUtc().toIso8601String()}"',
        );
    return rows.map((r) => {...r.data, 'id': r.id}).toList();
  }

  @override
  Future<void> upsert(
      String collection, String id, Map<String, dynamic> body) async {
    try {
      await client.collection(collection).update(id, body: body);
    } on pb.ClientException catch (e) {
      // 404 = record doesn't exist yet → create with our id + owner.
      if (e.statusCode == 404) {
        await client
            .collection(collection)
            .create(body: {...body, 'id': id, 'owner': userId});
      } else {
        rethrow;
      }
    }
  }
}

/// One synced Drift table → one PocketBase collection. The generic
/// push/pull/LWW loop in [PocketBaseSyncService] drives these; only the
/// field mapping is per-table.
class _Spec {
  final String collection;
  final Future<List<_Row>> Function(AppDatabase db, DateTime cursor, DateTime now)
      localChanges;
  final Future<Map<String, DateTime?>> Function(AppDatabase db, Set<String> ids)
      localLastUpdated;
  final Future<void> Function(
          AppDatabase db, String userId, Map<String, dynamic> row)
      applyRemote;
  const _Spec(this.collection, this.localChanges, this.localLastUpdated,
      this.applyRemote);
}

class _Row {
  final String id;
  final DateTime? lastUpdated;
  final Map<String, dynamic> body;
  const _Row({required this.id, this.lastUpdated, required this.body});
}

String? _toIso(DateTime? d) => d?.toUtc().toIso8601String();
DateTime? _fromIso(dynamic v) {
  if (v == null) return null;
  final s = v.toString();
  return s.isEmpty ? null : DateTime.parse(s);
}

int _toInt(dynamic v) => (v as num?)?.toInt() ?? 0;
double _toDouble(dynamic v) => (v as num?)?.toDouble() ?? 0.0;
bool _toBool(dynamic v) => v == true;
List<String> _toStringList(dynamic v) =>
    (v as List?)?.map((e) => e.toString()).toList() ?? const [];

/// Syncs the five LWW tables between Drift and PocketBase.
///
/// Protocol (single user, last-write-wins per row):
///   1. cursor = stored lastSyncAt (epoch on first sync).
///   2. PULL remote changes (lastUpdated > cursor); apply each unless the
///      local row is newer (conflict — local wins, pushed next).
///   3. PUSH local changes (lastUpdated > cursor, or NULL = seeds/restore
///      never stamped). NULL rows are stamped `now` so they carry a cursor.
///      Rows just applied from remote are skipped (already current).
///   4. cursor = max lastUpdated seen across pull + push.
///
/// Pull precedes push so a stale local edit can't clobber a newer remote row
/// before the comparison runs.
class PocketBaseSyncService {
  final SyncClient _client;
  final AppDatabase _db;
  final PersistenceService _persistence;
  final String _userId;
  bool _isSyncing = false;

  /// True while a sync is in flight — drives the top-right spinner in the UI.
  final ValueNotifier<bool> syncing = ValueNotifier<bool>(false);

  late final List<_Spec> _specs = [
    _categories,
    _tags,
    _accounts,
    _transactions,
    _budgets,
  ];

  PocketBaseSyncService(this._client, this._db, this._persistence, this._userId);

  bool get isSyncing => _isSyncing;

  Future<SyncSummary> sync() async {
    if (_isSyncing) return const SyncSummary();
    _isSyncing = true;
    syncing.value = true;
    final now = DateTime.now();
    var pushed = 0, pulled = 0, conflicts = 0;
    try {
      var cursor = _persistence.getLastSyncAt();
      var maxTs = cursor;
      var skipped = 0;

      for (final spec in _specs) {
        // --- PULL ---
        final remote = await _client.listChanges(spec.collection, cursor);
        final applied = <String>{};
        if (remote.isNotEmpty) {
          final localMap = await spec.localLastUpdated(
              _db, remote.map((r) => r['id'] as String).toSet());
          for (final r in remote) {
            final id = r['id'] as String;
            final remoteTs = _fromIso(r['lastUpdated']);
            final localTs = localMap[id];
            if (localTs != null &&
                remoteTs != null &&
                localTs.isAfter(remoteTs)) {
              conflicts++; // local wins; its edit is pushed below
              continue;
            }
            await spec.applyRemote(_db, _userId, r);
            applied.add(id);
            pulled++;
            if (remoteTs != null && remoteTs.isAfter(maxTs)) maxTs = remoteTs;
          }
        }

        // --- PUSH (skip rows just applied from remote) ---
        // Resilient: a row PB rejects (e.g. per-device seed ids that aren't
        // valid server PKs) is skipped + counted, not allowed to abort the
        // whole sync. User-created rows use UUIDs and sync fine; defaults are
        // re-seeded on every device so they don't need to travel.
        final changes = await spec.localChanges(_db, cursor, now);
        for (final row in changes) {
          if (applied.contains(row.id)) continue;
          try {
            await _client.upsert(spec.collection, row.id, row.body);
            pushed++;
            final ts = row.lastUpdated ?? now;
            if (ts.isAfter(maxTs)) maxTs = ts;
          } catch (e) {
            debugPrint('PB sync: skip ${spec.collection}/${row.id}: $e');
            skipped++;
          }
        }
      }

      await _persistence.setLastSyncAt(maxTs);
      final summary = SyncSummary(
        pushed: pushed,
        pulled: pulled,
        conflicts: conflicts,
        skipped: skipped,
        lastSyncAt: maxTs,
      );
      await _persistence.setLastSyncSummary(summary.toString());
      return summary;
    } catch (e) {
      debugPrint('PocketBase sync failed: $e');
      await _persistence.setLastSyncSummary('Sync failed');
      return SyncSummary(error: e.toString());
    } finally {
      _isSyncing = false;
      syncing.value = false;
    }
  }

  // ── categories ──────────────────────────────────────────────────────────
  _Spec get _categories => _Spec(
        'categories',
        (db, cursor, now) async {
          final rows = await (db.select(db.categories)
                ..where((t) =>
                    t.lastUpdated.isBiggerThanValue(cursor) |
                    t.lastUpdated.isNull()))
              .get();
          return _stampAndMap(rows, now,
              idOf: (c) => c.id,
              lastUpdatedOf: (c) => c.lastUpdated,
              stampWrite: (ids) => (db.update(db.categories)
                    ..where((t) => t.id.isIn(ids)))
                  .write(CategoriesCompanion(lastUpdated: Value(now))),
            toBody: (c) => {
              'name': c.name,
              'iconCode': c.iconCode,
              'colorHex': c.colorHex,
              'type': c.type,
              'description': c.description,
              'isDeleted': c.isDeleted,
              'lastUpdated': _toIso(c.lastUpdated ?? now),
            });
        },
        (db, ids) async {
          final rows = await (db.select(db.categories)
                ..where((t) => t.id.isIn(ids)))
              .get();
          return {for (final r in rows) r.id: r.lastUpdated};
        },
        (db, userId, r) => db.into(db.categories).insert(
              CategoriesCompanion.insert(
                id: r['id'] as String,
                userId: Value(userId),
                name: r['name'] as String? ?? '',
                iconCode: _toInt(r['iconCode']),
                colorHex: _toInt(r['colorHex']),
                type: r['type'] as String? ?? 'expense',
                description: Value(r['description'] as String?),
                isDeleted: Value(_toBool(r['isDeleted'])),
                lastUpdated: Value(_fromIso(r['lastUpdated'])),
              ),
              mode: InsertMode.insertOrReplace,
            ),
      );

  // ── tags ────────────────────────────────────────────────────────────────
  _Spec get _tags => _Spec(
        'tags',
        (db, cursor, now) async {
          final rows = await (db.select(db.tags)
                ..where((t) =>
                    t.lastUpdated.isBiggerThanValue(cursor) |
                    t.lastUpdated.isNull()))
              .get();
          return _stampAndMap(rows, now,
              idOf: (t) => t.id,
              lastUpdatedOf: (t) => t.lastUpdated,
              stampWrite: (ids) => (db.update(db.tags)
                    ..where((t) => t.id.isIn(ids)))
                  .write(TagsCompanion(lastUpdated: Value(now))),
            toBody: (t) => {
              'name': t.name,
              'colorHex': t.colorHex,
              'isDeleted': t.isDeleted,
              'lastUpdated': _toIso(t.lastUpdated ?? now),
            });
        },
        (db, ids) async {
          final rows = await (db.select(db.tags)..where((t) => t.id.isIn(ids)))
              .get();
          return {for (final r in rows) r.id: r.lastUpdated};
        },
        (db, userId, r) => db.into(db.tags).insert(
              TagsCompanion.insert(
                id: r['id'] as String,
                userId: Value(userId),
                name: r['name'] as String? ?? '',
                colorHex: _toInt(r['colorHex']),
                isDeleted: Value(_toBool(r['isDeleted'])),
                lastUpdated: Value(_fromIso(r['lastUpdated'])),
              ),
              mode: InsertMode.insertOrReplace,
            ),
      );

  // ── accounts ────────────────────────────────────────────────────────────
  _Spec get _accounts => _Spec(
        'accounts',
        (db, cursor, now) async {
          final rows = await (db.select(db.accounts)
                ..where((t) =>
                    t.lastUpdated.isBiggerThanValue(cursor) |
                    t.lastUpdated.isNull()))
              .get();
          return _stampAndMap(rows, now,
              idOf: (a) => a.id,
              lastUpdatedOf: (a) => a.lastUpdated,
              stampWrite: (ids) => (db.update(db.accounts)
                    ..where((t) => t.id.isIn(ids)))
                  .write(AccountsCompanion(lastUpdated: Value(now))),
            toBody: (a) => {
              'name': a.name,
              'balance': a.balance,
              'currency': a.currency,
              'providerName': a.providerName,
              'isDefault': a.isDefault,
              'initialBalanceDate': _toIso(a.initialBalanceDate),
              'isDeleted': a.isDeleted,
              'lastUpdated': _toIso(a.lastUpdated ?? now),
            });
        },
        (db, ids) async {
          final rows =
              await (db.select(db.accounts)..where((t) => t.id.isIn(ids)))
                  .get();
          return {for (final r in rows) r.id: r.lastUpdated};
        },
        (db, userId, r) => db.into(db.accounts).insert(
              AccountsCompanion.insert(
                id: r['id'] as String,
                userId: Value(userId),
                name: r['name'] as String? ?? '',
                balance: Value(_toDouble(r['balance'])),
                currency: Value(r['currency'] as String? ?? 'EUR'),
                providerName: Value(r['providerName'] as String?),
                isDefault: Value(_toBool(r['isDefault'])),
                initialBalanceDate: Value(_fromIso(r['initialBalanceDate'])),
                isDeleted: Value(_toBool(r['isDeleted'])),
                lastUpdated: Value(_fromIso(r['lastUpdated'])),
              ),
              mode: InsertMode.insertOrReplace,
            ),
      );

  // ── transactions ─────────────────────────────────────────────────────────
  _Spec get _transactions => _Spec(
        'transactions',
        (db, cursor, now) async {
          final rows = await (db.select(db.transactions)
                ..where((t) =>
                    t.lastUpdated.isBiggerThanValue(cursor) |
                    t.lastUpdated.isNull()))
              .get();
          return _stampAndMap(rows, now,
              idOf: (t) => t.id,
              lastUpdatedOf: (t) => t.lastUpdated,
              stampWrite: (ids) => (db.update(db.transactions)
                    ..where((t) => t.id.isIn(ids)))
                  .write(TransactionsCompanion(lastUpdated: Value(now))),
            toBody: (t) => {
              'accountId': t.accountId,
              'toAccountId': t.toAccountId,
              'amount': t.amount,
              'description': t.description,
              'category': t.category,
              'type': t.type,
              'date': _toIso(t.date),
              'tags': t.tags ?? const <String>[],
              'isDeleted': t.isDeleted,
              'lastUpdated': _toIso(t.lastUpdated ?? now),
            });
        },
        (db, ids) async {
          final rows = await (db.select(db.transactions)
                ..where((t) => t.id.isIn(ids)))
              .get();
          return {for (final r in rows) r.id: r.lastUpdated};
        },
        (db, userId, r) => db.into(db.transactions).insert(
              TransactionsCompanion.insert(
                id: r['id'] as String,
                userId: Value(userId),
                accountId: Value(r['accountId'] as String?),
                toAccountId: Value(r['toAccountId'] as String?),
                amount: _toDouble(r['amount']),
                description: r['description'] as String? ?? '',
                category: r['category'] as String? ?? '',
                type: Value(r['type'] as String? ?? 'expense'),
                date: _fromIso(r['date']) ?? DateTime.now(),
                tags: Value(_toStringList(r['tags'])),
                isDeleted: Value(_toBool(r['isDeleted'])),
                lastUpdated: Value(_fromIso(r['lastUpdated'])),
              ),
              mode: InsertMode.insertOrReplace,
            ),
      );

  // ── budgets ──────────────────────────────────────────────────────────────
  _Spec get _budgets => _Spec(
        'budgets',
        (db, cursor, now) async {
          final rows = await (db.select(db.budgets)
                ..where((t) =>
                    t.lastUpdated.isBiggerThanValue(cursor) |
                    t.lastUpdated.isNull()))
              .get();
          return _stampAndMap(rows, now,
              idOf: (b) => b.id,
              lastUpdatedOf: (b) => b.lastUpdated,
              stampWrite: (ids) => (db.update(db.budgets)
                    ..where((t) => t.id.isIn(ids)))
                  .write(BudgetsCompanion(lastUpdated: Value(now))),
            toBody: (b) => {
              'category': b.category,
              'limitAmount': b.limitAmount,
              'period': b.period,
              'isDeleted': b.isDeleted,
              'lastUpdated': _toIso(b.lastUpdated ?? now),
            });
        },
        (db, ids) async {
          final rows =
              await (db.select(db.budgets)..where((t) => t.id.isIn(ids)))
                  .get();
          return {for (final r in rows) r.id: r.lastUpdated};
        },
        (db, userId, r) => db.into(db.budgets).insert(
              BudgetsCompanion.insert(
                id: r['id'] as String,
                userId: Value(userId),
                category: r['category'] as String? ?? '',
                limitAmount: _toDouble(r['limitAmount']),
                period: r['period'] as String? ?? 'monthly',
                isDeleted: Value(_toBool(r['isDeleted'])),
                lastUpdated: Value(_fromIso(r['lastUpdated'])),
              ),
              mode: InsertMode.insertOrReplace,
            ),
      );

  /// Stamps NULL-`lastUpdated` rows (seeds / restored backups) with [now],
  /// writes the stamp back so they don't re-sync, and maps every row to a
  /// [_Row] body for push.
  Future<List<_Row>> _stampAndMap<T>(
    List<T> rows,
    DateTime now, {
    required String Function(T) idOf,
    required DateTime? Function(T) lastUpdatedOf,
    required Future<void> Function(Set<String> ids) stampWrite,
    required Map<String, dynamic> Function(T) toBody,
  }) async {
    final nullIds = <String>{};
    for (final r in rows) {
      if (lastUpdatedOf(r) == null) nullIds.add(idOf(r));
    }
    if (nullIds.isNotEmpty) await stampWrite(nullIds);

    return rows
        .map((r) => _Row(
              id: idOf(r),
              lastUpdated: lastUpdatedOf(r) ?? now,
              body: toBody(r),
            ))
        .toList();
  }
}

/// Pushes to PocketBase the moment local data changes, instead of only on the
/// daily schedule / manual "Sync now". Every insert/edit/delete on a synced
/// table lands on the DB, so one debounced listener there covers all call
/// sites (add modal, edit page, import, delete, email-inbox commit).
///
/// Debounced so a burst (e.g. an import of many rows) collapses to one sync.
/// Pulled rows keep their remote `lastUpdated`, so applying them never looks
/// like a fresh local change — no push/pull ping-pong.
class PocketBaseAutoSync {
  PocketBaseAutoSync({
    required AppDatabase db,
    required bool Function() isEnabled,
    required Future<void> Function() runSync,
    this.debounce = const Duration(seconds: 2),
  })  : _db = db,
        _isEnabled = isEnabled,
        _runSync = runSync {
    _sub = _db
        .tableUpdates(TableUpdateQuery.onAllTables([
          _db.transactions,
          _db.accounts,
          _db.budgets,
          _db.categories,
          _db.tags,
        ]))
        .listen((_) => _schedule());
  }

  final AppDatabase _db;
  final bool Function() _isEnabled;
  final Future<void> Function() _runSync;
  final Duration debounce;
  StreamSubscription<void>? _sub;
  Timer? _timer;

  void _schedule() {
    if (!_isEnabled()) return; // no server configured → stay offline
    _timer?.cancel();
    _timer = Timer(debounce, () async {
      try {
        await _runSync();
      } catch (e) {
        debugPrint('PB auto-sync failed: $e');
      }
    });
  }

  void dispose() {
    _timer?.cancel();
    _sub?.cancel();
  }
}
