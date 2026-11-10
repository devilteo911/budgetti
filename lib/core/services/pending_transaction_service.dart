import 'package:budgetti/core/database/database.dart';
import 'package:budgetti/core/services/bank_draft.dart' show foreignAmountOf;
import 'package:budgetti/core/services/bank_sync_service.dart';
import 'package:budgetti/core/services/finance_service.dart';
import 'package:budgetti/core/services/persistence_service.dart';
import 'package:budgetti/models/account.dart' as wallet;
import 'package:budgetti/models/transaction.dart' as model;
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

/// What approving a draft still needs from the owner, or how it ended.
enum ApprovalStatus {
  /// A foreign-currency draft: its euro amount comes from "edit and approve".
  needsEuroAmount,

  /// An undecided draft: expense or transfer?
  needsKind,

  /// A transfer with no destination wallet yet.
  needsDestination,

  /// The draft's source matches no wallet.
  needsWallet,

  /// A transfer into its own source wallet: refused, it moves nothing.
  movesNothing,

  /// A twin showed up in the ledger since capture: the draft is now flagged.
  duplicate,

  /// Approved or rejected meanwhile (double tap, another screen).
  alreadyHandled,

  /// In the ledger: the only status that carries [Approval.transaction], and
  /// the only one after which the follow-up of a write was started.
  booked,
}

/// The answer of [PendingTransactionService.tryApprove]; [transaction] is what
/// reached the ledger, set only when [status] is [ApprovalStatus.booked].
class Approval {
  const Approval(this.status, [this.transaction]);
  final ApprovalStatus status;
  final model.Transaction? transaction;
}

/// Reads and resolves email-derived transaction drafts ([PendingTransactions]).
/// Approval converts a draft into a real [Transactions] row; the draft is then
/// marked (not deleted) so its Gmail id stays in the de-duplication ledger.
class PendingTransactionService {
  final AppDatabase _db;
  final FinanceService _finance;

  final PersistenceService? _persistence;

  PendingTransactionService(this._db, this._finance, [this._persistence]);

  Future<List<PendingTransaction>> getPending() => _pendingQuery().get();

  /// Live stream of pending drafts — updates as the sync inserts new ones or
  /// the user approves/rejects.
  Stream<List<PendingTransaction>> watchPending() => _pendingQuery().watch();

  /// Transaction-looking emails the parser couldn't read, surfaced so the user
  /// knows the sync skipped something.
  Stream<List<PendingTransaction>> watchSkipped() {
    return (_db.select(_db.pendingTransactions)
          ..where((t) => t.status.equals('skipped'))
          ..orderBy([(t) => OrderingTerm.desc(t.emailReceivedAt)]))
        .watch();
  }

  MultiSelectable<PendingTransaction> _pendingQuery() {
    return _db.select(_db.pendingTransactions)
      ..where((t) => t.status.equals('pending'))
      ..orderBy([(t) => OrderingTerm.desc(t.emailReceivedAt)]);
  }

  /// The wallet a draft's [source] belongs to. The one the owner chose for that
  /// source last time comes first (if it still exists); otherwise the one whose
  /// name (or provider) mentions the bank, e.g. source 'revolut' -> a wallet
  /// called "Revolut". Null when neither, in which case the inbox asks.
  Future<String?> resolveAccountIdForSource(String source) async {
    final accounts = await _finance.getAccounts();
    return sourceWalletId(
      source,
      _wallets(accounts),
      remembered: _persistence?.getSourceWalletId(source),
    );
  }

  Iterable<SourceWallet> _wallets(List<wallet.Account> accounts) => [
        for (final a in accounts)
          (id: a.id, name: a.name, providerName: a.providerName),
      ];

  /// Remembers [accountId] for [source] only when it differs from what the name
  /// match alone would pick, and forgets it when the owner is back on that
  /// pick — so a wallet set by hand for one draft doesn't silently stick.
  Future<void> _rememberWallet(String source, String accountId) async {
    final prefs = _persistence;
    if (prefs == null) return;
    final deduced = sourceWalletId(source, _wallets(await _finance.getAccounts()));
    await prefs.setSourceWalletId(
        source, accountId == deduced ? null : accountId);
  }

