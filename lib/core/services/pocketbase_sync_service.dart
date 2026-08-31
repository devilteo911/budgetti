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

  /// Rows where the server's LWW guard rejected our push and the remote body
  /// was applied locally — the mirror of [conflicts] ("local won").
  final int remoteWins;
  final DateTime? lastSyncAt;
  final String? error;

  /// A 401 aborted the sync: the PB token is expired/revoked. The listener on
  /// [PocketBaseSyncService.authExpired] clears the dead session so the
  /// router's redirect offers login again.
  final bool authExpired;

  /// Rows dead-lettered this run (crossed [PocketBaseSyncService._maxPushAttempts]
  /// failed attempts) — surfaced once here, not retried afterwards.
  final int deadLettered;

  /// First per-row rejection message, so "N skipped" is diagnosable from the
  /// Settings subtitle instead of only from debug logs.
  final String? firstSkipReason;

  const SyncSummary({
    this.pushed = 0,
    this.pulled = 0,
    this.conflicts = 0,
    this.skipped = 0,
    this.remoteWins = 0,
    this.lastSyncAt,
    this.error,
    this.authExpired = false,
    this.deadLettered = 0,
    this.firstSkipReason,
  });

  bool get hasChanges => pushed + pulled + conflicts + remoteWins > 0;

  @override
  String toString() {
    if (authExpired) return 'Session expired — log in again';
    if (error != null) return 'Sync failed';
    if (!hasChanges && skipped == 0 && deadLettered == 0) {
      return 'Already in sync';
    }
    final parts = <String>[];
    if (pushed > 0) parts.add('↑$pushed pushed');
    if (pulled > 0) parts.add('↓$pulled pulled');
    if (conflicts > 0) parts.add('$conflicts conflicts (local won)');
    if (remoteWins > 0) parts.add('$remoteWins remote-wins');
    if (skipped > 0) {
      parts.add(firstSkipReason == null
          ? '$skipped skipped'
          : '$skipped skipped ($firstSkipReason)');
    }
    if (deadLettered > 0) parts.add('$deadLettered dead-lettered');
    return parts.isEmpty ? 'Already in sync' : parts.join(' · ');
  }
}

/// The server's LWW guard rejected a push: the stored row's `lastUpdated` is
/// newer than the body's (see server/pb_hooks/lww_guard.pb.js). The sync
/// treats this as *remote wins* — fetch + apply + advance — never a skip.
class LwwStaleWrite implements Exception {
  final String collection;
  final String id;
  const LwwStaleWrite(this.collection, this.id);
  @override
  String toString() => 'LwwStaleWrite($collection/$id)';
}

/// A PB request came back 401: the token is expired or revoked. Aborts the
/// whole sync (all six collections would fail identically).
class SyncAuthExpired implements Exception {
  const SyncAuthExpired();
}

/// Per-row outcome of a batched push, aligned with the input order.
class PushOutcome {
  /// The server-stamped `updated` when the row landed (the pull cursor is
  /// driven by this server clock — see the cursor notes in [PocketBaseSyncService]).
  final DateTime? updated;
  final LwwStaleWrite? stale;
  final Object? error;
  const PushOutcome.pushed(this.updated) : stale = null, error = null;
  const PushOutcome.remoteWins(this.stale) : updated = null, error = null;
  const PushOutcome.failed(this.error) : updated = null, stale = null;
  bool get pushed => updated != null;
}

/// The only IO seam in sync: reads remote changes and upserts rows by id.
/// Faked in tests; [PocketBaseSyncClient] wraps the real SDK.
abstract class SyncClient {
  String get userId;

  /// Rows in [collection] whose `updated` (server-stamped autodate) is after
  /// [since]. Driving the pull by the server clock, not by the device-written
  /// `lastUpdated`, is what keeps a fast device clock from permanently
  /// diverging the pull filter.
  Future<List<Map<String, dynamic>>> listChanges(
      String collection, DateTime since);

  /// Update [id], or create it (with `id` + `owner`) when missing. Returns
  /// the stored row (server fields included); throws [LwwStaleWrite] when the
  /// server's guard says remote wins, [SyncAuthExpired] on 401.
  Future<Map<String, dynamic>> upsert(
      String collection, String id, Map<String, dynamic> body);

  /// One stored row, for the remote-wins apply after an [LwwStaleWrite].
  Future<Map<String, dynamic>> getRecord(String collection, String id);

  /// Fails with [SyncAuthExpired] when the stored token no longer
  /// authenticates. PB never 401s rule-guarded CRUD: an invalid token just
  /// reads as anonymous, so pulls silently come back empty and pushes fail as
  /// 404/rule-denied — the sync would report success over a dead session.
  /// The auth endpoint is the only place a dead token says 401.
  Future<void> ensureAuthenticated() async {}

