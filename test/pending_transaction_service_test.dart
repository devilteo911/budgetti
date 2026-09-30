import 'dart:ffi';

import 'package:budgetti/core/database/database.dart';
import 'package:budgetti/core/services/bank_sync_service.dart'
    show duplicateThreshold;
import 'package:budgetti/core/services/finance_service.dart';
import 'package:budgetti/core/services/pending_transaction_service.dart';
import 'package:budgetti/core/services/persistence_service.dart';
import 'package:budgetti/models/transaction.dart' as model;
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart' show NativeDatabase;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/open.dart' as sqlite3open;

// `flutter test` runs in the VM without sqlite3_flutter_libs' bundled native,
// so point the FFI loader at the system library (.so.0 — no -dev symlink here).
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

final _day = DateTime(2026, 6, 24, 19, 3);

Future<void> _insertDraft(
  AppDatabase db, {
  String id = 'pending_x',
  double amount = -10,
  String description = 'Coffee',
  String type = 'expense',
  String status = 'pending',
  String source = 'widiba',
  String? suggestedCategory,
  String rawSnippet = '',
  String? duplicateOfId,
  double? duplicateScore,
}) =>
    db.into(db.pendingTransactions).insert(
          PendingTransactionsCompanion.insert(
            id: id,
            gmailMessageId: id,
            emailSubject: 'subject',
            emailReceivedAt: _day,
            parsedAmount: amount,
            parsedDescription: description,
            parsedDate: _day,
            createdAt: _day,
            suggestedType: Value(type),
            status: Value(status),
            source: Value(source),
            suggestedCategory: Value(suggestedCategory),
            rawSnippet: Value(rawSnippet),
            duplicateOfId: Value(duplicateOfId),
            duplicateScore: Value(duplicateScore),
          ),
        );

Future<PendingTransaction> _draft(AppDatabase db, [String id = 'pending_x']) =>
    (db.select(db.pendingTransactions)..where((t) => t.id.equals(id)))
        .getSingle();

Future<void> _insertTx(
  AppDatabase db, {
  String id = 'tx-existing',
  double amount = -10,
  String description = 'Coffee',
  String category = 'Dining',
  String type = 'expense',
  String? toAccountId,
  DateTime? date,
  bool isDeleted = false,
}) =>
    db.into(db.transactions).insert(
          TransactionsCompanion.insert(
            id: id,
            userId: const Value('user-a'),
            accountId: const Value('wallet'),
            toAccountId: Value(toAccountId),
            amount: amount,
            description: description,
            category: category,
            type: Value(type),
            date: date ?? _day,
            isDeleted: Value(isDeleted),
          ),
        );

Future<void> _insertCategory(AppDatabase db, String name,
        {bool deleted = false}) =>
    db.into(db.categories).insert(CategoriesCompanion.insert(
          id: 'cat_$name',
          userId: const Value('user-a'),
          name: name,
          iconCode: 0,
          colorHex: 0,
          type: 'expense',
          isDeleted: Value(deleted),
        ));

(AppDatabase, PendingTransactionService) _setup() {
  final db = AppDatabase.forExecutor(NativeDatabase.memory());
  addTearDown(db.close);
  return (db, PendingTransactionService(db, FinanceService(db, 'user-a')));
}

Future<void> _insertAccount(AppDatabase db, String id, String name,
        {bool deleted = false}) =>
    db.into(db.accounts).insert(AccountsCompanion.insert(
          id: id,
          userId: const Value('user-a'),
          name: name,
          isDeleted: Value(deleted),
        ));

/// Same as [_setup] plus the prefs the wallet memory lives in.
Future<(AppDatabase, PendingTransactionService, PersistenceService)>
    _setupWithPrefs() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = PersistenceService(await SharedPreferences.getInstance());
  final db = AppDatabase.forExecutor(NativeDatabase.memory());
  addTearDown(db.close);
  return (
    db,
    PendingTransactionService(db, FinanceService(db, 'user-a'), prefs),
    prefs,
  );
}

model.Transaction _edited({
  String accountId = 'wallet',
  String? toAccountId,
  double amount = -12.5,
  String description = 'Edited by hand',
  String type = 'expense',
}) =>
    model.Transaction(
      id: 'edited-tx',
      accountId: accountId,
      toAccountId: toAccountId,
      amount: amount,
      date: _day,
      description: description,
      category: 'Treats',
      type: type,
    );

