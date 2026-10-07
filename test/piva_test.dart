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
}