  /// Approving [draft] as one decision: books it when nothing is missing, else
  /// says what to ask the owner, to be called again with the answer. [type]
  /// answers [ApprovalStatus.needsKind] (a draft that already knows its type
  /// keeps it), [accountId] answers [ApprovalStatus.needsWallet], [toAccountId]
  /// answers [ApprovalStatus.needsDestination].
  Future<Approval> tryApprove(
    PendingTransaction draft, {
    String? type,
    String? accountId,
    String? toAccountId,
  }) async {
    if (draftForeignAmount(draft) != null) {
      return const Approval(ApprovalStatus.needsEuroAmount);
    }
    if (draft.suggestedType != 'undecided') type = draft.suggestedType;
    if (type == null) return const Approval(ApprovalStatus.needsKind);
    if (type == 'transfer' && toAccountId == null) {
      return const Approval(ApprovalStatus.needsDestination);
    }
    accountId ??= await resolveAccountIdForSource(draft.source);
    if (accountId == null) return const Approval(ApprovalStatus.needsWallet);
    if (type == 'transfer' && toAccountId == accountId) {
      return const Approval(ApprovalStatus.movesNothing);
    }

    final tx = await approve(
      draft,
      type: type,
      accountId: accountId,
      toAccountId: toAccountId,
      category: draft.suggestedCategory,
    );
    if (tx != null) return Approval(ApprovalStatus.booked, tx);
    // Nothing booked: the recheck flagged a twin (the draft is still pending),
    // or someone handled the draft first.
    final pending = await _claim(draft.id, const ['pending']) != null;
    return Approval(
        pending ? ApprovalStatus.duplicate : ApprovalStatus.alreadyHandled);
  }

  /// Converts a draft into a real transaction and marks it approved. Mirrors the
  /// sign and category conventions of the add-transaction modal: expenses are
  /// negative, income/transfer positive, transfers use the "Transfer" category.
  ///
  /// The booking under [tryApprove], which is the door for a screen: here the
  /// answers are taken as given. Throws, booking nothing, for a foreign-currency
  /// draft (its parsed figure is not euros, so [approveWith] is its only door)
  /// and for a transfer that moves nothing (see [_book]).
  ///
  /// Returns the booked transaction, or null when nothing was booked: the draft
  /// was already handled (double-tap, crash retry), or — new — a twin showed up
  /// since capture. A draft that was never flagged or dismissed is re-checked
  /// against the ledger here, because the capture-time check goes stale: the
  /// owner may have logged the same purchase by hand, or another device synced
  /// it in, in the meantime. The new match is written onto the draft (the inbox
  /// re-renders it with the amber notice) and the owner decides.
  Future<model.Transaction?> approve(
    PendingTransaction draft, {
    required String type,
    required String accountId,
    String? toAccountId,
    String? category,
  }) async {
    // The draft may hold no category, or one the owner deleted since capture:
    // ask the ledger before falling back to 'Uncategorized'.
    if (type != 'transfer' &&
        (category == null || !await isLiveCategory(_db, category))) {
      category = await learnedCategory(
        _db,
        draft.parsedDescription,
        income: type == 'income',
      );
    }

    final amountAbs = draft.parsedAmount.abs();
    final tx = model.Transaction(
      id: const Uuid().v4(),
      accountId: accountId,
      toAccountId: type == 'transfer' ? toAccountId : null,
      amount: type == 'expense' ? -amountAbs : amountAbs,
      date: draft.parsedDate,
      description: draft.parsedDescription,
      category: type == 'transfer' ? 'Transfer' : (category ?? 'Uncategorized'),
      type: type,
    );

    final booked = await _db.transaction(() async {
      // Re-check under the transaction: a double-tap or a crash-retried
      // approval must not book the same draft twice.
      final still = await _claim(draft.id, const ['pending']);
      if (still == null) return null;

      // Flagged at capture and approved anyway, or dismissed: the owner has
      // already ruled on it.
      if (!still.duplicateDismissed && still.duplicateOfId == null) {
        final twin = await findDuplicate(
          _db,
          amount: still.parsedAmount,
          description: still.parsedDescription,
          date: still.parsedDate,
          // The wallet the income is about to be booked into: a transfer INTO it
          // is the same money.
          incomeIntoAccountId:
              still.parsedAmount > 0 && type == 'income' ? accountId : null,
        );
        if (twin != null) {
          await (_db.update(_db.pendingTransactions)
                ..where((t) => t.id.equals(draft.id)))
              .write(PendingTransactionsCompanion(
            duplicateOfId: Value(twin.transactionId),
            duplicateScore: Value(twin.score),
          ));
          return null;
        }
      }

      return _book(still, tx);
    });
    if (booked != null) {
      await _rememberWallet(draft.source, accountId);
      _finance.afterTransactionWrite(booked);
    }
    return booked;
  }

