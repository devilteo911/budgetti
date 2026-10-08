/// One year of the Partita IVA screen: the compensi month by month against the
/// year before, the figures of the tiles, and the estimate of the year.
///
/// The web derives all of this inside its components —
/// `web/src/components/PivaIncome.tsx` (the `useMemo` at lines 31–72) and
/// `PivaForecast.tsx` (64–87) — so, unlike `models/piva.dart`, it is not a mirror
/// of `piva.ts`. Same figures, same rules, to the cent.
///
/// The figures of the year are made on `compensiForYear` (what the owner declared
/// for a year the ledger does not cover, else the ledger's total), tiles and
/// estimate alike, as `PivaIncome.tsx` and `PivaForecast.tsx` do. A declared year
/// is one yearly figure: its `months` (and the tiles built on them: average, best
/// month) stay the ledger's and the screen does not draw them; a year after it has
/// no months to compare with, so it is never set against a stretch of it.
///
/// Pure: no I/O, and `now` is a parameter, read once per derivation on the local
/// calendar. It imports the engine and the transaction model only — no Flutter,
/// Drift or Riverpod — so the background isolate can use it too.
library;

import 'package:budgetti/models/piva.dart';
import 'package:budgetti/models/transaction.dart';

class PivaYearView {
  const PivaYearView({
    required this.year,
    required this.months,
    required this.priorMonths,
    required this.total,
    required this.prior,
    required this.pct,
    required this.concludedMonths,
    required this.average,
    required this.count,
    required this.best,
    required this.bestMonth,
    required this.currentMonth,
    required this.hasData,
    required this.carved,
    required this.gross,
    required this.toRemit,
    required this.estimate,
    required this.ratePct,
    required this.declared,
    required this.priorDeclared,
    required this.noPrev,
  });

  final int year;

  /// The 12 monthly compensi of [year] and of the year before: whole months, the
  /// chart's bars (the ledger's, also for a declared year).
  final List<double> months, priorMonths;

  /// Compensi of [year] (`compensiForYear`: the declared figure, else the ledger's);
  /// and of the year before — the same stretch of it (1 January to the day of
  /// `now`) while [year] is still running, the whole year otherwise, and also the
  /// whole year while [noStretch] (the figure the tile names, not a base for [pct]).
  final double total, prior;

  /// [total] against [prior], in %; `null` when there is no base to compare with
  /// (and always while [noStretch]).
  final double? pct;

  /// The owner declared [year] as one yearly figure: it has no months to average,
  /// rank or draw.
  final bool declared;

  /// The year before [year] is declared: no months to set against, so the chart
  /// draws one rod per month.
  final bool priorDeclared;

  /// The year before has nothing at all: not declared, no compensi, and the ledger
  /// does not reach back to 1 January of it. "New vs" would read as "no income the
  /// year before" when the ledger just does not cover it, so no delta is shown. A
  /// covered year with no income is a real zero and stays "new".
  final bool noPrev;

  /// [year] is running and the year before is declared: there is no stretch of
  /// that year to compare with, so the tile names its whole figure ([prior])
  /// instead of a delta.
  bool get noStretch => priorDeclared && currentMonth >= 0;

  /// Months of [year] that are over: 12, or the ones before the current month.
  final int concludedMonths;

  /// Mean of the concluded months; `null` in January, when there are none.
  final double? average;

  /// Payments counted in [year] (rows of the ledger, not months).
  final int count;

  /// The best month (0 when none), and its index 0–11 (the first on a tie).
  final double best;
  final int bestMonth;

  /// Index 0–11 of the month in progress, `-1` when [year] is not the current one.
  final int currentMonth;

  /// Whether [year] or the year before has anything to show: compensi in the
  /// ledger, or a declared figure for either.
  final bool hasData;

  /// A cassa that charges an integrativo: the bank amounts include money that is
  /// not income.
  final bool carved;

  /// What the bank credited in [year] for the profile's categories (the
  /// integrativo included): the declared figure for a declared year, else the
  /// ledger's. And the integrativo to remit out of it (0 unless [carved]).
  final double gross, toRemit;

  /// The tax and contributions of [year], with the contributions that come off
  /// the income following the cash rule of the deadlines.
  final PivaYear estimate;

  /// The imposta sostitutiva rate of [year], in %.
  final double ratePct;
}

