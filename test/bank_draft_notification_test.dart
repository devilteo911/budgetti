import 'package:budgetti/core/services/notification_service.dart';
import 'package:budgetti/l10n/app_localizations_en.dart';
import 'package:budgetti/l10n/app_localizations_it.dart';
import 'package:flutter_test/flutter_test.dart';

/// A captured bank movement is a draft awaiting the owner's review, not a
/// booked transaction: its notification must not say "recorded".
void main() {
  test('titles say the draft is waiting for review (it)', () {
    final it = AppLocalizationsIt();

    expect(it.notifEmailExpense, 'Pagamento da rivedere');
    expect(it.notifEmailIncome, 'Accredito da rivedere');
    expect(it.notifEmailReview, 'Bonifico da rivedere');
  });

  test('titles say the draft is waiting for review (en)', () {
    final en = AppLocalizationsEn();

    expect(en.notifEmailExpense, 'Payment to review');
    expect(en.notifEmailIncome, 'Credit to review');
    expect(en.notifEmailReview, 'Transfer to review');
  });

  // A busy morning of captures should collapse into one stack in the shade, not
  // a column of separate cards.
  test('every capture notification joins one group', () {
    expect(bankDraftNotificationDetails.android!.groupKey, bankDraftsGroupKey);
    expect(bankDraftNotificationDetails.iOS!.threadIdentifier, bankDraftsGroupKey);
    expect(bankDraftsGroupKey, 'bank_drafts');
  });

  // Android's own summary for the stack has no intent from us: tapping the
  // COLLAPSED group only brought the app back on its last screen and cleared all
  // the notifications. We post the summary ourselves, with the same tap route.
  group('the group summary', () {
    test('is a summary of the same group, with the same channel', () {
      final android = bankDraftsSummaryDetails.android!;

      expect(android.setAsGroupSummary, isTrue);
      expect(android.groupKey, bankDraftsGroupKey);
      expect(android.channelId, bankDraftNotificationDetails.android!.channelId);
      expect(bankDraftsSummaryDetails.iOS!.threadIdentifier, bankDraftsGroupKey);
    });

    test('carries a payload, or the tap handler would ignore it', () {
      expect(bankDraftsSummaryPayload, isNotEmpty);
    });

    test('a tap on it reaches the tap handler, like an individual one', () {
      final taps = <String>[];

      routeNotificationTap(bankDraftsSummaryPayload, taps.add);
      routeNotificationTap('pending_rev_abc', taps.add);
      routeNotificationTap(null, taps.add);
      routeNotificationTap('', taps.add);

      expect(taps, [bankDraftsSummaryPayload, 'pending_rev_abc']);
    });

    test('is titled without a count, in both languages', () {
      expect(AppLocalizationsIt().notifBankDraftsSummary, 'Transazioni da rivedere');
      expect(AppLocalizationsEn().notifBankDraftsSummary, 'Transactions to review');
    });
  });
}
