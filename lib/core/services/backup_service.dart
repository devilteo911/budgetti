import 'dart:convert';
import 'dart:io';
import 'package:budgetti/core/database/database.dart';

import 'package:budgetti/core/services/google_drive_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class BackupService {
  final AppDatabase _db;
  final GoogleDriveService _driveService;

  BackupService(this._db, this._driveService);

  Future<void> exportDatabase() async {
    final file = await _createBackupFile();
    // ignore: deprecated_member_use
    await Share.shareXFiles([XFile(file.path)], text: 'Budgetti Backup');
  }

  Future<void> backupToDrive() async {
    final file = await _createBackupFile();
    await _driveService.uploadBackup(file);
  }

  Future<void> restoreFromDrive(String fileId) async {
    final tempDir = await getTemporaryDirectory();
    final file = await _driveService.downloadBackup(
      fileId,
      '${tempDir.path}/restore_${DateTime.now().millisecondsSinceEpoch}.json',
    );
    await importDatabase(file);
  }

  Future<File> _createBackupFile() async {
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
    return file;
  }

  Future<void> importDatabase(File file) async {
    final jsonString = await file.readAsString();
    final data = jsonDecode(jsonString) as Map<String, dynamic>;

    // 1. Validate keys
    final requiredKeys = [
      'accounts',
      'transactions',
      'categories',
      'tags',
      'budgets',
    ];
    for (var key in requiredKeys) {
      if (!data.containsKey(key)) {
        throw Exception('Invalid backup file: Missing $key');
      }
    }

    // 2. Parse data
    final accounts = (data['accounts'] as List)
        .map((e) => Account.fromJson(e as Map<String, dynamic>))
        .toList();
    final transactions = (data['transactions'] as List).map((e) {
      try {
        final map = e as Map<String, dynamic>;
        // Robust handling for tags list
        if (map['tags'] != null) {
          if (map['tags'] is List) {
            // Explicitly cast to List<String>
            map['tags'] = List<String>.from(map['tags'] as List);
          } else {
            // Fallback for unexpected types
            map['tags'] = [];
          }
        }
        return Transaction.fromJson(map);
      } catch (e) {
        print('Error parsing transaction: $e');
        rethrow;
      }
    }).toList();
    final categories = (data['categories'] as List)
        .map((e) => Category.fromJson(e as Map<String, dynamic>))
        .toList();
    final tags = (data['tags'] as List)
        .map((e) => Tag.fromJson(e as Map<String, dynamic>))
        .toList();
    final budgets = (data['budgets'] as List)
        .map((e) => Budget.fromJson(e as Map<String, dynamic>))
        .toList();

    // 3. Replace data in transaction
    await _db.transaction(() async {
      // Clear all tables
      await _db.delete(_db.transactions).go();
      await _db.delete(_db.budgets).go();
      await _db.delete(_db.accounts).go();
      await _db.delete(_db.categories).go();
      await _db.delete(_db.tags).go();

      // Insert new data
      await _db.batch((batch) {
        batch.insertAll(_db.accounts, accounts);
        batch.insertAll(_db.categories, categories);
        batch.insertAll(_db.tags, tags);
        batch.insertAll(_db.budgets, budgets);
        batch.insertAll(_db.transactions, transactions);
      });
    });
  }
}
