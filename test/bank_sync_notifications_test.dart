import 'dart:ffi';

import 'package:budgetti/core/database/database.dart';
import 'package:budgetti/core/services/bank_sync_service.dart';
import 'package:budgetti/core/services/gmail_service.dart';
import 'package:budgetti/core/services/google_auth_service.dart';
import 'package:budgetti/core/services/notification_listener_service.dart';
import 'package:drift/native.dart' show NativeDatabase;
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/open.dart' as sqlite3open;

// See finance_service_seed_test.dart: point the FFI loader at the system lib.
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

/// Stands in for the native buffer: counts how often the drain is asked for.
class _CountingListener extends NotificationListenerService {
  _CountingListener({this.fail = false});

  final bool fail;
  int pulls = 0;

  @override
  Future<List<RawNotification>> pull() async {
    pulls++;
    await Future<void>.delayed(const Duration(milliseconds: 30));
    if (fail) throw StateError('buffer unreadable');
    return [
      RawNotification(
        key: 'k$pulls',
        title: 'Revolut',
        text: 'Hai speso €12,50 presso LO CHEF',
        when: DateTime.utc(2026, 7, 30, 10, 15),
      ),
    ];
  }
}

/// Launch, resume, pull-to-refresh and the background task all ask for a
/// notification drain; two passes at once would parse and insert the same
/// pushes twice over.
void main() {
  setUpAll(_ensureSqlite);

  late AppDatabase db;
  setUp(() => db = AppDatabase.forExecutor(NativeDatabase.memory()));
  tearDown(() => db.close());

  BankSyncService service(NotificationListenerService l) => BankSyncService(
        db,
        GmailService(GoogleAuthService()),
        'user-a',
        notifications: l,
      );

  test('two overlapping passes drain the buffer once and share the result',
      () async {
    final listener = _CountingListener();
    final s = service(listener);

    final results =
        await Future.wait([s.syncNotifications(), s.syncNotifications()]);

    expect(listener.pulls, 1);
    expect(results[0].single.id, results[1].single.id);
    expect(await db.select(db.pendingTransactions).get(), hasLength(1));
  });

  test('the guard is per isolate, not per service instance', () async {
    // The provider hands out one instance today, but the guard must not depend
    // on it: the resume hook and pull-to-refresh may build their own.
    final listener = _CountingListener();

    await Future.wait([
      service(listener).syncNotifications(),
      service(listener).syncNotifications(),
    ]);

    expect(listener.pulls, 1);
  });

  test('a later pass drains again', () async {
    final listener = _CountingListener();
    final s = service(listener);

    await s.syncNotifications();
    await s.syncNotifications();

    expect(listener.pulls, 2);
  });

  test('a failed pass does not wedge the next one', () async {
    final broken = _CountingListener(fail: true);
    await expectLater(service(broken).syncNotifications(), throwsStateError);

    final ok = _CountingListener();
    final drafts = await service(ok).syncNotifications();

    expect(ok.pulls, 1);
    expect(drafts, hasLength(1));
  });
}