  /// Pushes [rows] (id + body) in bulk. The real client uses PB's
  /// transactional `/api/batch` (PUT upserts, ≤200 per call); this default
  /// loops [upsert] so simple clients and tests get identical per-row
  /// semantics. Returns one [PushOutcome] per input row, in order.
  Future<List<PushOutcome>> batchPush(
      String collection, List<(String, Map<String, dynamic>)> rows) async {
    return [
      for (final (id, body) in rows)
        await () async {
          try {
            final row = await upsert(collection, id, body);
            return PushOutcome.pushed(_fromIso(row['updated']));
          } on LwwStaleWrite catch (e) {
            return PushOutcome.remoteWins(e);
          } on SyncAuthExpired {
            rethrow;
          } catch (e) {
            return PushOutcome.failed(e);
          }
        }()
    ];
  }
}

/// [SyncClient] over a live PocketBase instance. `owner` on create is the
/// authed user; the API rules (`owner = @request.auth.id`) require it.
class PocketBaseSyncClient implements SyncClient {
  final pb.PocketBase client;
  PocketBaseSyncClient(this.client);

  /// PB's documented ceiling for `/api/batch` sub-requests (and what the
  /// server's enable_batch hook configures).
  static const _batchChunk = 200;

  @override
  String get userId => client.authStore.record?.id ?? '';

  @override
  Future<void> ensureAuthenticated() async {
    try {
      // Rotates the token (a fresh expiry, persisted by the AsyncAuthStore) —
      // a session stays alive as long as the app syncs within the token
      // duration, and surfaces re-login when it doesn't.
      await client.collection('users').authRefresh();
    } on pb.ClientException catch (e) {
      throw _mapClientException(e);
    }
  }

  @override
  Future<List<Map<String, dynamic>>> listChanges(
      String collection, DateTime since) async {
    try {
      final rows = await client.collection(collection).getFullList(
            batch: 500,
            filter: 'updated > "${pbDateLiteral(since)}"',
          );
      return rows.map((r) => {...r.data, 'id': r.id}).toList();
    } on pb.ClientException catch (e) {
      throw _mapClientException(e);
    }
  }

  @override
  Future<List<PushOutcome>> batchPush(
      String collection, List<(String, Map<String, dynamic>)> rows) async {
    final outcomes = <PushOutcome>[];
    for (var i = 0; i < rows.length; i += _batchChunk) {
      final chunk = rows.skip(i).take(_batchChunk).toList();
      outcomes.addAll(await _pushChunk(collection, chunk));
    }
    return outcomes;
  }

  /// One `/api/batch` call per chunk: PUT upserts (id in the body) — PB
  /// creates when missing and updates when present, and the update route is
  /// what the server's LWW guard watches, so stale rows reject here too.
  /// The batch is transactional all-or-nothing, so any failure rolls the
  /// whole chunk back and we replay row-by-row through [upsert] — per-row
  /// outcomes (skip counting, remote-wins, dead-lettering) survive intact.
  Future<List<PushOutcome>> _pushChunk(
      String collection, List<(String, Map<String, dynamic>)> chunk) async {
    final batch = client.createBatch();
    final sub = batch.collection(collection);
    for (final (id, body) in chunk) {
      sub.upsert(body: {...body, 'id': id, 'owner': userId});
    }
    try {
      final results = await batch.send();
      return [
        for (final r in results)
          PushOutcome.pushed(_fromIso(
              (r.body as Map<String, dynamic>?)?['updated']))
      ];
    } on pb.ClientException catch (e) {
      if (e.statusCode == 401) throw const SyncAuthExpired();
      debugPrint(
          'PB sync: batch chunk failed ($collection, ${chunk.length} rows), '
          'replaying row-by-row: $e');
      // ponytail: replay-through-upsert also covers the mixed case; a future
      // per-item error map from PB could skip straight to the guilty rows.
      final outcomes = <PushOutcome>[];
      for (final (id, body) in chunk) {
        try {
          final row = await upsert(collection, id, body);
          outcomes.add(PushOutcome.pushed(_fromIso(row['updated'])));
        } on LwwStaleWrite catch (e2) {
          outcomes.add(PushOutcome.remoteWins(e2));
        } on SyncAuthExpired {
          rethrow;
        } catch (e2) {
          outcomes.add(PushOutcome.failed(e2));
        }
      }
      return outcomes;
    }
  }

