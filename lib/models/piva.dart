/// Partita IVA forfettaria: tax, contributions and deadlines, derived from a
/// profile, the ledger and the amounts the accountant saved.
///
/// This is the mirror of `web/src/piva.ts` minus the simulations
/// (`netFromRevenue`, `rateSwitch`, `thresholdStatus`, `grossMonthlyIncassi`,
/// `setAside`) and minus `writeFailure`. `parseProfileForm` is here too, with a
/// code (`ProfileFormError`) where the web has an English message. Same names,
/// same cases, same figures to the cent: the arithmetic follows the web's order
/// of operations on purpose, since JavaScript and Dart share IEEE-754 doubles
/// but not their rounding helpers.
///
/// "Ricavi" always means *compensi*: cash received, minus the integrativo a
/// `cassa` profile charges its clients (not income).
///
/// What the engine reads is the ledger, plus one figure the profile can hold: the
/// gross the owner declared for a past year the ledger does not cover
/// (`declaredIncome`). The public functions around it — `declaredFor`,
/// `compensiForYear`, the declared-aware `integrativeCollected`, `askDeclaredIncome`
/// and `ledgerCovers` — are part of the mirror. The web's `declaredFromForm` (the
/// previous-year field of the profile form) is web-only until the phone has that
/// field (devilteo911/budgetti#30), so `parseProfileForm` here only passes the map
/// through.
///
/// The code is pure — no I/O, no database — and the clock is never read:
/// `now` / `today` are always injected by the caller. Days are local
/// `DateTime`s of which only year, month and day count.
///
/// Every fiscal figure lives in the year-keyed table below and nowhere else.
///
/// Change one, change both: `test/piva_test.dart` and `web/src/piva.test.ts`
/// run the same cases against the two engines.
library;

import 'dart:math';

import 'package:budgetti/core/finance_math.dart' show parseAmount;
import 'package:budgetti/models/transaction.dart';

// ── The fiscal table ──────────────────────────────────────────────────────
// Every fiscal figure of the module lives here and nowhere else, each with the
// source it was read from (verified 06/10/2026). Code below reads figures from
// `_rulesFor`, never as a literal.

/// The rules of one year. The fields with an initializer are the same in 2025
/// and 2026 (the web's BASE); the three required ones change every year.
class _Rules {
  const _Rules({required this.gsMax, required this.minimale, required this.band});

  // L. 190/2014 art. 1 c. 54 (85.000: stay in the regime the year after) and
  // c. 71 (100.000 received in the year: the regime ends that same year), as
  // amended by L. 197/2022 art. 1 c. 54; Circolare AdE 32/E del 5/12/2023, premessa:
  // https://www.agenziaentrate.gov.it/portale/documents/20143/5718712/Circolare_n_32_Regime+forfetario_05_12_2023.pdf/23d1370d-6bba-0eb7-70b8-d1d24d5a1c0f
  final double limit = 85000, exit = 100000;
  // Imposta sostitutiva: 15%, 5% for the first five years under the legal
  // conditions. Scheda AdE «Regime forfetario – Che cos'è»:
  // https://www.agenziaentrate.gov.it/portale/regime-forfetario-le-regole-2020-/infogen-regime-forfetario-le-regole-2020-
  final double taxRate = 15, startupTaxRate = 5;
  final int startupYears = 5;
  // Acconti of the imposta sostitutiva — fonte secondaria (fisco7.it, the norm
  // cited, official text not read): no acconto under 51,65 €; if the first rate
  // is ≤ 103 € everything is paid at once by 30/11 (art. 17 c. 3 D.P.R.
  // 435/2001); two equal rates for ISA activities (art. 58 D.L. 124/2019;
  // Risoluzione AdE 93/E del 12/11/2019:
  // https://www.agenziaentrate.gov.it/portale/documents/20143/2139920/Risoluzione+n.+93+del+12+novembre+2019.pdf/731cf395-788b-06d4-4d6b-f8f69be11928 ;
  // summary: https://www.fisco7.it/2025/11/forfettari-e-acconto-di-novembre-breve-guida/ )
  final double accontoMin = 51.65, accontoFirstMin = 103;
  // Gestione Separata (professionisti senza altra cassa): 26,07% = 25,00 IVS +
  // 0,72 + 0,35 ISCRO, same in 2025 and 2026 — Circolare INPS n. 8 del
  // 3/02/2026 par. 2 (2025: Circ. INPS n. 27 del 30/01/2025):
  // https://www.inps.it/content/dam/inps-site/it/scorporati/circolari-e-messaggi/2026/02/Circolare_15153/Allegati/16573_Circolare-numero-8-del-03-02-2026.pdf
  // Acconti at 80% of the contribution due for the year before (40% + 40%) —
  // fonte secondaria.
  final double gsRate = 26.07, gsAccontoPct = 80;
  // Artigiani 24%, commercianti 24,48% up to the `band` income, one point more
  // above it; maternità 0,62 €/mese = 7,44 €/anno. Circolare INPS n. 14 del
  // 9/02/2026 par. 1–5 (2025: Circ. INPS n. 38 del 7/02/2025, same rates):
  // https://www.inps.it/content/dam/inps-site/it/scorporati/circolari-e-messaggi/2026/02/Circolare_15162/Allegati/16561_Circolare-numero-14-del-09-02-2026.pdf
  final double artRate = 24, comRate = 24.48, overBandPoints = 1, maternity = 7.44;
  // Regime agevolato dei forfettari: -35% on the IVS contribution, on request,
  // both on the minimale and on what exceeds it; maternità stays due in full.
  // Circolare INPS n. 14/2026 par. 8–9; Circolare INPS n. 35 del 19/02/2016.
  final double reductionPct = 35;