  /// "Edit and approve": books what the owner finished by hand in the
  /// add-transaction sheet instead of the parsed draft. Accepts a pending draft
  /// or a skipped raw message (unrecognised, finished entirely by hand — once
  /// approved the row stops being retried by sync). False when the draft was
  /// already handled, so a second save books nothing.
  ///
  /// No duplicate recheck, unlike [approve]: the owner has looked at the
  /// numbers and chose them.
  Future<bool> approveWith(String draftId, model.Transaction edited) async {
    final done = await _db.transaction(() async {
      final still = await _claim(draftId, const ['pending', 'skipped']);
      if (still == null) return null;
      return (still.source, await _book(still, edited, confirmed: true));
    });
    if (done == null) return false;
    final (source, booked) = done;
    await _rememberWallet(source, edited.accountId);
    _finance.afterTransactionWrite(booked);
    return true;
  }

  Future<PendingTransaction?> _claim(String id, List<String> statuses) {
    return (_db.select(_db.pendingTransactions)
          ..where((t) => t.id.equals(id) & t.status.isIn(statuses)))
        .getSingleOrNull();
  }

  /// The one place both [approve] and [approveWith] book through. Throws inside
  /// the caller's DB transaction, so a refused booking leaves the draft pending.
  /// Returns what is now in the ledger: [tx], or [tx] under the id of the income
  /// it took over (see [_creditLeg]).
  ///
  /// [confirmed] says the owner set [tx]'s amount (edit and approve), as opposed
  /// to the draft's parsed figure.
  ///
  /// The writes are plain: the budget check and the Sheets sync that follow a
  /// write are run by the callers once the DB transaction has committed, so
  /// they never see, or outlive, a booking that is rolled back.
  Future<model.Transaction> _book(
    PendingTransaction draft,
    model.Transaction tx, {
    bool confirmed = false,
  }) async {
    // A foreign-currency draft holds its foreign figure as if it were euros:
    // only an amount the owner confirmed may be booked for it.
    if (!confirmed && draftForeignAmount(draft) != null) {
      throw ArgumentError(
          'A foreign-currency draft needs a euro amount confirmed by the owner');
    }
    // A transfer with no destination loses the money. The write refuses one
    // into its own source but lets this through (the Sheets import has no
    // destination to give), so a draft is stopped here.
    if (tx.type == 'transfer' && tx.toAccountId == null) {
      throw ArgumentError('A transfer needs a destination');
    }
    // The Revolut push of a Widiba recharge may already be booked as income: the
    // transfer replaces it instead of standing beside it as a debit and a credit.
    final leg = tx.type == 'transfer' ? await _creditLeg(tx) : null;
    if (leg == null) {
      await _finance.addTransaction(tx, followUp: false);
    } else {
      tx = tx.copyWith(id: leg);
      await _finance.updateTransaction(tx, followUp: false);
    }
    await _markStatus(draft.id, 'approved');
    return tx;
  }

  /// The id of the income that is the other half of the transfer [tx]: a live,
  /// positive, non-transfer row in its destination wallet, for the same amount,
  /// within the matcher's +-3 day window; the nearest day wins. Null when there is
  /// none. The owner chose "transfer" for this exact movement, so the match is
  /// taken without asking (the draft-side twin check, [findDuplicate], asks because
  /// there nobody has said what the movement is).
  ///
  /// ponytail: a genuine second income of the same amount into the same wallet
  /// inside those days would be merged too; ask first if that ever happens.
  Future<String?> _creditLeg(model.Transaction tx) async {
    final day = DateTime(tx.date.year, tx.date.month, tx.date.day);
    final rows = await (_db.select(_db.transactions)
          ..where((t) =>
              t.isDeleted.equals(false) &
              t.accountId.equals(tx.toAccountId!) &
              t.type.equals('transfer').not() &
              t.amount.isBetweenValues(
                  tx.amount.abs() - 0.005, tx.amount.abs() + 0.005) &
              t.date.isBetweenValues(
                day.subtract(const Duration(days: 3)),
                day.add(const Duration(days: 4)),
              )))
        .get();
    int apart(Transaction r) => r.date.difference(tx.date).inMinutes.abs();
    rows.sort((a, b) => apart(a).compareTo(apart(b)));
    return rows.isEmpty ? null : rows.first.id;
  }

