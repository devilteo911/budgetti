import 'dart:ffi';

import 'package:budgetti/core/database/database.dart';
import 'package:budgetti/core/providers/providers.dart';
import 'package:budgetti/core/services/finance_service.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart' show NativeDatabase;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/open.dart' as sqlite3open;

// See finance_service_seed_test.dart for why the FFI loader is overridden.
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

/// The ledger's search box: by name (description / category) or by amount, as
/// one SQL predicate shared by the page query and the hero totals.
void main() {
  setUpAll(_ensureSqlite);

  late AppDatabase db;
  late FinanceService service;

  Future<void> insert(
    String id,
    double amount,
    String description, {
    String category = 'Food',
  }) =>
      db.into(db.transactions).insert(TransactionsCompanion.insert(
            id: id,
            userId: const Value('user-a'),
            accountId: const Value('a1'),
            amount: amount,
            description: description,
            category: category,
            date: DateTime(2026, 8, 1),
          ));

  Future<Set<String>> find(String q) async => {
        for (final t in await service.getTransactions(search: q)) t.id,
      };

  setUp(() async {
    db = AppDatabase.forExecutor(NativeDatabase.memory());
    service = FinanceService(db, 'user-a');
    await insert('conad', -34.53, 'CONAD CITY MILANO');
    await insert('pizza', -12.5, "L'Oste da Gino", category: 'Restaurants');
    await insert('salary', 1234.56, 'Stipendio', category: 'Salary');
    await insert('promo', -50, 'Sconto 50% su tutto');
  });
  tearDown(() => db.close());

  test('a blank query matches everything', () async {
    expect(await find(''), hasLength(4));
    expect(await find('   '), hasLength(4));
  });

  test('matches the description or the category, ignoring case', () async {
    expect(await find('conad'), {'conad'});
    expect(await find('RESTAUR'), {'pizza'});
  });

  test('every term has to hit, in any order', () async {
    expect(await find('milano conad'), {'conad'});
    expect(await find('conad roma'), isEmpty);
  });

  test('an amount matches to the cent, in either locale, sign ignored', () async {
    expect(await find('12,5'), {'pizza'});
    expect(await find('12.50'), {'pizza'});
    expect(await find('-34,53'), {'conad'});
    expect(await find('1.234,56'), {'salary'});
    // Whole amounts only: "12" is not 12.50.
    expect(await find('12'), isEmpty);
  });

  test('wildcards and quotes are literal text, not SQL', () async {
    expect(await find('%'), {'promo'});
    expect(await find('_'), isEmpty);
    expect(await find("l'oste"), {'pizza'});
    expect(await find("'; DROP TABLE transactions; --"), isEmpty);
    expect(await find(r'\'), isEmpty);
    expect(await service.getTransactions(), hasLength(4));
  });

  test('the hero totals follow the same search as the list', () async {
    expect(await service.watchTotals(search: 'conad').first, (0.0, 34.53, 1));
    expect(
      await service.watchTotals(search: '1.234,56').first,
      (1234.56, 0.0, 1),
    );
    expect(await service.watchTotals(search: 'nothing').first, (0.0, 0.0, 0));
  });

  test('typing narrows the open list in place; closing restores it', () async {
    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      financeServiceProvider.overrideWithValue(service),
    ]);
    addTearDown(container.dispose);
    // The dev DB filters to the current year by default; widen it.
    container.read(transactionFiltersProvider.notifier).setDateRange(null);

    Future<List<String>> settled(bool Function(List<String> ids) until) async {
      for (var i = 0; i < 300; i++) {
        final s = container.read(paginatedTransactionsProvider);
        final ids = [for (final t in s.transactions) t.id];
        if (!s.isLoading && until(ids)) return ids;
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      fail('list never settled');
    }

    await settled((ids) => ids.length == 4);

    final search = container.read(transactionSearchProvider.notifier);
    search.open();
    search.set('conad');
    expect(await settled((ids) => ids.length == 1), ['conad']);

    search.close();
    await settled((ids) => ids.length == 4);
  });
}