  // gsMax: massimale GS (Circ. INPS 27/2025 for 2025, Circ. INPS 8/2026 for
  // 2026); minimale: artigiani/commercianti minimal income (Circ. INPS 38/2025,
  // 14/2026); band: income where the extra point starts (same circolari).
  // The GS minimale (18.808 € in 2026) is NOT a minimum due, so it is not here.
  final double gsMax, minimale, band;
}

const _rules = {
  2025: _Rules(gsMax: 120607, minimale: 18555, band: 55448),
  2026: _Rules(gsMax: 122295, minimale: 18808, band: 56224),
};

/// The rules of [year]: the newest known year ≤ [year], else the oldest known
/// (2024 → 2025 rules, 2027 → 2026 rules).
_Rules _rulesFor(int year) {
  final years = _rules.keys.toList()..sort();
  return _rules[years.lastWhere((y) => y <= year, orElse: () => years.first)]!;
}

/// Revenue limits of the regime for [year].
({double limit, double exit}) forfettarioLimits(int year) {
  final r = _rulesFor(year);
  return (limit: r.limit, exit: r.exit);
}

/// Imposta sostitutiva rate of [year] as a fraction: the startup rate for the
/// first `startupYears` years from `startYear`, the ordinary one after.
double taxRate(PivaProfileData profile, int year) {
  final r = _rulesFor(year);
  final startup = profile.startupRate && year < profile.startYear + r.startupYears;
  return (startup ? r.startupTaxRate : r.taxRate) / 100;
}

// ── Coefficiente di redditività ───────────────────────────────────────────
// Allegato 4, L. 190/2014 (art. 1 c. 54) — Agenzia delle Entrate, «Tabella
// Ateco con soglie di ricavi e percentuale di redditività»:
// https://www.agenziaentrate.gov.it/portale/documents/20143/241180/nuovo+regime+forfetario+TabellaAteco_Nuovo+regime+forfetario_Tabella+Ateco+con+soglie+di+ricavi+e+percentuale+di+redditivit%C3%A0.pdf/0b238223-88cc-6514-45a3-6438744b2d71
// Codici ATECO 2007, D.Lgs. 81/2025: until new coefficients are approved the
// income is set with the coefficient of the code "secondo la classificazione
// ATECO 2007" (D.Lgs. 12 giugno 2025 n. 81, G.U. n. 134 del 12/06/2025:
// https://www.gazzettaufficiale.it/atto/vediMenuHTML?atto.dataPubblicazioneGazzetta=2025-06-12&atto.codiceRedazionale=25G00090&tipoSerie=serie_generale&tipoVigenza=originario ).
// Not approved yet on 06/10/2026. A code written in ATECO 2025 can land in the
// wrong group where 2025 moved a division (47.x reordered, car repair 45.2 →
// 95.3): this is only a suggestion, the profile's `coefficient` is what counts.

/// (first code prefix, last code prefix, %) — a code matches when its digits
/// start with a prefix in that range (same length, compared as strings).
/// Written as data so that what the table leaves out is `null`: '46' and '47'
/// alone, '478' without its fourth digit, '34', '04', '76'…
const _coefficients = [
  ('10', '11', 40.0), // industrie alimentari e delle bevande
  ('45', '45', 40.0), // commercio all'ingrosso e al dettaglio: 45,
  ('462', '469', 40.0), //   46.2–46.9,
  ('471', '477', 40.0), //   47.1–47.7,
  ('479', '479', 40.0), //   47.9
  ('4781', '4781', 40.0), // commercio ambulante di alimentari e bevande
  ('55', '56', 40.0), // servizi di alloggio e ristorazione
  ('4782', '4789', 54.0), // commercio ambulante di altri prodotti (47.82, 47.89)
  ('461', '461', 62.0), // intermediari del commercio
  ('41', '43', 86.0), // costruzioni
  ('68', '68', 86.0), // attività immobiliari
  ('64', '66', 78.0), // servizi finanziari e assicurativi
  ('69', '75', 78.0), // attività professionali, scientifiche, tecniche
  ('85', '88', 78.0), // istruzione, sanità, assistenza sociale
  // altre attività economiche — note 62 (software) is here, not at 78:
  ('01', '03', 67.0), ('05', '09', 67.0), ('12', '33', 67.0), ('35', '39', 67.0),
  ('49', '53', 67.0), ('58', '63', 67.0), ('77', '82', 67.0), ('84', '84', 67.0),
  ('90', '99', 67.0),
];

/// Suggested coefficient (%) for an ATECO 2007 code, with or without dots and
/// also partial ('62', '62.01', '62.01.00'); `null` when the code is too short,
/// outside the table, or 46/47 with no digit that decides.
double? coefficientFor(String atecoCode) {
  final d = atecoCode.replaceAll(RegExp(r'\D'), '');
  for (final (lo, hi, pct) in _coefficients) {
    if (d.length < lo.length) continue; // substring would throw, slice would not
    final p = d.substring(0, lo.length);
    if (p.compareTo(lo) >= 0 && p.compareTo(hi) <= 0) return pct;
  }
  return null;
}

// ── Domain types ──────────────────────────────────────────────────────────

/// Partita IVA forfettaria profile: what the form saves, minus `id` and
/// `isDeleted` (the engine reads neither). `fundType` is one of
/// `gestione_separata | artigiani | commercianti | cassa` but stays a `String`:
/// on the server it is a `text` field, so an unexpected value is not a sync
/// error, and an unknown one is computed as `commercianti`.
class PivaProfileData {
  const PivaProfileData({
    required this.atecoCode,
    required this.coefficient,
    required this.startYear,
    required this.startupRate,
    required this.fundType,
    required this.fundName,
    required this.subjectiveRate,
    required this.integrativeRate,
    required this.minSubjective,
    required this.minIntegrative,
    required this.inpsReduction,
    required this.incomeCategories,
    this.declaredIncome = const {},
  });