  Future<void> reject(String id) => _markStatus(id, 'rejected');

  /// "No, it's a different one": permanently un-flags the draft — the dismissed
  /// marker stops the approve-time recheck from raising the warning again.
  Future<void> clearDuplicateFlag(String id) {
    return (_db.update(_db.pendingTransactions)..where((t) => t.id.equals(id)))
        .write(const PendingTransactionsCompanion(
      duplicateOfId: Value(null),
      duplicateScore: Value(null),
      duplicateDismissed: Value(true),
    ));
  }

  /// The existing transaction a draft was flagged against, for the compare UI.
  Future<Transaction?> getTransactionById(String id) {
    // A deleted twin is no evidence of a duplicate: the notice must not point
    // at a row the owner already removed.
    return (_db.select(_db.transactions)
          ..where((t) => t.id.equals(id) & t.isDeleted.equals(false)))
        .getSingleOrNull();
  }

  /// The inbox chip's pick: what [approve] will file the draft under.
  Future<void> setSuggestedCategory(String id, String name) {
    return (_db.update(_db.pendingTransactions)..where((t) => t.id.equals(id)))
        .write(PendingTransactionsCompanion(suggestedCategory: Value(name)));
  }

  Future<void> _markStatus(String id, String status) {
    return (_db.update(_db.pendingTransactions)..where((t) => t.id.equals(id)))
        .write(PendingTransactionsCompanion(status: Value(status)));
  }
}

/// The original amount and currency of a foreign-currency draft ("12,50",
/// "USD"), null for a euro one. Its stored amount is that figure read as euros,
/// so nothing may show or book it as euros. The cue lives in the description
/// (see `bank_draft.dart`); screens ask here instead of parsing it.
({String amount, String currency})? draftForeignAmount(PendingTransaction d) =>
    foreignAmountOf(d.parsedDescription);

/// What the edit-and-approve sheet opens with. An undecided draft (Widiba's
/// SEPA out) starts as an expense; a skipped raw message has no amount (0 — the
/// sheet shows an empty field), its receipt date and its subject as the note.
/// [accountId] and the category are empty when unknown, for the sheet to default.
///
/// An unreadable push (Revolut, PayPal) is described by its BODY, not its title:
/// the title ("Revolut") says nothing, and the raw text is `title ⟂ body` (or
/// the body alone when the push had no title). A Widiba draft keeps its own
/// description: its snippet is the email greeting.
///
/// [euroAmount] is the euro estimate of a foreign-currency draft (see
/// `fx_rates.dart`), when one could be had.
model.Transaction draftPrefill(
  PendingTransaction d, {
  String? accountId,
  double? euroAmount,
}) {
  final type = d.suggestedType == 'income' || d.suggestedType == 'transfer'
      ? d.suggestedType
      : 'expense';
  // A foreign-currency push stored its foreign figure as if it were euros: the
  // sheet starts on the euro estimate, or empty when there is none, for the
  // owner to set the real euro amount (the original stays visible in the
  // description).
  final amount = draftForeignAmount(d) != null
      ? (euroAmount ?? 0.0)
      : d.parsedAmount.abs();
  return model.Transaction(
    id: '',
    accountId: accountId ?? '',
    amount: type == 'expense' ? -amount : amount,
    date: d.status == 'skipped' ? d.emailReceivedAt : d.parsedDate,
    description: _prefillDescription(d),
    category: d.suggestedCategory ?? '',
    type: type,
  );
}

String _prefillDescription(PendingTransaction d) {
  if (d.status != 'skipped' || d.source == 'widiba') return d.parsedDescription;
  const separator = ' ⟂ ';
  final at = d.rawSnippet.indexOf(separator);
  var body = at >= 0
      ? d.rawSnippet.substring(at + separator.length)
      // No separator: the title alone (== the description) or, for a push with
      // no title, the body alone.
      : (d.rawSnippet == d.parsedDescription ? '' : d.rawSnippet);
  body = body.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (body.isEmpty) return d.parsedDescription;
  return body.length > 60 ? '${body.substring(0, 60).trimRight()}…' : body;
}
