import 'dart:ffi';

import 'package:budgetti/core/database/database.dart';
import 'package:budgetti/core/services/bank_draft.dart';
import 'package:budgetti/core/services/bank_sync_service.dart';
import 'package:budgetti/core/services/revolut_notification_parser.dart'
    show revolutFallbackDescription;
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart' show NativeDatabase;
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/open.dart' as sqlite3open;

// See finance_service_seed_test.dart: point the FFI loader at the system lib.
void _ensureSqlite() {
  try {
    sqlite3open.open.overrideFor(
      sqlite3open.OperatingSystem.linux,
      () => DynamicLibrary.open('/lib/x86_64-linux-gnu/libsqlite3.so.0'),
    );
  } catch (_) {
    // Already overridden or not on Linux — ignore.
  }
}

void main() {
  setUpAll(_ensureSqlite);

  group('descriptionSimilarity', () {
    test('merchant name buried in POS boilerplate scores high', () {
      final sim = descriptionSimilarity(
        'Esselunga',
        'PAGAMENTO POS ESSELUNGA SPA MILANO',
      );
      expect(sim, greaterThanOrEqualTo(0.9));
    });

    test('identical strings score 1.0', () {
      expect(descriptionSimilarity('Netflix', 'Netflix'), 1.0);
    });

    test('unrelated merchants score low', () {
      final sim = descriptionSimilarity(
        'Farmacia Comunale',
        'PAGAMENTO POS ESSELUNGA SPA',
      );
      expect(sim, lessThan(0.2));
    });

    test('boilerplate-only overlap does not count', () {
      final sim = descriptionSimilarity(
        'PAGAMENTO POS CARTA',
        'PAGAMENTO POS ESSELUNGA',
      );
      expect(sim, 0);
    });
  });

  group('duplicateConfidence', () {
    final day = DateTime(2026, 6, 9);

    test('same day + same merchant is a confident duplicate', () {
      final score = duplicateConfidence(
        draftDate: day,
        draftDescription: 'PAGAMENTO POS ESSELUNGA SPA',
        txDate: day,
        txDescription: 'Esselunga',
      );
      expect(score, greaterThanOrEqualTo(duplicateThreshold));
    });

    test('same day with unrelated title still gets flagged', () {
      final score = duplicateConfidence(
        draftDate: day,
        draftDescription: 'PAGAMENTO POS ESSELUNGA SPA',
        txDate: day,
        txDescription: 'Spesa settimanale',
      );
      expect(score, greaterThanOrEqualTo(duplicateThreshold));
    });

    test('3 days apart with unrelated title is not flagged', () {
      final score = duplicateConfidence(
        draftDate: day,
        draftDescription: 'PAGAMENTO POS ESSELUNGA SPA',
        txDate: day.subtract(const Duration(days: 3)),
        txDescription: 'Cena fuori',
      );
      expect(score, lessThan(duplicateThreshold));
    });

    test('3 days apart but same merchant is flagged', () {
      final score = duplicateConfidence(
        draftDate: day,
        draftDescription: 'PAGAMENTO POS ESSELUNGA SPA',
        txDate: day.subtract(const Duration(days: 3)),
        txDescription: 'Esselunga',
      );
      expect(score, greaterThanOrEqualTo(duplicateThreshold));
    });
  });

  // Day gaps are calendar days. Measured as elapsed 24h blocks between local
  // midnights they shrink across a spring-forward change (2026-03-29 in Rome is
  // a 23-hour day), so consecutive days scored as the same day. The dates are
  // built local, as the app's are: under TZ=Europe/Rome this fails on the old
  // arithmetic; under TZ=UTC there is no DST and it passes either way.
  group('duplicateConfidence across a DST change', () {
    double score(DateTime draft, DateTime tx) => duplicateConfidence(
          draftDate: draft,
          draftDescription: 'Esselunga', // nothing shared with the other title
          txDate: tx,
          txDescription: 'Farmacia',
        );

    test('consecutive days over the spring change are one day apart', () {
      // 0.5 * 0.8 (one day) + 0 (names share nothing)
      expect(score(DateTime(2026, 3, 30), DateTime(2026, 3, 29)), closeTo(0.4, 1e-9));
      expect(score(DateTime(2026, 3, 29), DateTime(2026, 3, 28)), closeTo(0.4, 1e-9));
    });

    test('the same day is still the same day', () {
      expect(score(DateTime(2026, 3, 29, 23), DateTime(2026, 3, 29, 1)),
          closeTo(0.5, 1e-9));
    });

    test('two days over the change are two days, not one', () {
      // 0.5 * 0.6
      expect(score(DateTime(2026, 3, 30), DateTime(2026, 3, 28)), closeTo(0.3, 1e-9));
    });

    test('and the autumn change behaves the same', () {
      expect(score(DateTime(2026, 10, 26), DateTime(2026, 10, 25)), closeTo(0.4, 1e-9));
      expect(score(DateTime(2026, 10, 27), DateTime(2026, 10, 25)), closeTo(0.3, 1e-9));
    });
  });

  // Widiba -> Revolut: the owner books the transfer, and the Revolut top-up that
  // arrives as a push or a statement row is the SAME money. Its description
  // ("Pagamento da ROSSI MARIO") shares nothing with the transfer's, so by name
  // and date alone it scores under the threshold and is booked twice. A transfer
  // whose DESTINATION is the wallet an INCOME draft lands in, for the same amount
  // within the window, is a twin regardless of the wording — and only then, so an
  // ordinary expense of the same amount is never flagged by it.
  //
  // The other order (top-up approved as income first) is the booking core's job:
  // the transfer takes the income over (pending_transaction_service_test.dart).
  group('findDuplicate: a top-up against a wallet-to-wallet transfer', () {
    late AppDatabase db;
    var n = 0;
    setUp(() {
      db = AppDatabase.forExecutor(NativeDatabase.memory());
      n = 0;
    });
    tearDown(() => db.close());

    final day = DateTime(2026, 6, 23, 10);
    Future<void> transfer({
      double amount = 100,
      DateTime? date,
      String to = 'rev',
      bool deleted = false,
    }) =>
        db.into(db.transactions).insert(TransactionsCompanion.insert(
              id: 'tr${n++}',
              accountId: const Value('wid'),
              toAccountId: Value(to),
              amount: amount,
              description: 'Giroconto verso conto secondario',
              category: 'Transfer',
              type: const Value('transfer'),
              date: date ?? day.subtract(const Duration(days: 2)),
              isDeleted: Value(deleted),
            ));

    Future<DuplicateMatch?> topUp({
      double amount = 100,
      String? into = 'rev',
      DateTime? date,
    }) =>
        findDuplicate(db,
            amount: amount,
            description: 'Pagamento da ROSSI MARIO',
            date: date ?? day,
            incomeIntoAccountId: into);

    test('an income into the transfer\'s destination is flagged whatever it '
        'is called', () async {
      await transfer();

      final m = await topUp();

      expect(m?.transactionId, 'tr0');
      expect(m?.score, greaterThanOrEqualTo(duplicateThreshold));
    });

    test('without the wallet context nothing changes', () async {
      await transfer();

      expect(await topUp(into: null), isNull);
    });

    test('an expense of the same amount near the transfer is not flagged',
        () async {
      await transfer();

      // Same amount, negative, no income wallet: an ordinary purchase.
      final m = await findDuplicate(db,
          amount: -100,
          description: 'Pagamento presso Conad',
          date: day,
          incomeIntoAccountId: null);

      expect(m, isNull);
    });

    test('an income into another wallet is not flagged', () async {
      await transfer(to: 'rev');

      expect(await topUp(into: 'paypal'), isNull);
    });

    test('another amount is not flagged', () async {
      await transfer(amount: 100);

      expect(await topUp(amount: 99.5), isNull);
    });

    test('four days apart is outside the window', () async {
      await transfer(date: day.subtract(const Duration(days: 4)));

      expect(await topUp(), isNull);
    });

    test('three days apart is inside it', () async {
      await transfer(date: day.subtract(const Duration(days: 3)));

      expect((await topUp())?.transactionId, 'tr0');
    });

    test('a deleted transfer is no twin', () async {
      await transfer(deleted: true);

      expect(await topUp(), isNull);
    });

    test('a same-amount expense (not a transfer) still needs its usual score',
        () async {
      await db.into(db.transactions).insert(TransactionsCompanion.insert(
          id: 'exp',
          accountId: const Value('rev'),
          amount: 100,
          description: 'Stipendio',
          category: 'Salary',
          type: const Value('income'),
          date: day.subtract(const Duration(days: 2))));

      // An ordinary income two days earlier with an unrelated name: today's
      // scoring (0.3), not the transfer floor.
      expect(await topUp(), isNull);
    });
  });

  group('guessCategory', () {
    String? guess(String description, {String type = 'expense'}) =>
        guessCategory(ParsedBankDraft(
          amount: type == 'income' ? 10 : -10,
          description: description,
          date: DateTime(2026, 8, 20),
          type: type,
          counterparty: null,
          rawSnippet: description,
        ));

    test('a cash withdrawal is never a tram ticket', () {
      // "atm" is a Transport keyword (the Milan transit company).
      expect(guess('Prelievo ATM Intesa'), isNull);
      expect(guess('Prelievo Bancomat'), isNull);
    });

    test('short keywords are whole words, not substrings', () {
      expect(guess('Genius'), isNull); // eni
      expect(guess('Timberland'), isNull); // tim
      expect(guess('Intimissimi'), isNull); // tim
      expect(guess('Espresso House'), isNull); // esso
      expect(guess('Cooperativa Sociale'), isNull); // coop
      expect(guess('Barilla'), isNull); // bar
    });

    test('a short keyword still matches as a word', () {
      expect(guess('Conad'), 'Groceries');
      expect(guess('PAGAMENTO POS COOP LOMBARDIA'), 'Groceries');
      expect(guess('ENI STATION 1234'), 'Transport');
      expect(guess('TIM SPA'), 'Bills');
      expect(guess('Bar Sport'), 'Dining');
    });

    test('long stems still match as a word prefix', () {
      expect(guess('Pizzeria Da Mario'), 'Dining');
      expect(guess('SUPERMERCATI ROSSI'), 'Groceries');
      expect(guess('Carburanti Vega'), 'Transport');
      expect(guess('Pineapple Studio'), isNull); // apple, mid-word
    });

    test('a Bancomat Pay purchase is a purchase, only cash is not', () {
      // "bancomat" alone means the ATM circuit; "Bancomat Pay" is a merchant
      // payment whose text ends with the shop.
      expect(
        guess('Bancomat Pay - A1000000000 Pagamento Effettuato Con Bancomat '
            'Pay Vs Amazon'),
        'Shopping',
      );
      expect(guess('Prelievo Bancomat'), isNull);
      expect(guess('Bancomat ATM Milano'), isNull);
    });

    test('a short keyword may be followed by digits (station codes)', () {
      expect(guess('ENI80018 Cesena'), 'Transport');
      expect(guess('Eni Station'), 'Transport');
      expect(guess('Genius2000'), isNull);
    });

    test('"bar" may end a word but never start one', () {
      expect(guess('Sportbar Gargazon'), 'Dining');
      expect(guess('Bar Sport'), 'Dining');
      expect(guess('Barilla'), isNull);
      expect(guess('Barcelona Viaggi'), isNull);
    });

    test('glued merchant names the stems missed', () {
      expect(guess('OCONAD Cesena'), 'Groceries');
      expect(guess('Enimoov Ricarica'), 'Transport');
    });

    test('words that merely contain a keyword stay unguessed', () {
      expect(guess('LA SERENISSIMA'), isNull); // eni
      expect(guess('Mafaldina'), isNull); // aldi
      expect(guess('Accessori Moda'), isNull); // esso
      expect(guess('Gelato a Firenze'), isNull); // iren
      expect(guess('Acqua Firenze'), isNull); // iren
      expect(guess('Zenith'), isNull); // eni
    });

    test('income keeps its own table', () {
      expect(guess('Stipendio agosto', type: 'income'), 'Salary');
    });
  });

  // B1: the suggestion at capture comes from what the owner actually filed under
  // the same merchant, newest first. Rule and threshold were measured by
  // replaying the real ledger (see the commit that introduced it).
  group('learnedCategory', () {
    late AppDatabase db;
    setUp(() => db = AppDatabase.forExecutor(NativeDatabase.memory()));
    tearDown(() => db.close());

    Future<void> category(String name, {bool deleted = false}) =>
        db.into(db.categories).insert(CategoriesCompanion.insert(
              id: 'cat_$name',
              name: name,
              iconCode: 0,
              colorHex: 0,
              type: 'expense',
              isDeleted: Value(deleted),
            ));

    var n = 0;
    Future<void> tx(
      String description,
      String category, {
      double amount = -10,
      String type = 'expense',
      int day = 1,
      bool deleted = false,
    }) =>
        db.into(db.transactions).insert(TransactionsCompanion.insert(
              id: 'tx${n++}',
              amount: amount,
              description: description,
              category: category,
              type: Value(type),
              date: DateTime(2026, 1, day),
              isDeleted: Value(deleted),
            ));

    Future<String?> learn(String d, {bool income = false}) =>
        learnedCategory(db, d, income: income);

    test('the merchant is filed where the owner filed it last', () async {
      await category('Groceries');
      await category('Spesa');
      await tx('Conad', 'Groceries', day: 1);
      await tx('CONAD ADRIATICO SPA', 'Spesa', day: 9);

      // Containment either way round scores 0.9: the newest one wins.
      expect(await learn('Conad'), 'Spesa');
      expect(await learn('PAGAMENTO POS CONAD'), 'Spesa');
    });

    test('a merchant the ledger never saw learns nothing', () async {
      await category('Spesa');
      await tx('Conad', 'Spesa');

      expect(await learn('Lidl'), isNull);
    });

    test('a newest match filed under a dead category is null, not skipped past',
        () async {
      await category('Spesa');
      await category('Pranzo', deleted: true);
      await tx('Conad', 'Spesa', day: 1);
      await tx('Pranzo conad', 'Pranzo', day: 9); // one-off, category since removed

      // Measured on the real ledger: skipping to the older live match made 52
      // wrong suggestions (CONAD hijacked by a one-off "Pranzo conad").
      expect(await learn('Conad'), isNull);
    });

    test('Uncategorized and Transfer are not categories to suggest', () async {
      await tx('Conad', 'Uncategorized');
      expect(await learn('Conad'), isNull);
    });

    test('income and expense never learn from each other', () async {
      await category('Salary');
      await category('Spesa');
      await tx('Acme Srl', 'Salary', amount: 1500, type: 'income');
      await tx('Acme Srl', 'Spesa', amount: -20);

      expect(await learn('Acme Srl', income: true), 'Salary');
      expect(await learn('Acme Srl', income: false), 'Spesa');
    });

    test('a transfer is never learned from, even under a live category name',
        () async {
      await category('Spesa');
      await tx('Ricarica Revolut', 'Spesa', type: 'transfer');

      expect(await learn('Ricarica Revolut'), isNull);
    });

    test('a deleted transaction teaches nothing', () async {
      await category('Spesa');
      await tx('Conad', 'Spesa', deleted: true);

      expect(await learn('Conad'), isNull);
    });

    test('the generic Revolut fallback description is never learned', () async {
      await category('Spesa');
      await tx(revolutFallbackDescription, 'Spesa');

      expect(await learn(revolutFallbackDescription), isNull);
      // A foreign-currency cue appended to it does not make it a merchant.
      await tx('$revolutFallbackDescription · 4.20 USD', 'Spesa');
      expect(await learn('$revolutFallbackDescription · 9.99 USD'), isNull);
      expect(await learn(''), isNull);
      expect(await learn('   '), isNull);
    });
  });

  // A push with no merchant carries the shared fallback text, so its name says
  // nothing: the match runs on date + amount alone (0.5 for the same day, just
  // over the 0.45 threshold; a day apart 0.4, under it). Deliberate: a false
  // flag costs one "No, è diversa" tap, a missed one silently double-counts.
  group('findDuplicate with the generic Revolut description', () {
    late AppDatabase db;
    var n = 0;
    setUp(() {
      db = AppDatabase.forExecutor(NativeDatabase.memory());
      n = 0;
    });
    tearDown(() => db.close());

    final noon = DateTime(2026, 6, 24, 12);
    Future<void> tx(String description, DateTime date,
            {double amount = -12.26}) =>
        db.into(db.transactions).insert(TransactionsCompanion.insert(
              id: 'tx${n++}',
              amount: amount,
              description: description,
              category: 'Groceries',
              type: const Value('expense'),
              date: date,
            ));

    Future<DuplicateMatch?> find(String description, DateTime date,
            {double amount = -12.26}) =>
        findDuplicate(db, amount: amount, description: description, date: date);

    test('a merchant-less push is flagged against a same-day same-amount tx',
        () async {
      await tx('Conad', noon);

      final m = await find(revolutFallbackDescription, noon);

      expect(m?.transactionId, 'tx0');
      expect(m?.score, 0.5); // date only: the names share nothing
    });

    test('a day apart the same push is not flagged', () async {
      await tx('Conad', noon.subtract(const Duration(days: 1)));

      expect(await find(revolutFallbackDescription, noon), isNull);
    });

    test('a different amount is never a twin, whatever the day', () async {
      await tx('Conad', noon, amount: -5);

      expect(await find(revolutFallbackDescription, noon), isNull);
    });

    test('the statement row with the real merchant still catches a booked '
        'merchant-less push', () async {
      await tx(revolutFallbackDescription, noon); // approved from the push

      final m = await find('Conad', noon); // the CSV row, later

      expect(m?.transactionId, 'tx0');
    });

    test('two different merchant-less pushes of the same amount and day: the '
        'second is flagged once the first is booked (one tap to dismiss)',
        () async {
      await tx(revolutFallbackDescription, noon);

      expect(await find(revolutFallbackDescription, noon), isNotNull);
    });
  });
}
