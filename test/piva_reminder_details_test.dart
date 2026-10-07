import 'package:budgetti/core/services/notification_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

/// How a reminder looks in the shade. The long body of an estimate ends in
/// "(stima)": a plain body is clipped at two lines, so the whole text goes in a
/// big-text style, which an expanded notification shows in full.
void main() {
  const body = 'Gestione Separata · Secondo acconto 2026 · 30/11/2026 · circa 1.345,25 € (stima)';

  test('a reminder carries its whole body as big text', () {
    final android = pivaReminderDetails(groupKey: 'g', body: body).android!;

    final style = android.styleInformation as BigTextStyleInformation;
    expect(style.bigText, body);
    expect(android.setAsGroupSummary, isFalse);
    expect(android.groupKey, 'g');
  });

  test('the stack summary has no body and no style, and shares the reminders\' group and channel', () {
    final reminder = pivaReminderDetails(groupKey: 'g', body: body).android!;
    final summary = pivaReminderDetails(groupKey: 'g', summary: true).android!;

    expect(summary.styleInformation, isNull);
    expect(summary.setAsGroupSummary, isTrue);
    expect(summary.groupKey, reminder.groupKey);
    expect(summary.channelId, reminder.channelId);
  });

  test('a lone reminder has no group', () {
    expect(pivaReminderDetails(body: body).android!.groupKey, isNull);
  });
}
