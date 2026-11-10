import 'package:budgetti/core/services/fx_rates.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _feed = """<?xml version="1.0" encoding="UTF-8"?>
<gesmes:Envelope><Cube><Cube time='2026-11-09'>
<Cube currency='USD' rate='1.1193'/>
<Cube currency='GBP' rate='0.83430'/>
</Cube></Cube></gesmes:Envelope>""";

void main() {
  test('the ECB feed is read as units per euro', () {
    expect(parseEcbRates(_feed), {'USD': 1.1193, 'GBP': 0.8343});
    expect(parseEcbRates('<html>down</html>'), isEmpty);
  });

  // One test, in this order: the rates are cached for the isolate, so the
  // failing fetch has to come before the one that fills the cache.
  test('no rate, no estimate; then euros to the cent', () async {
    final down = MockClient((_) async => http.Response('nope', 503));
    expect(await euroEstimate(25, 'USD', client: down), isNull);

    final up = MockClient((_) async => http.Response(_feed, 200));
    expect(await euroEstimate(25, 'USD', client: up), 22.34); // 25 / 1.1193
    expect(await euroEstimate(15, 'GBP', client: up), 17.98); // 15 / 0.8343
    expect(await euroEstimate(10, 'XXX', client: up), isNull);
    // Cached: a dead network no longer matters.
    expect(await euroEstimate(25, 'USD', client: down), 22.34);
  });
}
