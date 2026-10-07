import 'dart:io' show Platform;

import 'package:budgetti/models/piva.dart';
import 'package:budgetti/models/transaction.dart';
import 'package:flutter_test/flutter_test.dart';

// Mirror of web/src/piva.test.ts — change one, change both.
//
// Every fixture is built from local components (`DateTime(y, m, d, h)`), never
// `DateTime.utc` or a string with `Z`, so the suite is TZ-independent:
//   TZ=Europe/Rome|UTC|Pacific/Auckland|America/Los_Angeles flutter test test/piva_test.dart

/// Local stamp (m is 1-based), like the web's `at`.
DateTime at(int y, int m, int d, [int h = 12, int min = 0]) =>
    DateTime(y, m, d, h, min);

/// 'YYYY-MM-DD' without a zone → local midnight.
DateTime day(String ymd) => DateTime.parse(ymd);

PivaProfileData profile({
  String atecoCode = '69.20.11',
  double coefficient = 78,
  int startYear = 2022,
  bool startupRate = true,
  String fundType = 'gestione_separata',
  String fundName = '',
  double subjectiveRate = 0,
  double integrativeRate = 0,
  double minSubjective = 0,
  double minIntegrative = 0,
  bool inpsReduction = false,
  List<String> incomeCategories = const ['Fatture'],
}) => PivaProfileData(
  atecoCode: atecoCode,
  coefficient: coefficient,
  startYear: startYear,
  startupRate: startupRate,
  fundType: fundType,
  fundName: fundName,
  subjectiveRate: subjectiveRate,
  integrativeRate: integrativeRate,
  minSubjective: minSubjective,
  minIntegrative: minIntegrative,
  inpsReduction: inpsReduction,
  incomeCategories: incomeCategories,
);

Transaction fattura(
  String id,
  double amount,
  DateTime date, {
  String category = 'Fatture',
  String type = 'income',
}) => Transaction(
  id: id,
  accountId: 'a1',
  amount: amount,
  date: date,
  description: '',
  category: category,
  type: type,
);

const _unset = Object();

/// `dueDate` omitted → 30 June 2026; an explicit `null` → a row with no day.
PivaPaymentData payment({
  required String id,
  String key = '',
  String kind = 'imposta',
  String label = '',
  Object? dueDate = _unset,
  double amount = 0,
  DateTime? paidDate,
  String note = '',
  bool isDeleted = false,
}) => PivaPaymentData(
  id: id,
  key: key,
  kind: kind,
  label: label,
  dueDate: identical(dueDate, _unset) ? at(2026, 6, 30) : dueDate as DateTime?,
  amount: amount,
  paidDate: paidDate,
  note: note,
  isDeleted: isDeleted,
);

/// A calendar row; `due` and `paid` are 'YYYY-MM-DD' (an explicit `null` due =
/// a row with no day). `estimated: false` is "official".
PivaDeadline row({
  String key = '2026:contributi_saldo',
  String kind = 'contributi',
  String label = '',
  String? due = '2026-06-30',
  String? paid,
  double amount = 0,
  bool estimated = true,
  String? paymentId,
  String note = '',
}) => PivaDeadline(
  key: key,
  kind: kind,
  label: label,
  dueDate: due == null ? null : day(due),
  amount: amount,
  estimated: estimated,
  paidDate: paid == null ? null : day(paid),
  paymentId: paymentId,
  note: note,
);

final now = DateTime(2026, 10, 6, 12);
final today = day('2026-10-06');

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

/// Cassa with every parameter at 0: no contributions, so the tax is on the whole
/// income. The coefficient is the saved one, not what `coefficientFor` says.
PivaProfileData cassaZero({
  double subjectiveRate = 0,
  double integrativeRate = 0,
  double minIntegrative = 0,
  bool startupRate = true,
}) => profile(
  coefficient: 78,
  startYear: 2024,
  startupRate: startupRate,
  fundType: 'cassa',
  subjectiveRate: subjectiveRate,
  integrativeRate: integrativeRate,
  minIntegrative: minIntegrative,
);

/// 'YYYY-MM-DD' of a day, like the strings the web compares; `null` stays `null`.
String? ymd(DateTime? d) => d == null
    ? null
    : '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

PivaDeadline? byKey(List<PivaDeadline> rows, String key) => rows.where((r) => r.key == key).firstOrNull;

/// Every expected (key, day, amount) is the row with that key.
void expectRows(List<PivaDeadline> rows, List<(String, String, double)> expected) {
  for (final (key, due, amount) in expected) {
    final r = byKey(rows, key);
    expect((ymd(r?.dueDate), r?.amount), (due, amount), reason: key);
  }
}

void expectAbsent(List<PivaDeadline> rows, List<String> keys) {
  for (final key in keys) {
    expect(byKey(rows, key), isNull, reason: '$key non esiste');
  }
}

/// The days of the calendar, as the web sorts them: as strings.
void expectSorted(List<PivaDeadline> rows) {
  final days = [for (final r in rows) ymd(r.dueDate)!];
  expect(days, [...days]..sort(), reason: 'ordinate per scadenza');
}

/// The nine fields of a row (the class has no `==`).
List<Object?> cells(PivaDeadline d) => [
  d.key,
  d.kind,
  d.label,
  d.dueDate,
  d.amount,
  d.estimated,
  d.paidDate,
  d.paymentId,
  d.note,
];

// Hand arithmetic (Gestione Separata 26,07%, coefficient 78, startYear 2024, 5% tax):
//   compensi 2024 20.000, 2025 30.000, 2026 projected 3.500 × 12 = 42.000
//   contributions of competence: 2024 15.600 × 26,07% = 4.066,92
//                                2025 23.400 × 26,07% = 6.100,38
//                                2026 32.760 × 26,07% = 8.540,53
//   GS acconti (80%): 2025 80% × 4.066,92 = 3.253,54; 2026 4.880,30; 2027 6.832,42
//   contributions deducted: 2024 0; 2025 4.066,92 + 3.253,54 = 7.320,46;
//                           2026 2.846,84 + 4.880,30 = 7.727,14
//   imposta at 5%: 2024 15.600 × 5% = 780; 2025 (23.400 − 7.320,46) × 5% = 803,98;
//                  2026 (32.760 − 7.727,14) × 5% = 1.251,64
final gs = profile(startYear: 2024);
final gsTxns = [
  fattura('y24', 20000, at(2024, 6, 15)),
  fattura('y25', 30000, at(2025, 6, 15)),
  for (var m = 0; m < 9; m++) fattura('m$m', 3500, at(2026, m + 1, 10)),
];

