import 'dart:ui' show Locale;

import 'package:budgetti/core/services/piva_reminders.dart';
import 'package:budgetti/l10n/app_localizations.dart';
import 'package:budgetti/models/piva.dart';
import 'package:flutter_test/flutter_test.dart';

/// The plan of the deadline reminders. Everything here is plain `DateTime(...)`
/// values and expectations built from components: the planner reads `now` by its
/// components and builds `fireAt` as a UTC wall-clock carrier, so no case depends
/// on the machine's time zone (and none touches it).
void main() {
  final it = lookupAppLocalizations(const Locale('it'));
  final en = lookupAppLocalizations(const Locale('en'));

  // The no-break space Italian puts between amount and symbol (`1.234,56 €`).
  const nbsp = ' ';

  PivaDeadline dl(
    DateTime? due, {
    String key = '2026:imposta_saldo',
    String label = 'Imposta sostitutiva · Saldo 2025',
    double amount = 1234.56,
    bool estimated = true,
    DateTime? paid,
    String? paymentId,
  }) => PivaDeadline(
    key: key,
    kind: 'imposta',
    label: label,
    dueDate: due,
    amount: amount,
    estimated: estimated,
    paidDate: paid,
    paymentId: paymentId,
    note: '',
  );

  List<PivaReminder> plan(List<PivaDeadline> ds, DateTime now, {AppLocalizations? l10n}) =>
      planPivaReminders(ds, now, l10n: l10n ?? it);

  group('planPivaReminders: when', () {
    test('a deadline 60 days away gets four reminders, all at 9:00', () {
      final p = plan([dl(DateTime(2026, 6, 30))], DateTime(2026, 5, 1, 8));

      expect(p.map((r) => r.daysBefore), [30, 7, 1, 0]);
      expect(p.map((r) => r.fireAt), [
        DateTime.utc(2026, 5, 31, 9),
        DateTime.utc(2026, 6, 23, 9),
        DateTime.utc(2026, 6, 29, 9),
        DateTime.utc(2026, 6, 30, 9),
      ]);
      expect(p.every((r) => r.fireAt.hour == pivaReminderHour), isTrue);
      expect(p.first.title, 'Partita IVA · scade tra 30 giorni');
    });

    test('a deadline 5 days away gets two: the day before and the day itself', () {
      final p = plan([dl(DateTime(2026, 6, 30))], DateTime(2026, 6, 25, 8));

      expect(p.map((r) => r.daysBefore), [1, 0]);
    });

    test('due today: one reminder before 9:00, none from 9:00 on', () {
      final today = [dl(DateTime(2026, 6, 30))];

      expect(plan(today, DateTime(2026, 6, 30, 8, 59)).map((r) => r.fireAt), [DateTime.utc(2026, 6, 30, 9)]);
      expect(plan(today, DateTime(2026, 6, 30, 9, 0)), isEmpty);
      expect(plan(today, DateTime(2026, 6, 30, 9, 1)), isEmpty);
    });

    test('due tomorrow, asked at 10:00: only the reminder of the day itself', () {
      final p = plan([dl(DateTime(2026, 6, 30))], DateTime(2026, 6, 29, 10));

      expect(p.map((r) => (r.daysBefore, r.fireAt)), [(0, DateTime.utc(2026, 6, 30, 9))]);
    });

    test('the clock change does not move them: 30/03/2026 and 30/11/2026', () {
      // Italy goes to summer time on 29/03/2026 and back on 25/10/2026: the day
      // before 30/03 is the change itself, and 30 days before 30/11 cross the
      // second one. Subtracting Durations would land an hour off.
      final spring = plan([dl(DateTime(2026, 3, 30))], DateTime(2026, 1, 1, 8));
      expect(spring.map((r) => r.fireAt), [
        DateTime.utc(2026, 2, 28, 9),
        DateTime.utc(2026, 3, 23, 9),
        DateTime.utc(2026, 3, 29, 9),
        DateTime.utc(2026, 3, 30, 9),
      ]);
      expect(spring[2].payload, 'piva:2026-03-29T09:00:00.000Z');

      final autumn = plan([dl(DateTime(2026, 11, 30))], DateTime(2026, 10, 1, 8));
      expect(autumn.first.daysBefore, 30);
      expect(autumn.first.fireAt, DateTime.utc(2026, 10, 31, 9));
    });

    test('twelve future deadlines give the 32 nearest reminders, by time', () {
      final ds = [for (var i = 0; i < 12; i++) dl(DateTime(2026, 3, 1 + 11 * i), key: '2026:k$i')];
      final all = [
        for (final d in ds)
          for (final n in pivaReminderOffsets)
            DateTime.utc(d.dueDate!.year, d.dueDate!.month, d.dueDate!.day - n, pivaReminderHour),
      ]..sort();

      final p = plan(ds, DateTime(2026, 1, 1, 8));

      expect(all, hasLength(48));
      expect(p, hasLength(pivaReminderCap));
      expect(p.map((r) => r.fireAt), all.take(32));
    });
  });

  group('planPivaReminders: which deadlines', () {
    final now = DateTime(2026, 6, 1, 8);

    test('paid, past, without a day and without an amount give nothing', () {
      final excluded = {
        'paid': dl(DateTime(2026, 7, 15), paid: DateTime(2026, 6, 1)),
        'unrecorded: past, only estimated': dl(DateTime(2026, 5, 16)),
        'overdue: past, official': dl(DateTime(2026, 5, 16), estimated: false, paymentId: 'p1'),
        'no day': dl(null, estimated: false, paymentId: 'p2'),
        'zero amount': dl(DateTime(2026, 7, 15), amount: 0),
      };

      for (final e in excluded.entries) {
        expect(plan([e.value], now), isEmpty, reason: e.key);
      }
    });

    test('the integrativo row, future and unpaid, is notified like the others', () {
      final p = plan([
        dl(DateTime(2026, 7, 15), paid: DateTime(2026, 6, 1)),
        dl(null, estimated: false, paymentId: 'p2'),
        dl(DateTime(2026, 12, 31), key: '2026:contributi_integrativo'),
      ], now);

      expect(p, hasLength(4));
      expect(p.every((r) => r.deadlineKey == '2026:contributi_integrativo'), isTrue);
    });
  });

  group('planPivaReminders: the text', () {
    // 7, 1 and 0 days before: the 30-day one (31/05) is already past on 01/06.
    final now = DateTime(2027, 6, 1, 8);
    final due = DateTime(2027, 6, 30);

    test('an estimate says "circa … (stima)" / "about … (estimate)"', () {
      expect(
        plan([dl(due)], now).first.body,
        'Imposta sostitutiva · Saldo 2025 · 30/06/2027 · circa 1.234,56$nbsp€ (stima)',
      );
      expect(
        plan([dl(due)], now, l10n: en).first.body,
        'Imposta sostitutiva · Saldo 2025 · 30/06/2027 · about €1,234.56 (estimate)',
      );
    });

    test('an official amount has neither "circa" nor "stima"', () {
      final official = dl(due, estimated: false, paymentId: 'p1');

      final italian = plan([official], now).first.body;
      expect(italian, 'Imposta sostitutiva · Saldo 2025 · 30/06/2027 · 1.234,56$nbsp€');
      expect(italian, isNot(anyOf(contains('circa'), contains('stima'))));

      final english = plan([official], now, l10n: en).first.body;
      expect(english, 'Imposta sostitutiva · Saldo 2025 · 30/06/2027 · €1,234.56');
      expect(english, isNot(anyOf(contains('about'), contains('estimate'))));
    });

    test('the date is written day/month/year with zeros', () {
      final p = plan([dl(DateTime(2027, 3, 5))], DateTime(2027, 3, 4, 8));

      expect(p.first.body, contains('05/03/2027'));
    });

    test('the three titles, in both languages', () {
      expect(plan([dl(due)], now).map((r) => r.title), [
        'Partita IVA · scade tra 7 giorni',
        'Partita IVA · scade domani',
        'Partita IVA · scade oggi',
      ]);
      expect(plan([dl(due)], now, l10n: en).map((r) => r.title), [
        'Partita IVA · due in 7 days',
        'Partita IVA · due tomorrow',
        'Partita IVA · due today',
      ]);
    });
  });

  group('ids', () {
    final now = DateTime(2026, 1, 1, 8);
    final due = DateTime(2026, 6, 30);

    test('pivaReminderId is stable, negative and moves with the offset', () {
      expect(pivaReminderId('2026:imposta_saldo', 7), pivaReminderId('2026:imposta_saldo', 7));

      final ids = {for (final n in pivaReminderOffsets) pivaReminderId('2026:imposta_saldo', n)};
      expect(ids, hasLength(pivaReminderOffsets.length));
      expect(ids.every((id) => id < 0 && id >= -0x80000000), isTrue);
      expect(pivaReminderId('2026:imposta_saldo', 7), isNot(pivaReminderId('2026:imposta_acconto1', 7)));
    });

    test('two rows with the same key and different paymentId have different ids', () {
      final p = plan([
        dl(due, key: '2026:contributi_fissi1', estimated: false, paymentId: 'a'),
        dl(due, key: '2026:contributi_fissi1', estimated: false, paymentId: 'b'),
      ], now);

      expect(p, hasLength(8));
      expect(p.map((r) => r.id).toSet(), hasLength(8));
    });

    test('a hand-added deadline takes its id from the paymentId, an estimate from the key', () {
      final manual = plan([dl(due, key: '', estimated: false, paymentId: 'pay-1')], now);
      expect(manual.map((r) => r.id), [for (final n in pivaReminderOffsets) pivaReminderId('pay-1', n)]);
      expect(manual.first.deadlineKey, '');

      final estimate = plan([dl(due, key: '2026:imposta_saldo')], now);
      expect(estimate.map((r) => r.id), [for (final n in pivaReminderOffsets) pivaReminderId('2026:imposta_saldo', n)]);
    });

    test('the ids of a plan are all distinct', () {
      final p = plan([
        dl(due, key: '2026:imposta_saldo'),
        dl(due, key: '2026:imposta_acconto1'),
        dl(DateTime(2026, 11, 30), key: '2026:imposta_acconto2'),
        dl(DateTime(2026, 12, 31), key: '', estimated: false, paymentId: 'pay-1'),
      ], now);

      expect(p, hasLength(16));
      expect(p.map((r) => r.id).toSet(), hasLength(16));
    });
  });

  group('diffPivaReminders', () {
    PivaPending p(int id, {String title = 't', String body = 'b', String payload = 'piva:x'}) =>
        (id: id, title: title, body: body, payload: payload);

    test('a plan identical to what is pending changes nothing', () {
      final d = diffPivaReminders([p(-1), p(-2)], [p(-2), p(-1)]);

      expect(d.cancel, isEmpty);
      expect(d.schedule, isEmpty);
    });

    test('a changed body, title or payload is in both lists', () {
      for (final changed in [p(-1, body: 'c'), p(-1, title: 'c'), p(-1, payload: 'piva:y')]) {
        final d = diffPivaReminders([p(-1), p(-2)], [changed, p(-2)]);

        expect(d.cancel, [-1]);
        expect(d.schedule, [changed]);
      }
    });

    test('a new reminder is only scheduled, a gone one only cancelled', () {
      final d = diffPivaReminders([p(-1), p(-2)], [p(-2), p(-3)]);

      expect(d.cancel, [-1]);
      expect(d.schedule, [p(-3)]);
    });

    test('nothing wanted cancels every negative id', () {
      final d = diffPivaReminders([p(-1), p(-2), p(-3)], const []);

      expect(d.cancel, unorderedEquals([-1, -2, -3]));
      expect(d.schedule, isEmpty);
    });

    test('888, 999 and 4001 are never cancelled', () {
      final others = [p(888), p(999), p(4001), p(0), p(12345)];

      expect(diffPivaReminders([...others, p(-1)], const []).cancel, [-1]);
      expect(diffPivaReminders([...others, p(-1)], [p(-1)]).cancel, isEmpty);
    });
  });
}
