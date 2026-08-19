import 'dart:ffi';

import 'package:budgetti/core/database/database.dart';
import 'package:budgetti/core/services/finance_service.dart';
import 'package:budgetti/models/category.dart' as model;
import 'package:budgetti/models/tag.dart' as model_tag;
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart' show NativeDatabase;
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/open.dart' as sqlite3open;

// See finance_service_seed_test.dart for why the FFI loader is overridden.
void _ensureSqlite() {
  try {
    sqlite3open.open.overrideFor(
      sqlite3open.OperatingSystem.linux,
      () => DynamicLibrary.open('/lib/x86_64-linux-gnu/libsqlite3.so.0'),
    );
  } catch (_) {}
}

void main() {
  setUpAll(_ensureSqlite);

  // The real case this came from: "Transport" renamed to "Megane" in the
  // category list left every historical transaction on "Transport", splitting
  // one logical category into two in every chart. Same for tags ("Family" →
  // "Sciclub") — tags are stored as a JSON array of names per transaction.
  test('renaming a category rewrites transactions, budgets, installments '
      'and pending suggestions carrying the old name', () async {
    final db = AppDatabase.forExecutor(NativeDatabase.memory());
    addTearDown(db.close);
    final service = FinanceService(db, 'user-a');

    await service.addCategory(model.Category(
      id: 'cat-1', userId: 'user-a', name: 'Transport', iconCode: 0, colorHex: 0,
      type: 'expense',
    ));
    await db.into(db.transactions).insert(TransactionsCompanion.insert(
          id: 'tx-1',
          userId: const Value('user-a'),
          amount: -10,
          description: 'Benzina',
          category: 'Transport',
          date: DateTime(2026, 1, 1),
        ));
    // Another user's row with the same name must not be touched.
    await db.into(db.transactions).insert(TransactionsCompanion.insert(
          id: 'tx-other',
          userId: const Value('user-b'),
          amount: -5,
          description: 'Theirs',
          category: 'Transport',
          date: DateTime(2026, 1, 1),
        ));
    await db.into(db.budgets).insert(BudgetsCompanion.insert(
          id: 'b-1',
          userId: const Value('user-a'),
          category: 'Transport',
          limitAmount: 100,
          period: 'monthly',
        ));
    await db.into(db.installments).insert(InstallmentsCompanion.insert(
          id: 'i-1',
          userId: const Value('user-a'),
          description: 'Gomme',
          totalAmount: 400,
          installmentCount: 4,
          startDate: DateTime(2026, 1, 10),
          category: const Value('Transport'),
        ));
    await db.into(db.pendingTransactions).insert(PendingTransactionsCompanion.insert(
          id: 'p-1',
          userId: const Value('user-a'),
          gmailMessageId: 'gm-1',
          emailSubject: 's',
          emailReceivedAt: DateTime(2026, 1, 1),
          parsedAmount: -10,
          parsedDescription: 'Benzina',
          parsedDate: DateTime(2026, 1, 1),
          suggestedCategory: const Value('Transport'),
          createdAt: DateTime(2026, 1, 1),
        ));

    await service.updateCategory(model.Category(
      id: 'cat-1', userId: 'user-a', name: 'Megane', iconCode: 0, colorHex: 0,
      type: 'expense',
    ));

    final tx = await db.select(db.transactions).get();
    expect(tx.firstWhere((t) => t.id == 'tx-1').category, 'Megane');
    expect(tx.firstWhere((t) => t.id == 'tx-other').category, 'Transport');
    final budget = await db.select(db.budgets).getSingle();
    expect(budget.category, 'Megane');
    final inst = await db.select(db.installments).getSingle();
    expect(inst.category, 'Megane');
    final pending = await db.select(db.pendingTransactions).getSingle();
    expect(pending.suggestedCategory, 'Megane');
  });

  test('renaming a tag rewrites only exact matches in the tags array',
      () async {
    final db = AppDatabase.forExecutor(NativeDatabase.memory());
    addTearDown(db.close);
    final service = FinanceService(db, 'user-a');

    await service.addTag(model_tag.Tag(id: 'tag-1', userId: 'user-a', name: 'Family', colorHex: 0));
    await db.into(db.transactions).insert(TransactionsCompanion.insert(
          id: 'tx-1',
          userId: const Value('user-a'),
          amount: -10,
          description: 'Cena',
          category: 'Eating out',
          date: DateTime(2026, 1, 1),
          tags: const Value(['Family', 'Friends']),
        ));
    await db.into(db.transactions).insert(TransactionsCompanion.insert(
          id: 'tx-2',
          userId: const Value('user-a'),
          amount: -10,
          description: 'Famiglia larga',
          category: 'Eating out',
          date: DateTime(2026, 1, 1),
          tags: const Value(['Family reunion']),
        ));

    await service.updateTag(
        model_tag.Tag(id: 'tag-1', userId: 'user-a', name: 'Sciclub', colorHex: 0));

    final tx = await db.select(db.transactions).get();
    expect(tx.firstWhere((t) => t.id == 'tx-1').tags, ['Friends', 'Sciclub']);
    expect(tx.firstWhere((t) => t.id == 'tx-2').tags, ['Family reunion']);
  });

  test('updating a category without renaming it touches no transactions',
      () async {
    final db = AppDatabase.forExecutor(NativeDatabase.memory());
    addTearDown(db.close);
    final service = FinanceService(db, 'user-a');

    await service.addCategory(model.Category(
      id: 'cat-1', userId: 'user-a', name: 'Transport', iconCode: 0, colorHex: 0,
      type: 'expense',
    ));
    final before = DateTime(2026, 1, 1);
    await db.into(db.transactions).insert(TransactionsCompanion.insert(
          id: 'tx-1',
          userId: const Value('user-a'),
          amount: -10,
          description: 'Benzina',
          category: 'Transport',
          date: DateTime(2026, 1, 1),
          lastUpdated: Value(before),
        ));

    await service.updateCategory(model.Category(
      id: 'cat-1', userId: 'user-a', name: 'Transport', iconCode: 123, colorHex: 456,
      type: 'expense',
    ));

    final tx = await db.select(db.transactions).getSingle();
    expect(tx.lastUpdated, before); // unchanged, so sync won't re-push it
  });
}