/// Cassa 15% soggettivo / 4% integrativo, minimo 2.000 / 500, coefficient 78,
/// opened 2025.
final inarcassa = profile(
  fundType: 'cassa',
  coefficient: 78,
  subjectiveRate: 15,
  integrativeRate: 4,
  minSubjective: 2000,
  minIntegrative: 500,
  startupRate: false,
  startYear: 2025,
  fundName: 'Inarcassa',
);

final stray = [
  payment(id: 'b', kind: 'contributi', label: 'Rata straordinaria', amount: 100, dueDate: at(2026, 7, 15)),
  payment(id: 'c', key: '2023:imposta_saldo', label: 'Saldo 2022', amount: 60, dueDate: at(2023, 6, 30)),
  payment(id: 'd', key: '2026:imposta_saldo', amount: 999, isDeleted: true),
];

void main() {
  // ── limits and tax rate ─────────────────────────────────────────────────
  test('forfettarioLimits: 85k/100k, e un anno fuori tabella usa il più vicino noto', () {
    for (final y in [2025, 2026, 2030, 2020]) {
      expect(
        forfettarioLimits(y),
        (limit: 85000.0, exit: 100000.0),
        reason: 'year $y',
      );
    }
  });

  test("taxRate: 5% per cinque anni dall'apertura, poi 15%", () {
    final p = profile(startYear: 2022, startupRate: true);
    expect(taxRate(p, 2022), 0.05, reason: 'opening year');
    expect(taxRate(p, 2026), 0.05, reason: 'fifth year');
    expect(taxRate(p, 2027), 0.15, reason: 'sixth year');
    expect(
      taxRate(profile(startYear: 2022, startupRate: false), 2022),
      0.15,
      reason: 'no startup rate',
    );
    // From the web's `rateSwitch` case (not ported): the switch year.
    final q = profile(startYear: 2024, startupRate: true);
    expect(taxRate(q, 2028), 0.05, reason: 'last year at 5%');
    expect(taxRate(q, 2029), 0.15, reason: 'first year at 15%');
  });

  // ── coefficiente di redditività ─────────────────────────────────────────
  test("coefficientFor: i nove gruppi dell'Allegato 4, con o senza punti, anche parziale", () {
    const rows = <(String, double)>[
      ('10.71', 40), ('45.20.10', 40), ('46.90', 40), ('47.91.10', 40), ('47.81.01', 40),
      ('47.82.01', 54), ('47.89', 54), ('46.19.02', 62), ('41.20.00', 86), ('68.20.01', 86),
      ('56.10.11', 40), ('69.20.11', 78), ('74.90.99', 78), ('85.59.20', 78), ('86.90.29', 78),
      ('62.01.00', 67), ('62.01', 67), ('62', 67), ('620100', 67), ('96.02.01', 67),
    ];
    for (final (code, pct) in rows) {
      expect(coefficientFor(code), pct, reason: code);
    }
    // The first three are shorter than any prefix: they must not throw.
    for (final code in ['', 'abc', '6', '34.00', '46', '47.8']) {
      expect(coefficientFor(code), isNull, reason: "'$code' has no coefficient");
    }
  });

  // ── compensi ────────────────────────────────────────────────────────────
  test('pivaIncome: solo le entrate delle categorie del profilo', () {
    // The web's `gone` row (isDeleted) is not ported: the model has no
    // `isDeleted`, deleted rows never reach it.
    final txns = [
      fattura('inc', 1000, at(2026, 3, 1)),
      fattura('salary', 500, at(2026, 3, 1), category: 'Salary'),
      fattura('out', -200, at(2026, 3, 1), type: 'expense'),
      fattura('xfer', 300, at(2026, 3, 1), type: 'transfer'),
      fattura('qif', 50, at(2026, 3, 1), type: 'expense'), // import QIF: il segno decide
    ];
    expect(pivaIncome(txns, profile()).map((t) => t.id), ['inc', 'qif'], reason: 'categorie del profilo');
    expect(txns.map((t) => t.id), ['inc', 'salary', 'out', 'xfer', 'qif'], reason: 'input non mutato');
    expect(pivaIncome(txns, profile(incomeCategories: [])), isEmpty, reason: 'incomeCategories vuoto');
  });

  test('incomeByMonth: 12 mesi, per giorno locale', () {
    final txns = [
      fattura('a', 1000, DateTime(2026, 1, 1, 0, 0, 0)),
      fattura('b', 400, DateTime(2025, 12, 31, 23, 59, 59)),
      fattura('c', 250, at(2026, 6, 10)),
      fattura('d', 150, at(2026, 6, 20)),
    ];
    expect(incomeByMonth(txns, profile(), 2026), [1000.0, 0, 0, 0, 0, 400, 0, 0, 0, 0, 0, 0], reason: '2026');
    expect(incomeByMonth(txns, profile(), 2025)[11], 400.0, reason: 'dicembre 2025');
  });

  test('scorporo: con una cassa al 4% un incasso di 1040 sono 1000 di compensi e 40 di integrativo', () {
    final txns = [fattura('a', 1040, at(2026, 3, 10)), fattura('b', 52000, at(2026, 6, 15))];
    final cassa = profile(fundType: 'cassa', integrativeRate: 4);
    expect(incomeByMonth(txns, cassa, 2026)[2], 1000.0, reason: 'marzo');
    expect(incomeByMonth(txns, cassa, 2026)[5], 50000.0, reason: 'giugno');
    expect(integrativeCollected(txns, cassa, 2026), 2040.0, reason: 'integrativo incassato');
    expect(pivaIncome(txns, cassa)[0].amount, 1040.0, reason: 'importo di banca intatto');
    final zero = profile(fundType: 'cassa', integrativeRate: 0);
    expect(incomeByMonth(txns, zero, 2026)[2], 1040.0, reason: 'cassa senza integrativo');
    expect(integrativeCollected(txns, zero, 2026), 0.0, reason: 'cassa senza integrativo: niente da riversare');
    final gs = profile(fundType: 'gestione_separata', integrativeRate: 4);
    expect(incomeByMonth(txns, gs, 2026)[2], 1040.0, reason: 'GS con integrativeRate rimasto');
    expect(integrativeCollected(txns, gs, 2026), 0.0, reason: 'GS: niente da riversare');
  });

  test("projectRevenue: media dei mesi conclusi, mai meno dell'incassato", () {
    List<Transaction> monthly(double amount) => [
      for (var m = 0; m < 9; m++) fattura('m$m', amount, at(2026, m + 1, 10)),
    ];
    expect(projectRevenue(monthly(3500), profile(), now), 42000.0, reason: 'media × 12');
    expect(
      projectRevenue([...monthly(3500), fattura('oct', 20000, at(2026, 10, 2))], profile(), now),
      51500.0,
      reason: 'incassato oltre la media',
    );
    expect(
      projectRevenue([fattura('jan', 5000, at(2026, 1, 10))], profile(), DateTime(2026, 1, 20, 12)),
      5000.0,
      reason: 'gennaio: incassato',
    );
    expect(projectRevenue([], profile(), now), 0.0, reason: 'niente');
    expect(
      projectRevenue(monthly(3640), profile(fundType: 'cassa', integrativeRate: 4), now),
      42000.0,
      reason: 'in compensi',
    );
  });

  // ── stima di un anno ────────────────────────────────────────────────────
  test('estimateYear, Gestione Separata', () {
    final p = profile();
    expect(
      fields(estimateYear(p, 40000, 2026)),
      [2026, 40000.0, 31200.0, 8133.84, 23066.16, 1153.31, 8133.84, 30712.85],
      reason: '2026',
    );
    final y27 = estimateYear(p, 40000, 2027);
    expect([y27.tax, y27.net], [3459.92, 28406.24], reason: '2027: regole 2026, aliquota 15%');
  });

  test('estimateYear, artigiani e commercianti', () {
    final art = profile(fundType: 'artigiani', coefficient: 67);
    expect(estimateYear(art, 10000, 2026).contributions, 4521.36, reason: 'sul minimale (Circ. 14/2026)');
    expect(estimateYear(art, 50000, 2026).contributions, 8047.44, reason: 'oltre il minimale');
    expect(
      estimateYear(profile(fundType: 'artigiani', coefficient: 67, inpsReduction: true), 50000, 2026).contributions,
      5233.44,
      reason: 'riduzione 35%',
    );
    expect(estimateYear(art, 10000, 2025).contributions, 4460.64, reason: '2025');
    final com = profile(fundType: 'commercianti', coefficient: 86);
    expect(estimateYear(com, 80000, 2026).contributions, 16975.44, reason: 'oltre la soglia 56.224');
  });

  test("estimateYear, cassa: l'integrativo è una partita di giro, pesa solo quello che manca al minimo", () {
    final p = profile(
      fundType: 'cassa',
      coefficient: 78,
      subjectiveRate: 15,
      integrativeRate: 4,
      minSubjective: 2000,
      minIntegrative: 500,
      startupRate: false,
    );
    expect(
      fields(estimateYear(p, 50000, 2026)),
      [2026, 50000.0, 39000.0, 5850.0, 33150.0, 4972.5, 5850.0, 39177.5],
      reason: 'integrativo sopra il minimo',
    );
    expect(
      fields(estimateYear(p, 5000, 2026)),
      [2026, 5000.0, 3900.0, 2000.0, 1900.0, 285.0, 2300.0, 2415.0],
      reason: 'minimo soggettivo, 300 di integrativo mancante',
    );
  });

  test("estimateYear: i contributi pagati si possono passare, e prima dell'apertura è tutto zero", () {
    final p = profile();
    final paid0 = estimateYear(p, 40000, 2026, 0);
    expect([paid0.taxable, paid0.tax, paid0.contributions], [31200.0, 1560.0, 8133.84], reason: 'contributi pagati 0');
    final before = estimateYear(p, 40000, 2021);
    expect([before.revenue, before.tax, before.contributions, before.net], [0.0, 0.0, 0.0, 0.0], reason: 'prima di startYear');
  });

  // Figures of the web's `netFromRevenue` and `rateSwitch` cases (not ported):
  // `estimateYear` is the same call, so its figures are checked here.
  test('estimateYear, cassa a zero (cifre dei casi netFromRevenue e rateSwitch del web)', () {
    PivaYear y(PivaProfileData p) => estimateYear(p, 50000, 2026);
    final base = y(cassaZero());
    expect([base.grossIncome, base.taxable, base.tax, base.net], [39000.0, 39000.0, 1950.0, 48050.0], reason: 'imposta al 5% su tutto il reddito');
    final c10 = y(cassaZero(subjectiveRate: 10));
    expect([c10.taxable, c10.tax, c10.contributions, c10.net], [35100.0, 1755.0, 3900.0, 44345.0], reason: '10% di 39000 si deduce');
    final integr = y(cassaZero(subjectiveRate: 10, integrativeRate: 4));
    expect([integr.tax, integr.net], [1755.0, 44345.0], reason: "l'integrativo è una partita di giro");
    final short = y(cassaZero(subjectiveRate: 10, integrativeRate: 4, minIntegrative: 2500));
    expect([short.tax, short.contributions, short.net], [1755.0, 4400.0, 43845.0], reason: 'il 4% di 50000 è 2000: scarto 500, non deducibile');
    final at15 = y(cassaZero(startupRate: false));
    expect([at15.tax, at15.net], [5850.0, 44150.0], reason: 'senza aliquota ridotta');
    final at15c = y(cassaZero(startupRate: false, subjectiveRate: 10));
    expect([at15c.tax, at15c.net], [5265.0, 40835.0], reason: 'senza aliquota ridotta, con contributi');
    final zero = estimateYear(cassaZero(), 0, 2026);
    expect([zero.tax, zero.net], [0.0, 0.0], reason: 'compensi 0');
    expect(fields(zero).every((v) => v.isFinite), isTrue, reason: 'nessun NaN');
  });

  // ── calendario: scadenze, acconti, deduzione ────────────────────────────
  test('dueDay: sabato e domenica slittano al lunedì', () {
    expect(dueDay(2026, 6, 30), day('2026-06-30'), reason: 'martedì');
    expect(dueDay(2025, 11, 30), day('2025-12-01'), reason: 'domenica');
    expect(dueDay(2026, 5, 16), day('2026-05-18'), reason: 'sabato (Circ. 14/2026)');
    expect(dueDay(2027, 5, 16), day('2027-05-17'), reason: 'domenica');
    expect(dueDay(2027, 2, 16), day('2027-02-16'), reason: 'martedì');
  });

  test('splitAcconto: soglie di 51,65 e di 103 sulla prima rata', () {
    expect(splitAcconto(780), (390.0, 390.0), reason: '780');
    expect(splitAcconto(803.98), (401.99, 401.99), reason: '803,98');
    expect(splitAcconto(206.02), (103.01, 103.01), reason: 'prima rata 103,01: due rate');
    expect(splitAcconto(206), (0.0, 206.0), reason: 'prima rata 103: tutto a novembre');
    expect(splitAcconto(150), (0.0, 150.0), reason: '150');
    expect(splitAcconto(51.65), (0.0, 51.65), reason: 'esattamente la soglia: si versa');
    expect(splitAcconto(51.64), (0.0, 0.0), reason: 'sotto la soglia');
    expect(splitAcconto(0), (0.0, 0.0), reason: 'zero');
  });

  test("contributionsDeductible: conta il giorno del pagamento, salta l'integrativo e l'imposta", () {
    // The deduction rule: a contributions row counts in the year of its paidDate,
    // else of its dueDate; the integrativo (a pass-through) never does.
    final rows = [
      row(amount: 100),
      row(amount: 200, due: '2025-12-01', paid: '2026-01-10'),
      row(amount: 50, key: '2026:contributi_integrativo', due: '2026-12-31'),
      row(amount: 70, kind: 'imposta', key: '2026:imposta_saldo'),
      row(amount: 30, key: '', due: '2026-07-15'),
      row(amount: 40, due: '2025-06-30'),
    ];
    expect(contributionsDeductible(rows, 2026), 330.0, reason: '2026');
    expect(contributionsDeductible(rows, 2025), 40.0, reason: '2025');
    expect(contributionsDeductible(rows, 2024), 0.0, reason: '2024');
  });

  // ── calendario: righe stimate ───────────────────────────────────────────
  test('schedule, Gestione Separata: tre anni di saldi e acconti', () {
    final rows = schedule(gs, gsTxns, now);
    expect(rows.length, 18, reason: 'tre anni di sei righe');
    expectRows(rows, [
      ('2025:imposta_saldo', '2025-06-30', 780.0),
      ('2025:imposta_acconto1', '2025-06-30', 390.0),
      ('2025:imposta_acconto2', '2025-12-01', 390.0),
      ('2025:contributi_saldo', '2025-06-30', 4066.92),
      ('2025:contributi_acconto1', '2025-06-30', 1626.77),
      ('2025:contributi_acconto2', '2025-12-01', 1626.77),
      ('2026:imposta_saldo', '2026-06-30', 23.98),
      ('2026:imposta_acconto1', '2026-06-30', 401.99),
      ('2026:imposta_acconto2', '2026-11-30', 401.99),
      ('2026:contributi_saldo', '2026-06-30', 2846.84),
      ('2026:contributi_acconto1', '2026-06-30', 2440.15),
      ('2026:contributi_acconto2', '2026-11-30', 2440.15),
      ('2027:imposta_saldo', '2027-06-30', 447.66),
      ('2027:imposta_acconto1', '2027-06-30', 625.82),
      ('2027:imposta_acconto2', '2027-11-30', 625.82),
      ('2027:contributi_saldo', '2027-06-30', 3660.23),
      ('2027:contributi_acconto1', '2027-06-30', 3416.21),
      ('2027:contributi_acconto2', '2027-11-30', 3416.21),
    ]);
    expect(
      rows.every((r) => r.estimated && r.paidDate == null && r.paymentId == null && r.note == ''),
      isTrue,
      reason: 'tutte stimate, non pagate',
    );
    expect(contributionsDeductible(rows, 2026), 7727.14, reason: 'deducibili 2026');
    expect(byKey(rows, '2026:imposta_saldo')?.label, 'Imposta sostitutiva · Saldo 2025', reason: 'label imposta');
    expect(
      byKey(rows, '2026:contributi_acconto2')?.label,
      'Gestione Separata · Secondo acconto 2026',
      reason: 'label contributi',
    );
    expectSorted(rows);
  });

  test("schedule, artigiani: quattro rate fisse, la quarta a febbraio dell'anno dopo", () {
    final rows = schedule(profile(fundType: 'artigiani', coefficient: 67, startYear: 2025), [], now);
    expect(rows.length, 11, reason: 'undici righe');
    expect(rows.every((r) => r.kind == 'contributi'), isTrue, reason: 'solo contributi');
    expect(
      [for (final r in rows) (r.key, ymd(r.dueDate), r.amount)],
      [
        ('2025:contributi_fissi1', '2025-05-16', 1115.16),
        ('2025:contributi_fissi2', '2025-08-20', 1115.16),
        ('2025:contributi_fissi3', '2025-11-17', 1115.16),
        ('2026:contributi_fissi4', '2026-02-16', 1115.16),
        ('2026:contributi_fissi1', '2026-05-18', 1130.34),
        ('2026:contributi_fissi2', '2026-08-20', 1130.34),
        ('2026:contributi_fissi3', '2026-11-16', 1130.34),
        ('2027:contributi_fissi4', '2027-02-16', 1130.34),
        ('2027:contributi_fissi1', '2027-05-17', 1130.34),
        ('2027:contributi_fissi2', '2027-08-20', 1130.34),
        ('2027:contributi_fissi3', '2027-11-16', 1130.34),
      ],
      reason: 'rate fisse',
    );
    expect(
      byKey(rows, '2026:contributi_fissi4')?.label,
      'INPS Artigiani · Rata fissa 4/4 2025',
      reason: 'label della quarta',
    );
  });

  // Born in the web as devilteo911/budgetti-web#10; figures redone with
  // web/src/piva.ts. 60.000 in 2025 and 9 × 5.000 in 2026 (projected 60.000):
  // contributions of competence 9.655,44 both years (gross 40.200: minimale +
  // 21.645 or 21.392 above it, at 24%, plus maternità); fisso 4.460,64 / 4.521,36,
  // so the rate is 1.115,16 / 1.130,34 and the quota above the fisso 5.194,80 / 5.134,08.
  test('schedule, artigiani: saldo e acconti sopra il minimale', () {
    final art = profile(fundType: 'artigiani', coefficient: 67, startYear: 2025, startupRate: false);
    final txns = [
      fattura('y25', 60000, at(2025, 6, 15)),
      for (var m = 0; m < 9; m++) fattura('m$m', 5000, at(2026, m + 1, 10)),
    ];
    final rows = schedule(art, txns, now);
    expect(rows.length, 21, reason: 'ventuno righe');
    expectRows(rows, [
      ('2025:contributi_fissi1', '2025-05-16', 1115.16),
      ('2025:contributi_fissi2', '2025-08-20', 1115.16),
      ('2025:contributi_fissi3', '2025-11-17', 1115.16),
      ('2026:contributi_fissi4', '2026-02-16', 1115.16),
      ('2026:contributi_fissi1', '2026-05-18', 1130.34),
      ('2026:contributi_fissi2', '2026-08-20', 1130.34),
      ('2026:contributi_fissi3', '2026-11-16', 1130.34),
      ('2026:contributi_saldo', '2026-06-30', 5194.8),
      ('2026:contributi_acconto1', '2026-06-30', 2567.04),
      ('2026:contributi_acconto2', '2026-11-30', 2567.04),
      ('2026:imposta_saldo', '2026-06-30', 5528.18),
      ('2026:imposta_acconto1', '2026-06-30', 2764.09),
      ('2026:imposta_acconto2', '2026-11-30', 2764.09),
      ('2027:imposta_acconto1', '2027-06-30', 1902.37),
      ('2027:imposta_acconto2', '2027-11-30', 1902.37),
      ('2027:contributi_fissi4', '2027-02-16', 1130.34),
      ('2027:contributi_fissi1', '2027-05-17', 1130.34),
      ('2027:contributi_fissi2', '2027-08-20', 1130.34),
      ('2027:contributi_fissi3', '2027-11-16', 1130.34),
      ('2027:contributi_acconto1', '2027-06-30', 2567.04),
      ('2027:contributi_acconto2', '2027-11-30', 2567.04),
    ]);
    expectAbsent(rows, [
      '2025:contributi_saldo',
      '2025:contributi_acconto1',
      '2025:imposta_saldo',
      '2027:contributi_saldo',
      '2027:imposta_saldo',
    ]);
    expect(contributionsDeductible(rows, 2025), 3345.48, reason: 'tre rate fisse');
    expect(contributionsDeductible(rows, 2026), 14835.06, reason: 'quarta rata, tre rate, saldo e due acconti');
    expect(contributionsDeductible(rows, 2027), 9655.44, reason: 'quarta rata, tre rate e due acconti');
    expect(byKey(rows, '2026:contributi_saldo')?.label, 'INPS Artigiani · Saldo 2025', reason: 'label del saldo');
    expect(
      byKey(rows, '2026:contributi_acconto1')?.label,
      'INPS Artigiani · Primo acconto 2026',
      reason: "label dell'acconto",
    );
    expectSorted(rows);
  });

  test('schedule, cassa: minimo a settembre, conguaglio e integrativo a dicembre, si deduce solo il soggettivo', () {
    final rows = schedule(inarcassa, [fattura('f', 52000, at(2025, 6, 15))], now);
    expectRows(rows, [
      ('2025:contributi_minimi', '2025-09-30', 2000.0),
      ('2026:contributi_minimi', '2026-09-30', 2000.0),
      ('2026:contributi_saldo', '2026-12-31', 3850.0), // conguaglio: 5.850 − 2.000
      ('2026:contributi_integrativo', '2026-12-31', 2000.0), // integrativo 2025
      ('2026:imposta_saldo', '2026-06-30', 5550.0), // (39.000 − 2.000) × 15%
      ('2026:imposta_acconto2', '2026-11-30', 2775.0),
      ('2027:contributi_integrativo', '2027-12-31', 500.0), // nessun compenso 2026: resta il minimo
    ]);
    expect(byKey(rows, '2026:contributi_minimi')?.label, 'Inarcassa · Contributi minimi 2026', reason: 'label minimo');
    expect(
      byKey(rows, '2026:contributi_integrativo')?.label,
      'Inarcassa · Contributo integrativo 2025',
      reason: 'label integrativo',
    );
    expect(byKey(rows, '2026:imposta_acconto1')?.amount, 2775.0, reason: 'primo acconto');
    expectAbsent(rows, ['2025:contributi_integrativo', '2027:contributi_saldo', '2027:imposta_acconto1']);
    expect(contributionsDeductible(rows, 2026), 5850.0, reason: 'soggettivo 2.000 + 3.850, integrativo fuori');
  });

  // ── calendario con gli importi della commercialista ─────────────────────
  test('deadlines: una riga con la stessa key sostituisce la stima', () {
    final pay = payment(
      id: 'a',
      key: '2026:imposta_acconto2',
      amount: 450,
      dueDate: at(2026, 11, 30),
      paidDate: at(2026, 11, 27),
      note: 'F24 del 27/11',
    );
    final rows = deadlines(gs, gsTxns, [pay], now);
    expect(rows.length, 18, reason: 'ancora diciotto righe');
    final r = byKey(rows, '2026:imposta_acconto2')!;
    expect(
      (r.amount, r.estimated, r.paymentId, ymd(r.paidDate), ymd(r.dueDate), r.note),
      (450.0, false, 'a', '2026-11-27', '2026-11-30', 'F24 del 27/11'),
      reason: 'riga ufficiale',
    );
    expect(r.label, 'Imposta sostitutiva · Secondo acconto 2026', reason: 'label stimata');
    expect(
      (byKey(rows, '2026:imposta_acconto1')?.amount, byKey(rows, '2026:imposta_acconto1')?.estimated),
      (401.99, true),
      reason: 'primo acconto resta stimato',
    );
    expect(byKey(rows, '2027:imposta_saldo')?.amount, 447.66, reason: 'un importo ufficiale di imposta non ricalcola niente');
    expect(
      deadlines(gs, gsTxns, [], now).map(cells).toList(),
      schedule(gs, gsTxns, now).map(cells).toList(),
      reason: 'senza pagamenti: uguale a schedule',
    );
  });

  test("deadlines: un importo ufficiale di contributi sposta l'imposta stimata", () {
    final g = payment(id: 'g', key: '2025:contributi_saldo', kind: 'contributi', amount: 5000, dueDate: at(2025, 6, 30));
    final rows = deadlines(gs, gsTxns, [g], now);
    expect(contributionsDeductible(rows, 2025), 8253.54, reason: 'deducibili 2025: 5.000 + 3.253,54');
    final y = estimateYear(gs, 30000, 2025, 8253.54);
    expect([y.taxable, y.tax], [15146.46, 757.32], reason: 'imposta 2025');
    expect(byKey(rows, '2026:imposta_saldo'), isNull, reason: '757,32 − 780 < 0: niente saldo');
    expect(byKey(rows, '2026:imposta_acconto1')?.amount, 378.66, reason: 'primo acconto 2026');
    expect(byKey(rows, '2026:imposta_acconto2')?.amount, 378.66, reason: 'secondo acconto 2026');
    expect(byKey(rows, '2027:imposta_saldo')?.amount, 494.32, reason: 'saldo 2027: 1.251,64 − 757,32');
    expect(byKey(rows, '2027:imposta_acconto1')?.amount, 625.82, reason: 'acconto 2027 invariato');
    expect(byKey(rows, '2026:contributi_saldo')?.amount, 2846.84, reason: 'le altre righe dei contributi non si ricalcolano');
    expect(rows.length, 17, reason: 'diciassette righe');
  });

  test('deadlines: key vuota e key sconosciuta si aggiungono, le cancellate no', () {
    final rows = deadlines(gs, gsTxns, stray, now);
    expect(rows.length, 20, reason: 'diciotto più due');
    expect((rows[0].paymentId, ymd(rows[0].dueDate)), ('c', '2023-06-30'), reason: 'la prima è la riga del 2023');
    final b = rows.firstWhere((r) => r.paymentId == 'b');
    expect(
      (b.key, b.label, ymd(b.dueDate), b.estimated, b.paidDate),
      ('', 'Rata straordinaria', '2026-07-15', false, null),
      reason: 'riga a mano',
    );
    expect(byKey(rows, '2026:imposta_saldo')?.amount, 23.98, reason: 'la cancellata non sostituisce');
    expect(contributionsDeductible(rows, 2026), 7827.14, reason: 'la riga a mano conta: 7.727,14 + 100');
    expect(byKey(rows, '2027:imposta_saldo')?.amount, 442.66, reason: 'saldo 2027: (32.760 − 7.827,14) × 5% − 803,98');
    expect(byKey(rows, '2027:imposta_acconto1')?.amount, 623.32, reason: 'acconto 2027');
  });

  test('una riga ufficiale senza dueDate: unione, ordine, stato, deduzione', () {
    // A row saved without a day (the PocketBase admin UI, a sync) has no day, never a made-up one.
    final noDay = payment(id: 'nd', key: '2026:imposta_acconto2', amount: 300, dueDate: null); // replaces an estimate
    final orphan = payment(id: 'od', kind: 'contributi', label: 'Senza data', amount: 120, dueDate: null); // nothing behind it
    final paidOrphan = payment(
      id: 'pd',
      kind: 'contributi',
      label: 'Pagata senza data',
      amount: 70,
      dueDate: null,
      paidDate: at(2026, 7, 10),
    );
    final rows = deadlines(gs, gsTxns, [noDay, orphan, paidOrphan], now);
    final replaced = byKey(rows, '2026:imposta_acconto2');
    expect(
      (ymd(replaced?.dueDate), replaced?.amount, replaced?.estimated, replaced?.paymentId),
      ('2026-11-30', 300.0, false, 'nd'),
      reason: 'sostituisce la stima e ne tiene il giorno',
    );
    final blanks = rows.where((r) => r.dueDate == null).toList();
    expect(blanks.map((r) => r.label), ['Senza data', 'Pagata senza data'], reason: "senza giorno: in coda, nell'ordine di inserimento");
    expect(rows.sublist(rows.length - 2).map((r) => r.paymentId), ['od', 'pd'], reason: "le ultime due righe dell'elenco");
    expect(deadlineState(blanks[0], today), DeadlineState.due, reason: 'non pagata e senza giorno: da pagare, non scaduta');
    expect(deadlineState(blanks[1], today), DeadlineState.paid, reason: 'con paidDate: pagata');
    expect(
      contributionsDeductible(deadlines(gs, gsTxns, [orphan], now), 2026),
      7727.14,
      reason: 'senza paidDate né dueDate non si deduce',
    );
    expect(
      contributionsDeductible(deadlines(gs, gsTxns, [paidOrphan], now), 2026),
      7797.14,
      reason: "con paidDate conta nell'anno del pagamento: 7.727,14 + 70",
    );
    // The web also asserts a `setAside` plan here and the absence of the text
    // `NaN` in the rows: neither is ported (no setAside; a DateTime? has no NaN).
    final totals = deadlineTotals(blanks, today);
    expect((totals.upcoming, totals.count.upcoming), (120.0, 1), reason: 'la riga senza giorno e non pagata conta fra le prossime');
  });

  test("deadlines: ordinate per data, e l'input resta intatto", () {
    final rows = deadlines(gs, gsTxns, stray, now);
    expectSorted(rows);
    expect(stray.map((p) => p.id), ['b', 'c', 'd'], reason: 'payments non mutati');
    expect(
      gsTxns.map((t) => t.id),
      ['y24', 'y25', 'm0', 'm1', 'm2', 'm3', 'm4', 'm5', 'm6', 'm7', 'm8'],
      reason: 'txns non mutate',
    );
    expect(deadlines(profile(), [], [], now), isEmpty, reason: 'niente transazioni né pagamenti: nessuna riga');
  });

  test("composizione del prospetto: un importo ufficiale di contributi_saldo sposta l'imponibile della differenza, uno di integrativo no", () {
    // Cassa `inarcassa`. 52.000 banked in 2025 = 50.000 compensi (52.000 / 1,04);
    // 62.400 banked in 2026 = 60.000 compensi, so the 2026 revenue is 60.000
    // whatever the projection says. Round-cent amounts only, so "exactly the
    // difference" cannot be blurred by rounding.
    //   2026 reddito lordo 60.000 × 78% = 46.800
    //   estimated 2026 deduction: minimi 2.000 + saldo (15% × 39.000 − 2.000 = 3.850) = 5.850
    //   → imponibile 46.800 − 5.850 = 40.950
    //   saldo ufficiale 5.000 (3.850 + 1.150): deduction 7.000 → 39.800, i.e. −1.150
    //   integrativo ufficiale 7.000 (stima 2.000): not deductible → 40.950, i.e. ±0
    final txns = [fattura('f25', 52000, at(2025, 6, 15)), fattura('f26', 62400, at(2026, 3, 10))];
    final revenue = incomeByMonth(txns, inarcassa, 2026).reduce((a, b) => a + b);
    expect(revenue, 60000.0, reason: 'compensi 2026');
    double taxable(List<PivaPaymentData> payments) => estimateYear(
      inarcassa,
      revenue,
      2026,
      contributionsDeductible(deadlines(inarcassa, txns, payments, now), 2026),
    ).taxable;
    PivaPaymentData official(String key, double amount) =>
        payment(id: 'x', key: key, kind: 'contributi', amount: amount, dueDate: at(2026, 12, 31));

    final base = taxable([]);
    expect(base, 40950.0, reason: 'senza righe');
    final saldo = deadlines(inarcassa, txns, [official('2026:contributi_saldo', 5000)], now);
    expect(
      (byKey(saldo, '2026:contributi_saldo')?.amount, byKey(saldo, '2026:contributi_saldo')?.estimated),
      (5000.0, false),
      reason: 'la riga sostituisce la stima',
    );
    expect(taxable([official('2026:contributi_saldo', 5000)]), 39800.0, reason: 'saldo ufficiale 5.000');
    expect(taxable([official('2026:contributi_saldo', 5000)]) - base, -1150.0, reason: 'spostato esattamente della differenza');
    final integ = deadlines(inarcassa, txns, [official('2026:contributi_integrativo', 7000)], now);
    expect(
      (byKey(integ, '2026:contributi_integrativo')?.amount, byKey(integ, '2026:contributi_integrativo')?.estimated),
      (7000.0, false),
      reason: "la riga sostituisce l'integrativo stimato",
    );
    expect(taxable([official('2026:contributi_integrativo', 7000)]), base, reason: 'integrativo ufficiale: imponibile fermo');
  });

  // ── stato delle scadenze ────────────────────────────────────────────────
  test('deadlineState: pagata, da pagare, scaduta (ufficiale) e non registrata (solo stima); oggi non è ancora passata', () {
    DeadlineState state(PivaDeadline d) => deadlineState(d, today);
    expect(state(row(due: '2026-06-30', paid: '2026-06-28')), DeadlineState.paid, reason: 'pagata');
    expect(
      state(row(due: '2026-06-30', paid: '2026-10-20', estimated: false)),
      DeadlineState.paid,
      reason: 'pagata anche in ritardo',
    );
    expect(
      state(row(due: '2026-06-30', estimated: false)),
      DeadlineState.overdue,
      reason: 'passata con un importo ufficiale: scaduta',
    );
    expect(state(row(due: '2026-10-05', estimated: false)), DeadlineState.overdue, reason: 'scaduta ieri');
    expect(
      state(row(due: '2026-06-30')),
      DeadlineState.unrecorded,
      reason: "passata ma solo stimata: nessuno l'ha mai registrata",
    );
    expect(state(row(due: '2026-10-05')), DeadlineState.unrecorded, reason: 'stimata, ieri');
    expect(state(row(due: '2026-11-30')), DeadlineState.due, reason: 'futura');
    expect(state(row(due: '2026-11-30', estimated: false)), DeadlineState.due, reason: 'futura e ufficiale');
    expect(state(row(due: '2026-10-06')), DeadlineState.due, reason: 'esattamente oggi, stimata');
    expect(state(row(due: '2026-10-06', estimated: false)), DeadlineState.due, reason: 'esattamente oggi, ufficiale');
  });

  test("deadlineTotals e isPassThrough: da pagare entro l'anno, scaduto, non registrato; l'integrativo conta, e solo lui è una partita di giro", () {
    final rows = [
      row(amount: 100, due: '2026-06-30', paid: '2026-06-28'), // pagata: fuori da tutto
      row(amount: 250.5, due: '2026-06-30', estimated: false), // ufficiale e passata: scaduta
      row(amount: 300, due: '2026-06-30'), // solo stimata e passata: non registrata
      row(amount: 400.25, due: '2026-11-30'), // futura, quest'anno
      row(amount: 2000, key: '2026:contributi_integrativo', due: '2026-12-31'), // integrativo non pagato, quest'anno
      row(amount: 999, due: '2027-06-30'), // futura ma dell'anno dopo: fuori da «upcoming»
    ];
    expect(
      deadlineTotals(rows, today),
      (upcoming: 2400.25, overdue: 250.5, unrecorded: 300.0, count: (upcoming: 2, overdue: 1, unrecorded: 1)),
      reason: '400,25 + 2.000 entro il 31/12; 250,50 scaduto; 300 non registrato; il 2027 non entra',
    );
    expect(
      deadlineTotals([], today),
      (upcoming: 0.0, overdue: 0.0, unrecorded: 0.0, count: (upcoming: 0, overdue: 0, unrecorded: 0)),
      reason: 'elenco vuoto',
    );
    expect(isPassThrough(row(key: '2026:contributi_integrativo')), isTrue, reason: 'integrativo');
    for (final key in ['2026:contributi_saldo', '', '2026:imposta_saldo']) {
      expect(isPassThrough(row(key: key)), isFalse, reason: "'$key'");
    }
  });

  // ── JavaScript → Dart traps ─────────────────────────────────────────────
  test("trappola: i mezzi centesimi vanno verso l'alto anche sotto zero", () {
    // -0,875 × 100 = -87,5 exactly in binary: Math.round gives -87, rounding
    // away from zero (Dart's `round`) would give -88.
    final p = profile(fundType: 'cassa', coefficient: 78, minSubjective: 1);
    final y = estimateYear(p, 0.125, 2026);
    expect(
      [y.revenue, y.grossIncome, y.contributions, y.taxable, y.tax, y.net],
      [0.13, 0.1, 1.0, 0.0, 0.0, -0.87],
    );
  });

  test("trappola: si arrotonda il mese, non la fattura né l'anno", () {
    final txns = [
      for (final (m, d) in [(1, 10), (2, 10), (3, 10), (4, 10), (4, 20)])
        fattura('f$m-$d', 100, at(2025, m, d)),
    ];
    final cassa = profile(fundType: 'cassa', integrativeRate: 4);
    // April is round(200 / 1.04) = 192.31; per invoice it would be 96.15 + 96.15 = 192.30.
    expect(incomeByMonth(txns, cassa, 2025), [96.15, 96.15, 96.15, 192.31, 0, 0, 0, 0, 0, 0, 0, 0]);
    // 500 - 480.76; from the unrounded total it would be 19.23.
    expect(integrativeCollected(txns, cassa, 2025), 19.24);
  });

  test("trappola: l'imponibile parte dai valori già arrotondati", () {
    final y = estimateYear(profile(), 1000.33, 2026);
    // 780.26 - 203.41 = 576.85; from the unrounded values 780.2574 - 203.4131 = 576.84.
    expect(
      fields(y),
      [2026, 1000.33, 780.26, 203.41, 576.85, 28.84, 203.41, 768.08],
    );
  });

  test('trappola: una transazione con flag UTC cade nel suo mese locale', () {
    final txns = [fattura('a', 1000, DateTime(2026, 1, 1, 0, 30).toUtc())];
    expect(incomeByMonth(txns, profile(), 2026)[0], 1000.0);
    expect(incomeByMonth(txns, profile(), 2025)[11], 0.0);
  });

  test('trappola: oggi si confronta per giorno, qualunque ora abbia', () {
    final dueToday = row(due: '2026-10-06', estimated: false);
    expect(
      deadlineState(dueToday, DateTime(2026, 10, 6, 23, 59)),
      DeadlineState.due,
      reason: 'scadenza di oggi, a fine giornata',
    );
    final yesterday = row(due: '2026-10-05', estimated: false);
    expect(
      deadlineState(yesterday, DateTime(2026, 10, 6, 0, 0, 1)),
      DeadlineState.overdue,
      reason: 'ieri, un secondo dopo mezzanotte',
    );
    expect(
      deadlineState(yesterday, DateTime(2026, 10, 6, 0, 30).toUtc()),
      DeadlineState.overdue,
      reason: 'ieri, con today in UTC',
    );
  });

  // Born here: 42.000 in 2026 and 50.000 in January 2027, now = 20/01/2027.
  // c(2026) = 32.760 × 26,07% = 8.540,532 → 8.540,53; 80% = 6.832,42 (from the
  // unrounded figure it would be 6.832,43). c(2027) = 39.000 × 26,07% = 10.167,30;
  // saldo 2028 = 10.167,30 − 6.832,42 = 3.334,88 (3.334,87 from the unrounded one).
  test("trappola: l'acconto GS è l'80% del contributo già arrotondato", () {
    final txns = [fattura('a', 42000, at(2026, 6, 15)), fattura('b', 50000, at(2027, 1, 10))];
    final rows = schedule(profile(startYear: 2026), txns, DateTime(2027, 1, 20, 12));
    expect(byKey(rows, '2027:contributi_acconto1')?.amount, 3416.21, reason: 'la metà di 6.832,42');
    expect(byKey(rows, '2028:contributi_saldo')?.amount, 3334.88, reason: 'saldo 2028');
  });

  test('trappola: i due 31/12 della cassa non slittano, il 30/09 sì', () {
    final rows = schedule(inarcassa, [], DateTime(2028, 3, 1, 12));
    final minimi = byKey(rows, '2028:contributi_minimi');
    expect((ymd(minimi?.dueDate), minimi?.amount), ('2028-10-02', 2000.0), reason: 'il 30/9/2028 è sabato');
    final integrativo = byKey(rows, '2028:contributi_integrativo');
    expect((ymd(integrativo?.dueDate), integrativo?.amount), ('2028-12-31', 500.0), reason: 'il 31/12/2028 è domenica e resta lì');
  });

  test("trappola: a pari giorno resta l'ordine di inserimento, anche su una lista lunga", () {
    // 18 estimated rows + 80 saved ones: past the 32 elements under which Dart's
    // sort is an insertion sort (stable), so only the index tiebreak holds the order.
    final extra = [
      for (var i = 0; i < 40; i++) payment(id: 'p$i', amount: 1, dueDate: at(2026, 7, 15)),
      for (var i = 0; i < 40; i++) payment(id: 'q$i', amount: 1, dueDate: null),
    ];
    final rows = deadlines(gs, gsTxns, extra, now);
    expect(rows.length, 98, reason: '18 + 40 + 40');
    expect(
      [
        for (final r in rows)
          if (r.paymentId?.startsWith('p') ?? false) r.paymentId,
      ],
      [for (var i = 0; i < 40; i++) 'p$i'],
      reason: 'stesso giorno: ordine di inserimento',
    );
    expect(
      rows.sublist(rows.length - 40).map((r) => r.paymentId),
      [for (var i = 0; i < 40; i++) 'q$i'],
      reason: 'senza giorno: in coda, in ordine',
    );
  });

  test('trappola: una data salvata si legge come giorno locale', () {
    final pay = payment(
      id: 'u',
      key: '2026:imposta_acconto2',
      amount: 450,
      dueDate: DateTime(2026, 11, 30, 0, 30).toUtc(),
      paidDate: DateTime(2026, 11, 27, 0, 30).toUtc(),
    );
    final r = byKey(deadlines(gs, gsTxns, [pay], now), '2026:imposta_acconto2')!;
    expect(r.dueDate, day('2026-11-30'), reason: 'dueDate');
    expect(r.paidDate, day('2026-11-27'), reason: 'paidDate');
  });

  // The suite is TZ-independent by construction and is rerun with
  // `TZ=… flutter test test/piva_test.dart`; this proves TZ reaches the tester:
  //   PIVA_EXPECT_OFFSET_MIN=60 TZ=Europe/Rome flutter test test/piva_test.dart
  // The offset is the one of 15 January, in minutes: 60 Europe/Rome, 0 UTC,
  // 780 Pacific/Auckland, -480 America/Los_Angeles.
  test('trappola: un now con flag UTC legge lo stesso calendario locale', () {
    // Local 1 Jan 00:30 is still 31 Dec in UTC for every zone east of Greenwich
    // (Rome, Auckland); local 31 Dec 23:30 is already 1 Jan in UTC for every zone
    // west of it (Los Angeles). Two instants, so the check bites on both sides. In
    // TZ=UTC local and UTC coincide and it can only pass — like trap 9, it earns
    // its keep in the other zones (see the TZ reruns in CLAUDE.md).
    for (final local in [DateTime(2027, 1, 1, 0, 30), DateTime(2026, 12, 31, 23, 30)]) {
      expect(projectRevenue(gsTxns, gs, local.toUtc()), projectRevenue(gsTxns, gs, local),
          reason: 'projectRevenue at $local');
      expect(deadlines(gs, gsTxns, const [], local.toUtc()).map(cells).toList(),
          deadlines(gs, gsTxns, const [], local).map(cells).toList(),
          reason: 'deadlines at $local');
      expect(schedule(gs, gsTxns, local.toUtc()).map(cells).toList(),
          schedule(gs, gsTxns, local).map(cells).toList(),
          reason: 'schedule at $local');
    }
  });

  test('fuso del run', () {
    final expected = Platform.environment['PIVA_EXPECT_OFFSET_MIN'];
    if (expected == null) return; // not asked: nothing to check
    expect(DateTime(2026, 1, 15).timeZoneOffset.inMinutes, int.parse(expected));
  });
}
