import 'dart:convert';

import 'package:budgetti/core/database/database.dart';
import 'package:budgetti/core/services/gmail_service.dart';
import 'package:budgetti/core/services/notification_listener_service.dart';
import 'package:budgetti/core/services/revolut_notification_parser.dart';
import 'package:budgetti/core/services/revolut_statement_parser.dart';
import 'package:budgetti/core/services/widiba_email_parser.dart';
import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

/// Captures bank movements into [PendingTransactions] drafts for the user to
/// review. Two capture paths, one review inbox:
///
///   - [sync] pulls Widiba notification emails over Gmail.
///   - [syncNotifications] drains Revolut's Android push notifications.
///
/// Both de-duplicate against already-seen external ids, flag likely repeats of
/// existing transactions, and surface anything unreadable rather than dropping
/// it. Account mapping and the final [Transactions] insert happen at approval
/// time, not here.
///
/// Note the column names: `gmailMessageId` is the generic external id (a Gmail
/// message id or a notification content hash) and `emailSubject` /
/// `emailReceivedAt` hold the notification title / post time for the Revolut
/// path. They predate the second source; `source` is what tells the rows apart.
class BankSyncService {
  final AppDatabase _db;
  final GmailService _gmail;
  final WidibaEmailParser _parser;
  final RevolutNotificationParser _revolutParser;
  final NotificationListenerService _notifications;
  final String _userId;

  BankSyncService(
    this._db,
    this._gmail,
    this._userId, {
    WidibaEmailParser parser = const WidibaEmailParser(),
    RevolutNotificationParser revolutParser = const RevolutNotificationParser(),
    NotificationListenerService notifications = const NotificationListenerService(),
  })  : _parser = parser,
        _revolutParser = revolutParser,
        _notifications = notifications;

  /// Keyword rules name the app's *default* categories, but the user may have
  /// renamed or deleted them ("Dining" → "Eating out"). Resolve the rule's
  /// name against the live set: exact name first, then the per-user seed id —
  /// `…_cat_Dining` survives a rename, only `name` changes — else null, so
  /// the review falls back to "uncategorised" instead of pre-selecting a
  /// label that no longer exists.
  Future<String?> _liveCategory(String? rule) async {
    if (rule == null) return null;
    final rows = await (_db.select(_db.categories)
          ..where((t) => t.isDeleted.equals(false) & t.userId.equals(_userId)))
        .get();
    for (final r in rows) {
      if (r.name == rule) return rule;
    }
    for (final r in rows) {
      if (r.id.endsWith('_cat_$rule')) return r.name;
    }
    return null;
  }

  /// Runs one sync pass. Returns the newly inserted rows: parsed drafts
  /// (status 'pending') plus surfaced unparsable emails (status 'skipped').
  /// Previously skipped emails are re-fetched and retried every pass, so a
  /// parser fix picks them up without any manual reset.
  Future<List<PendingTransaction>> sync({int days = 7, DateTime? after}) async {
    final skippedIds = await _skippedGmailIds();
    final existingIds = await _existingGmailIds()..removeAll(skippedIds);

    final emails = await _gmail.fetchRecent(
      days: days,
      after: after,
      excludeIds: existingIds,
    );

    final insertedIds = <String>[];
    for (final email in emails) {
      if (existingIds.contains(email.id)) continue;

      // The plain part is sometimes a "view in HTML" stub: retry on the
      // stripped HTML before giving up.
      final parsed = _parser.parse(
            subject: email.subject,
            body: email.body,
            receivedAt: email.receivedAt,
          ) ??
          (email.altBody != null
              ? _parser.parse(
                  subject: email.subject,
                  body: email.altBody!,
                  receivedAt: email.receivedAt,
                )
              : null);

      if (parsed == null) {
        if (skippedIds.contains(email.id)) {
          // Retried and still unreadable: the row is already surfaced.
          existingIds.add(email.id);
          continue;
        }
        debugPrint('EmailSync: skipped unparsable "${email.subject}"');
        final id = await _recordSkipped(email);
        existingIds.add(email.id);
        if (id != null) insertedIds.add(id);
        continue;
      }

      final duplicate = await _findDuplicate(parsed);

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
              suggestedCategory: Value(await _liveCategory(guessCategory(parsed))),
              counterparty: Value(parsed.counterparty),
              rawSnippet: Value(parsed.rawSnippet),
              createdAt: DateTime.now(),
              duplicateOfId: Value(duplicate?.transactionId),
              duplicateScore: Value(duplicate?.score),
            ),
            // Replace, not ignore: a retried skipped row becomes a real draft.
            mode: InsertMode.insertOrReplace,
          );