  final String atecoCode;

  /// Percent, e.g. 67 — this is what counts, not [coefficientFor].
  final double coefficient;
  final int startYear;

  /// true = 5% for the first five years from [startYear].
  final bool startupRate;
  final String fundType, fundName;

  /// % of the gross income (`cassa` only).
  final double subjectiveRate;

  /// % of the compensi, charged to the client (`cassa` only).
  final double integrativeRate;

  /// Euro/year (`cassa` only).
  final double minSubjective, minIntegrative;

  /// -35% (artigiani and commercianti only).
  final bool inpsReduction;

  /// Category *names*. Never null: a database `null` or `''` is `[]` in the
  /// mapping.
  final List<String> incomeCategories;

  /// The gross collected in a concluded year, as the accountant's figure, keyed
  /// by four-digit year (`'2025'`). Never null: a database `NULL` is `{}`.
  /// `containsKey` tells the two non-numbers apart: a `null` value means "derive
  /// it from the ledger" (asked and answered), an absent key "not answered".
  final Map<String, double?> declaredIncome;
}

/// A tax/contribution payment row. An official amount from the accountant
/// replaces the estimated deadline with the same `key` (see `deadlines`).
class PivaPaymentData {
  const PivaPaymentData({
    required this.id,
    required this.key,
    required this.kind,
    required this.label,
    required this.dueDate,
    required this.amount,
    required this.paidDate,
    required this.note,
    this.isDeleted = false,
  });

  final String id;

  /// `'<year>:<slot>'` of the deadline it replaces; `''` = added by hand.
  final String key;

  /// `imposta | contributi`.
  final String kind;
  final String label;

  /// A local day (only year, month and day count); `null` = no day.
  final DateTime? dueDate;
  final double amount;

  /// `null` = not paid.
  final DateTime? paidDate;
  final String note;
  final bool isDeleted;
}

// ── Compensi ──────────────────────────────────────────────────────────────

/// Euro amounts are returned rounded to the cent. This is JavaScript's
/// `Math.round(x * 100) / 100`: halves go towards +∞ (-12.5 → -12). Dart's own
/// rounding helpers move them away from zero (-13), return an int, or round the
/// exact decimal expansion instead, so this is the only rounding in the file.
double _round2(double x) {
  final v = x * 100;
  final f = v.floorToDouble();
  return (v - f >= 0.5 ? f + 1 : f) / 100;
}

/// Left to right, from 0, like the web's `reduce`: the order is part of the figure.
double _sum(Iterable<double> xs) => xs.fold(0.0, (a, b) => a + b);

/// What a bank amount is divided by to get the compensi: a `cassa` with an
/// integrativo charges it to the client on top of the fee, so it is not income.
/// The three INPS funds never split, even if `integrativeRate` is left set.
double _compensiDivisor(PivaProfileData p) =>
    p.fundType == 'cassa' && p.integrativeRate > 0 ? 1 + p.integrativeRate / 100 : 1.0;

/// The gross the owner declared for [year] (what the bank received, integrativo
/// included), or null when the year is to be read from the ledger: a `null`
/// value, an absent key, anything not a finite number ≥ 0.
double? declaredFor(PivaProfileData profile, int year) {
  final d = profile.declaredIncome['$year'];
  return d != null && d.isFinite && d >= 0 ? d : null;
}

/// The ledger income of the profile's categories, as banked (integrativo
/// included). The sign decides, like everywhere else: [Transaction.isIncome].
/// The model has no `isDeleted`: deleted rows never reach it.
List<Transaction> pivaIncome(List<Transaction> txns, PivaProfileData profile) =>
    txns.where((t) => t.isIncome && profile.incomeCategories.contains(t.category)).toList();

/// 12 monthly *compensi* of [year] (local calendar month of `t.date`): each
/// month is summed as banked, then divided, then rounded.
List<double> incomeByMonth(List<Transaction> txns, PivaProfileData profile, int year) {
  final months = List<double>.filled(12, 0.0);
  for (final t in pivaIncome(txns, profile)) {
    final d = t.date.toLocal();
    if (d.year == year) months[d.month - 1] += t.amount;
  }
  final div = _compensiDivisor(profile);
  return [for (final m in months) _round2(m / div)];
}

/// Compensi of a concluded [year]: the declared gross divided once, else the
/// ledger's total. One yearly division, never twelve monthly ones — a declared
/// year has no months.
double compensiForYear(PivaProfileData profile, List<Transaction> txns, int year) {
  final d = declaredFor(profile, year);
  return d != null ? _round2(d / _compensiDivisor(profile)) : _round2(_sum(incomeByMonth(txns, profile, year)));
}

/// Integrativo collected in [year] on behalf of the cassa: gross banked minus
/// compensi (the declared gross, if the year is declared). 0 when nothing is split.
double integrativeCollected(List<Transaction> txns, PivaProfileData profile, int year) {
  if (_compensiDivisor(profile) == 1) return 0.0;
  final declared = declaredFor(profile, year);
  if (declared != null) return _round2(declared - compensiForYear(profile, txns, year));
  final gross = _sum(
    pivaIncome(txns, profile).where((t) => t.date.toLocal().year == year).map((t) => t.amount),
  );
  return _round2(gross - _sum(incomeByMonth(txns, profile, year)));
}