double _sum(Iterable<double> xs) => xs.fold(0.0, (a, b) => a + b);

/// Days of [month] (1–12) of [year]: day 0 of the next month, on UTC so no clock
/// change can move it.
int _daysInMonth(int year, int month) => DateTime.utc(year, month + 1, 0).day;

/// A local day as a number that sorts like the calendar: days are compared by
/// year, month and day, never as instants.
int _key(int year, int month, int day) => year * 10000 + month * 100 + day;

/// Signed % change against a prior value; `null` when there is no baseline.
/// `web/src/finance.ts` `pctDelta`.
double? _pctDelta(double cur, double prev) =>
    prev == 0 ? (cur == 0 ? 0.0 : null) : ((cur - prev) / prev.abs()) * 100;

/// [year] of the profile as the screen shows it. [txns] is the whole income
/// history, not a window: the deductible contributions of the estimate reach back
/// years (see `deadlines`). [now] is read once, on the local calendar.
/// [ledgerStart] is the first live transaction of the whole ledger (any type), for
/// [PivaYearView.noPrev]; null is an empty ledger, which covers nothing.
PivaYearView pivaYearView(
  PivaProfileData profile,
  List<Transaction> txns,
  List<PivaPaymentData> payments,
  int year,
  DateTime now, {
  DateTime? ledgerStart,
}) {
  final n = now.toLocal();
  final running = year == n.year;
  final months = incomeByMonth(txns, profile, year);
  final priorMonths = incomeByMonth(txns, profile, year - 1);
  // Any year with a number is declared, whatever `now` is: the stored answer is
  // what counts, as on the web.
  final declaredGross = declaredFor(profile, year);
  final priorDeclared = declaredFor(profile, year - 1) != null;
  final prevTotal = compensiForYear(profile, txns, year - 1);
  final noStretch = running && priorDeclared;

  // A year still running is set against the same stretch of the year before: up
  // to the day of `now`, clamped to the length of that month then, and the whole
  // month on the last day of its own (29 February meets all of a leap February).
  // A declared year before it has no months, so there is no stretch: `prior` is
  // its whole figure and the percentage is dropped.
  var prior = prevTotal;
  if (running && !noStretch) {
    final dim = _daysInMonth(year - 1, n.month);
    final cut = (n.day == _daysInMonth(year, n.month) || n.day > dim) ? dim : n.day;
    final last = _key(year - 1, n.month, cut);
    prior = _sum(
      incomeByMonth(
        txns.where((t) {
          final d = t.date.toLocal();
          return _key(d.year, d.month, d.day) <= last;
        }).toList(),
        profile,
        year - 1,
      ),
    );
  }

  final total = compensiForYear(profile, txns, year);
  final concluded = running ? n.month - 1 : 12;
  final inYear = pivaIncome(txns, profile).where((t) => t.date.toLocal().year == year).toList();
  final carved = profile.fundType == 'cassa' && profile.integrativeRate > 0;
  final best = months.reduce((a, b) => b > a ? b : a);

  return PivaYearView(
    year: year,
    months: List.unmodifiable(months),
    priorMonths: List.unmodifiable(priorMonths),
    total: total,
    prior: prior,
    pct: noStretch ? null : _pctDelta(total, prior),
    concludedMonths: concluded,
    // The month in progress would dilute it; January has no concluded month yet.
    average: concluded > 0 ? _sum(months.take(concluded)) / concluded : null,
    count: inYear.length,
    best: best,
    bestMonth: months.indexOf(best),
    currentMonth: running ? n.month - 1 : -1,
    hasData: total != 0 || _sum(priorMonths) != 0 || declaredGross != null || priorDeclared,
    carved: carved,
    gross: declaredGross ?? _sum(inYear.map((t) => t.amount)),
    toRemit: carved ? integrativeCollected(txns, profile, year) : 0.0,
    estimate: estimateYear(
      profile,
      total,
      year,
      contributionsDeductible(deadlines(profile, txns, payments, now), year),
    ),
    ratePct: taxRate(profile, year) * 100,
    declared: declaredGross != null,
    priorDeclared: priorDeclared,
    noPrev: !priorDeclared && prevTotal == 0 && !ledgerCovers(ledgerStart, year - 1),
  );
}