      existingIds.add(email.id);
      insertedIds.add('pending_${email.id}');
    }

    if (insertedIds.isEmpty) return const [];
    return _rowsById(insertedIds);
  }

  /// Drains the Revolut notification buffer into drafts. Same review inbox,
  /// dedup ledger and duplicate flagging as the email path.
  ///
  /// One difference from [sync]: a drained notification is gone from the buffer
  /// for good, so there is no retry pass. Notifications the parser can't read
  /// are surfaced with their raw text and stay that way — the fix is to teach
  /// the parser the template and re-enter that one by hand.
  Future<List<PendingTransaction>> syncNotifications() async {
    final notifications = await _notifications.pull();
    if (notifications.isEmpty) return const [];

    final existingIds = await _existingGmailIds();
    final insertedIds = <String>[];

    for (final n in notifications) {
      final externalId = _notificationId(n);
      if (existingIds.contains(externalId)) continue;
      existingIds.add(externalId);

      final title = n.title.trim().isEmpty ? 'Notifica Revolut' : n.title.trim();
      final parsed =
          _revolutParser.parse(title: n.title, text: n.text, when: n.when);

      if (parsed == null) {
        final surfaced = _revolutParser.looksTransactional(n.title, n.text);
        final raw = [n.title.trim(), n.text.trim()]
            .where((s) => s.isNotEmpty)
            .join(' ⟂ ');
        await _db.into(_db.pendingTransactions).insert(
              PendingTransactionsCompanion.insert(
                id: 'pending_$externalId',
                userId: Value(_userId),
                gmailMessageId: externalId,
                source: const Value('revolut'),
                emailSubject: title,
                emailReceivedAt: n.when.toLocal(),
                parsedAmount: 0,
                parsedDescription: title,
                parsedDate: n.when.toLocal(),
                suggestedType: const Value('undecided'),
                rawSnippet: Value(raw.length > 240 ? '${raw.substring(0, 240)}…' : raw),
                status: Value(surfaced ? 'skipped' : 'ignored'),
                createdAt: DateTime.now(),
              ),
              mode: InsertMode.insertOrIgnore,
            );
        if (surfaced) insertedIds.add('pending_$externalId');
        if (!surfaced) debugPrint('RevolutSync: ignored "$title"');
        continue;
      }

      final duplicate = await _findDuplicate(parsed);

      await _db.into(_db.pendingTransactions).insert(
            PendingTransactionsCompanion.insert(
              id: 'pending_$externalId',
              userId: Value(_userId),
              gmailMessageId: externalId,
              source: const Value('revolut'),
              emailSubject: title,
              emailReceivedAt: n.when.toLocal(),
              parsedAmount: parsed.amount,
              parsedDescription: parsed.description,
              parsedDate: parsed.date,
              suggestedType: Value(parsed.type),
              suggestedCategory: Value(await _liveCategory(guessCategory(parsed))),
              counterparty: Value(parsed.counterparty),
              rawSnippet: Value(parsed.rawSnippet),
              createdAt: DateTime.now(),
              duplicateOfId: Value(duplicate?.transactionId),
              duplicateScore: Value(duplicate?.score),
            ),
            mode: InsertMode.insertOrIgnore,
          );
      insertedIds.add('pending_$externalId');
    }

    if (insertedIds.isEmpty) return const [];
    return _rowsById(insertedIds);
  }

  /// Turns Revolut's "Estratto conto" CSV into drafts. Same review inbox as the
  /// other two paths, so the user still approves row by row.
  ///
  /// Two dedup layers, because the statement overlaps whatever the notification
  /// listener already caught: an identical row imported before is skipped by its
  /// external id, a movement already sitting in the inbox is skipped by day +
  /// amount, and one already approved into [Transactions] comes through flagged
  /// as a duplicate for the user to reject.
  ///
  /// Both layers count occurrences instead of just testing membership: the same
  /// movement can legitimately repeat inside one day — two top-ups of the same
  /// amount ten minutes apart, the same coffee twice — and a set would keep the
  /// first and silently swallow every repeat.
  Future<RevolutImportResult> importStatement(String csv) async {
    final statement = const RevolutStatementParser().parse(csv);
    final existingIds = await _existingGmailIds();
    final pending = await _pendingKeys();
    final occurrence = <String, int>{};
    final insertedIds = <String>[];
    var duplicates = 0;

    for (final draft in statement.rows) {
      final base = _statementId(draft);
      final nth = occurrence.update(base, (n) => n + 1, ifAbsent: () => 0);
      final externalId = nth == 0 ? base : '$base#$nth';
      if (existingIds.contains(externalId)) {
        duplicates++;
        continue;
      }
      final key = _dayAmountKey(draft.date, draft.amount);
      final alreadyDrafted = pending[key] ?? 0;
      if (alreadyDrafted > 0) {
        pending[key] = alreadyDrafted - 1;
        duplicates++;
        continue;
      }
      existingIds.add(externalId);

      final duplicate = await _findDuplicate(draft);

      await _db.into(_db.pendingTransactions).insert(
            PendingTransactionsCompanion.insert(
              id: 'pending_$externalId',
              userId: Value(_userId),
              gmailMessageId: externalId,
              source: const Value('revolut'),
              emailSubject: draft.description,
              emailReceivedAt: draft.date,
              parsedAmount: draft.amount,
              parsedDescription: draft.description,
              parsedDate: draft.date,
              suggestedType: Value(draft.type),
              suggestedCategory: Value(await _liveCategory(guessCategory(draft))),
              counterparty: Value(draft.counterparty),
              rawSnippet: Value(draft.rawSnippet),
              createdAt: DateTime.now(),
              duplicateOfId: Value(duplicate?.transactionId),
              duplicateScore: Value(duplicate?.score),
            ),
            mode: InsertMode.insertOrIgnore,
          );
      insertedIds.add('pending_$externalId');
    }

    return RevolutImportResult(
      drafts: insertedIds.isEmpty ? const [] : await _rowsById(insertedIds),
      duplicates: duplicates,
      unreadable: statement.skipped.length,
    );
  }

  /// Stable across re-imports of an overlapping statement: the same movement
  /// hashes the same however many times the CSV is exported. Rows that hash
  /// identically (a repeated top-up) get a `#n` suffix from the caller — the
  /// statement lists a whole day at a time, so the n-th repeat stays the n-th.
  String _statementId(ParsedBankDraft draft) {
    final day = DateTime(draft.date.year, draft.date.month, draft.date.day);
    final digest = sha1.convert(utf8.encode(
      '${day.toIso8601String()}|${draft.amount.toStringAsFixed(2)}|${draft.description}',
    ));
    return 'revcsv_${digest.toString().substring(0, 16)}';
  }

  /// Day + amount is all a statement row and a push notification agree on: a
  /// push says "Vega Carburanti", the statement may say something longer.
  String _dayAmountKey(DateTime date, double amount) =>
      '${date.year}-${date.month}-${date.day}|${amount.toStringAsFixed(2)}';

  /// How many drafts already sit in the inbox per day+amount, so an import can
  /// skip exactly that many and let the extra repeats through.
  Future<Map<String, int>> _pendingKeys() async {
    // Source-scoped: this layer skips statement rows the push listener
    // already caught, and those drafts are 'revolut'. A same-day same-amount
    // Widiba draft must not mask a Revolut statement row.
    final rows = await (_db.select(_db.pendingTransactions)
          ..where((t) => t.status.equals('pending') & t.source.equals('revolut')))
        .get();
    final counts = <String, int>{};
    for (final r in rows) {
      final key = _dayAmountKey(r.parsedDate, r.parsedAmount);
      counts[key] = (counts[key] ?? 0) + 1;
    }
    return counts;
  }

  /// Content hash, not the Android notification key: apps reuse notification
  /// ids, so keying on `sbn.key` would make two unrelated spends collide and
  /// silently drop the second one.
  ///
  /// ponytail: this does collapse two byte-identical notifications posted in
  /// the same millisecond — same merchant, same amount, same instant. If real
  /// double-charges start going missing, add the notification key back as a
  /// tiebreaker.
  String _notificationId(RawNotification n) {
    final digest = sha1.convert(utf8.encode(
      '${n.title}|${n.text}|${n.when.millisecondsSinceEpoch}',
    ));
    return 'rev_${digest.toString().substring(0, 16)}';
  }

  Future<List<PendingTransaction>> _rowsById(List<String> ids) {
    return (_db.select(_db.pendingTransactions)
          ..where((t) => t.id.isIn(ids))
          ..orderBy([(t) => OrderingTerm.desc(t.emailReceivedAt)]))
        .get();
  }

  /// Stores an unparsable email so it's never re-fetched. Transaction-looking
  /// ones get status 'skipped' (surfaced in the review inbox); marketing and
  /// receipt-confirmations get 'ignored' (never shown). Returns the row id
  /// when the email was surfaced.
  Future<String?> _recordSkipped(WidibaEmail email) async {
    final surfaced = _looksTransactional(email.subject);

    final plain = email.body.replaceAll(RegExp(r'\s+'), ' ').trim();
    final alt = email.altBody?.replaceAll(RegExp(r'\s+'), ' ').trim();
    var snippet = plain.length > 240 ? '${plain.substring(0, 240)}…' : plain;
    if (alt != null && alt.isNotEmpty) {
      snippet +=
          ' ⟂ ${alt.length > 240 ? '${alt.substring(0, 240)}…' : alt}';
    }

    final id = 'pending_${email.id}';
    await _db.into(_db.pendingTransactions).insert(
          PendingTransactionsCompanion.insert(
            id: id,
            userId: Value(_userId),
            gmailMessageId: email.id,
            emailSubject: email.subject,
            emailReceivedAt: email.receivedAt,
            parsedAmount: 0,
            parsedDescription: email.subject,
            parsedDate: email.receivedAt,
            suggestedType: const Value('undecided'),
            rawSnippet: Value(snippet),
            status: Value(surfaced ? 'skipped' : 'ignored'),
            createdAt: DateTime.now(),
          ),
          mode: InsertMode.insertOrIgnore,
        );
    return surfaced ? id : null;
  }

  bool _looksTransactional(String subject) {
    final s = subject.toLowerCase();
    if (s.contains('conferma ricezione')) return false;
    const keywords = [
      'pagamento', 'bonifico', 'accredito', 'addebito',
      'carta', 'cbill', 'bollettino', 'prelievo',
    ];
    return keywords.any(s.contains);
  }

  Future<Set<String>> _existingGmailIds() async {
    final col = _db.pendingTransactions.gmailMessageId;
    final rows = await (_db.selectOnly(_db.pendingTransactions)
          ..addColumns([col]))
        .get();
    return rows.map((r) => r.read(col)!).toSet();
  }

  Future<Set<String>> _skippedGmailIds() async {
    final col = _db.pendingTransactions.gmailMessageId;
    final rows = await (_db.selectOnly(_db.pendingTransactions)
          ..addColumns([col])
          ..where(_db.pendingTransactions.status.equals('skipped')))
        .get();
    return rows.map((r) => r.read(col)!).toSet();
  }

  /// Looks for an existing transaction the draft may be repeating: same
  /// amount, within ±3 days, with date proximity and description similarity
  /// combined into a confidence score. Returns the best match above threshold.
  Future<DuplicateMatch?> _findDuplicate(ParsedBankDraft parsed) async {
    final day =
        DateTime(parsed.date.year, parsed.date.month, parsed.date.day);
    final candidates = await (_db.select(_db.transactions)
          ..where((t) =>
              t.isDeleted.equals(false) &
              t.date.isBetweenValues(
                day.subtract(const Duration(days: 3)),
                day.add(const Duration(days: 4)),
              )))
        .get();

    DuplicateMatch? best;
    for (final tx in candidates) {
      if ((tx.amount.abs() - parsed.amount.abs()).abs() > 0.005) continue;
      // Transfers carry no sign convention, everything else must agree.
      if (tx.type != 'transfer' && tx.amount.sign != parsed.amount.sign) {
        continue;
      }

      final score = duplicateConfidence(
        draftDate: parsed.date,
        draftDescription: parsed.description,
        txDate: tx.date,
        txDescription: tx.description,
      );
      if (score < duplicateThreshold) continue;
      if (best == null || score > best.score) {
        best = DuplicateMatch(tx.id, score);
      }
    }
    return best;
  }
}

