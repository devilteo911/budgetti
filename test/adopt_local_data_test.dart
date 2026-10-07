import 'dart:ffi';

import 'package:budgetti/core/database/database.dart';
import 'package:budgetti/core/services/auth_service.dart';
import 'package:budgetti/core/services/persistence_service.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart' show NativeDatabase;
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketbase/pocketbase.dart' as pb;
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

void main() {
  setUpAll(_ensureSqlite);

  // adoptLocalData is the chaser of every backup restore: a table missing from
  // its list leaves the restored rows owned by the backup's old user id, where
  // FinanceService never sees them and the sync never pushes them.
  test('adoptLocalData claims the Partita IVA rows and re-arms the cursor',
      () async {
    SharedPreferences.setMockInitialValues({});
    final persistence =
        PersistenceService(await SharedPreferences.getInstance());
    await persistence.setLastSyncAt(DateTime(2026, 6, 1));

    final db = AppDatabase.forExecutor(NativeDatabase.memory());
    addTearDown(db.close);
    await db.into(db.pivaProfiles).insert(
        PivaProfilesCompanion.insert(id: 'profile1')); // userId left null
    await db.into(db.pivaPayments).insert(PivaPaymentsCompanion.insert(
        id: 'pay1', userId: const Value('someone-else')));

    // The session is only an id in the auth store: nothing here touches the
    // network, so the address is never dialled.
    final client = pb.PocketBase('http://pb.invalid')
      ..authStore.save('token', pb.RecordModel({'id': 'user-new'}));

    await AuthService(client, persistence, db).adoptLocalData();

    expect((await db.select(db.pivaProfiles).getSingle()).userId, 'user-new');
    expect((await db.select(db.pivaPayments).getSingle()).userId, 'user-new');
    expect(persistence.getLastSyncAt().millisecondsSinceEpoch, 0);
    expect(persistence.getLocalUserId(), 'user-new');
  });
}
