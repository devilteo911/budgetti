import 'package:budgetti/core/database/database.dart' show PendingTransaction;
import 'package:budgetti/core/providers/providers.dart';
import 'package:budgetti/features/home/scaffold_with_nav_bar.dart';
import 'package:budgetti/l10n/app_localizations.dart';
import 'package:budgetti/l10n/app_localizations_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The History icon carries what the History banner lists: drafts awaiting
/// review plus messages the parser could not read.
void main() {
  PendingTransaction row(String id) => PendingTransaction(
        id: id,
        gmailMessageId: id,
        source: 'revolut',
        emailSubject: 's',
        emailReceivedAt: DateTime(2026, 6, 24),
        parsedAmount: -10,
        parsedDescription: 'Coffee',
        parsedDate: DateTime(2026, 6, 24),
        suggestedType: 'expense',
        rawSnippet: '',
        status: 'skipped',
        createdAt: DateTime(2026, 6, 24),
        duplicateDismissed: false,
      );

  group('reviewInboxCountProvider', () {
    Future<int> count({required int pending, required int skipped}) async {
      final container = ProviderContainer(overrides: [
        pendingTransactionsCountProvider.overrideWithValue(pending),
        skippedEmailsProvider.overrideWith(
            (ref) => Stream.value([for (var i = 0; i < skipped; i++) row('s$i')])),
      ]);
      addTearDown(container.dispose);
      // Listened, so the stream provider is live; then let it deliver.
      final sub = container.listen(reviewInboxCountProvider, (_, __) {});
      await Future<void>.delayed(const Duration(milliseconds: 20));
      return sub.read();
    }

    test('drafts and unreadable messages add up', () async {
      expect(await count(pending: 2, skipped: 3), 5);
    });

    test('either alone', () async {
      expect(await count(pending: 4, skipped: 0), 4);
      expect(await count(pending: 0, skipped: 1), 1);
    });

    test('an empty inbox is zero', () async {
      expect(await count(pending: 0, skipped: 0), 0);
    });

    test('unreadable messages still loading count as none, not an error', () {
      final container = ProviderContainer(overrides: [
        pendingTransactionsCountProvider.overrideWithValue(2),
        skippedEmailsProvider.overrideWith((ref) => const Stream.empty()),
      ]);
      addTearDown(container.dispose);

      final sub = container.listen(reviewInboxCountProvider, (_, __) {});
      expect(sub.read(), 2);
    });
  });

  group('the nav pill', () {
    final l10n = AppLocalizationsEn();

    List<NavSlot> slots(int review) =>
        buildNavSlots(l10n, reviewCount: review, onAdd: () {});

    test('only History carries the count', () {
      final s = slots(3);

      expect([for (final x in s) x.badge], [0, 3, 0, 0, 0]);
      expect(s[1].label, 'History');
    });

    // The pill's glass container reads the theme settings, hence the prefs.
    Future<void> pumpPill(WidgetTester tester, int review) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Center(
              child: FloatingPillNav(
                slots: slots(review),
                currentBranchIndex: 0,
                onBranchSelected: (_) {},
              ),
            ),
          ),
        ),
      ));
    }

    testWidgets('shows the count on the History icon', (tester) async {
      await pumpPill(tester, 3);

      expect(find.byType(Badge), findsOneWidget);
      expect(find.descendant(of: find.byType(Badge), matching: find.text('3')),
          findsOneWidget);
    });

    testWidgets('shows nothing when the inbox is empty', (tester) async {
      await pumpPill(tester, 0);

      expect(find.byType(Badge), findsNothing);
    });

    testWidgets('a screen reader hears the count after the label',
        (tester) async {
      final handle = tester.ensureSemantics();
      await pumpPill(tester, 3);

      expect(find.bySemanticsLabel('History, 3 transactions to review'),
          findsOneWidget);
      expect(find.bySemanticsLabel('Dashboard'), findsOneWidget);
      handle.dispose();
    });
  });
}
