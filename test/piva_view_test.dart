import 'dart:io' show File;

import 'package:budgetti/features/piva/piva_view.dart';
import 'package:budgetti/models/piva.dart';
import 'package:budgetti/models/transaction.dart';
import 'package:flutter_test/flutter_test.dart';

// The derivation of one year of the Partita IVA screen. `now` is always passed
// in. Every fixture is built from local components, never `DateTime.utc` or a
// string with `Z`, so the suite is TZ-independent:
//   TZ=Europe/Rome|UTC|Pacific/Auckland|America/Los_Angeles flutter test test/piva_view_test.dart

/// Local stamp (m is 1-based).
DateTime at(int y, int m, int d, [int h = 12, int min = 0]) => DateTime(y, m, d, h, min);

PivaProfileData profile({
  double coefficient = 78,
  int startYear = 2024,
  bool startupRate = true,
  String fundType = 'gestione_separata',
  double integrativeRate = 0,
  Map<String, double?> declaredIncome = const {},
}) => PivaProfileData(
  atecoCode: '69.20.11',
  coefficient: coefficient,
  startYear: startYear,
  startupRate: startupRate,
  fundType: fundType,
  fundName: '',
  subjectiveRate: 0,
  integrativeRate: integrativeRate,
  minSubjective: 0,
  minIntegrative: 0,
  inpsReduction: false,
  incomeCategories: const ['Fatture'],
  declaredIncome: declaredIncome,
);

Transaction fattura(String id, double amount, DateTime date) => Transaction(
  id: id,
  accountId: 'a1',
  amount: amount,
  date: date,
  description: '',
  category: 'Fatture',
  type: 'income',
);

/// One invoice on the 15th of each month of [year] with a non-zero amount.
List<Transaction> fatture(int year, List<double> byMonth) => [
  for (var m = 0; m < 12; m++)
    if (byMonth[m] != 0) fattura('f$year-$m', byMonth[m], at(year, m + 1, 15)),
];

PivaPaymentData payment({
  required String id,
  String key = '',
  String kind = 'contributi',
  required DateTime dueDate,
  required double amount,
}) => PivaPaymentData(
  id: id,
  key: key,
  kind: kind,
  label: '',
  dueDate: dueDate,
  amount: amount,
  paidDate: null,
  note: '',
);

/// The fields of a [PivaYear] in declaration order (the class has no `==`).
List<num> fields(PivaYear y) => [
  y.year,
  y.revenue,
  y.grossIncome,
  y.contributionsPaid,
  y.taxable,
  y.tax,
  y.contributions,
  y.net,
];

// Hand arithmetic, as in test/piva_test.dart (Gestione Separata 26,07%,
// coefficient 78, startYear 2024, 5% tax), now = 6 October 2026:
//   compensi 2024 20.000, 2025 30.000, 2026 9 × 3.500 = 31.500
//   contributions deducted in 2026: saldo 2025 2.846,84 + acconti 2 × 2.440,15 = 7.727,14
//     (they come from 2025 and 2024, not from the compensi of 2026)
//   gross income 31.500 × 78% = 24.570; taxable 24.570 − 7.727,14 = 16.842,86
//   imposta 5% = 842,14; contributions 24.570 × 26,07% = 6.405,40
//   net 31.500 − 842,14 − 6.405,40 = 24.252,46
final gs = profile();
final gsTxns = [
  fattura('y24', 20000, at(2024, 6, 15)),
  fattura('y25', 30000, at(2025, 6, 15)),
  for (var m = 0; m < 9; m++) fattura('m$m', 3500, at(2026, m + 1, 10)),
];
final now = at(2026, 10, 6);

