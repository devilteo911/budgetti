import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'dart:io';

part 'database.g.dart';

class Categories extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  IntColumn get iconCode => integer()();
  IntColumn get colorHex => integer()();
  TextColumn get type => text()(); // 'income' or 'expense'
  TextColumn get description => text().nullable()();
  
  @override
  Set<Column> get primaryKey => {id};
}

class Tags extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  IntColumn get colorHex => integer()();
  
  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [Categories, Tags])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
      await _seedCategories();
      await _seedTags();
    },
    onUpgrade: (Migrator m, int from, int to) async {
      if (from < 2) {
        await m.createTable(tags);
        await _seedTags();
      }
      if (from < 3) {
        await m.addColumn(categories, categories.description);
      }
    },
  );

  Future<void> _seedCategories() async {
    final defaults = [
      // Expenses
      (name: 'Groceries', icon: 57954, color: 0xFF4CAF50, type: 'expense'), // shopping_basket
      (name: 'Transport', icon: 57675, color: 0xFF2196F3, type: 'expense'), // directions_car
      (name: 'Dining', icon: 57924, color: 0xFFFF9800, type: 'expense'), // restaurant
      (name: 'Shopping', icon: 59600, color: 0xFF9C27B0, type: 'expense'), // shopping_bag
      (name: 'Entertainment', icon: 58022, color: 0xFFFF5722, type: 'expense'), // movie
      (name: 'Health', icon: 58009, color: 0xFFF44336, type: 'expense'), // local_hospital
      (name: 'Bills', icon: 59469, color: 0xFF607D8B, type: 'expense'), // receipt_long
      
      // Income
      (name: 'Salary', icon: 57357, color: 0xFF009688, type: 'income'), // attach_money
      (name: 'Freelance', icon: 59647, color: 0xFF3F51B5, type: 'income'), // work
      (name: 'Investments', icon: 60232, color: 0xFF673AB7, type: 'income'), // trending_up
    ];

    await batch((batch) {
      batch.insertAll(categories, defaults.map((d) {
        return CategoriesCompanion.insert(
          id: DateTime.now().millisecondsSinceEpoch.toString() + d.name, // Simple unique ID
          name: d.name,
          iconCode: d.icon,
          colorHex: d.color,
          type: d.type,
        );
      }));
    });
  }

  Future<void> _seedTags() async {
    final defaults = [
      (name: 'Vacation', color: 0xFFE91E63),
      (name: 'Family', color: 0xFF9C27B0),
      (name: 'Work', color: 0xFF3F51B5),
      (name: 'Personal', color: 0xFF00BCD4),
      (name: 'Gift', color: 0xFFFF5722),
    ];

    await batch((batch) {
      batch.insertAll(tags, defaults.map((d) {
        return TagsCompanion.insert(
          id: DateTime.now().millisecondsSinceEpoch.toString() + d.name,
          name: d.name,
          colorHex: d.color,
        );
      }));
    });
  }

  /// Seeds default categories if the table is empty
  Future<void> seedIfEmpty() async {
    final count = await (select(categories)..limit(1)).get();
    if (count.isEmpty) {
      await _seedCategories();
    }
    
    final tagCount = await (select(tags)..limit(1)).get();
    if (tagCount.isEmpty) {
      await _seedTags();
    }
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'db.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
