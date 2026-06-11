import 'package:budgetti/core/database/database.dart';
import 'package:budgetti/core/services/gmail_service.dart';
import 'package:budgetti/core/services/widiba_email_parser.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

/// Fetches Widiba emails, parses them into transaction drafts, de-duplicates
/// against already-seen Gmail message ids, and stores fresh drafts in
/// [PendingTransactions] for the user to review. Account mapping and the final
/// [Transactions] insert happen at approval time, not here.
class EmailSyncService {
  final AppDatabase _db;
  final GmailService _gmail;
  final WidibaEmailParser _parser;
  final String _userId;

  EmailSyncService(
    this._db,
    this._gmail,
    this._userId, {
    WidibaEmailParser parser = const WidibaEmailParser(),
  }) : _parser = parser;

  /// Runs one sync pass. Returns the newly created drafts (empty if none).
  Future<List<PendingTransaction>> sync({int days = 7, DateTime? after}) async {
    final existingIds = await _existingGmailIds();

    final emails = await _gmail.fetchRecent(
      days: days,
      after: after,
      excludeIds: existingIds,
    );

    final insertedIds = <String>[];
    for (final email in emails) {
      if (existingIds.contains(email.id)) continue;

      final parsed = _parser.parse(
        subject: email.subject,
        body: email.body,
        receivedAt: email.receivedAt,
      );
      if (parsed == null) {
        debugPrint('EmailSync: skipped unparsable "${email.subject}"');
        continue;
      }

      await _db.into(_db.pendingTransactions).insert(
            PendingTransactionsCompanion.insert(
              id: 'pending_${email.id}',
              userId: Value(_userId),
              gmailMessageId: email.id,
              emailSubject: email.subject,
              emailReceivedAt: email.receivedAt,
              parsedAmount: parsed.amount,
              parsedDescription: parsed.description,
              parsedDate: parsed.date,
              suggestedType: Value(parsed.type),
              suggestedCategory: Value(guessCategory(parsed)),
              counterparty: Value(parsed.counterparty),
              rawSnippet: Value(parsed.rawSnippet),
              createdAt: DateTime.now(),
            ),
            mode: InsertMode.insertOrIgnore,
          );

      existingIds.add(email.id);
      insertedIds.add('pending_${email.id}');
    }

    if (insertedIds.isEmpty) return const [];
    return (_db.select(_db.pendingTransactions)
          ..where((t) => t.id.isIn(insertedIds))
          ..orderBy([(t) => OrderingTerm.desc(t.emailReceivedAt)]))
        .get();
  }

  Future<Set<String>> _existingGmailIds() async {
    final col = _db.pendingTransactions.gmailMessageId;
    final rows = await (_db.selectOnly(_db.pendingTransactions)
          ..addColumns([col]))
        .get();
    return rows.map((r) => r.read(col)!).toSet();
  }
}

/// Best-effort category guess from the merchant/counterparty text. Returns null
/// when nothing matches, so the review UI can fall back to "uncategorised".
/// Italian merchant keywords mapped to the app's (English) category names.
String? guessCategory(ParsedWidibaEmail parsed) {
  final text = '${parsed.description} ${parsed.counterparty ?? ''}'.toLowerCase();

  final table = parsed.type == 'income' ? _incomeKeywords : _expenseKeywords;
  for (final entry in table) {
    for (final kw in entry.keywords) {
      if (text.contains(kw)) return entry.category;
    }
  }
  return null;
}

class _CategoryRule {
  final String category;
  final List<String> keywords;
  const _CategoryRule(this.category, this.keywords);
}

const _expenseKeywords = <_CategoryRule>[
  _CategoryRule('Groceries', [
    'esselunga', 'conad', 'lidl', 'coop', 'carrefour', 'eurospin', 'pam',
    'penny', 'despar', 'supermerc', 'aldi', 'bennet', 'famila',
  ]),
  _CategoryRule('Dining', [
    'ristorante', 'pizzer', 'trattoria', 'osteria', 'lo chef', 'bar ',
    'caffe', 'mcdonald', 'burger', 'sushi', 'kebab', 'deliveroo', 'glovo',
    'just eat', 'gelater', 'pasticc',
  ]),
  _CategoryRule('Transport', [
    'trenitalia', 'italo', 'atm', 'gtt', 'autostrad', 'telepass', 'eni',
    'q8', 'esso', 'tamoil', 'ip ', 'benzin', 'carburant', 'uber', 'free now',
    'taxi', 'parcheg', 'parking', 'flixbus',
  ]),
  _CategoryRule('Shopping', [
    'amazon', 'zalando', 'zara', 'h&m', 'decathlon', 'mediaworld', 'unieuro',
    'ikea', 'leroy', 'apple', 'aliexpress',
  ]),
  _CategoryRule('Entertainment', [
    'netflix', 'spotify', 'disney', 'cinema', 'steam', 'playstation', 'xbox',
    'dazn', 'prime video', 'twitch',
  ]),
  _CategoryRule('Health', [
    'farmacia', 'parafarm', 'medic', 'dentist', 'ospedale', 'analisi',
    'poliambulator', 'fisioterap',
  ]),
  _CategoryRule('Bills', [
    'enel', 'a2a', 'hera', 'iren', 'tim', 'vodafone', 'windtre', 'iliad',
    'fastweb', 'sky', 'affitto', 'condominio', 'inps', 'agenzia entrate',
  ]),
];

const _incomeKeywords = <_CategoryRule>[
  _CategoryRule('Salary', ['stipendio', 'salary', 'retribuz', 'busta paga']),
  _CategoryRule('Freelance', ['fattura', 'compenso', 'parcella', 'onorario']),
  _CategoryRule('Investments', ['dividend', 'cedola', 'interess', 'rendimento']),
];