  @override
  Future<Map<String, dynamic>> upsert(
      String collection, String id, Map<String, dynamic> body) async {
    try {
      final r = await client.collection(collection).update(id, body: body);
      return {...r.data, 'id': r.id};
    } on pb.ClientException catch (e) {
      // 404 = record doesn't exist yet → create with our id + owner.
      if (e.statusCode == 404) {
        try {
          final r = await client
              .collection(collection)
              .create(body: {...body, 'id': id, 'owner': userId});
          return {...r.data, 'id': r.id};
        } on pb.ClientException catch (e2) {
          // Another device created it between our 404 and this create. Fall
          // through to update — the server's LWW guard arbitrates which body
          // deserves to win.
          if (_isPkConflict(e2)) return await _retryUpdate(collection, id, body);
          throw _mapClientException(e2, collection: collection, id: id);
        }
      }
      throw _mapClientException(e, collection: collection, id: id);
    }
  }

  Future<Map<String, dynamic>> _retryUpdate(
      String collection, String id, Map<String, dynamic> body) async {
    try {
      final r = await client.collection(collection).update(id, body: body);
      return {...r.data, 'id': r.id};
    } on pb.ClientException catch (e) {
      throw _mapClientException(e, collection: collection, id: id);
    }
  }

  @override
  Future<Map<String, dynamic>> getRecord(String collection, String id) async {
    try {
      final r = await client.collection(collection).getOne(id);
      return {...r.data, 'id': r.id};
    } on pb.ClientException catch (e) {
      throw _mapClientException(e, collection: collection, id: id);
    }
  }

  /// Translates raw SDK errors into the exceptions the sync loop reasons
  /// about: 401 → [SyncAuthExpired], the guard's rejection → [LwwStaleWrite].
  Never _mapClientException(pb.ClientException e,
      {String collection = '', String id = ''}) {
    if (e.statusCode == 401) throw const SyncAuthExpired();
    final msg = (e.response['message'] as String?) ?? '';
    if (msg.toLowerCase().contains('lww_stale_write')) {
      throw LwwStaleWrite(collection, id);
    }
    throw e;
  }

  /// PB's duplicate-id create failure: 400 with data.id populated
  /// (`validation_pk_invalid`). Confirms the row exists rather than the body
  /// being invalid.
  bool _isPkConflict(pb.ClientException e) =>
      e.statusCode == 400 && e.response['data']?['id'] != null;

  /// Live (non-deleted) row counts per collection for the current user.
  /// Drives the post-login sync-setup choice ("the server already has N…").
  Future<Map<String, int>> counts() async {
    final out = <String, int>{};
    for (final c in syncedCollections) {
      final page = await client
          .collection(c)
          .getList(page: 1, perPage: 1, filter: 'isDeleted = false');
      out[c] = page.totalItems;
    }
    return out;
  }
}

/// The LWW-synced collections, in push order (parents before rows that
/// reference them by name/id).
const syncedCollections = [
  'categories',
  'tags',
  'accounts',
  'transactions',
  'budgets',
  'installments',
];

/// One synced Drift table → one PocketBase collection. The generic
/// push/pull/LWW loop in [PocketBaseSyncService] drives these; only the
/// field mapping is per-table.
class _Spec {
  final String collection;
  final Future<List<_Row>> Function(AppDatabase db, DateTime cursor, DateTime now)
      localChanges;
  final Future<Map<String, DateTime?>> Function(AppDatabase db, Set<String> ids)
      localLastUpdated;

  /// Applies remote rows in one `db.batch()` — one table-update notification
  /// per collection instead of one per row (the full-pull watch storm).
  final Future<void> Function(
          AppDatabase db, String userId, List<Map<String, dynamic>> rows)
      applyRemotes;

  /// Writes `lastUpdated = now` on [ids]. Called only for rows the server
  /// actually accepted — see the push loop in [PocketBaseSyncService.sync].
  final Future<void> Function(AppDatabase db, Set<String> ids, DateTime now)
      stamp;
  const _Spec(this.collection, this.localChanges, this.localLastUpdated,
      this.applyRemotes, this.stamp);
}

class _Row {
  final String id;
  final DateTime? lastUpdated;
  final Map<String, dynamic> body;

  /// Row arrived with NULL `lastUpdated` (seed / restored backup) — it needs a
  /// stamp, but only once the push succeeds.
  final bool needsStamp;
  const _Row({
    required this.id,
    this.lastUpdated,
    required this.body,
    this.needsStamp = false,
  });
}

