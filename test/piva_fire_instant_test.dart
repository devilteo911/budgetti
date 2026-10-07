import 'package:budgetti/core/services/notification_service.dart' show pivaFireInstant;
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// A reminder fires at 9:00 on Italian clocks, whichever zone the machine runs
/// in: the instant is built from the location it is given, never from the zone
/// of the test run, so this passes anywhere. The three days are the two clock
/// changes of 2026 and the day before the first.
void main() {
  setUpAll(tz.initializeTimeZones);

  // As `planPivaReminders` makes it: the wall clock in a UTC carrier.
  DateTime nineOn(int year, int month, int day) => DateTime.utc(year, month, day, 9);

  void expectUtc(DateTime nine, tz.Location rome, DateTime utc) {
    final at = pivaFireInstant(nine, rome);
    expect(at.hour, 9, reason: 'still 9:00 on the Italian clock');
    expect(at.millisecondsSinceEpoch, utc.millisecondsSinceEpoch);
  }

  test('9:00 in Rome: winter time before the change, summer time after it, winter again', () {
    final rome = tz.getLocation('Europe/Rome');

    expectUtc(nineOn(2026, 3, 28), rome, DateTime.utc(2026, 3, 28, 8)); // CET, +1
    expectUtc(nineOn(2026, 3, 29), rome, DateTime.utc(2026, 3, 29, 7)); // CEST, +2
    expectUtc(nineOn(2026, 10, 25), rome, DateTime.utc(2026, 10, 25, 8)); // CET again
  });
}