/// The year whose gross the owner should be asked for, or null. Only the
/// previous year is ever asked: the year of `now − 1`, once the partita IVA was
/// open, nothing is stored for it yet (a `null` value is an answer too) and the
/// ledger does not reach back to 1 January of it. [ledgerStart] — the first live
/// transaction of the whole ledger, any category or type, null when empty — is an
/// input because the app feeds the engine income rows only.
int? askDeclaredIncome(PivaProfileData profile, DateTime? ledgerStart, DateTime now) {
  final y = now.toLocal().year - 1;
  if (y < profile.startYear || profile.declaredIncome.containsKey('$y')) return null;
  return ledgerCovers(ledgerStart, y) ? null : y;
}

/// The ledger reaches back to 1 January of [year] (local calendar): its first
/// live transaction, any category or type, falls on that day or before. An empty
/// ledger ([ledgerStart] null) covers nothing. Compared as local days, never as
/// instants (the web's `+ledgerStart < +new Date(year, 0, 2)`): 1 January 23:59
/// covers, 2 January 00:00 does not, and a UTC-flagged start reads the local one.
bool ledgerCovers(DateTime? ledgerStart, int year) => ledgerStart != null && _ord(ledgerStart) <= year * 10000 + 101;

// ponytail: linear average, diluted when the activity started mid-year; add
// seasonality from the previous year's months if that proves too rough.
/// Compensi expected for the year of [now]: what came in so far, or the average
/// of the `m` concluded months × 12 if that is more. In January (no concluded
/// month) just what came in. The project's only revenue projection.
double projectRevenue(List<Transaction> txns, PivaProfileData profile, DateTime now) {
  // `now` may arrive UTC-flagged: year and month are read on the local calendar,
  // like the web's getFullYear()/getMonth(), or 00:30 of 1 January in Rome would
  // still be December of the year before.
  final n = now.toLocal();
  final months = incomeByMonth(txns, profile, n.year);
  final m = n.month - 1;
  final sofar = _sum(months);
  return _round2(m == 0 ? sofar : max(sofar, (_sum(months.take(m)) / m) * 12));
}

// ── Stima di un anno ──────────────────────────────────────────────────────

class PivaYear {
  const PivaYear({
    required this.year,
    required this.revenue,
    required this.grossIncome,
    required this.contributionsPaid,
    required this.taxable,
    required this.tax,
    required this.contributions,
    required this.net,
  });

  final int year;

  /// Compensi.
  final double revenue;

  /// [revenue] × coefficient.
  final double grossIncome;

  /// Deducted from the income.
  final double contributionsPaid;
  final double taxable, tax;

  /// Cost to the professional.
  final double contributions;
  final double net;
}

/// Contributions of competence of [year] on [revenue] (compensi): `total` is the
/// cost to the professional, `deductible` what comes off the taxable income.
({double total, double deductible}) _contributionsOf(
  PivaProfileData p,
  double revenue,
  int year,
) {
  final r = _rulesFor(year);
  final gross = (revenue * p.coefficient) / 100;
  if (p.fundType == 'gestione_separata') {
    final c = (min(gross, r.gsMax) * r.gsRate) / 100;
    return (total: c, deductible: c);
  }
  if (p.fundType == 'cassa') {
    // The integrativo charged to clients is a pass-through: only what is short
    // of the minimum comes out of the professional's pocket, and not deductible.
    final subjective = max(p.minSubjective, (gross * p.subjectiveRate) / 100);
    final shortfall = max(0.0, p.minIntegrative - (revenue * p.integrativeRate) / 100);
    return (total: subjective + shortfall, deductible: subjective);
  }
  final pct = p.fundType == 'artigiani' ? r.artRate : r.comRate;
  final ivs =
      (r.minimale * pct) / 100 +
      (max(0.0, min(gross, r.band) - r.minimale) * pct) / 100 +
      (max(0.0, gross - r.band) * (pct + r.overBandPoints)) / 100;
  final c = (p.inpsReduction ? ivs * (1 - r.reductionPct / 100) : ivs) + r.maternity;
  return (total: c, deductible: c);
}

/// Tax and contributions of [year] on [revenue] (compensi). [contributionsPaid]
/// is what is deducted from the income (cash principle); omitted, the year's own
/// deductible contributions stand in for it — the "at regime" approximation.
/// The coefficient is the profile's, never [coefficientFor]'s suggestion. Every
/// derived field starts from the already rounded ones, as in the web.
PivaYear estimateYear(
  PivaProfileData profile,
  double revenue,
  int year, [
  double? contributionsPaid,
]) {
  if (year < profile.startYear) {
    return PivaYear(
      year: year,
      revenue: 0,
      grossIncome: 0,
      contributionsPaid: 0,
      taxable: 0,
      tax: 0,
      contributions: 0,
      net: 0,
    );
  }
  final c = _contributionsOf(profile, revenue, year);
  final grossIncome = _round2((revenue * profile.coefficient) / 100);
  final paid = _round2(contributionsPaid ?? c.deductible);
  final taxable = _round2(max(0.0, grossIncome - paid));
  final tax = _round2(taxable * taxRate(profile, year));
  final contributions = _round2(c.total);
  return PivaYear(
    year: year,
    revenue: _round2(revenue),
    grossIncome: grossIncome,
    contributionsPaid: paid,
    taxable: taxable,
    tax: tax,
    contributions: contributions,
    net: _round2(revenue - tax - contributions),
  );
}

// ── Calendario stimato ────────────────────────────────────────────────────

/// One row of the calendar: an estimate, or the accountant's saved amount that
/// replaced it.
class PivaDeadline {
  const PivaDeadline({
    required this.key,
    required this.kind,
    required this.label,
    required this.dueDate,
    required this.amount,
    required this.estimated,
    required this.paidDate,
    required this.paymentId,
    required this.note,
  });

  /// `'<law year>:<slot>'`, e.g. `'2026:imposta_saldo'`; `''` = added by hand.
  final String key;

  /// `imposta | contributi`.
  final String kind;
  final String label;