/// What one statement import produced: the drafts to review, how many rows were
/// already known, and how many table lines the parser couldn't read.
class RevolutImportResult {
  final List<PendingTransaction> drafts;
  final int duplicates;
  final int unreadable;
  const RevolutImportResult({
    required this.drafts,
    required this.duplicates,
    required this.unreadable,
  });
}

class DuplicateMatch {
  final String transactionId;
  final double score;
  const DuplicateMatch(this.transactionId, this.score);
}

const double duplicateThreshold = 0.45;

/// Confidence that two same-amount movements are the same one. Date proximity
/// alone is enough to flag a same-day twin even when the user typed a totally
/// different title ("Spesa" vs "PAGAMENTO POS ESSELUNGA").
double duplicateConfidence({
  required DateTime draftDate,
  required String draftDescription,
  required DateTime txDate,
  required String txDescription,
}) {
  final dayDiff = DateTime(draftDate.year, draftDate.month, draftDate.day)
      .difference(DateTime(txDate.year, txDate.month, txDate.day))
      .inDays
      .abs();
  final dateScore = switch (dayDiff) {
    0 => 1.0,
    1 => 0.8,
    2 => 0.6,
    _ => 0.4,
  };
  return 0.5 * dateScore +
      0.5 * descriptionSimilarity(draftDescription, txDescription);
}

