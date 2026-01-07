import 'dart:convert';
import 'dart:io';
import 'package:budgetti/core/database/database.dart';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class BackupService {
  final AppDatabase _db;

  BackupService(this._db);

  Future<void> exportDatabase() async {
    // 1. Fetch all data
    final accounts = await _db.select(_db.accounts).get();
    final transactions = await _db.select(_db.transactions).get();
    final categories = await _db.select(_db.categories).get();
    final tags = await _db.select(_db.tags).get();
    final budgets = await _db.select(_db.budgets).get();

    // 2. Convert to JSON
    final data = {
      'generated_at': DateTime.now().toIso8601String(),
      'accounts': accounts.map((e) => e.toJson()).toList(),
      'transactions': transactions.map((e) => e.toJson()).toList(),
      'categories': categories.map((e) => e.toJson()).toList(),
      'tags': tags.map((e) => e.toJson()).toList(),
      'budgets': budgets.map((e) => e.toJson()).toList(),
    };

    final jsonString = jsonEncode(data);

    // 3. Write to temp file
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/budgetti_backup_${DateTime.now().millisecondsSinceEpoch}.json');
    await file.writeAsString(jsonString);

    // 4. Share
    // ignore: deprecated_member_use
    await Share.shareXFiles([XFile(file.path)], text: 'Budgetti Backup');
  }
}
