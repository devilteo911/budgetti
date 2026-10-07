import 'dart:ffi';

import 'package:budgetti/core/database/database.dart';
import 'package:budgetti/core/services/finance_service.dart';
import 'package:budgetti/core/services/notification_logic.dart';
import 'package:budgetti/core/services/notification_service.dart';
import 'package:budgetti/core/services/persistence_service.dart';
import 'package:budgetti/core/services/piva_reminders.dart';
import 'package:budgetti/models/piva.dart' show PivaPaymentData, PivaProfileData, PivaProfileInput, deadlines;
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

/// Records what the plan handed to the device was; [fail] makes the call throw
/// as the plugin does when the OS refuses.
class _Recording extends NotificationService {
  _Recording({this.fail = false});

  final bool fail;
  final plans = <List<PivaReminder>>[];

  @override
  Future<void> syncPivaReminders(List<PivaReminder> plan) async {
    plans.add(plan);
    if (fail) throw PlatformException(code: 'exact_alarms_not_permitted');
  }
}

// "Now" of the Partita IVA cases: a plain wall clock of Italy, as the logic
// reads it, 40 days before the deadline.
final _today = DateTime(2027, 1, 10, 8);

// A made-up Gestione Separata profile with no income in the ledger: every amount
// of its calendar is zero, so it has no estimated row and the plan holds only
// the deadline a test adds.
const _profile = PivaProfileData(
  atecoCode: '62.01',
  coefficient: 67,
  startYear: 2020,
  startupRate: false,
  fundType: 'gestione_separata',
  fundName: '',
  subjectiveRate: 0,
  integrativeRate: 0,
  minSubjective: 0,
  minIntegrative: 0,
  inpsReduction: false,
  incomeCategories: ['Freelance'],
);

const _profileInput = PivaProfileInput(
  atecoCode: '62.01',
  coefficient: 67,
  startYear: 2020,
  startupRate: false,
  fundType: 'gestione_separata',
  fundName: '',
  subjectiveRate: 0,
  integrativeRate: 0,
  minSubjective: 0,
  minIntegrative: 0,
  inpsReduction: false,
  incomeCategories: ['Freelance'],
);

/// A deadline added by hand (empty key), due on 19 February 2027.
PivaPaymentData _bollo({DateTime? paid}) => PivaPaymentData(
      id: 'p-bollo',
      key: '',
      kind: 'imposta',
      label: 'Bollo',
      dueDate: DateTime(2027, 2, 19),
      amount: 120,
      paidDate: paid,
      note: '',
    );

/// The reminders of [_bollo]: 30, 7 and 1 day before and the day itself, at 9:00.
void _expectBolloReminders(List<PivaReminder> plan) {
  expect([for (final r in plan) r.daysBefore], [30, 7, 1, 0]);
  expect([for (final r in plan) r.fireAt], [
    DateTime.utc(2027, 1, 20, 9),
    DateTime.utc(2027, 2, 12, 9),
    DateTime.utc(2027, 2, 18, 9),
    DateTime.utc(2027, 2, 19, 9),
  ]);
  expect(plan.every((r) => r.deadlineKey == '' && r.id < 0), isTrue);
  expect(plan.every((r) => r.payload.startsWith(pivaReminderPayloadPrefix)), isTrue);
}

void main() {
  setUpAll(_ensureSqlite);

  /// A logic over an empty in-memory database, with the preferences [prefs].
  Future<({_Recording service, NotificationLogic logic, FinanceService finance})> build(
    Map<String, Object> prefs, {
    bool fail = false,
  }) async {
    SharedPreferences.setMockInitialValues(prefs);
    final db = AppDatabase.forExecutor(NativeDatabase.memory());
    addTearDown(db.close);
    final finance = FinanceService(db, 'user-a');
    final service = _Recording(fail: fail);
    final logic = NotificationLogic(
      service,
      finance,
      PersistenceService(await SharedPreferences.getInstance()),
    );
    return (service: service, logic: logic, finance: finance);
  }

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

  group('Partita IVA reminders', () {
    test('no profile: an empty plan, saved payments or not', () async {
      final t = await build({});

      await t.logic.applyPivaReminders(null, [_bollo()], const [], now: _today);

      expect(t.service.plans.single, isEmpty);
    });

    test('a profile and a hand-made deadline in 40 days: its four reminders', () async {
      final t = await build({});
      expect(deadlines(_profile, const [], const [], _today), isEmpty, reason: 'the premise: no estimated row');

      await t.logic.applyPivaReminders(_profile, [_bollo()], const [], now: _today);

      _expectBolloReminders(t.service.plans.single);
    });

    test('piva_reminders_enabled off: an empty plan', () async {
      final t = await build({'piva_reminders_enabled': false});

      await t.logic.applyPivaReminders(_profile, [_bollo()], const [], now: _today);

      expect(t.service.plans.single, isEmpty);
    });

    test('notifications_enabled off: an empty plan', () async {
      final t = await build({'notifications_enabled': false});

      await t.logic.applyPivaReminders(_profile, [_bollo()], const [], now: _today);

      expect(t.service.plans.single, isEmpty);
    });

    test('the deadline marked paid: no reminder of it', () async {
      final t = await build({});

      await t.logic.applyPivaReminders(_profile, [_bollo(paid: DateTime(2027, 1, 5))], const [], now: _today);

      expect(t.service.plans.single, isEmpty);
    });

    test('updatePivaReminders reads the rows of the database and gives the same four', () async {
      final t = await build({});
      await t.finance.savePivaProfile(_profileInput);
      await t.finance.savePivaPayment(
        key: '',
        kind: 'imposta',
        label: 'Bollo',
        dueDate: DateTime(2027, 2, 19),
        amount: 120,
      );

      await t.logic.updatePivaReminders(now: _today);

      _expectBolloReminders(t.service.plans.single);
    });

    test('updatePivaReminders on an empty database: an empty plan', () async {
      final t = await build({});

      await t.logic.updatePivaReminders(now: _today);

      expect(t.service.plans.single, isEmpty);
    });

    // main() awaits these ahead of the backup and the syncs, and the sync task
    // ends with one: the OS refusing must not stop the caller.
    test('a sync the OS refuses does not throw at either caller', () async {
      final t = await build({}, fail: true);
      await t.finance.savePivaProfile(_profileInput);
      await t.finance.savePivaPayment(
        key: '',
        kind: 'imposta',
        label: 'Bollo',
        dueDate: DateTime(2027, 2, 19),
        amount: 120,
      );

      await t.logic.applyPivaReminders(_profile, [_bollo()], const [], now: _today);
      await t.logic.updatePivaReminders(now: _today);

      // Both did reach the device call, with the four reminders each.
      expect(t.service.plans, hasLength(2));
      for (final plan in t.service.plans) {
        _expectBolloReminders(plan);
      }
    });
  });
}