  /// Local calendar day (only year, month and day count); `null` = no day (an
  /// official row saved without one).
  final DateTime? dueDate;
  final double amount;

  /// `false` once an official row of `piva_payments` stands behind it.
  final bool estimated;

  /// `null` = not paid.
  final DateTime? paidDate;

  /// `null` = no saved row behind it.
  final String? paymentId;

  /// `''` for the estimates.
  final String note;
}

/// The statutory deadline `day`/`month` (1–12) of [year]. A deadline on a
/// Saturday or Sunday slides to the Monday after: art. 7 c. 1 lett. h D.L.
/// 70/2011. National holidays are not handled because none of the dates
/// generated here (16/02, 16/05, 30/06, 20/08, 30/09, 16/11, 30/11) is one, and
/// Easter Monday (23/03–26/04) cannot fall on any of them. The weekday is read
/// on a UTC date, so it is the same in every time zone; the result is built with
/// the local constructor, which carries the extra days over on the calendar —
/// adding a time span to a local date would land at 23:00 of the day before
/// across the clock change back to winter time.
DateTime dueDay(int year, int month, int day) {
  final wd = DateTime.utc(year, month, day).weekday;
  return DateTime(
    year,
    month,
    day + (wd == DateTime.saturday ? 2 : wd == DateTime.sunday ? 1 : 0),
  );
}

/// First and second acconto of the imposta sostitutiva on [base] (the tax of the
/// year before). Under `accontoMin` none; if the first rate would not exceed
/// `accontoFirstMin` everything is paid at once, in the second. Thresholds from
/// the table's first entry: the same in every year, and a base has no year to
/// look them up by.
(double, double) splitAcconto(double base) {
  final r = _rules.values.first;
  if (base < r.accontoMin) return (0.0, 0.0);
  if (base / 2 <= r.accontoFirstMin) return (0.0, base);
  final first = _round2(base / 2);
  return (first, _round2(base - first));
}

/// What comes off the income of [year]: the contributions rows (not the
/// integrativo, which is a pass-through) whose day — `paidDate` if set, else
/// `dueDate` — falls in [year]. Run on the merged calendar, so the accountant's
/// amounts win; the estimated tax deadlines use this same rule.
double contributionsDeductible(List<PivaDeadline> rows, int year) => _round2(
  _sum(
    rows
        // a row with neither a paidDate nor a dueDate has no year and counts nowhere
        .where(
          (d) => d.kind == 'contributi' && !isPassThrough(d) && (d.paidDate ?? d.dueDate)?.year == year,
        )
        .map((d) => d.amount),
  ),
);

// ── Calendario: righe stimate e importi salvati ───────────────────────────

/// Compensi of [year] as the calendar sees them: the declared figure, else the
/// ledger total, for a concluded year ([compensiForYear]); the projection for the
/// year of [now], 0 for later years and for those before the opening.
double _compensiOf(PivaProfileData p, List<Transaction> txns, int year, DateTime now) {
  if (year < p.startYear || year > now.year) return 0.0;
  return year == now.year ? projectRevenue(txns, p, now) : compensiForYear(p, txns, year);
}

/// One slot of the calendar: the statutory date of each slot, the only place
/// these dates are written. [slides] is false for the cassa's two 31/12
/// deadlines: they must stay in their year, or the deduction would move by one.
class _Slot {
  const _Slot(this.slot, this.month, this.day, this.amount, this.item, {this.slides = true});

  final String slot, item;
  final int month, day;
  final double amount;
  final bool slides;
}

/// The estimated rows of [slots] with law year [year]; amounts ≤ 0 make no row.
List<PivaDeadline> _estimatedRows(String kind, String prefix, int year, List<_Slot> slots) => [
  for (final s in slots)
    PivaDeadline(
      key: '$year:${s.slot}',
      kind: kind,
      label: '$prefix · ${s.item}',
      dueDate: s.slides ? dueDay(year, s.month, s.day) : DateTime(year, s.month, s.day),
      amount: _round2(s.amount),
      estimated: true,
      paidDate: null,
      paymentId: null,
      note: '',
    ),
].where((d) => d.amount > 0).toList();