void main() {
  setUpAll(_ensureSqlite);

  // The double-booking bug: approve() wrote the transaction and the status
  // as two unguarded writes, so a double-tap (or a crash retried later)
  // booked the same draft twice.
  test('approving the same draft twice books exactly one transaction', () async {
    final db = AppDatabase.forExecutor(NativeDatabase.memory());
    addTearDown(db.close);
    final service =
        PendingTransactionService(db, FinanceService(db, 'user-a'));

    await db.into(db.pendingTransactions).insert(
          PendingTransactionsCompanion.insert(
            id: 'pending_x',
            gmailMessageId: 'x',
            emailSubject: 'Hai pagato 10 €',
            emailReceivedAt: DateTime(2026, 1, 1),
            parsedAmount: -10,
            parsedDescription: 'Coffee',
            parsedDate: DateTime(2026, 1, 1),
            createdAt: DateTime(2026, 1, 1),
            suggestedType: const Value('expense'),
          ),
        );
    final draft = await (db.select(db.pendingTransactions)
          ..where((t) => t.id.equals('pending_x')))
        .getSingle();

    await service.approve(draft, type: 'expense', accountId: 'wallet');
    await service.approve(draft, type: 'expense', accountId: 'wallet');

    expect(await db.select(db.transactions).get(), hasLength(1));
    final status = await (db.select(db.pendingTransactions)
          ..where((t) => t.id.equals('pending_x')))
        .getSingle();
    expect(status.status, 'approved');
  });

  // B4: a capture-time check goes stale — the owner can log the same purchase
  // by hand (or another device can sync it in) between capture and approval.
  group('duplicate recheck at approval', () {
    test('a twin logged after capture is caught: nothing booked, draft flagged',
        () async {
      final (db, service) = _setup();
      await _insertDraft(db); // captured with no twin around
      await _insertTx(db); // ...then the owner logged it by hand

      final tx = await service.approve(await _draft(db),
          type: 'expense', accountId: 'wallet');

      expect(tx, isNull);
      expect(await db.select(db.transactions).get(), hasLength(1)); // untouched
      final d = await _draft(db);
      expect(d.status, 'pending'); // still in the inbox, now with the notice
      expect(d.duplicateOfId, 'tx-existing');
      expect(d.duplicateScore, greaterThan(duplicateThreshold));
    });

    test('a deleted twin does not count', () async {
      final (db, service) = _setup();
      await _insertDraft(db);
      await _insertTx(db, isDeleted: true);

      final tx = await service.approve(await _draft(db),
          type: 'expense', accountId: 'wallet');

      expect(tx, isNotNull);
    });

    test('a dismissed warning is not raised again', () async {
      final (db, service) = _setup();
      await _insertDraft(db, duplicateOfId: 'tx-existing', duplicateScore: 0.9);
      await _insertTx(db);
      await service.clearDuplicateFlag('pending_x'); // "No, è diversa"

      final d = await _draft(db);
      expect(d.duplicateDismissed, isTrue);
      expect(d.duplicateOfId, isNull);

      final tx = await service.approve(d, type: 'expense', accountId: 'wallet');

      expect(tx, isNotNull);
      expect(await db.select(db.transactions).get(), hasLength(2));
    });

    test('an unflagged draft with no twin books, under its real id', () async {
      final (db, service) = _setup();
      await _insertDraft(db);
      await _insertTx(db, amount: -99); // other amount: not a twin

      final tx = await service.approve(await _draft(db),
          type: 'expense', accountId: 'wallet');

      final booked = await (db.select(db.transactions)
            ..where((t) => t.id.equals(tx?.id ?? '')))
          .getSingleOrNull();
      expect(tx?.id, isNotEmpty);
      expect(booked, isNotNull);
      expect(booked!.amount, -10);
      expect((await _draft(db)).status, 'approved');
    });

    test('a draft flagged at capture and approved anyway books as before',
        () async {
      final (db, service) = _setup();
      await _insertTx(db);
      await _insertDraft(db, duplicateOfId: 'tx-existing', duplicateScore: 0.9);

      final tx = await service.approve(await _draft(db),
          type: 'expense', accountId: 'wallet');

      expect(tx, isNotNull);
      expect(await db.select(db.transactions).get(), hasLength(2));
    });

    test('approving twice books once and the second call returns null',
        () async {
      final (db, service) = _setup();
      await _insertDraft(db);
      final draft = await _draft(db);

      final first =
          await service.approve(draft, type: 'expense', accountId: 'wallet');
      final second =
          await service.approve(draft, type: 'expense', accountId: 'wallet');

      expect(first, isNotNull);
      expect(second, isNull); // was a phantom un-booked transaction with id ''
      expect(await db.select(db.transactions).get(), hasLength(1));
    });
  });

  // B1: approve() must never book a category that no longer exists. A draft can
  // hold a name the owner deleted after capture, or none at all.
  group('category at approval', () {
    // Months before the draft, so the duplicate recheck ignores it.
    final old = DateTime(2026, 1, 5);

    Future<String> booked(AppDatabase db, model.Transaction? tx) async =>
        (await (db.select(db.transactions)
                  ..where((t) => t.id.equals(tx?.id ?? '')))
                .getSingle())
            .category;

    test('a draft with no category is filed where the ledger filed it',
        () async {
      final (db, service) = _setup();
      await _insertCategory(db, 'Coffee shops');
      await _insertTx(db, description: 'Coffee', category: 'Coffee shops', date: old);
      await _insertDraft(db);

      final tx = await service.approve(await _draft(db),
          type: 'expense', accountId: 'wallet');

      expect(await booked(db, tx), 'Coffee shops');
    });

    test('a draft holding a deleted category is re-resolved, not booked dead',
        () async {
      final (db, service) = _setup();
      await _insertCategory(db, 'Coffee shops');
      await _insertCategory(db, 'Eating out', deleted: true);
      await _insertTx(db, description: 'Coffee', category: 'Coffee shops', date: old);
      await _insertDraft(db);

      final tx = await service.approve(await _draft(db),
          type: 'expense', accountId: 'wallet', category: 'Eating out');

      expect(await booked(db, tx), 'Coffee shops');
    });

    test('nothing learned and nothing live falls back to Uncategorized',
        () async {
      final (db, service) = _setup();
      await _insertCategory(db, 'Eating out', deleted: true);
      await _insertDraft(db);

      final tx = await service.approve(await _draft(db),
          type: 'expense', accountId: 'wallet', category: 'Eating out');

      expect(await booked(db, tx), 'Uncategorized');
    });

    test('a live category the owner picked is kept over the ledger', () async {
      final (db, service) = _setup();
      await _insertCategory(db, 'Coffee shops');
      await _insertCategory(db, 'Treats');
      await _insertTx(db, description: 'Coffee', category: 'Coffee shops', date: old);
      await _insertDraft(db);

      final tx = await service.approve(await _draft(db),
          type: 'expense', accountId: 'wallet', category: 'Treats');

      expect(await booked(db, tx), 'Treats');
    });

    test('a transfer stays Transfer and never learns', () async {
      final (db, service) = _setup();
      await _insertCategory(db, 'Coffee shops');
      await _insertTx(db, description: 'Coffee', category: 'Coffee shops', date: old);
      await _insertDraft(db);

      final tx = await service.approve(await _draft(db),
          type: 'transfer', accountId: 'wallet', toAccountId: 'other');

      expect(await booked(db, tx), 'Transfer');
    });

    test('the inbox chip can set the category the approval will use', () async {
      final (db, service) = _setup();
      await _insertDraft(db);

      await service.setSuggestedCategory('pending_x', 'Treats');

      expect((await _draft(db)).suggestedCategory, 'Treats');
    });
  });

  // B2: "modifica e approva" — the owner finishes a draft by hand (or a raw
  // unrecognised message) and the result is booked in one step.
  group('approveWith (edit and approve)', () {
    test('books the edited transaction and marks the draft approved', () async {
      final (db, service) = _setup();
      await _insertDraft(db);

      final ok = await service.approveWith('pending_x', _edited());

      expect(ok, isTrue);
      final booked = await db.select(db.transactions).getSingle();
      expect(booked.id, 'edited-tx');
      expect(booked.description, 'Edited by hand');
      expect(booked.amount, -12.5);
      expect((await _draft(db)).status, 'approved');
    });

    test('twice books one transaction, the second call reports false', () async {
      final (db, service) = _setup();
      await _insertDraft(db);

      final first = await service.approveWith('pending_x', _edited());
      final second = await service.approveWith('pending_x', _edited());

      expect([first, second], [true, false]);
      expect(await db.select(db.transactions).get(), hasLength(1));
    });

    test('an unrecognised message (skipped) can be finished by hand', () async {
      final (db, service) = _setup();
      await _insertDraft(db, status: 'skipped', amount: 0, type: 'undecided');

      expect(await service.approveWith('pending_x', _edited()), isTrue);

      // Approved, so a later sync pass stops retrying the raw message.
      expect((await _draft(db)).status, 'approved');
      expect(await db.select(db.transactions).get(), hasLength(1));
    });

    test('a rejected or already approved draft is not booked', () async {
      final (db, service) = _setup();
      await _insertDraft(db, id: 'rej', status: 'rejected');
      await _insertDraft(db, id: 'app', status: 'approved');
      await _insertDraft(db, id: 'ign', status: 'ignored');

      expect(await service.approveWith('rej', _edited()), isFalse);
      expect(await service.approveWith('app', _edited()), isFalse);
      expect(await service.approveWith('ign', _edited()), isFalse);
      expect(await db.select(db.transactions).get(), isEmpty);
    });

    // The sheet blocks this itself, but the booking core is the last line: a
    // transfer that moves nothing (or loses money) must not reach the ledger
    // whichever door it comes through.
    test('a transfer with no destination, or into its own source, is refused',
        () async {
      final (db, service) = _setup();
      await _insertDraft(db);

      for (final to in [null, 'wallet']) {
        await expectLater(
          service.approveWith('pending_x',
              _edited(type: 'transfer', toAccountId: to, amount: 30)),
          throwsArgumentError,
          reason: 'toAccountId: $to',
        );
      }
      expect(await db.select(db.transactions).get(), isEmpty);
      expect((await _draft(db)).status, 'pending'); // still there to fix

      // A real destination books.
      expect(
        await service.approveWith('pending_x',
            _edited(type: 'transfer', toAccountId: 'other', amount: 30)),
        isTrue,
      );
    });

    test('an explicit choice is not second-guessed by the duplicate recheck',
        () async {
      final (db, service) = _setup();
      await _insertDraft(db);
      await _insertTx(db); // a twin: approve() would stop here

      expect(await service.approveWith('pending_x', _edited()), isTrue);
      expect(await db.select(db.transactions).get(), hasLength(2));
    });
  });

  group('draftPrefill', () {
    Future<PendingTransaction> draft(AppDatabase db, {String id = 'pending_x'}) =>
        _draft(db, id);

    test('an expense draft opens as a negative expense with its own fields',
        () async {
      final (db, _) = _setup();
      await _insertDraft(db, suggestedCategory: 'Dining');

      final t = draftPrefill(await draft(db), accountId: 'w1');

      expect(
          (t.type, t.amount, t.description, t.date, t.accountId, t.category),
          ('expense', -10.0, 'Coffee', _day, 'w1', 'Dining'));
    });

    test('an income draft opens positive', () async {
      final (db, _) = _setup();
      await _insertDraft(db, type: 'income', amount: 42.5);

      final t = draftPrefill(await draft(db));

      expect((t.type, t.amount), ('income', 42.5));
    });

    test('an undecided draft (Widiba SEPA out) opens as an expense', () async {
      final (db, _) = _setup();
      await _insertDraft(db, type: 'undecided', amount: -80);

      final t = draftPrefill(await draft(db));

      expect((t.type, t.amount), ('expense', -80.0));
    });

    test('an unrecognised message opens with an empty amount, its receipt date '
        'and subject', () async {
      final (db, _) = _setup();
      await _insertDraft(db,
          status: 'skipped', amount: 0, type: 'undecided', description: 'Weird');
      final row = await draft(db);

      final t = draftPrefill(row);

      expect(t.amount, 0); // the sheet renders 0 as an empty field
      expect(t.date, row.emailReceivedAt);
      expect(t.description, 'Weird');
    });

    // A skipped Revolut push carries only its TITLE ("Revolut") as description,
    // which tells the owner nothing: the body is what they need to finish it.
    group('an unreadable Revolut push', () {
      Future<String> descriptionOf(String snippet,
          {String title = 'Revolut', String source = 'revolut'}) async {
        final (db, _) = _setup();
        await _insertDraft(db,
            status: 'skipped',
            amount: 0,
            type: 'undecided',
            description: title,
            source: source,
            rawSnippet: snippet);
        return draftPrefill(await draft(db)).description;
      }

      test('opens with its body as the description', () async {
        expect(
          await descriptionOf('Revolut ⟂ Pagamento in elaborazione presso un '
              'nuovo esercente'),
          'Pagamento in elaborazione presso un nuovo esercente',
        );
      });

      test('a long body is cut, on one line', () async {
        final d = await descriptionOf('Revolut ⟂ ${'parola ' * 30}\nfine');

        expect(d.length, lessThanOrEqualTo(61)); // 60 + the ellipsis
        expect(d, endsWith('…'));
        expect(d, isNot(contains('\n')));
      });

      test('with no body it is the title', () async {
        expect(await descriptionOf('Revolut'), 'Revolut');
      });

      test('a push with no title (the text alone) opens with the text',
          () async {
        expect(
          await descriptionOf('Pagamento in elaborazione',
              title: 'Notifica Revolut'),
          'Pagamento in elaborazione',
        );
      });

      test('a Widiba email keeps its subject: its snippet is the greeting',
          () async {
        expect(
          await descriptionOf('Ciao Matteo, il giorno 04/06 hai',
              title: 'Disposizione', source: 'widiba'),
          'Disposizione',
        );
      });

      test('a draft that parsed keeps its description', () async {
        final (db, _) = _setup();
        await _insertDraft(db,
            source: 'revolut', description: 'Lo Chef', rawSnippet: 'Revolut ⟂ Hai speso');

        expect(draftPrefill(await draft(db)).description, 'Lo Chef');
      });
    });

    test('a foreign-currency draft opens with an empty amount, keeping its cue',
        () async {
      final (db, _) = _setup();
      await _insertDraft(db, description: 'Starbucks · 12,50 USD', amount: -12.5);

      final t = draftPrefill(await draft(db));

      expect(t.amount, 0); // the stored figure is dollars read as euros
      expect(t.description, 'Starbucks · 12,50 USD');
      expect(t.type, 'expense');
    });

    test('an unknown wallet or category is empty, for the sheet to default',
        () async {
      final (db, _) = _setup();
      await _insertDraft(db);

      final t = draftPrefill(await draft(db));

      expect((t.accountId, t.category), ('', ''));
    });
  });

  // B2 wallet memory: a source whose wallet can't be deduced from its name is
  // asked once, not on every draft — but only what the owner chose against the
  // deduction is remembered, so one mis-tap can't stick.
  group('source wallet memory', () {
    test('the remembered wallet wins over the name match', () async {
      final (db, service, prefs) = await _setupWithPrefs();
      await _insertAccount(db, 'rev', 'Revolut');
      await _insertAccount(db, 'other', 'Pocket');
      await prefs.setSourceWalletId('revolut', 'other');

      expect(await service.resolveAccountIdForSource('revolut'), 'other');
    });

    test('a remembered wallet that was deleted is ignored', () async {
      final (db, service, prefs) = await _setupWithPrefs();
      await _insertAccount(db, 'rev', 'Revolut');
      await _insertAccount(db, 'gone', 'Old', deleted: true);
      await prefs.setSourceWalletId('revolut', 'gone');

      expect(await service.resolveAccountIdForSource('revolut'), 'rev');
    });

    test('a wallet the owner picked against the deduction is remembered',
        () async {
      final (db, service, prefs) = await _setupWithPrefs();
      await _insertAccount(db, 'rev', 'Revolut');
      await _insertAccount(db, 'other', 'Pocket');
      await _insertDraft(db, source: 'revolut');

      await service.approveWith('pending_x', _edited(accountId: 'other'));

      expect(prefs.getSourceWalletId('revolut'), 'other');
    });

    test('picking the deduced wallet again clears the memory', () async {
      final (db, service, prefs) = await _setupWithPrefs();
      await _insertAccount(db, 'rev', 'Revolut');
      await _insertAccount(db, 'other', 'Pocket');
      await prefs.setSourceWalletId('revolut', 'other');
      await _insertDraft(db, source: 'revolut');

      await service.approveWith('pending_x', _edited(accountId: 'rev'));

      expect(prefs.getSourceWalletId('revolut'), isNull);
      expect(await service.resolveAccountIdForSource('revolut'), 'rev');
    });

    test('the deduced wallet is never written down', () async {
      final (db, service, prefs) = await _setupWithPrefs();
      await _insertAccount(db, 'rev', 'Revolut');
      await _insertDraft(db, source: 'revolut');

      await service.approveWith('pending_x', _edited(accountId: 'rev'));

      expect(prefs.getSourceWalletId('revolut'), isNull);
    });

    test('the plain Approva picker (no wallet matches the source) remembers '
        'its pick', () async {
      final (db, service, prefs) = await _setupWithPrefs();
      await _insertAccount(db, 'other', 'Pocket');
      await _insertDraft(db, source: 'revolut');
      expect(await service.resolveAccountIdForSource('revolut'), isNull);

      await service.approve(await _draft(db),
          type: 'expense', accountId: 'other');

      expect(prefs.getSourceWalletId('revolut'), 'other');
      expect(await service.resolveAccountIdForSource('revolut'), 'other');
    });

    test('a memory of another source is not consulted', () async {
      final (db, service, prefs) = await _setupWithPrefs();
      await _insertAccount(db, 'rev', 'Revolut');
      await _insertAccount(db, 'other', 'Pocket');
      await prefs.setSourceWalletId('widiba', 'other');

      expect(await service.resolveAccountIdForSource('revolut'), 'rev');
    });
  });

  test('a transfer into its own source wallet is refused', () async {
    final (db, service) = _setup();
    await _insertDraft(db, type: 'undecided');

    await expectLater(
      service.approve(await _draft(db),
          type: 'transfer', accountId: 'wallet', toAccountId: 'wallet'),
      throwsArgumentError,
    );
    expect(await db.select(db.transactions).get(), isEmpty);
    expect((await _draft(db)).status, 'pending');
  });

  // Widiba -> Revolut, seen at approval: the top-up draft was captured before the
  // owner booked the transfer, so it carries no flag; the recheck must catch it.
  // (Ceiling: approve the Widiba transfer FIRST — a top-up approved before it
  // flags nothing.)
  group('a top-up against a wallet-to-wallet transfer, at approval', () {
    Future<(AppDatabase, PendingTransactionService)> setup() async {
      final (db, service) = _setup();
      await _insertAccount(db, 'wid', 'Widiba');
      await _insertAccount(db, 'rev', 'Revolut');
      await _insertAccount(db, 'other', 'Pocket');
      return (db, service);
    }

    Future<void> transferTwoDaysBefore(AppDatabase db, {double amount = 100}) =>
        _insertTx(db,
            id: 'tr',
            amount: amount,
            description: 'Giroconto verso conto secondario',
            category: 'Transfer',
            type: 'transfer',
            toAccountId: 'rev',
            date: _day.subtract(const Duration(days: 2)));

    test('an income into the destination wallet is stopped and flagged',
        () async {
      final (db, service) = await setup();
      await _insertDraft(db,
          source: 'revolut',
          type: 'income',
          amount: 100,
          description: 'Pagamento da ROSSI MARIO'); // captured with no twin around
      await transferTwoDaysBefore(db); // booked afterwards

      final tx = await service.approve(await _draft(db),
          type: 'income', accountId: 'rev');

      expect(tx, isNull);
      expect(await db.select(db.transactions).get(), hasLength(1));
      final d = await _draft(db);
      expect(d.status, 'pending');
      expect(d.duplicateOfId, 'tr');
      expect(d.duplicateScore, greaterThanOrEqualTo(duplicateThreshold));
    });

    test('"Sì, è la stessa" rejects it and books nothing', () async {
      final (db, service) = await setup();
      await _insertDraft(db,
          source: 'revolut', type: 'income', amount: 100, description: 'Ricarica');
      await transferTwoDaysBefore(db);
      await service.approve(await _draft(db), type: 'income', accountId: 'rev');

      await service.reject('pending_x'); // what the compare sheet's button does

      expect((await _draft(db)).status, 'rejected');
      expect(await db.select(db.transactions).get(), hasLength(1));
    });

    test('an income into another wallet books', () async {
      final (db, service) = await setup();
      await _insertDraft(db,
          source: 'revolut', type: 'income', amount: 100, description: 'Ricarica');
      await transferTwoDaysBefore(db);

      final tx = await service.approve(await _draft(db),
          type: 'income', accountId: 'other');

      expect(tx, isNotNull);
    });

    test('an expense of the same amount books', () async {
      final (db, service) = await setup();
      await _insertDraft(db,
          source: 'revolut', type: 'expense', amount: -100, description: 'Conad');
      await transferTwoDaysBefore(db);

      final tx = await service.approve(await _draft(db),
          type: 'expense', accountId: 'rev');

      expect(tx, isNotNull);
    });

    test('a transfer of another amount does not stop it', () async {
      final (db, service) = await setup();
      await _insertDraft(db,
          source: 'revolut', type: 'income', amount: 100, description: 'Ricarica');
      await transferTwoDaysBefore(db, amount: 250);

      final tx = await service.approve(await _draft(db),
          type: 'income', accountId: 'rev');

      expect(tx, isNotNull);
    });
  });

  test('the compare sheet never resolves to a deleted transaction', () async {
    final (db, service) = _setup();
    await _insertTx(db, isDeleted: true);

    expect(await service.getTransactionById('tx-existing'), isNull);
  });
}
