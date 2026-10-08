import 'dart:async';
import 'dart:ffi';

import 'package:budgetti/core/database/database.dart' show AppDatabase;
import 'package:budgetti/core/providers/providers.dart';
import 'package:budgetti/core/services/auth_service.dart';
import 'package:budgetti/core/services/persistence_service.dart';
import 'package:drift/native.dart' show NativeDatabase;
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

// The session as the providers see it: an id and a `changes` stream. The real
// AuthService adds a PocketBase client and a database that nothing here needs.
class _FakeAuth extends Fake implements AuthService {
  final _changes = StreamController<void>.broadcast();

  @override
  String? pbUserId;

  @override
  Stream<void> get changes => _changes.stream;

  /// Sets the id, then fires the event login() and logout() fire — always null.
  void emit(String? id) {
    pbUserId = id;
    _changes.add(null);
  }
}

void main() {
  setUpAll(_ensureSqlite);

  // On a fresh install a pre-login 401 runs logout() and the real login()
  // follows. Both emit `null`, and Riverpod drops an AsyncData equal to the
  // previous one, so the login never reached currentUserIdProvider: it kept the
  // local id, and the services below it stamped every pulled row with it. So
  // the finance and sync services must be rebuilt too, each holds its own id.
  test('a login after a pre-login logout reaches currentUserIdProvider',
      () async {
    SharedPreferences.setMockInitialValues({});
    final persistence =
        PersistenceService(await SharedPreferences.getInstance());
    await persistence.setLocalUserId('local');
    final db = AppDatabase.forExecutor(NativeDatabase.memory());
    addTearDown(db.close);
    final auth = _FakeAuth();
    final container = ProviderContainer.test(overrides: [
      authServiceProvider.overrideWithValue(auth),
      persistenceServiceProvider.overrideWithValue(persistence),
      databaseProvider.overrideWithValue(db),
    ]);
    // The app keeps these alive (router, services); an unlistened chain would
    // not be subscribed to the auth stream.
    container.listen(currentUserIdProvider, (_, _) {});
    container.listen(financeServiceProvider, (_, _) {});
    container.listen(pocketBaseSyncServiceProvider, (_, _) {});
    expect(container.read(currentUserIdProvider), 'local');
    final financeBefore = container.read(financeServiceProvider);
    final syncBefore = container.read(pocketBaseSyncServiceProvider);

    Future<void> settle() async {
      await Future<void>.delayed(Duration.zero);
      await container.pump();
    }

    auth.emit(null); // the 401 before login
    await settle();
    auth.emit('u1'); // the login itself
    await settle();

    expect(container.read(currentUserIdProvider), 'u1');
    expect(identical(container.read(financeServiceProvider), financeBefore),
        isFalse);
    expect(
        identical(container.read(pocketBaseSyncServiceProvider), syncBefore),
        isFalse);
  });
}