/// Estimated contributions rows with law year [year] (the web's `Y`). Depends
/// only on the compensi and the table, never on the tax. `c(y)` below is the
/// contribution of competence of `y`, 0 before the opening.
List<PivaDeadline> _contributionRows(PivaProfileData p, double Function(int) comp, int year) {
  if (year < p.startYear) return [];
  bool open(int y) => y >= p.startYear;
  final prefix = switch (p.fundType) {
    'gestione_separata' => 'Gestione Separata',
    'artigiani' => 'INPS Artigiani',
    'cassa' => p.fundName.isEmpty ? 'Cassa' : p.fundName,
    // the web labels an unknown fund `undefined · …`: the one declared difference
    _ => 'INPS Commercianti',
  };

  if (p.fundType == 'cassa') {
    // Generic calendar — every cassa has its own, the accountant's row corrects it.
    double subjective(int y) => open(y) ? _contributionsOf(p, comp(y), y).deductible : 0.0;
    return _estimatedRows('contributi', prefix, year, [
      _Slot('contributi_minimi', 9, 30, p.minSubjective, 'Contributi minimi $year'),
      _Slot('contributi_saldo', 12, 31, subjective(year - 1) - p.minSubjective, 'Saldo ${year - 1}', slides: false),
      _Slot(
        'contributi_integrativo',
        12,
        31,
        open(year - 1) ? max(p.minIntegrative, (p.integrativeRate * comp(year - 1)) / 100) : 0.0,
        'Contributo integrativo ${year - 1}',
        slides: false,
      ),
    ]);
  }

  double c(int y) => open(y) ? _round2(_contributionsOf(p, comp(y), y).total) : 0.0;
  final fixed = p.fundType != 'gestione_separata';
  // Contribution on the minimale (reduction and maternità included), 0 for the GS.
  double fisso(int y) => fixed && open(y) ? _round2(_contributionsOf(p, 0, y).total) : 0.0;
  // What saldo and acconti settle: all of it for the GS, the part above the fisso
  // for artigiani/commercianti.
  double quota(int y) => c(y) - fisso(y);
  // Total acconti of `y`: GS 80% of the contribution of y−1 (already rounded);
  // artigiani/commercianti the excess recomputed on the compensi of y−1 with the
  // rules of y (fonte secondaria).
  double acconti(int y) => !open(y)
      ? 0.0
      : fixed
      ? _round2(_contributionsOf(p, comp(y - 1), y).total) - fisso(y)
      : _round2((_rulesFor(y).gsAccontoPct * c(y - 1)) / 100);
  final half = _round2(acconti(year) / 2);
  _Slot rate(int n, int y, String slot, int month, int day) =>
      _Slot(slot, month, day, fisso(y) / 4, 'Rata fissa $n/4 $y');

  return _estimatedRows('contributi', prefix, year, [
    if (fixed) ...[
      rate(4, year - 1, 'contributi_fissi4', 2, 16),
      rate(1, year, 'contributi_fissi1', 5, 16),
      rate(2, year, 'contributi_fissi2', 8, 20),
      rate(3, year, 'contributi_fissi3', 11, 16),
    ],
    _Slot('contributi_saldo', 6, 30, quota(year - 1) - acconti(year - 1), 'Saldo ${year - 1}'),
    _Slot('contributi_acconto1', 6, 30, half, 'Primo acconto $year'),
    _Slot('contributi_acconto2', 11, 30, half, 'Secondo acconto $year'),
  ]);
}

/// Estimated imposta sostitutiva rows with law year [year]. `deducibili(y)` is
/// what is deducted from the income of `y` (see [contributionsDeductible]).
List<PivaDeadline> _taxRows(
  PivaProfileData p,
  double Function(int) comp,
  int year,
  double Function(int) deducibili,
) {
  double imposta(int y) => estimateYear(p, comp(y), y, deducibili(y)).tax;
  final (first, second) = splitAcconto(imposta(year - 1));
  final (a, b) = splitAcconto(imposta(year - 2));
  return _estimatedRows('imposta', 'Imposta sostitutiva', year, [
    _Slot('imposta_saldo', 6, 30, imposta(year - 1) - (a + b), 'Saldo ${year - 1}'),
    _Slot('imposta_acconto1', 6, 30, first, 'Primo acconto $year'),
    _Slot('imposta_acconto2', 11, 30, second, first > 0 ? 'Secondo acconto $year' : 'Acconto $year'),
  ]);
}

/// The local day of a stored instant (UTC or local), `null` stays `null`.
DateTime? _day(DateTime? d) {
  if (d == null) return null;
  final l = d.toLocal();
  return DateTime(l.year, l.month, l.day);
}

/// The estimated rows with the saved `piva_payments` rows folded in. A live row
/// whose non-empty `key` is that of an estimated row replaces it (amount, kind,
/// dates, note from the row; label from the row if it has one, else the
/// estimate's); any other live row is added as it is. Of several rows with the
/// same key the last wins and the others are added, so no saved row vanishes.
/// Deleted rows are ignored; neither input is mutated.
List<PivaDeadline> _mergePayments(List<PivaDeadline> estimated, List<PivaPaymentData> payments) {
  final live = payments.where((p) => !p.isDeleted).toList();
  final winner = <String, int>{};
  for (var i = 0; i < live.length; i++) {
    if (live[i].key.isNotEmpty) winner[live[i].key] = i;
  }
  final keys = {for (final d in estimated) d.key};
  // A row that replaces an estimate keeps the estimate's day when it has none of
  // its own; one with nothing behind it has no day.
  PivaDeadline fromRow(PivaPaymentData p, String label, DateTime? due) => PivaDeadline(
    key: p.key,
    kind: p.kind,
    label: p.label.isEmpty ? label : p.label,
    dueDate: _day(p.dueDate) ?? due,
    amount: p.amount,
    estimated: false,
    paidDate: _day(p.paidDate),
    paymentId: p.id,
    note: p.note,
  );
  final replaced = [
    for (final d in estimated)
      if (winner[d.key] case final i?) fromRow(live[i], d.label, d.dueDate) else d,
  ];
  final added = [
    for (var i = 0; i < live.length; i++)
      if (!(keys.contains(live[i].key) && winner[live[i].key] == i)) fromRow(live[i], '', null),
  ];
  return [...replaced, ...added];
}

/// By day, a row with no day goes last. Ties are the caller's business: the
/// order is only meaningful together with the generation index (see `deadlines`).
int _byDueDate(PivaDeadline a, PivaDeadline b) {
  final x = a.dueDate, y = b.dueDate;
  if (x == null && y == null) return 0;
  if (x == null) return 1;
  if (y == null) return -1;
  return _ord(x).compareTo(_ord(y));
}

