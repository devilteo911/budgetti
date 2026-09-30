import 'package:budgetti/core/providers/providers.dart';
import 'package:budgetti/features/dashboard/widgets/budget_overview_card.dart';
import 'package:budgetti/l10n/app_localizations.dart';
import 'package:budgetti/models/budget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

/// On the 1st of a month nothing is spent yet, and the Categories legend used to
/// list the first three budgeted categories alphabetically, each at 0,00 € —
/// rows that say nothing. The legend lists what was spent, and only that.
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  Budget budget(String category) => Budget(
      id: 'b-$category', userId: 'u', category: category, limit: 100);

  Future<void> pump(WidgetTester tester, Map<String, double> spent) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        budgetsProvider.overrideWith((ref) => Stream.value([
              budget('Bills'),
              budget('Eating out'),
              budget('Entertainment'),
              budget('Groceries'),
            ])),
        budgetStatsProvider.overrideWithValue(AsyncData(spent)),
        currencyProvider.overrideWithValue(
            NumberFormat.simpleCurrency(locale: 'en_US', name: 'EUR')),
        categoryColorCacheProvider.overrideWith((ref, _) => const {}),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(body: SingleChildScrollView(child: BudgetOverviewCard())),
      ),
    ));
    await tester.runAsync(GoogleFonts.pendingFonts);
    await tester.pumpAndSettle();
  }

  testWidgets('a month with nothing spent lists no category, and says so',
      (tester) async {
    await pump(tester, const {});

    for (final name in ['BILLS', 'EATING OUT', 'ENTERTAINMENT', 'GROCERIES']) {
      expect(find.text(name), findsNothing, reason: '$name at 0,00 is noise');
    }
    expect(find.text('Nothing spent yet'), findsOneWidget);
  });

  testWidgets('the budget itself still reads 0% — that is true on the 1st',
      (tester) async {
    await pump(tester, const {});

    expect(find.textContaining('0', findRichText: true), findsWidgets);
    expect(find.byType(BudgetOverviewCard), findsOneWidget);
    // 0 spent of 400 budgeted.
    expect(find.textContaining('€0.00', findRichText: true), findsWidgets);
    expect(find.textContaining('€400.00', findRichText: true), findsWidgets);
  });

  testWidgets('only categories with spend are listed, biggest first, at most 3',
      (tester) async {
    await pump(tester, const {'Groceries': 30, 'Bills': 80});

    expect(find.text('GROCERIES'), findsOneWidget);
    expect(find.text('BILLS'), findsOneWidget);
    expect(find.text('EATING OUT'), findsNothing);
    expect(find.text('ENTERTAINMENT'), findsNothing);
    expect(find.text('Nothing spent yet'), findsNothing);
    expect(tester.getTopLeft(find.text('BILLS')).dy,
        lessThan(tester.getTopLeft(find.text('GROCERIES')).dy));
  });

  testWidgets('four categories with spend still show only the top three',
      (tester) async {
    await pump(tester,
        const {'Bills': 10, 'Eating out': 40, 'Entertainment': 20, 'Groceries': 30});

    expect(find.text('EATING OUT'), findsOneWidget);
    expect(find.text('GROCERIES'), findsOneWidget);
    expect(find.text('ENTERTAINMENT'), findsOneWidget);
    expect(find.text('BILLS'), findsNothing);
  });
}
