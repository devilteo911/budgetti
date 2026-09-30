import 'package:budgetti/core/database/database.dart';
import 'package:drift/drift.dart' show Value;

import 'owner_defaults_fixture.dart';

/// The user id every fixture row carries.
const owner = 'owner';

/// What the five rows still carried before the batch stamped them.
const beforeStamp = 1784585637;

DateTime at(int seconds) => DateTime.fromMillisecondsSinceEpoch(seconds * 1000);

/// Fills [db] with the owner's categories and tags, in rowid order. With
/// [beforeTheBatch] the rows the batch stamped are still live under their old
/// stamp; otherwise it is the state the phone exported.
Future<void> seedOwner(AppDatabase db, {required bool beforeTheBatch}) async {
  for (final (id, name, type, icon, color, deleted, sec) in exportedCategories) {
    final hit = beforeTheBatch && sec == theBatchSecond;
    await db.into(db.categories).insert(CategoriesCompanion.insert(
          id: id,
          name: name,
          iconCode: icon,
          colorHex: color,
          type: type,
          userId: const Value(owner),
          isDeleted: Value(hit ? false : deleted),
          lastUpdated: Value(at(hit ? beforeStamp : sec)),
        ));
  }
  for (final (id, name, color, deleted, sec) in exportedTags) {
    final hit = beforeTheBatch && sec == theBatchSecond;
    await db.into(db.tags).insert(TagsCompanion.insert(
          id: id,
          name: name,
          colorHex: color,
          userId: const Value(owner),
          isDeleted: Value(hit ? false : deleted),
          lastUpdated: Value(at(hit ? beforeStamp : sec)),
        ));
  }
}
