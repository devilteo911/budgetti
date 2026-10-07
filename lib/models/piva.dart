/// Partita IVA forfettaria: tax, contributions and deadlines, derived from a
/// profile, the ledger and the amounts the accountant saved.
///
/// This is the mirror of `web/src/piva.ts` minus the simulations
/// (`netFromRevenue`, `rateSwitch`, `thresholdStatus`, `grossMonthlyIncassi`,
/// `setAside`), minus `writeFailure`, and — until #19 ports it into this same
/// file — minus `parseProfileForm`. Same names, same cases, same figures to the
/// cent: the arithmetic follows the web's order of operations on purpose, since
/// JavaScript and Dart share IEEE-754 doubles but not their rounding helpers.
///
/// "Ricavi" always means *compensi*: cash received, minus the integrativo a
/// `cassa` profile charges its clients (not income).
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
