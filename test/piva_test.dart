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
}
