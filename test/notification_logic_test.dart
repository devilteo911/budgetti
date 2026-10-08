import 'dart:async';
import 'dart:ffi';

import 'package:budgetti/core/database/database.dart';
import 'package:budgetti/core/providers/providers.dart'
    show financeServiceProvider, notificationServiceProvider, persistenceServiceProvider, pivaProfileProvider;
import 'package:budgetti/core/services/finance_service.dart';
import 'package:budgetti/core/services/notification_logic.dart';
import 'package:budgetti/core/services/notification_service.dart';
import 'package:budgetti/core/services/persistence_service.dart';
import 'package:budgetti/core/services/piva_reminders.dart';
import 'package:budgetti/models/piva.dart' show PivaPaymentData, PivaProfileData, PivaProfileInput, deadlines;
import 'package:drift/native.dart' show NativeDatabase;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/open.dart' as sqlite3open;
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

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
  declaredIncome: {},
);

/// [_profileInput] with the gross declared for a past year.
PivaProfileInput _declaring(Map<String, double?> declared) => PivaProfileInput(
      atecoCode: _profileInput.atecoCode,
      coefficient: _profileInput.coefficient,
      startYear: _profileInput.startYear,
      startupRate: _profileInput.startupRate,
      fundType: _profileInput.fundType,
      fundName: _profileInput.fundName,
      subjectiveRate: _profileInput.subjectiveRate,
      integrativeRate: _profileInput.integrativeRate,
      minSubjective: _profileInput.minSubjective,
      minIntegrative: _profileInput.minIntegrative,
      inpsReduction: _profileInput.inpsReduction,
      incomeCategories: _profileInput.incomeCategories,
      declaredIncome: declared,
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

/// The four reminders of a deadline due on [due] (a day), at 9:00: what
/// [_expectBolloReminders] says for its fixed date, for one that moves with today.
void _expectFourReminders(List<PivaReminder> plan, DateTime due) {
  expect([for (final r in plan) r.daysBefore], [30, 7, 1, 0]);
  expect([for (final r in plan) r.fireAt], [
    for (final n in [30, 7, 1, 0]) DateTime.utc(due.year, due.month, due.day - n, 9),
  ]);
  expect(plan.every((r) => r.deadlineKey == '' && r.id < 0), isTrue);
}

/// Polls until [done]. Drift streams and the debounce timer need real time, so
/// the provider tests wait for the state they expect, not for a fixed time.
Future<void> _until(bool Function() done) async {
  final end = DateTime.now().add(const Duration(seconds: 5));
  while (!done()) {
    if (DateTime.now().isAfter(end)) fail('timed out waiting for the plan');
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

void main() {
  setUpAll(() {
    _ensureSqlite();
    // The logic reads Italy's clock from tz.local, which NotificationService.init()
    // sets in the app; the provider tests do not pass a `now`.
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Europe/Rome'));
  });

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

    // The background replan reads the profile from the database and nothing else,
    // so a figure declared for the previous year (2026, for `_today`) moves the
    // calendar and its reminders with no change in the logic. Hand arithmetic,
    // Gestione Separata 26,07%, coefficient 67, 15% tax, an empty ledger, 2026
    // declared at 50.000 (a made-up figure):
    //   gross income 50.000 × 67% = 33.500; contributions 33.500 × 26,07% = 8.733,45
    //   contributions: saldo 2026 8.733,45 (30/06/2027); acconti 2027 80% = 6.986,76,
    //     two halves of 3.493,38 (30/06 and 30/11/2027)
    //   imposta 33.500 × 15% = 5.025, nothing deducted in 2026: saldo 5.025 (30/06/2027);
    //     acconti 2027 two halves of 2.512,50 (30/06 and 30/11/2027)
    //   six deadlines, all in the future, four reminders each: 24
    test('the previous year declared, an empty ledger: the estimated saldo and acconti are planned', () async {
      final t = await build({});
      await t.finance.savePivaProfile(_profileInput);
      await t.logic.updatePivaReminders(now: _today);
      expect(t.service.plans.single, isEmpty, reason: 'the premise: nothing declared, nothing in the ledger');

      await t.finance.savePivaProfile(_declaring({'2026': 50000.0}));
      await t.logic.updatePivaReminders(now: _today);

      expect(t.service.plans, hasLength(2));
      final plan = t.service.plans.last;
      expect({for (final r in plan) r.deadlineKey}, {
        '2027:imposta_saldo',
        '2027:imposta_acconto1',
        '2027:imposta_acconto2',
        '2027:contributi_saldo',
        '2027:contributi_acconto1',
        '2027:contributi_acconto2',
      });
      expect(plan, hasLength(24), reason: 'four reminders for each of the six deadlines');
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

  // The provider reads the real clock (Italy's wall clock), so its deadline is 40
  // days from today: a fixed date would one day be in the past.
  group('pivaRemindersSyncProvider', () {
    final soon = DateTime.now().add(const Duration(days: 40));
    final due = DateTime(soon.year, soon.month, soon.day);

    Future<void> saveBollo(FinanceService finance, {DateTime? paid}) => finance.savePivaPayment(
          id: 'p-bollo',
          key: '',
          kind: 'imposta',
          label: 'Bollo',
          dueDate: due,
          amount: 120,
          paidDate: paid,
        );

    /// Listens to the provider as main() does, with a 50 ms debounce, over the
    /// database and the recording service of [t]; [profile] stands in for the
    /// profile stream, so a test decides when it answers.
    Future<void> listen(
      ({_Recording service, NotificationLogic logic, FinanceService finance}) t, {
      StreamController<PivaProfileData?>? profile,
    }) async {
      final debounce = pivaRemindersDebounce;
      pivaRemindersDebounce = const Duration(milliseconds: 50);
      addTearDown(() => pivaRemindersDebounce = debounce);
      final container = ProviderContainer(overrides: [
        financeServiceProvider.overrideWithValue(t.finance),
        notificationServiceProvider.overrideWithValue(t.service),
        persistenceServiceProvider.overrideWithValue(PersistenceService(await SharedPreferences.getInstance())),
        if (profile != null) pivaProfileProvider.overrideWith((ref) => profile.stream),
      ]);
      // Registered after the database's close: it runs before it.
      addTearDown(container.dispose);
      container.listen(pivaRemindersSyncProvider, (_, __) {});
    }

    /// A profile and the deadline saved, the provider started, its four reminders
    /// planned.
    Future<({_Recording service, NotificationLogic logic, FinanceService finance})> planned() async {
      final t = await build({});
      expect(deadlines(_profile, const [], const [], DateTime.now()), isEmpty, reason: 'the premise: no estimated row');
      await t.finance.savePivaProfile(_profileInput);
      await saveBollo(t.finance);
      await listen(t);
      await _until(() => t.service.plans.isNotEmpty && t.service.plans.last.isNotEmpty);
      _expectFourReminders(t.service.plans.last, due);
      return t;
    }

    test('after the debounce the plan is the four reminders of the saved deadline', () async {
      await planned();
    });

    test('the deadline marked paid: the next plan has none of its reminders', () async {
      final t = await planned();

      await saveBollo(t.finance, paid: DateTime.now());
      await _until(() => t.service.plans.last.isEmpty);
    });

    test('the deadline deleted: the next plan has none of its reminders', () async {
      final t = await planned();

      await t.finance.deletePivaPayment('p-bollo');
      await _until(() => t.service.plans.last.isEmpty);
    });

    // An empty plan clears every reminder on the device: it must come from "no
    // profile", never from a source that has not answered yet.
    test('no plan while a source is loading; "no profile" gives the empty one', () async {
      final profile = StreamController<PivaProfileData?>();
      addTearDown(profile.close);
      final t = await build({});
      await saveBollo(t.finance);
      await listen(t, profile: profile);

      // Six debounces, with the payments and the ledger answered.
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(t.service.plans, isEmpty);

      profile.add(null);
      await _until(() => t.service.plans.isNotEmpty);
      expect(t.service.plans.last, isEmpty);
    });
  });
}