String? _toIso(DateTime? d) => d?.toUtc().toIso8601String();
DateTime? _fromIso(dynamic v) {
  if (v == null) return null;
  final s = v.toString();
  if (s.isEmpty) return null;
  // PB sends `YYYY-MM-DD HH:MM:SS.sssZ` (space separator) — DateTime.parse
  // accepts it, but normalize defensively for any strict future caller.
  return DateTime.parse(s.replaceFirst(' ', 'T'));
}

/// Whole-second floor, UTC — see the pull conflict compare for why.
DateTime _toWholeSeconds(DateTime d) => DateTime.fromMillisecondsSinceEpoch(
    (d.toUtc().millisecondsSinceEpoch ~/ 1000) * 1000, isUtc: true);

int _toInt(dynamic v) => (v as num?)?.toInt() ?? 0;
double _toDouble(dynamic v) => (v as num?)?.toDouble() ?? 0.0;
bool _toBool(dynamic v) => v == true;
String? _emptyToNull(dynamic v) {
  final s = v?.toString();
  return (s == null || s.isEmpty) ? null : s;
}

/// PocketBase compares date filters as raw strings against its stored
/// `YYYY-MM-DD HH:MM:SS.sssZ` form — it does not parse the literal. Dart's
/// `toIso8601String()` emits a `T` separator, and 'T' > ' ', so
/// `updated > "2026-08-20T09:00:00.000Z"` hid EVERY row stamped on the same
/// calendar day as the cursor: server-side edits only became visible once the
/// UTC date rolled over. Same instant, space separator, and the compare is
/// chronological again (the same canonical form lww_guard.pb.js relies on).
String pbDateLiteral(DateTime t) =>
    t.toUtc().toIso8601String().replaceFirst('T', ' ');

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

  /// Flips true when a 401 aborted a sync (expired/revoked token). main()
  /// listens and clears the dead session so the router offers login.
  final ValueNotifier<bool> sessionExpired = ValueNotifier<bool>(false);

  static const _lockId = 'pb_sync';

  /// A crashed lock holder (OOM-killed bg task, force-stop) is taken over
  /// after this long instead of deadlocking every future sync.
  static const _lockStaleAfter = Duration(minutes: 15);

  late final List<_Spec> _specs = [
    _categories,
    _tags,
    _accounts,
    _transactions,
    _budgets,
    _installments,
  ];

  PocketBaseSyncService(this._client, this._db, this._persistence, this._userId);

  bool get isSyncing => _isSyncing;

  /// Claims the one-row DB mutex. `_isSyncing` only guards this instance,
  /// but the workmanager PB task builds its own service in another isolate —
  /// without the DB lock a background and a foreground sync interleave: the
  /// stale body clobbers newer server rows and the slower run overwrites the
  /// fresh cursor. INSERT OR IGNORE seeds the row; the guarded UPDATE is the
  /// atomic claim (SQLite serializes writers, so exactly one claimer sees
  /// running=0 / a stale timestamp).
  Future<bool> _claimSyncLock() async {
    await _db.into(_db.syncLocks).insert(
          SyncLocksCompanion.insert(id: _lockId),
          mode: InsertMode.insertOrIgnore,
        );
    final now = DateTime.now();
    final claimed = await (_db.update(_db.syncLocks)
          ..where((t) =>
              t.id.equals(_lockId) &
              (t.running.equals(false) |
                  t.acquiredAt.isSmallerThanValue(
                      now.subtract(_lockStaleAfter))))
        )
        .write(SyncLocksCompanion(
      running: const Value(true),
      acquiredAt: Value(now),
    ));
    return claimed > 0;
  }

  Future<void> _releaseSyncLock() async {
    await (_db.update(_db.syncLocks)..where((t) => t.id.equals(_lockId)))
        .write(const SyncLocksCompanion(running: Value(false)));
  }

  /// [full] ignores the stored cursors and considers every row on both sides —
  /// the recovery lever for a poisoned cursor (rows stranded behind it) and
  /// the engine of the git-style "push/pull everything" actions. [pull] /
  /// [push] select the direction; each cursor is only advanced by a run that
  /// actually ran its direction, so a one-way pass can never strand the other.
  ///
  /// There are two cursors, one per clock domain:
  ///   * push cursor (`pb_last_sync_at`): max local `lastUpdated` confirmed
  ///     pushed — selects which local rows get pushed.
  ///   * pull cursor (`pb_pull_sync_at`): max server-stamped `updated`
  ///     confirmed seen (pulled or pushed) — filters the remote listChanges.
  /// One shared cursor mixed device wall-clock stamps with server stamps, so
  /// a fast device clock diverged the pull filter permanently.
  Future<SyncSummary> sync({
    bool full = false,
    bool pull = true,
    bool push = true,
  }) async {
    if (_isSyncing) return const SyncSummary();
    // Another isolate is mid-sync (or a stale holder hasn't timed out yet):
    // bow out rather than interleave — the next scheduled run covers us.
    if (!await _claimSyncLock()) return const SyncSummary();
    _isSyncing = true;
    syncing.value = true;
    sessionExpired.value = false;
    final now = DateTime.now();
    var pushed = 0, pulled = 0, conflicts = 0, remoteWins = 0;
    var deadLettered = 0;
    var authExpired = false;
    try {
      // Dead-session probe before any data traffic: an expired token reads
      // as anonymous everywhere else (empty pulls look like "no changes").
      await _client.ensureAuthenticated();
      final pushCursor =
          full ? DateTime.fromMillisecondsSinceEpoch(0) : _persistence.getLastSyncAt();
      final pullCursor =
          full ? DateTime.fromMillisecondsSinceEpoch(0) : _persistence.getPullSyncAt();
      var maxPushTs = pushCursor;
      var maxPullTs = pullCursor;
      var skipped = 0;
      String? firstSkipReason;
      // Oldest lastUpdated among rows the server rejected (and that are not
      // dead-lettered): the push cursor must stay behind it, or the row is
      // never selected again (the exact bug that stranded a whole ledger
      // behind an advanced cursor).
      DateTime? minFailedTs;
      // A whole collection failed (typically 404: the server hasn't run the
      // migration that creates it yet). The other collections still sync, but
      // neither cursor may advance — moving it would strand every row the
      // failed collection never got to compare.
      var collectionFailed = false;

      for (final spec in _specs) {
        try {
          // --- PULL (server `updated` > pull cursor) ---
          final applied = <String>{};
          if (pull) {
            final remote = await _client.listChanges(spec.collection, pullCursor);
            if (remote.isNotEmpty) {
              final localMap = await spec.localLastUpdated(
                  _db, remote.map((r) => r['id'] as String).toSet());
              // One insertOrReplace per row inside a single db.batch(): a
              // table-update notification per row re-ran every watch N times
              // during a full pull; a batch emits once per table.
              final toApply = <Map<String, dynamic>>[];
              for (final r in remote) {
                final remoteTs = _fromIso(r['lastUpdated']);
                final localTs = localMap[r['id'] as String];
                // Compare at whole-second granularity: a restored backup
                // truncates local timestamps to seconds, so a sub-second-newer
                // remote would otherwise win forever on a tie-ish compare.
                if (localTs != null &&
                    remoteTs != null &&
                    localTs.isAfter(_toWholeSeconds(remoteTs))) {
                  conflicts++; // local wins; its edit is pushed below
                  continue;
                }
                toApply.add(r);
              }
              if (toApply.isNotEmpty) {
                await spec.applyRemotes(_db, _userId, toApply);
                for (final r in toApply) {
                  applied.add(r['id'] as String);
                  pulled++;
                  final rts = _fromIso(r['lastUpdated']);
                  if (rts != null && rts.isAfter(maxPushTs)) maxPushTs = rts;
                  final rus = _fromIso(r['updated']);
                  if (rus != null && rus.isAfter(maxPullTs)) maxPullTs = rus;
                }
              }
            }
          }

          // --- PUSH (skip rows just applied from remote) ---
          // Resilient: a row PB rejects (e.g. per-device seed ids that aren't
          // valid server PKs) is skipped + counted, not allowed to abort the
          // whole sync. Rows that keep failing are dead-lettered (see
          // [_maxPushAttempts]) so the cursor can pass them.
          //
          // A rejected row must keep its NULL `lastUpdated` so the next sync
          // selects it again. Stamping before the push (as this used to do)
          // burned the only marker that said "not on the server yet", and once
          // the cursor advanced past it the row was excluded forever.
          if (push) {
            final failures = await _failuresFor(spec.collection);
            bool isDeadLetter(_Row r) {
              final f = failures[r.id];
              return f != null &&
                  f.attempts >= _maxPushAttempts &&
                  r.lastUpdated != null &&
                  f.lastUpdatedMs ==
                      r.lastUpdated!.millisecondsSinceEpoch;
            }

            final rows = (await spec.localChanges(_db, pushCursor, now))
                .where((r) => !applied.contains(r.id) && !isDeadLetter(r))
                .toList();
            if (rows.isNotEmpty) {
              final outcomes = await _client.batchPush(spec.collection,
                  [for (final r in rows) (r.id, r.body)]);
              final toStamp = <String>{};
              for (var i = 0; i < rows.length; i++) {
                final row = rows[i];
                final o = outcomes[i];
                if (o.pushed) {
                  pushed++;
                  if (row.needsStamp) toStamp.add(row.id);
                  final ts = row.lastUpdated ?? now;
                  if (ts.isAfter(maxPushTs)) maxPushTs = ts;
                  final su = o.updated;
                  if (su != null && su.isAfter(maxPullTs)) maxPullTs = su;
                } else if (o.stale != null) {
                  // The server's guard says the stored row is newer — remote
                  // wins. Fetch it and adopt it instead of skipping: a skip
                  // rewinds the cursor and re-picks the fight every sync.
                  final remote =
                      await _client.getRecord(spec.collection, row.id);
                  await spec.applyRemotes(_db, _userId, [remote]);
                  remoteWins++;
                  final rts = _fromIso(remote['lastUpdated']);
                  if (rts != null && rts.isAfter(maxPushTs)) maxPushTs = rts;
                  final rus = _fromIso(remote['updated']);
                  if (rus != null && rus.isAfter(maxPullTs)) maxPullTs = rus;
                } else {
                  debugPrint(
                      'PB sync: skip ${spec.collection}/${row.id}: ${o.error}');
                  skipped++;
                  firstSkipReason ??= '${spec.collection}/${row.id}';
                  final ts = row.lastUpdated;
                  if (ts != null) {
                    final attempts =
                        await _recordFailure(spec.collection, row.id, ts, '${o.error}');
                    if (attempts >= _maxPushAttempts) {
                      deadLettered++;
                    } else if (minFailedTs == null ||
                        ts.isBefore(minFailedTs)) {
                      minFailedTs = ts;
                    }
                  }
                }
              }
              if (toStamp.isNotEmpty) await spec.stamp(_db, toStamp, now);
            }
          }
        } on SyncAuthExpired {
          // Expired token: every remaining collection would fail the same
          // way. Abort, freeze both cursors, and surface re-login.
          debugPrint('PB sync: auth expired, aborting');
          authExpired = true;
          break;
        } catch (e) {
          // The collection itself is unreachable (404 before its migration
          // has run, permissions, outage). Every other collection still
          // syncs; see [collectionFailed] for why the cursors freeze.
          debugPrint('PB sync: collection ${spec.collection} failed: $e');
          collectionFailed = true;
          skipped++;
          firstSkipReason ??= spec.collection;
        }
      }

      // The pull cursor advances from everything the run confirmed about the
      // server's clock — rows it applied and server stamps on pushed rows —
      // regardless of which direction ran: a push-only pass that skips this
      // would make the next pull re-fetch (and re-apply) our own writes.
      // ponytail: a remote write landing between our pull and our push
      // outcome stamps can still fall behind this cursor; the window is
      // minutes, the guard keeps it non-corrupting, and Settings →
      // "Pull everything" is the rescue if it ever matters.
      if (!collectionFailed && !authExpired && maxPullTs.isAfter(pullCursor)) {
        await _persistence.setPullSyncAt(maxPullTs);
      }
      if (push && !collectionFailed && !authExpired) {
        var newCursor = maxPushTs;
        if (minFailedTs != null && minFailedTs.isBefore(newCursor)) {
          newCursor = minFailedTs.subtract(const Duration(milliseconds: 1));
        }
        await _persistence.setLastSyncAt(newCursor);
      }
      final summary = SyncSummary(
        pushed: pushed,
        pulled: pulled,
        conflicts: conflicts,
        skipped: skipped,
        remoteWins: remoteWins,
        lastSyncAt: maxPushTs,
        authExpired: authExpired,
        deadLettered: deadLettered,
        firstSkipReason: firstSkipReason,
      );
      if (authExpired) sessionExpired.value = true;
      await _persistence.setLastSyncSummary(summary.toString());
      return summary;
    } on SyncAuthExpired {
      // The pre-flight probe found a dead session: nothing ran, both cursors
      // are untouched. Report it as an auth expiry, not a generic failure —
      // main() listens on [sessionExpired] to clear the session.
      debugPrint('PB sync: auth expired before any traffic');
      sessionExpired.value = true;
      const summary = SyncSummary(authExpired: true);
      await _persistence.setLastSyncSummary(summary.toString());
      return summary;
    } catch (e) {
      debugPrint('PocketBase sync failed: $e');
      await _persistence.setLastSyncSummary('Sync failed');
      return SyncSummary(error: e.toString());
    } finally {
      _isSyncing = false;
      syncing.value = false;
      await _releaseSyncLock();
    }
  }

  /// After this many consecutive failed attempts (at the same lastUpdated),
  /// a row is dead-lettered: no longer selected, no longer pinning the push
  /// cursor — surfaced once in the summary instead. A row edit restamps it
  /// and clears the slate.
  static const _maxPushAttempts = 5;

  /// Failure-ledger entries for [collection]: id → (lastUpdatedMs, attempts).
  /// A row is dead-lettered only while BOTH attempts ≥ [maxPushAttempts] AND
  /// its lastUpdated still matches the failed one — editing the row changes
  /// the stamp and un-dead-letters it.
  Future<Map<String, SyncFailure>> _failuresFor(String collection) async {
    final rows = await (_db.select(_db.syncFailures)
          ..where((t) => t.collection.equals(collection)))
        .get();
    return {for (final r in rows) r.recordId: r};
  }

  /// Increments the failure ledger for one row (resetting when its
  /// lastUpdated changed since the last failure — the row was edited, so the
  /// old verdict no longer applies) and returns the new attempt count.
  Future<int> _recordFailure(
      String collection, String id, DateTime lastUpdated, Object error) async {
    final ms = lastUpdated.millisecondsSinceEpoch;
    final existing = await (_db.select(_db.syncFailures)
          ..where((t) =>
              t.collection.equals(collection) & t.recordId.equals(id)))
        .getSingleOrNull();
    // Read-modify-write, not an UPSERT: safe because the cross-isolate lock
    // means exactly one sync writes here at a time.
    final nextAttempts =
        (existing == null || existing.lastUpdatedMs != ms) ? 1 : existing.attempts + 1;
    final companion = SyncFailuresCompanion(
      collection: Value(collection),
      recordId: Value(id),
      lastUpdatedMs: Value(ms),
      attempts: Value(nextAttempts),
      lastError: Value('$error'),
      lastAttemptAt: Value(DateTime.now()),
    );
    if (existing == null) {
      await _db.into(_db.syncFailures).insert(companion);
    } else {
      await (_db.update(_db.syncFailures)
            ..where((t) =>
                t.collection.equals(collection) & t.recordId.equals(id)))
          .write(companion);
    }
    return nextAttempts;
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
          return _mapRows(rows, now,
              idOf: (c) => c.id,
              lastUpdatedOf: (c) => c.lastUpdated,
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
        (db, userId, rows) => db.batch((b) {
              for (final r in rows) {
                b.insert(
                    db.categories,
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
                    mode: InsertMode.insertOrReplace);
              }
            }),
        (db, ids, now) => (db.update(db.categories)
              ..where((t) => t.id.isIn(ids)))
            .write(CategoriesCompanion(lastUpdated: Value(now))),
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
          return _mapRows(rows, now,
              idOf: (t) => t.id,
              lastUpdatedOf: (t) => t.lastUpdated,
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
        (db, userId, rows) => db.batch((b) {
              for (final r in rows) {
                b.insert(
                    db.tags,
                    TagsCompanion.insert(
                      id: r['id'] as String,
                      userId: Value(userId),
                      name: r['name'] as String? ?? '',
                      colorHex: _toInt(r['colorHex']),
                      isDeleted: Value(_toBool(r['isDeleted'])),
                      lastUpdated: Value(_fromIso(r['lastUpdated'])),
                    ),
                    mode: InsertMode.insertOrReplace);
              }
            }),
        (db, ids, now) => (db.update(db.tags)..where((t) => t.id.isIn(ids)))
            .write(TagsCompanion(lastUpdated: Value(now))),
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
          return _mapRows(rows, now,
              idOf: (a) => a.id,
              lastUpdatedOf: (a) => a.lastUpdated,
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
        (db, userId, rows) => db.batch((b) {
              for (final r in rows) {
                b.insert(
                    db.accounts,
                    AccountsCompanion.insert(
                      id: r['id'] as String,
                      userId: Value(userId),
                      name: r['name'] as String? ?? '',
                      balance: Value(_toDouble(r['balance'])),
                      currency: Value(r['currency'] as String? ?? 'EUR'),
                      providerName: Value(r['providerName'] as String?),
                      isDefault: Value(_toBool(r['isDefault'])),
                      initialBalanceDate:
                          Value(_fromIso(r['initialBalanceDate'])),
                      isDeleted: Value(_toBool(r['isDeleted'])),
                      lastUpdated: Value(_fromIso(r['lastUpdated'])),
                    ),
                    mode: InsertMode.insertOrReplace);
              }
            }),
        (db, ids, now) => (db.update(db.accounts)..where((t) => t.id.isIn(ids)))
            .write(AccountsCompanion(lastUpdated: Value(now))),
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
          return _mapRows(rows, now,
              idOf: (t) => t.id,
              lastUpdatedOf: (t) => t.lastUpdated,
            toBody: (t) => {
              'accountId': t.accountId,
              'toAccountId': t.toAccountId,
              'amount': t.amount,
              'description': t.description,
              'category': t.category,
              'type': t.type,
              'date': _toIso(t.date),
              'tags': t.tags ?? const <String>[],
              'installmentId': t.installmentId,
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
        (db, userId, rows) => db.batch((b) {
              for (final r in rows) {
                b.insert(
                    db.transactions,
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
                      // PocketBase stores an unset text field as '' — keep
                      // that as "unlinked" rather than a dangling empty id.
                      installmentId: Value(_emptyToNull(r['installmentId'])),
                      isDeleted: Value(_toBool(r['isDeleted'])),
                      lastUpdated: Value(_fromIso(r['lastUpdated'])),
                    ),
                    mode: InsertMode.insertOrReplace);
              }
            }),
        (db, ids, now) => (db.update(db.transactions)
              ..where((t) => t.id.isIn(ids)))
            .write(TransactionsCompanion(lastUpdated: Value(now))),
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
          return _mapRows(rows, now,
              idOf: (b) => b.id,
              lastUpdatedOf: (b) => b.lastUpdated,
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
        (db, userId, rows) => db.batch((b) {
              for (final r in rows) {
                b.insert(
                    db.budgets,
                    BudgetsCompanion.insert(
                      id: r['id'] as String,
                      userId: Value(userId),
                      category: r['category'] as String? ?? '',
                      limitAmount: _toDouble(r['limitAmount']),
                      period: r['period'] as String? ?? 'monthly',
                      isDeleted: Value(_toBool(r['isDeleted'])),
                      lastUpdated: Value(_fromIso(r['lastUpdated'])),
                    ),
                    mode: InsertMode.insertOrReplace);
              }
            }),
        (db, ids, now) => (db.update(db.budgets)..where((t) => t.id.isIn(ids)))
            .write(BudgetsCompanion(lastUpdated: Value(now))),
      );

  // ── installments ─────────────────────────────────────────────────────────
  _Spec get _installments => _Spec(
        'installments',
        (db, cursor, now) async {
          final rows = await (db.select(db.installments)
                ..where((t) =>
                    t.lastUpdated.isBiggerThanValue(cursor) |
                    t.lastUpdated.isNull()))
              .get();
          return _mapRows(rows, now,
              idOf: (i) => i.id,
              lastUpdatedOf: (i) => i.lastUpdated,
            toBody: (i) => {
              'description': i.description,
              'totalAmount': i.totalAmount,
              'installmentCount': i.installmentCount,
              'startDate': _toIso(i.startDate),
              'category': i.category,
              'accountId': i.accountId,
              'isDeleted': i.isDeleted,
              'lastUpdated': _toIso(i.lastUpdated ?? now),
            });
        },
        (db, ids) async {
          final rows =
              await (db.select(db.installments)..where((t) => t.id.isIn(ids)))
                  .get();
          return {for (final r in rows) r.id: r.lastUpdated};
        },
        (db, userId, rows) => db.batch((b) {
              for (final r in rows) {
                b.insert(
                    db.installments,
                    InstallmentsCompanion.insert(
                      id: r['id'] as String,
                      userId: Value(userId),
                      description: r['description'] as String? ?? '',
                      totalAmount: _toDouble(r['totalAmount']),
                      installmentCount: _toInt(r['installmentCount']),
                      startDate: _fromIso(r['startDate']) ?? DateTime.now(),
                      category: Value(r['category'] as String?),
                      accountId: Value(r['accountId'] as String?),
                      isDeleted: Value(_toBool(r['isDeleted'])),
                      lastUpdated: Value(_fromIso(r['lastUpdated'])),
                    ),
                    mode: InsertMode.insertOrReplace);
              }
            }),
        (db, ids, now) => (db.update(db.installments)
              ..where((t) => t.id.isIn(ids)))
            .write(InstallmentsCompanion(lastUpdated: Value(now))),
      );

  /// Maps rows to [_Row] bodies for push, flagging NULL-`lastUpdated` rows
  /// (seeds / restored backups) as needing a stamp. The stamp itself is
  /// written by the push loop, and only for rows the server accepted.
  List<_Row> _mapRows<T>(
    List<T> rows,
    DateTime now, {
    required String Function(T) idOf,
    required DateTime? Function(T) lastUpdatedOf,
    required Map<String, dynamic> Function(T) toBody,
  }) {
    return rows
        .map((r) => _Row(
              id: idOf(r),
              lastUpdated: lastUpdatedOf(r) ?? now,
              body: toBody(r),
              needsStamp: lastUpdatedOf(r) == null,
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
          _db.installments,
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
