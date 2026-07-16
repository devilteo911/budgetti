import 'dart:async';

import 'package:budgetti/core/database/database.dart';
import 'package:budgetti/core/services/persistence_service.dart';
import 'package:drift/drift.dart' show Variable;
import 'package:flutter/foundation.dart';
import 'package:pocketbase/pocketbase.dart' as pb;

/// PocketBase auth: login/logout, offline-capable session (AsyncAuthStore),
/// and a one-time userId-unification migration so legacy local rows stay
/// visible and sync under the right owner.
class AuthService {
  final pb.PocketBase _pb;
  final PersistenceService _persistence;
  final AppDatabase _db;

  final _changes = StreamController<void>.broadcast();

  AuthService(this._pb, this._persistence, this._db);

  /// Emits on login/logout so the router and providers can react.
  Stream<void> get changes => _changes.stream;

  bool get isLoggedIn => _pb.authStore.isValid;

  /// Sync-readable PB auth id (from the persisted store, works offline), or
  /// null when never logged in.
  String? get pbUserId => _pb.authStore.record?.id;

  String get email => (_pb.authStore.record?.data['email'] as String?) ?? '';

  Future<void> login(String email, String password) async {
    await _pb.collection('users').authWithPassword(email, password);
    debugPrint('AuthService: authWithPassword OK');
    // Unify is a data migration — must not block login if it hiccups.
    try {
      await _unifyUserId();
      debugPrint('AuthService: unify OK');
    } catch (e, st) {
      debugPrint('AuthService: userId unify failed (non-fatal): $e\n$st');
    }
    _changes.add(null);
  }

  Future<void> logout() async {
    _pb.authStore.clear();
    // Ensure the cleared state persists across cold starts.
    await _persistence.setPbAuth(null);
    _changes.add(null);
  }

  /// Re-stamp every synced row to the PB user id. Keeps existing data visible
  /// (FinanceService filters by the current user id) and gives sync the right
  /// owner. Idempotent — no-op once localUserId == pbUserId.
  ///
  /// Only the five synced tables; [PendingTransactions] is device-local
  /// (review-inbox capture state) and isn't owner-scoped.
  Future<void> _unifyUserId() async {
    final pbId = pbUserId;
    if (pbId == null || pbId.isEmpty) return;
    if (_persistence.getLocalUserId() == pbId) return;

    const tables = ['categories', 'tags', 'accounts', 'transactions', 'budgets'];
    for (final t in tables) {
      await _db.customUpdate(
        'UPDATE $t SET user_id = ? WHERE user_id IS NULL OR user_id <> ?',
        variables: [Variable<String>(pbId), Variable<String>(pbId)],
      );
    }
    // A changed user id means a different (or freshly reset) backend. Re-arm the
    // sync cursor to epoch so every local row re-uploads to the new owner —
    // otherwise the incremental push skips all existing data (its lastUpdated is
    // older than the retained cursor) and the data is silently stranded.
    await _persistence.setLastSyncAt(DateTime.fromMillisecondsSinceEpoch(0));
    await _persistence.setLocalUserId(pbId);
  }
}
