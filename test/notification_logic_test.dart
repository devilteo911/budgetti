import 'dart:ffi';

import 'package:budgetti/core/database/database.dart';
import 'package:budgetti/core/services/finance_service.dart';
import 'package:budgetti/core/services/notification_logic.dart';
import 'package:budgetti/core/services/notification_service.dart';
import 'package:budgetti/core/services/persistence_service.dart';
import 'package:drift/native.dart' show NativeDatabase;
import 'package:flutter/services.dart';
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

/// What Android does when the exact-alarm grant is missing.
class _RefusingScheduler extends NotificationService {
  @override
  Future<void> scheduleDailyReminder({
    required int id,
    required int hour,
    required int minute,
  }) async =>
      throw PlatformException(code: 'exact_alarms_not_permitted');
}

void main() {
  setUpAll(_ensureSqlite);

  // main() awaits updateDailyReminder() ahead of the auto-backup, bank-sync
  // and PocketBase schedules; the exception skipped all of them.
  test('a reminder the OS refuses to schedule does not throw at the caller',
      () async {
    SharedPreferences.setMockInitialValues({
      'notifications_enabled': true,
      'daily_reminder_enabled': true,
    });
    final db = AppDatabase.forExecutor(NativeDatabase.memory());
    addTearDown(db.close);
    final logic = NotificationLogic(
      _RefusingScheduler(),
      FinanceService(db, 'user-a'),
      PersistenceService(await SharedPreferences.getInstance()),
    );

    await logic.updateDailyReminder();
  });
}