/// Token-overlap similarity (Jaccard) on normalized descriptions, boosted to
/// 0.9 when one side is contained in the other — the manual title is usually
/// just the merchant name buried inside the bank's POS boilerplate.
double descriptionSimilarity(String a, String b) {
  final ta = _tokens(a);
  final tb = _tokens(b);
  if (ta.isEmpty || tb.isEmpty) return 0;

  final jaccard =
      ta.intersection(tb).length / ta.union(tb).length;
  final contained = ta.containsAll(tb) || tb.containsAll(ta);
  return contained && jaccard < 0.9 ? 0.9 : jaccard;
}

// Bank boilerplate and filler words that carry no identity.
const _noiseTokens = <String>{
  'pagamento', 'pos', 'carta', 'addebito', 'accredito', 'bonifico', 'sepa',
  'operazione', 'presso', 'del', 'della', 'dello', 'di', 'da', 'per', 'con',
  'il', 'la', 'le', 'su', 'spa', 'srl', 'sas', 'snc', 'via', 'euro', 'eur',
};

Set<String> _tokens(String s) {
  return s
      .toLowerCase()
      .split(RegExp(r'[^a-zà-ù0-9]+'))
      .where((t) =>
          t.length >= 3 &&
          !_noiseTokens.contains(t) &&
          int.tryParse(t) == null)
      .toSet();
}

/// Best-effort category guess from the merchant/counterparty text. Returns null
/// when nothing matches, so the review UI can fall back to "uncategorised".
/// Italian merchant keywords mapped to the app's (English) category names.
String? guessCategory(ParsedBankDraft parsed) {
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
