import 'package:budgetti/core/database/database.dart';
import 'package:budgetti/core/theme/ledger_style.dart' show categorySlot;
import 'package:drift/drift.dart';

/// How many colours the category palette has.
const int colorSlotCount = 8;

/// The slot to give next: the least used of [used], ties to the lowest index.
/// With fewer than eight users it is the lowest slot nobody has.
int leastUsedSlot(Iterable<int> used) {
  final counts = List<int>.filled(colorSlotCount, 0);
  for (final s in used) {
    counts[s % colorSlotCount]++;
  }
  var best = 0;
  for (var i = 1; i < colorSlotCount; i++) {
    if (counts[i] < counts[best]) best = i;
  }
  return best;
}

/// Wire form of a slot. PocketBase number fields have no null, so the server
/// stores slot + 1 and 0 means "no slot yet" (migration 1751000011).
int slotToWire(int slot) => slot + 1;

/// The slot a server value stands for, or null when it is unset, absent (a server
/// that has not run the migration) or not a number.
int? slotFromWire(Object? wire) {
  final n = wire is num ? wire.toInt() : null;
  return n != null && n > 0 ? n - 1 : null;
}

/// The expense categories the owner sees: live, theirs, one per name — the oldest,
/// as every list shows them (see FinanceService._onePerKey).
Future<List<Category>> _visibleExpense(AppDatabase db, String userId) async {
  final rows = await (db.select(db.categories)
        ..where((t) =>
            t.isDeleted.equals(false) &
            t.userId.equals(userId) &
            t.type.equals('expense'))
        ..orderBy([
          (t) => OrderingTerm(expression: const CustomExpression<int>('rowid')),
        ]))
      .get();
  final seen = <String>{};
  return [for (final r in rows) if (seen.add(r.name)) r];
}

/// The slot for a category being created (or turned into an expense): the least
/// used among the slots the owner's expense categories show today. A category
/// with no stored slot shows its hash colour, so it counts as that slot — a
/// category made before the backfill reaches it must not land on a colour already
/// on screen.
Future<int> nextColorSlot(AppDatabase db, String userId) async {
  final rows = await _visibleExpense(db, userId);
  return leastUsedSlot([for (final r in rows) r.colorSlot ?? categorySlot(r.id)]);
}

/// Gives every visible expense category that has no slot one, once, biggest
/// spender first — so the categories that dominate the charts get different
/// colours. Returns how many it assigned.
///
/// Only rows with a NULL slot are ever written, so a stored slot is never
/// rewritten and a second run is a no-op. The batch is stamped with one [now] so
/// last-write-wins picks the same winner for all its rows if another device
/// backfilled apart: one whole, internally distinct assignment, never a mix. The
/// result is a pure function of (rows without a slot, spend, slots already set),
/// so devices with the same synced ledger compute the same slots.
///
/// ponytail: the write re-stamps whole rows, so an edit to the same category made
/// elsewhere since this device last pulled can be overwritten, once, by the stamp.
/// Fix would be a slot-only LWW; not worth it while one person owns the ledger.
Future<int> backfillColorSlots(AppDatabase db, String userId,
    {DateTime? now}) async {
  final rows = await _visibleExpense(db, userId);
  final open = [for (final r in rows) if (r.colorSlot == null) r];
  if (open.isEmpty) return 0;

  // Money out per category name: negative, non-transfer, live.
  final spendRows = await db.customSelect(
    'SELECT category, SUM(-amount) AS spent FROM transactions '
    "WHERE user_id = ? AND is_deleted = 0 AND type != 'transfer' AND amount < 0 "
    'GROUP BY category',
    variables: [Variable<String>(userId)],
  ).get();
  final spent = {
    for (final r in spendRows) r.read<String>('category'): r.read<double>('spent')
  };
  open.sort((a, b) {
    final bySpend = (spent[b.name] ?? 0).compareTo(spent[a.name] ?? 0);
    return bySpend != 0 ? bySpend : a.id.compareTo(b.id);
  });

  final used = [for (final r in rows) if (r.colorSlot != null) r.colorSlot!];
  final stamp = now ?? DateTime.now();
  await db.transaction(() async {
    for (final r in open) {
      final slot = leastUsedSlot(used);
      used.add(slot);
      await (db.update(db.categories)..where((t) => t.id.equals(r.id))).write(
        CategoriesCompanion(colorSlot: Value(slot), lastUpdated: Value(stamp)),
      );
    }
  });
  return open.length;
}