/// The calendar: every deadline with law date in the years of `now` − 1, `now`
/// and `now` + 1, plus every live row of [payments] (once), by `dueDate` (ties
/// keep generation order: tax before contributions, saldo before acconti, saved
/// rows without an estimate last; a row with no day goes after all the others).
/// Contributions are generated for `now` − 3 … `now` + 1 because the tax of year
/// y deducts what was paid in y.
///
/// Two rules on the accountant's amounts. An official amount of *contributions*
/// enters the deduction ([contributionsDeductible]), so it moves the estimated
/// tax of its year and, through the saldo and the acconti, of the next ones. An
/// official amount of *tax* replaces its own row and nothing else: the other tax
/// rows stay estimated on the estimates, each waiting for its own saved row.
List<PivaDeadline> deadlines(
  PivaProfileData profile,
  List<Transaction> txns,
  List<PivaPaymentData> payments,
  DateTime now,
) {
  final n = now.toLocal(); // local calendar, as in projectRevenue
  final year = n.year;
  // Each year's compensi is a pass over the whole ledger and the generators ask
  // for it dozens of times: compute it once per call (per call, not per module,
  // so the module stays pure).
  final memo = <int, double>{};
  double comp(int y) => memo.putIfAbsent(y, () => _compensiOf(profile, txns, y, n));
  final contributions = {for (var y = year - 3; y <= year + 1; y++) y: _contributionRows(profile, comp, y)};
  final merged = _mergePayments([for (final part in contributions.values) ...part], payments);
  double deducibili(int y) => contributionsDeductible(merged, y);
  final estimated = [
    for (final y in [year - 1, year, year + 1]) ...[..._taxRows(profile, comp, y, deducibili), ...contributions[y]!],
  ];
  final rows = _mergePayments(estimated, payments);
  // The sort is on (generation index, row) pairs with the index as tiebreak:
  // Dart's List.sort is not guaranteed stable (and short lists, which use an
  // insertion sort, would hide it).
  final indexed = [for (var i = 0; i < rows.length; i++) (i, rows[i])];
  indexed.sort((a, b) {
    final c = _byDueDate(a.$2, b.$2);
    return c != 0 ? c : a.$1.compareTo(b.$1);
  });
  return [for (final (_, d) in indexed) d];
}

/// The all-estimated calendar: [deadlines] with no saved rows.
List<PivaDeadline> schedule(PivaProfileData profile, List<Transaction> txns, DateTime now) =>
    deadlines(profile, txns, const [], now);

// ── Stato delle scadenze ──────────────────────────────────────────────────
// Read-only helpers for the screen. "Today" comes in as a `DateTime` of which
// only the local day counts, so they stay pure.

/// The ordinal of the local day of [d]: sorts exactly like the web's
/// `YYYY-MM-DD` string and does not depend on the time of day, the UTC flag or a
/// clock change. The engine never compares two instants.
int _ord(DateTime d) {
  final l = d.toLocal();
  return l.year * 10000 + l.month * 100 + l.day;
}

enum DeadlineState { paid, due, overdue, unrecorded }

/// [today]: only its local day counts. A deadline falling today is not past yet,
/// and one with no day at all (an official row saved without one) cannot be
/// past: it is `due`. Past and unpaid, it is `overdue` if someone entered an
/// amount for it (official), `unrecorded` if it is still only an estimate:
/// nobody ever recorded it here, and the owner has most likely paid it already.
DeadlineState deadlineState(PivaDeadline d, DateTime today) {
  if (d.paidDate != null) return DeadlineState.paid;
  final due = d.dueDate;
  if (due == null || _ord(due) >= _ord(today)) return DeadlineState.due;
  return d.estimated ? DeadlineState.unrecorded : DeadlineState.overdue;
}

/// What the screen adds up, all of it unpaid: `upcoming` is what falls due from
/// today to the end of the year of [today] (the integrativo included, it leaves
/// the account all the same), `overdue` the official amounts past their day,
/// `unrecorded` the estimates past their day. `count` is how many rows each sum
/// is made of.
({double upcoming, double overdue, double unrecorded, ({int upcoming, int overdue, int unrecorded}) count})
deadlineTotals(List<PivaDeadline> rows, DateTime today) {
  final year = today.toLocal().year;
  List<PivaDeadline> inState(DeadlineState s) => rows.where((d) => deadlineState(d, today) == s).toList();
  // a due row with no day counts as upcoming
  final upcoming = inState(DeadlineState.due).where((d) => (d.dueDate?.year ?? year) == year).toList();
  final overdue = inState(DeadlineState.overdue);
  final unrecorded = inState(DeadlineState.unrecorded);
  double total(List<PivaDeadline> xs) => _round2(_sum(xs.map((d) => d.amount)));
  return (
    upcoming: total(upcoming),
    overdue: total(overdue),
    unrecorded: total(unrecorded),
    count: (upcoming: upcoming.length, overdue: overdue.length, unrecorded: unrecorded.length),
  );
}

/// True for the integrativo slot only: money collected for the cassa, not a cost
/// and not deductible. The screen asks it here and nowhere else.
bool isPassThrough(PivaDeadline d) => d.key.endsWith(':contributi_integrativo');

// ── Profile form ──────────────────────────────────────────────────────────
// The validation of the profile form lives here, not in the sheet, so the unit
// tests can reach it. Its bounds (100 %, the first plausible opening year) are
// form sanity, not fiscal figures: those stay in the table at the top. The web
// answers with an English message; here the answer is a code and the sheet
// translates it — the rules and their order are the same.

/// The profile form as its state holds it: text for the numbers, booleans for
/// the checkboxes.
class ProfileFormValues {
  const ProfileFormValues({
    required this.atecoCode,
    required this.coefficient,
    required this.startYear,
    required this.startupRate,
    required this.fundType,
    required this.fundName,
    required this.subjectiveRate,
    required this.integrativeRate,
    required this.minSubjective,
    required this.minIntegrative,
    required this.inpsReduction,
    required this.incomeCategories,
    required this.declaredIncome,
  });

  final String atecoCode, coefficient, startYear;
  final bool startupRate;
  final String fundType, fundName;
  final String subjectiveRate, integrativeRate, minSubjective, minIntegrative;
  final bool inpsReduction;
  final List<String> incomeCategories;

  /// Not a field of the form: the profile's declared income, carried to the save
  /// untouched. Required so that no save can forget it and erase the figure.
  final Map<String, double?> declaredIncome;
}

