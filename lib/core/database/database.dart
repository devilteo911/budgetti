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
  
  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [Categories])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
      await _seedCategories();
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

  /// Seeds default categories if the table is empty
  Future<void> seedIfEmpty() async {
    final count = await (select(categories)..limit(1)).get();
    if (count.isEmpty) {
      await _seedCategories();
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
