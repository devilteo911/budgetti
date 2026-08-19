import 'dart:ffi';

import 'package:budgetti/core/database/database.dart';
import 'package:budgetti/core/services/bank_sync_service.dart';
import 'package:budgetti/core/services/gmail_service.dart';
import 'package:budgetti/core/services/google_auth_service.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart' show NativeDatabase;
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/open.dart' as sqlite3open;

// See finance_service_seed_test.dart: `flutter test` runs without
// sqlite3_flutter_libs' bundled native, so point FFI at the system library.
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

const _csv = '''
"Conto personale (EUR)",,,,,,,
Data,Descrizione,Categoria,"Denaro in entrata/uscita",Saldo,"Imposte ritenute","Altre imposte",Costi
"23 giu 2026","Pagamento da ROSSI MARIO",Ricarica,"100,00€","100,00€","0,00€","0,00€","0,00€"
"24 giu 2026",Conad,Esercente,"-12,26€","87,74€","0,00€","0,00€","0,00€"
"25 giu 2026","Vega Carburanti",Esercente,"-5,00€","82,74€","0,00€","0,00€","0,00€"
Totale,,,"82,74€",,"0,00€","0,00€","0,00€"
''';

BankSyncService _service(AppDatabase db) =>
    // importStatement never reaches Gmail; the service just wants one.
    BankSyncService(db, GmailService(GoogleAuthService()), 'user-a');

void main() {
  setUpAll(_ensureSqlite);

  test('imports statement rows as drafts to review', () async {
    final db = AppDatabase.forExecutor(NativeDatabase.memory());
    addTearDown(db.close);

    final r = await _service(db).importStatement(_csv);

    expect(r.drafts, hasLength(3));
    expect(r.duplicates, 0);
    expect(r.unreadable, 0);
    // Nothing reaches the ledger until the user approves.
    expect(await db.select(db.transactions).get(), isEmpty);
    final conad = r.drafts.firstWhere((d) => d.parsedDescription == 'Conad');
    expect(conad.parsedAmount, -12.26);
    expect(conad.suggestedType, 'expense');
    expect(conad.suggestedCategory, 'Groceries'); // guessed from the merchant
    expect(conad.source, 'revolut');
  });

  test('re-importing an overlapping statement adds nothing', () async {
    final db = AppDatabase.forExecutor(NativeDatabase.memory());
    addTearDown(db.close);
    final service = _service(db);

    await service.importStatement(_csv);
    final again = await service.importStatement(_csv);

    expect(again.drafts, isEmpty);
    expect(again.duplicates, 3);
    expect(await db.select(db.pendingTransactions).get(), hasLength(3));
  });

  test('a movement the notification listener already drafted is skipped',
      () async {
    final db = AppDatabase.forExecutor(NativeDatabase.memory());
    addTearDown(db.close);

    // What syncNotifications() would have left behind for the same charge,
    // with the merchant text the push carries rather than the statement's.
    await db.into(db.pendingTransactions).insert(
          PendingTransactionsCompanion.insert(
            id: 'pending_rev_abc',
            userId: const Value('user-a'),
            gmailMessageId: 'rev_abc',
            source: const Value('revolut'),
            emailSubject: 'Revolut',
            emailReceivedAt: DateTime(2026, 6, 24, 19, 3),
            parsedAmount: -12.26,
            parsedDescription: 'CONAD ADRIATICO SPA',
            parsedDate: DateTime(2026, 6, 24, 19, 3),
            createdAt: DateTime(2026, 6, 24, 19, 3),
          ),
        );

    final r = await _service(db).importStatement(_csv);

    expect(r.duplicates, 1);
    // Newest first, the order the review inbox reads them in.
    expect(r.drafts.map((d) => d.parsedDescription),
        ['Vega Carburanti', 'Pagamento da ROSSI MARIO']);
  });

  // Two top-ups of the same amount minutes apart are two real movements, not
  // the statement repeating itself. Same day, same amount, same description —
  // everything the dedup keys on.
  const repeatedCsv = '''
"Conto personale (EUR)",,,,,,,
Data,Descrizione,Categoria,"Denaro in entrata/uscita",Saldo,"Imposte ritenute","Altre imposte",Costi
"23 giu 2026","Pagamento da ROSSI MARIO",Ricarica,"50,00€","50,00€","0,00€","0,00€","0,00€"
"23 giu 2026","Pagamento da ROSSI MARIO",Ricarica,"50,00€","100,00€","0,00€","0,00€","0,00€"
"23 giu 2026","Pagamento da ROSSI MARIO",Ricarica,"50,00€","150,00€","0,00€","0,00€","0,00€"
Totale,,,"150,00€",,"0,00€","0,00€","0,00€"
''';

  test('repeated identical top-ups all become drafts, and stay stable on '
      're-import', () async {
    final db = AppDatabase.forExecutor(NativeDatabase.memory());
    addTearDown(db.close);
    final service = _service(db);

    final r = await service.importStatement(repeatedCsv);
    expect(r.drafts, hasLength(3));
    expect(r.duplicates, 0);

    final again = await service.importStatement(repeatedCsv);
    expect(again.drafts, isEmpty);
    expect(again.duplicates, 3);
    expect(await db.select(db.pendingTransactions).get(), hasLength(3));
  });

  test('a top-up the listener already drafted only masks one of the repeats',
      () async {
    final db = AppDatabase.forExecutor(NativeDatabase.memory());
    addTearDown(db.close);

    await db.into(db.pendingTransactions).insert(
          PendingTransactionsCompanion.insert(
            id: 'pending_rev_top',
            userId: const Value('user-a'),
            gmailMessageId: 'rev_top',
            source: const Value('revolut'),
            emailSubject: 'Revolut',
            emailReceivedAt: DateTime(2026, 6, 23, 10, 0),
            parsedAmount: 50,
            parsedDescription: 'Ricarica',
            parsedDate: DateTime(2026, 6, 23, 10, 0),
            createdAt: DateTime(2026, 6, 23, 10, 0),
          ),
        );

    final r = await _service(db).importStatement(repeatedCsv);

    expect(r.duplicates, 1);
    expect(r.drafts, hasLength(2));
  });

  test('a movement already approved comes through flagged as a duplicate',
      () async {
    final db = AppDatabase.forExecutor(NativeDatabase.memory());
    addTearDown(db.close);

    await db.into(db.transactions).insert(
          TransactionsCompanion.insert(
            id: 'tx-1',
            userId: const Value('user-a'),
            accountId: const Value('acc-1'),
            amount: -12.26,
            description: 'Conad',
            category: 'Groceries',
            type: const Value('expense'),
            date: DateTime(2026, 6, 24, 19, 3),
          ),
        );

    final r = await _service(db).importStatement(_csv);

    final conad = r.drafts.firstWhere((d) => d.parsedDescription == 'Conad');
    expect(conad.duplicateOfId, 'tx-1');
    expect(conad.duplicateScore, greaterThan(duplicateThreshold));
  });
}