/// What the form saves: the twelve fields of the profile plus the declared
/// income, typed, with neither `userId` nor `lastUpdated` — the write stamps
/// those.
class PivaProfileInput {
  const PivaProfileInput({
    required this.atecoCode,
    required this.coefficient,
    required this.startYear,
    required this.startupRate,
    required this.fundType,
    required this.fundName,
    required this.subjectiveRate,
    required this.integrativeRate,
    required this.minSubjective,
    required this.minIntegrative,
    required this.inpsReduction,
    required this.incomeCategories,
    required this.declaredIncome,
  });

  final String atecoCode;
  final double coefficient;
  final int startYear;
  final bool startupRate;
  final String fundType, fundName;
  final double subjectiveRate, integrativeRate, minSubjective, minIntegrative;
  final bool inpsReduction;
  final List<String> incomeCategories;

  /// Written as given, `{}` included: a save that dropped it would erase the
  /// figure the web (or an earlier answer) put there.
  final Map<String, double?> declaredIncome;
}

/// The first rule the form broke, in the order the rules run.
enum ProfileFormError {
  atecoCode,
  coefficient,
  startYear,
  fundType,
  subjectiveRate,
  integrativeRate,
  minimums,
  incomeCategories,
}

const _fundTypes = ['gestione_separata', 'artigiani', 'commercianti', 'cassa'];
const _firstYear = 1950;

({PivaProfileInput? profile, ProfileFormError? error}) _fail(ProfileFormError e) => (profile: null, error: e);

/// A percentage in (0, 100], or in [0, 100] with [zeroOk].
bool _validPct(double n, {bool zeroOk = false}) => n <= 100 && (zeroOk ? n >= 0 : n > 0);

/// An optional amount: blank reads as 0, anything else as [parseAmount].
double? _optionalAmount(String s) {
  if (s.trim().isEmpty) return 0.0;
  final v = parseAmount(s);
  // '-0' reads as -0.0, which Dart prints "-0.0" where JavaScript prints 0:
  // adding 0.0 turns it into 0.0 and leaves every other value as it is.
  return v == null ? null : v + 0.0;
}

/// The form's values as a profile to save, or the first error in field order.
/// Numbers are read with [parseAmount] (comma or dot, a leading sign kept so it
/// can be rejected). Only a `cassa` keeps its own fields: for any other fund the
/// hidden ones are saved as '' / 0 whatever they hold, and the INPS reduction
/// only counts for artigiani and commercianti. Exactly one of the two fields of
/// the result is set. The declared income is not a field of the form: its map
/// passes through untouched (copied, entry for entry, `null` values included);
/// the previous year's field and its rule come with #30.
({PivaProfileInput? profile, ProfileFormError? error}) parseProfileForm(ProfileFormValues f, DateTime now) {
  final atecoCode = f.atecoCode.trim();
  if (!RegExp(r'^\d{2}(\.?\d{1,2}){0,2}$').hasMatch(atecoCode)) return _fail(ProfileFormError.atecoCode);

  final coefficient = parseAmount(f.coefficient);
  if (coefficient == null || !_validPct(coefficient)) return _fail(ProfileFormError.coefficient);

  final year = f.startYear.trim();
  final startYear = RegExp(r'^\d{4}$').hasMatch(year) ? int.parse(year) : null;
  // `now` may arrive UTC-flagged: the year is the local one, like the web's getFullYear().
  if (startYear == null || startYear < _firstYear || startYear > now.toLocal().year) {
    return _fail(ProfileFormError.startYear);
  }

  final fundType = f.fundType;
  if (!_fundTypes.contains(fundType)) return _fail(ProfileFormError.fundType);

  var cassa = (fundName: '', subjectiveRate: 0.0, integrativeRate: 0.0, minSubjective: 0.0, minIntegrative: 0.0);
  if (fundType == 'cassa') {
    final subjectiveRate = parseAmount(f.subjectiveRate);
    if (subjectiveRate == null || !_validPct(subjectiveRate)) return _fail(ProfileFormError.subjectiveRate);
    final integrativeRate = _optionalAmount(f.integrativeRate);
    if (integrativeRate == null || !_validPct(integrativeRate, zeroOk: true)) {
      return _fail(ProfileFormError.integrativeRate);
    }
    final minSubjective = _optionalAmount(f.minSubjective);
    final minIntegrative = _optionalAmount(f.minIntegrative);
    if (minSubjective == null || minSubjective < 0 || minIntegrative == null || minIntegrative < 0) {
      return _fail(ProfileFormError.minimums);
    }
    cassa = (
      fundName: f.fundName.trim(),
      subjectiveRate: subjectiveRate,
      integrativeRate: integrativeRate,
      minSubjective: minSubjective,
      minIntegrative: minIntegrative,
    );
  }

  // toSet() keeps insertion order: the duplicates go, the order stays.
  final incomeCategories = f.incomeCategories.map((c) => c.trim()).where((c) => c.isNotEmpty).toSet().toList();
  if (incomeCategories.isEmpty) return _fail(ProfileFormError.incomeCategories);

  return (
    profile: PivaProfileInput(
      atecoCode: atecoCode,
      coefficient: coefficient,
      startYear: startYear,
      startupRate: f.startupRate,
      fundType: fundType,
      fundName: cassa.fundName,
      subjectiveRate: cassa.subjectiveRate,
      integrativeRate: cassa.integrativeRate,
      minSubjective: cassa.minSubjective,
      minIntegrative: cassa.minIntegrative,
      inpsReduction: f.inpsReduction && (fundType == 'artigiani' || fundType == 'commercianti'),
      incomeCategories: incomeCategories,
      declaredIncome: Map.of(f.declaredIncome),
    ),
    error: null,
  );
}
