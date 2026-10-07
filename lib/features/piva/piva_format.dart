import 'package:intl/intl.dart';

/// The only place a non-monetary Partita IVA number (a percentage, a
/// coefficient) becomes text, in its shortest form: `67`, not `67.0`; `26,07`
/// with the Italian separator, no trailing zeros, no thousands separator.
/// #19 and #20 reuse it to put a number back into a field, where `parseAmount`
/// reads the comma and the point alike. Money never comes through here: it goes
/// through `currencyProvider`.
String pivaNumber(num value) => NumberFormat('0.####').format(value);

/// A label as the lists show it: the no-break space before each ` · ` keeps the
/// dot on the line of the word it follows, where a plain wrap would leave it
/// dangling at the start of the next one. Display only — never saved, never
/// compared.
String pivaNoBreak(String s) => s.replaceAll(' · ', '\u00A0· ');

// The fiscal terms. Identical in both languages (decision of the parent issue),
// so Dart constants and not ARB keys: a key translated twice the same is one
// more place to get it wrong. Same words as the web (`PivaForecast.tsx`,
// `PivaProfileForm.tsx`).
const pivaCompensi = 'Compensi';
const pivaAteco = 'ATECO';
const pivaCoefficient = 'coefficiente';
const pivaGrossIncome = 'Reddito lordo · coefficiente di redditività';
const pivaContributionsPaid = 'Contributi dedotti';
const pivaTaxable = 'Imponibile';
const pivaFlatTax = 'Imposta sostitutiva';
const pivaContributions = 'Contributi';

/// `fundType` → the name of the fund. A `fundType` that is not here has no name.
const pivaFundLabels = {
  'gestione_separata': 'Gestione Separata INPS',
  'artigiani': 'Artigiani INPS',
  'commercianti': 'Commercianti INPS',
  'cassa': 'Cassa professionale',
};
