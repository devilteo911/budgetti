/// Partita IVA deadline reminders: what to notify and when, as pure functions.
///
/// [planPivaReminders] turns the engine's deadlines and today's date into the
/// notifications to schedule (30, 7 and 1 day before and on the day, at 9:00);
/// [diffPivaReminders] compares that plan with what is already scheduled on the
/// device. Neither reads the clock, the database or a `BuildContext`: `now` and
/// the language come in as arguments, so the same code runs in the UI isolate
/// and in the workmanager one. Putting the plan on the device is the notification
/// service's job.
///
/// Times are wall-clock times of Italy: a reminder's [PivaReminder.fireAt] holds
/// only year, month, day and hour, in a UTC `DateTime` used as a carrier because
/// UTC calendar arithmetic knows no daylight-saving change. The service applies
/// the Europe/Rome zone to it. `now` is read the same way, by its components, so
/// no instant is ever compared and the machine's time zone never matters.
library;

import 'dart:convert';

import 'package:budgetti/l10n/app_localizations.dart';
import 'package:budgetti/models/piva.dart';
import 'package:crypto/crypto.dart';
import 'package:intl/intl.dart' show NumberFormat;

/// Days before the deadline, the day itself included (0).
const pivaReminderOffsets = [30, 7, 1, 0];

/// Hour of the day, Italian time.
const pivaReminderHour = 9;

/// How many reminders are scheduled at most, the nearest ones.
const pivaReminderCap = 32;

/// What a reminder's payload starts with: the tap handler tells it from every
/// other notification by this.
const pivaReminderPayloadPrefix = 'piva:';

class PivaReminder {
  const PivaReminder({
    required this.id,
    required this.deadlineKey,
    required this.fireAt,
    required this.daysBefore,
    required this.title,
    required this.body,
  });

  /// Always negative: the other notifications of the app use non-negative ids.
  final int id;

  /// The `key` of the deadline, `''` for one added by hand.
  final String deadlineKey;

  /// Wall-clock time, `DateTime.utc(year, month, day, 9)`: only its components
  /// mean anything, the zone is applied by whoever schedules it.
  final DateTime fireAt;
  final int daysBefore;
  final String title;
  final String body;

  /// Carries the time, so a deadline that moves changes its reminders' payload
  /// and [diffPivaReminders] sees it.
  String get payload => '$pivaReminderPayloadPrefix${fireAt.toIso8601String()}';
}

/// The id of the reminder [daysBefore] days before the deadline [identity]
/// (`paymentId ?? key`): the first 4 bytes of a SHA-256, big-endian, folded into
/// the negative integers `-1 … -2^31`. Not `String.hashCode`, which Dart does not
/// promise to keep stable between versions.
int pivaReminderId(String identity, int daysBefore) {
  final b = sha256.convert(utf8.encode('$identity|$daysBefore')).bytes;
  final v = (b[0] << 24) | (b[1] << 16) | (b[2] << 8) | b[3];
  return -1 - (v & 0x7fffffff);
}

/// The reminders to have scheduled for [deadlines] as of [now], at most
/// [pivaReminderCap], nearest first.
///
/// Only a deadline that is `due`, has a day and an amount above zero is
/// notified: never a paid one, never one already past (the screen shows those
/// in red), never one with no day to count from or nothing to pay. A reminder
/// whose time is not strictly after [now] is skipped, not caught up: "in 7 days"
/// shown two days late would be false.
List<PivaReminder> planPivaReminders(
  List<PivaDeadline> deadlines,
  DateTime now, {
  required AppLocalizations l10n,
}) {
  final today = DateTime(now.year, now.month, now.day);
  // `now` as a wall clock, to compare with `fireAt` (both UTC carriers).
  final wallNow = DateTime.utc(now.year, now.month, now.day, now.hour, now.minute);
  final money = NumberFormat.currency(locale: l10n.localeName, symbol: '€');
  String two(int v) => v.toString().padLeft(2, '0');

  final planned = <(int, PivaReminder)>[];
  for (final d in deadlines) {
    final due = d.dueDate;
    if (due == null || d.amount <= 0 || deadlineState(d, today) != DeadlineState.due) continue;
    // Written by hand: DateFormat's date symbols are not initialised in the
    // workmanager isolate.
    final date = '${two(due.day)}/${two(due.month)}/${due.year}';
    final amount = money.format(d.amount);
    final body = d.estimated
        ? l10n.pivaRemBodyEstimate(d.label, date, amount)
        : l10n.pivaRemBody(d.label, date, amount);
    for (final n in pivaReminderOffsets) {
      // The constructor carries a day below 1 over to the month before.
      final fireAt = DateTime.utc(due.year, due.month, due.day - n, pivaReminderHour);
      if (!fireAt.isAfter(wallNow)) continue;
      planned.add((
        planned.length,
        PivaReminder(
          id: pivaReminderId(d.paymentId ?? d.key, n),
          deadlineKey: d.key,
          fireAt: fireAt,
          daysBefore: n,
          title: switch (n) {
            0 => l10n.pivaRemTitleToday,
            1 => l10n.pivaRemTitleTomorrow,
            _ => l10n.pivaRemTitleDays(n),
          },
          body: body,
        ),
      ));
    }
  }

  // By time, then by the order the deadlines came in: List.sort is not stable.
  planned.sort((a, b) {
    final c = a.$2.fireAt.compareTo(b.$2.fireAt);
    return c != 0 ? c : a.$1.compareTo(b.$1);
  });
  final seen = <int>{};
  return [
    for (final (_, r) in planned)
      if (seen.add(r.id)) r,
  ].take(pivaReminderCap).toList();
}

/// A notification as the plugin reports it pending, or as the plan wants it.
typedef PivaPending = ({int id, String? title, String? body, String? payload});

/// What to cancel and what to schedule to bring [pending] to [wanted]. Of
/// [pending] only the negative ids count: the others are not ours. A reminder
/// is cancelled when [wanted] lacks it or has it with another title, body or
/// payload, and scheduled when [pending] does not hold it identically — so a
/// changed one is in both lists, and an unchanged plan is in neither.
({List<int> cancel, List<PivaPending> schedule}) diffPivaReminders(List<PivaPending> pending, List<PivaPending> wanted) {
  final have = {
    for (final p in pending)
      if (p.id < 0) p.id: p,
  };
  final want = {for (final w in wanted) w.id: w};
  return (
    cancel: [
      for (final p in have.values)
        if (want[p.id] != p) p.id,
    ],
    schedule: [
      for (final w in wanted)
        if (have[w.id] != w) w,
    ],
  );
}