void main() {
  test("anno concluso: media su 12 mesi, nessun mese in corso, prior è l'anno intero", () {
    final ramp = [for (var m = 1; m <= 12; m++) m * 100.0];
    final txns = [...fatture(2026, ramp), ...fatture(2025, List.filled(12, 100.0))];
    final v = pivaYearView(gs, txns, const [], 2026, at(2027, 3, 10));
    expect(v.year, 2026);
    expect(v.months, ramp);
    expect(v.priorMonths, List.filled(12, 100.0));
    expect(v.total, 7800);
    expect(v.prior, 1200);
    expect(v.pct, closeTo(550, 1e-9));
    expect(v.concludedMonths, 12);
    expect(v.average, closeTo(650, 1e-9));
    expect(v.currentMonth, -1);
    expect(v.count, 12);
    expect(v.best, 1200);
    expect(v.bestMonth, 11);
    expect(v.hasData, isTrue);
    expect(() => v.months[0] = 0, throwsUnsupportedError);
  });

  test("anno in corso a metà mese: prior è l'anno prima fino allo stesso giorno", () {
    final txns = [
      ...fatture(2026, [for (var m = 0; m < 12; m++) m < 9 ? 1000.0 : (m == 9 ? 500.0 : 0.0)]),
      fattura('a', 100, at(2025, 1, 1)),
      fattura('b', 50, at(2025, 10, 14)),
      fattura('c', 200, at(2025, 10, 15, 23, 59)), // the same day, late: in
      fattura('d', 400, at(2025, 10, 16, 0, 1)), // the day after: out
      fattura('e', 800, at(2025, 11, 5)),
    ];
    final v = pivaYearView(gs, txns, const [], 2026, at(2026, 10, 15));
    expect(v.priorMonths[9], 650, reason: 'the bars keep whole months');
    expect(v.priorMonths[10], 800);
    expect(v.prior, 350);
    expect(v.total, 9500);
    expect(v.pct, closeTo(9150 / 350 * 100, 1e-9));
    expect(v.concludedMonths, 9);
    expect(v.average, closeTo(1000, 1e-9));
    expect(v.currentMonth, 9);
    expect(v.count, 10);
    expect(v.gross, 9500);
    expect(v.best, 1000);
    expect(v.bestMonth, 0, reason: 'the first of the ties');
  });

  test('now ultimo giorno di febbraio contro un anno prima bisestile: entra tutto febbraio', () {
    final txns = [
      fattura('a', 100, at(2024, 2, 10)),
      fattura('b', 300, at(2024, 2, 29)),
      fattura('c', 900, at(2024, 3, 1)),
      fattura('d', 700, at(2025, 1, 5)),
    ];
    final last = pivaYearView(gs, txns, const [], 2025, at(2025, 2, 28));
    expect(last.prior, 400);
    expect(last.priorMonths[1], 400);
    // The day before the last one is cut at the same day: 29 February is out.
    expect(pivaYearView(gs, txns, const [], 2025, at(2025, 2, 27)).prior, 100);
  });

  test('29 febbraio contro un anno prima non bisestile: il taglio resta a 28', () {
    final txns = [fattura('a', 100, at(2027, 2, 28)), fattura('b', 900, at(2027, 3, 1))];
    expect(pivaYearView(gs, txns, const [], 2028, at(2028, 2, 29)).prior, 100);
  });

  test("gennaio dell'anno in corso: nessun mese concluso, average null", () {
    final txns = [
      fattura('a', 500, at(2026, 1, 5)),
      fattura('b', 200, at(2025, 1, 10)),
      fattura('c', 300, at(2025, 1, 25)),
      fattura('d', 1000, at(2025, 12, 5)),
    ];
    final v = pivaYearView(gs, txns, const [], 2026, at(2026, 1, 20));
    expect(v.total, 500);
    expect(v.prior, 200, reason: '25 January is after the cut');
    expect(v.priorMonths[0], 500);
    expect(v.priorMonths[11], 1000);
    expect(v.pct, closeTo(150, 1e-9));
    expect(v.concludedMonths, 0);
    expect(v.average, isNull);
    expect(v.currentMonth, 0);
    expect(v.count, 1);
    expect(v.best, 500);
    expect(v.bestMonth, 0);
  });

  test('prior 0 con incassi: pct null', () {
    final v = pivaYearView(gs, [fattura('a', 1000, at(2026, 3, 10))], const [], 2026, now);
    expect(v.total, 1000);
    expect(v.prior, 0);
    expect(v.pct, isNull);
    expect(v.hasData, isTrue);
  });

  test('anno senza incassi e senza anno prima: hasData false, best 0', () {
    final v = pivaYearView(gs, const [], const [], 2026, at(2027, 3, 10));
    expect(v.hasData, isFalse);
    expect(v.best, 0);
    expect(v.bestMonth, 0);
    expect(v.total, 0);
    expect(v.prior, 0);
    expect(v.pct, 0, reason: 'nothing against nothing is no change');
    expect(v.average, 0);
    expect(v.count, 0);
    expect(v.gross, 0);
    expect(v.months, List.filled(12, 0.0));
    expect(v.estimate.revenue, 0);
  });

  test("solo l'anno prima e dopo il taglio: hasData guarda i mesi interi", () {
    final v = pivaYearView(gs, [fattura('a', 1000, at(2025, 12, 5))], const [], 2026, now);
    expect(v.total, 0);
    expect(v.prior, 0, reason: 'December is after the cut');
    expect(v.pct, 0);
    expect(v.hasData, isTrue);
  });

  test('profilo gestione_separata: carved false, toRemit 0, anche con un integrativo lasciato nel profilo', () {
    final p = profile(integrativeRate: 4);
    final v = pivaYearView(p, [fattura('a', 1040, at(2026, 3, 10))], const [], 2026, now);
    expect(v.carved, isFalse);
    expect(v.toRemit, 0);
    expect(v.total, 1040);
    expect(v.gross, 1040);
  });

  test('profilo cassa con integrativo 4%: un incasso da 1040 è compensi 1000 e 40 da versare', () {
    final p = profile(fundType: 'cassa', integrativeRate: 4);
    final v = pivaYearView(p, [fattura('a', 1040, at(2026, 3, 10))], const [], 2026, now);
    expect(v.carved, isTrue);
    expect(v.total, 1000);
    expect(v.toRemit, 40);
    expect(v.gross, 1040);
    expect(v.count, 1);
  });

  test('anno in corso su una fixture a mano: tessere e estimate (uguale a estimateYear a mano)', () {
    final v = pivaYearView(gs, gsTxns, const [], 2026, now);
    expect(v.total, 31500);
    expect(v.prior, 30000);
    expect(v.pct, closeTo(5, 1e-9));
    expect(v.concludedMonths, 9);
    expect(v.average, closeTo(3500, 1e-9));
    expect(v.currentMonth, 9);
    expect(v.count, 9);
    expect(v.gross, 31500);
    expect(fields(v.estimate), [2026, 31500, 24570, 7727.14, 16842.86, 842.14, 6405.40, 24252.46]);
    final byHand = estimateYear(
      gs,
      v.total,
      2026,
      contributionsDeductible(deadlines(gs, gsTxns, const [], now), 2026),
    );
    expect(fields(v.estimate), fields(byHand));
  });

  test("una riga contributi con giorno nell'anno cambia contributionsPaid e taxable", () {
    final base = pivaYearView(gs, gsTxns, const [], 2026, now).estimate;
    expect((base.contributionsPaid, base.taxable), (7727.14, 16842.86));

    // A row added by hand: its 500 comes off the income too.
    final added = [payment(id: 'x', dueDate: at(2026, 3, 10), amount: 500)];
    final a = pivaYearView(gs, gsTxns, added, 2026, now).estimate;
    expect((a.contributionsPaid, a.taxable), (8227.14, 16342.86));

    // The accountant's amount replaces the estimated saldo (2.846,84).
    final replaced = [
      payment(id: 'y', key: '2026:contributi_saldo', dueDate: at(2026, 6, 30), amount: 1000),
    ];
    final r = pivaYearView(gs, gsTxns, replaced, 2026, now).estimate;
    expect((r.contributionsPaid, r.taxable), (5880.30, 18689.70));

    for (final rows in [added, replaced]) {
      final byHand = estimateYear(
        gs,
        31500,
        2026,
        contributionsDeductible(deadlines(gs, gsTxns, rows, now), 2026),
      );
      expect(fields(pivaYearView(gs, gsTxns, rows, 2026, now).estimate), fields(byHand));
    }
  });

  test('una riga imposta, o contributi di un altro anno, non cambiano contributionsPaid né taxable', () {
    final base = pivaYearView(gs, gsTxns, const [], 2026, now).estimate;
    final rows = [
      payment(id: 't', key: '2026:imposta_saldo', kind: 'imposta', dueDate: at(2026, 6, 30), amount: 9999),
      payment(id: 'o', dueDate: at(2025, 3, 10), amount: 500),
    ];
    for (final row in rows) {
      final v = pivaYearView(gs, gsTxns, [row], 2026, now).estimate;
      expect(fields(v), fields(base), reason: row.id);
    }
  });

  // The estimate of a year is made on `compensiForYear`, as the web's PivaForecast
  // does for every year. Hand arithmetic, same profile as above (Gestione
  // Separata 26,07%, coefficient 78, startYear 2024, 5% tax), now = 6 October 2026,
  // an empty ledger and only 2025 declared, at 40.000:
  //   revenue 2025 = the declared 40.000 (a Gestione Separata splits nothing)
  //   contributions deducted in 2025: the saldo of 2024 and the acconti of 2025 are
  //     made on the compensi of 2024, which the ledger reads 0 → 0
  //   gross income 40.000 × 78% = 31.200; taxable 31.200 − 0 = 31.200
  //   imposta 5% = 1.560; contributions 31.200 × 26,07% = 8.133,84
  //   net 40.000 − 1.560 − 8.133,84 = 30.306,16
  test('anno concluso dichiarato su un registro vuoto: la stima parte dal dichiarato', () {
    final p = profile(declaredIncome: {'2025': 40000.0});
    expect(
      pivaYearView(gs, const [], const [], 2025, now).estimate.revenue,
      0,
      reason: 'the premise: the ledger alone reads nothing',
    );
    final v = pivaYearView(p, const [], const [], 2025, now);
    expect(fields(v.estimate), [2025, 40000, 31200, 0, 31200, 1560, 8133.84, 30306.16]);
    final byHand = estimateYear(
      p,
      40000,
      2025,
      contributionsDeductible(deadlines(p, const [], const [], now), 2025),
    );
    expect(fields(v.estimate), fields(byHand));
  });

  // A cassa at 4% integrativo (rates and minimums 0), 2025 declared at the 41.600
  // the bank received, an empty ledger:
  //   compensi 41.600 ÷ 1,04 = 40.000; integrativo to remit 41.600 − 40.000 = 1.600
  //   no contribution of the professional (rates and minimums 0), none deducted
  //   gross income 40.000 × 78% = 31.200; imposta 5% = 1.560
  //   net 40.000 − 1.560 − 0 = 38.440
  test('cassa al 4% dichiarata a 41600: compensi 40000 e 1600 da versare', () {
    final p = profile(fundType: 'cassa', integrativeRate: 4, declaredIncome: {'2025': 41600.0});
    final v = pivaYearView(p, const [], const [], 2025, now);
    expect(v.carved, isTrue);
    expect(v.estimate.revenue, 40000);
    expect(v.toRemit, 1600);
    expect(fields(v.estimate), [2025, 40000, 31200, 0, 31200, 1560, 0, 38440]);
  });

  // 2025 over gsTxns (Gestione Separata 26,07%, coefficient 78, 5% tax):
  //   compensi 2025 30.000; contributions deducted in 2025: saldo 2024
  //     (20.000 × 78% × 26,07% = 4.066,92) + acconti 2025 (80% of it = 3.253,54,
  //     two halves of 1.626,77) = 7.320,46
  //   gross income 30.000 × 78% = 23.400; taxable 23.400 − 7.320,46 = 16.079,54
  //   imposta 5% = 803,98; contributions 23.400 × 26,07% = 6.100,38
  //   net 30.000 − 803,98 − 6.100,38 = 23.095,64
  test("anno risposto «dal registro» (voce null): le cifre di un profilo mai interrogato", () {
    final answered = profile(declaredIncome: {'2025': null});
    for (final p in [gs, answered]) {
      final v = pivaYearView(p, gsTxns, const [], 2025, now);
      expect(fields(v.estimate), [2025, 30000, 23400, 7320.46, 16079.54, 803.98, 6100.38, 23095.64]);
    }
    // The year of now keeps the hand figures of the test above.
    final running = pivaYearView(answered, gsTxns, const [], 2026, now);
    expect(fields(running.estimate), [2026, 31500, 24570, 7727.14, 16842.86, 842.14, 6405.40, 24252.46]);
  });

  test("anno in corso senza voce dichiarata: la stima è sul registro finora, anche con un altro anno dichiarato", () {
    final p = profile(declaredIncome: {'2025': 40000.0});
    final v = pivaYearView(p, gsTxns, const [], 2026, now);
    expect(v.estimate.revenue, 31500, reason: '9 × 3.500 so far, not the projection');
    final byHand = estimateYear(
      p,
      31500,
      2026,
      contributionsDeductible(deadlines(p, gsTxns, const [], now), 2026),
    );
    expect(fields(v.estimate), fields(byHand));
  });

  test("ratePct: 5% fino all'ultimo anno di startup, poi 15%", () {
    expect(pivaYearView(gs, const [], const [], 2026, now).ratePct, closeTo(5, 1e-9));
    expect(pivaYearView(profile(startYear: 2020), const [], const [], 2026, now).ratePct, closeTo(15, 1e-9));
    expect(pivaYearView(profile(startupRate: false), const [], const [], 2026, now).ratePct, closeTo(15, 1e-9));
  });

  test('now con il flag UTC si legge sul calendario locale', () {
    final local = at(2026, 11, 1, 0, 30); // still October in UTC, east of Greenwich
    final a = pivaYearView(gs, gsTxns, const [], 2026, local);
    final b = pivaYearView(gs, gsTxns, const [], 2026, local.toUtc());
    expect(b.currentMonth, 10);
    expect(b.concludedMonths, 10);
    expect(b.prior, a.prior);
    expect(fields(b.estimate), fields(a.estimate));
  });

  test('piva_view.dart importa solo il motore e il modello delle transazioni', () {
    final imports = File('lib/features/piva/piva_view.dart')
        .readAsLinesSync()
        .where((l) => l.startsWith('import ') || l.startsWith('export '))
        .toList();
    expect(imports, [
      "import 'package:budgetti/models/piva.dart';",
      "import 'package:budgetti/models/transaction.dart';",
    ]);
  });
}
