import 'dart:ffi';

import 'package:budgetti/core/database/database.dart';
import 'package:budgetti/core/services/bank_sync_service.dart';
import 'package:budgetti/core/services/gmail_service.dart';
import 'package:budgetti/core/services/google_auth_service.dart';
import 'package:budgetti/core/services/notification_listener_service.dart';
import 'package:budgetti/core/services/paypal_notification_parser.dart'
    show paypalFallbackDescription;
import 'package:budgetti/core/services/persistence_service.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart' show NativeDatabase;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

/// Stands in for the native buffers: counts how often each drain is asked for.
/// The Revolut buffer always holds one push; the PayPal one holds [paypal].
class _CountingListener extends NotificationListenerService {
  _CountingListener({this.fail = false, this.paypal = const []});

  final bool fail;
  final List<RawNotification> paypal;
  int pulls = 0;
  int paypalPulls = 0;

  @override
  Future<List<RawNotification>> pullPayPal() async {
    paypalPulls++;
    return paypal;
  }

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

  BankSyncService service(
    NotificationListenerService l, {
    PersistenceService? persistence,
  }) =>
      BankSyncService(
        db,
        GmailService(GoogleAuthService()),
        'user-a',
        notifications: l,
        persistence: persistence,
      );

  /// Prefs as the switches leave them: only the sources named are on.
  Future<PersistenceService> switches({
    bool revolut = false,
    bool paypal = false,
  }) async {
    SharedPreferences.setMockInitialValues({
      'revolut_sync_enabled': revolut,
      'paypal_sync_enabled': paypal,
    });
    return PersistenceService(await SharedPreferences.getInstance());
  }

  RawNotification paypalPush(String text, {String title = 'PayPal'}) =>
      RawNotification(
        key: 'pp',
        title: title,
        text: text,
        when: DateTime.utc(2026, 7, 30, 11, 20),
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

  group('PayPal', () {
    test('money received becomes a pending income draft on source paypal',
        () async {
      final listener = _CountingListener(
        paypal: [paypalPush('Hai ricevuto 20,00 € EUR da Mario Rossi')],
      );
      final s = service(listener, persistence: await switches(paypal: true));

      final drafts = await s.syncNotifications();

      expect(drafts, hasLength(1));
      expect(drafts.single.source, 'paypal');
      expect(drafts.single.status, 'pending');
      expect(drafts.single.suggestedType, 'income');
      expect(drafts.single.parsedAmount, 20);
      expect(drafts.single.parsedDescription, 'Mario Rossi');
      expect(listener.pulls, 0, reason: 'the Revolut switch is off');
    });

    test('an untitled push is titled Notifica PayPal, its payer unnamed',
        () async {
      final listener =
          _CountingListener(paypal: [paypalPush('Hai ricevuto 5,00 €', title: '')]);
      final s = service(listener, persistence: await switches(paypal: true));

      final draft = (await s.syncNotifications()).single;

      expect(draft.emailSubject, 'Notifica PayPal');
      expect(draft.parsedDescription, 'Movimento PayPal');
    });

    test('the unnamed fallback description is no identity to learn a category',
        () async {
      await db.into(db.categories).insert(CategoriesCompanion.insert(
            id: 'cat_Rimborsi',
            name: 'Rimborsi',
            iconCode: 0,
            colorHex: 0,
            type: 'income',
          ));
      await db.into(db.transactions).insert(TransactionsCompanion.insert(
            id: 'tx0',
            amount: 5,
            description: paypalFallbackDescription,
            category: 'Rimborsi',
            type: const Value('income'),
            date: DateTime(2026, 1, 1),
          ));
      final listener =
          _CountingListener(paypal: [paypalPush('Hai ricevuto 8,00 €')]);
      final s = service(listener, persistence: await switches(paypal: true));

      final draft = (await s.syncNotifications()).single;

      expect(draft.parsedDescription, paypalFallbackDescription);
      expect(draft.suggestedCategory, isNull);
    });

    test('an outgoing push inserts nothing visible', () async {
      final listener = _CountingListener(
        paypal: [paypalPush('Hai pagato 9,99 € EUR a Spotify')],
      );
      final s = service(listener, persistence: await switches(paypal: true));

      expect(await s.syncNotifications(), isEmpty);

      final rows = await db.select(db.pendingTransactions).get();
      expect(rows.where((r) => r.status == 'pending' || r.status == 'skipped'),
          isEmpty);
    });

    test('an unknown wording is surfaced as skipped, with its raw text',
        () async {
      final listener = _CountingListener(
        paypal: [paypalPush('Pagamento di 15,00 € EUR completato')],
      );
      final s = service(listener, persistence: await switches(paypal: true));

      final drafts = await s.syncNotifications();

      expect(drafts, hasLength(1));
      expect(drafts.single.source, 'paypal');
      expect(drafts.single.status, 'skipped');
      expect(drafts.single.rawSnippet, contains('Pagamento di 15,00 € EUR completato'));
    });

    test('with PayPal off its buffer is not drained, Revolut still is',
        () async {
      final listener = _CountingListener(
        paypal: [paypalPush('Hai ricevuto 20,00 € EUR da Mario Rossi')],
      );
      final s = service(listener, persistence: await switches(revolut: true));

      final drafts = await s.syncNotifications();

      expect(listener.paypalPulls, 0);
      expect(listener.pulls, 1);
      expect(drafts.single.source, 'revolut');
    });

    test('with both on, each buffer lands under its own source', () async {
      final listener = _CountingListener(
        paypal: [paypalPush('Hai ricevuto 20,00 € EUR da Mario Rossi')],
      );
      final s = service(listener,
          persistence: await switches(revolut: true, paypal: true));

      final drafts = await s.syncNotifications();

      expect(drafts.map((d) => d.source).toSet(), {'revolut', 'paypal'});
      expect(drafts, hasLength(2));
    });

    test('without prefs only Revolut is drained, as before', () async {
      final listener = _CountingListener(
        paypal: [paypalPush('Hai ricevuto 20,00 € EUR da Mario Rossi')],
      );

      await service(listener).syncNotifications();

      expect(listener.pulls, 1);
      expect(listener.paypalPulls, 0);
    });
  });
}
