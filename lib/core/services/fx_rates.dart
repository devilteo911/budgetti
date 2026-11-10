/// Euro estimate of a foreign amount, at the European Central Bank's daily
/// reference rate (free, no key, about thirty currencies, published on working
/// days around 16:00 CET).
///
/// An ESTIMATE: PayPal and the card networks apply their own rate and a spread
/// of a few percent, so the figure prefills the amount field and the owner
/// corrects it against the real debit.
library;

import 'package:http/http.dart' as http;

final _ecbDaily =
    Uri.parse('https://www.ecb.europa.eu/stats/eurofxref/eurofxref-daily.xml');

/// Units of each currency per euro, as the ECB feed lists them.
Map<String, double> parseEcbRates(String xml) => {
      for (final m in RegExp(r"currency='([A-Z]{3})'\s+rate='([\d.]+)'")
          .allMatches(xml))
        m.group(1)!: double.parse(m.group(2)!),
    };

Map<String, double> _rates = const {};
DateTime _fetchedAt = DateTime.fromMillisecondsSinceEpoch(0);

/// [amount] of [currency] (ISO code) in euros, to the cent, or null when the
/// rate cannot be had (offline, feed down, currency not listed): the caller
/// then leaves the amount for the owner to type.
// ponytail: today's rate, not the rate of the day of the movement, and an
// in-memory cache of 12 hours. A draft is approved within days and the spread
// already makes it an estimate; use the ECB's 90-day feed if that ever matters.
Future<double?> euroEstimate(
  double amount,
  String currency, {
  http.Client? client,
}) async {
  try {
    if (DateTime.now().difference(_fetchedAt) > const Duration(hours: 12)) {
      final res = await (client?.get ?? http.get)(_ecbDaily)
          .timeout(const Duration(seconds: 4));
      final rates = res.statusCode == 200
          ? parseEcbRates(res.body)
          : const <String, double>{};
      if (rates.isNotEmpty) {
        _rates = rates;
        _fetchedAt = DateTime.now();
      }
    }
    final rate = _rates[currency];
    if (rate == null || rate <= 0) return null;
    return (amount / rate * 100).roundToDouble() / 100;
  } catch (_) {
    return null;
  }
}
