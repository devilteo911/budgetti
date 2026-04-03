import 'dart:convert';
import 'dart:io';
import 'package:budgetti/core/database/database.dart';

import 'package:budgetti/core/services/google_auth_service.dart';
import 'package:budgetti/core/services/google_drive_service.dart';
import 'package:budgetti/core/services/persistence_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class BackupService {
  final AppDatabase _db;
  final GoogleDriveService _driveService;
  final GoogleAuthService _authService;

  BackupService(this._db, this._driveService, this._authService);

  Future<void> exportDatabase() async {
    final file = await _createBackupFile(isAutoBackup: false);
    // ignore: deprecated_member_use
    await Share.shareXFiles([XFile(file.path)], text: 'Budgetti Backup');
  }

  Future<void> backupToDrive() async {
    try {
      print('Starting backup to Google Drive...');
      final file = await _createBackupFile(isAutoBackup: false);
      print('Local backup file created: ${file.path}');
      await _driveService.uploadBackup(file);
      print('Backup to Google Drive completed successfully.');
    } catch (e, s) {
      print('Error during backupToDrive: $e\n$s');
      rethrow;
    }
  }

  Future<bool> performAutoBackup(PersistenceService persistence) async {
    try {
      if (!persistence.getAutoBackupEnabled()) return false;

      final lastBackup = persistence.getLastAutoBackupTimestamp();
      final now = DateTime.now();
      final todayAtMidnight = DateTime(now.year, now.month, now.day);

      if (lastBackup >= todayAtMidnight.millisecondsSinceEpoch) {
        print('Auto-backup already performed today.');
        return false;
      }

      print('Starting automatic backup...');
      
      // 1. Create local persistent backup (using custom path if set)
      final file = await _createBackupFile(isAutoBackup: true, persistence: persistence);
      print('Local persistent auto-backup created: ${file.path}');
      
      // 2. Manage local backup rotation (keep last 5)
      await _rotateLocalBackups(persistence: persistence);

      // 3. Attempt cloud backup if possible
      try {
        await _authService.signInSilently();
        if (_authService.currentUser != null) {
          await _driveService.uploadBackup(file);
          print('Auto-backup uploaded to Google Drive.');
        } else {
          print('Auto-backup skipped cloud upload: User not signed in to Google Drive');
        }
      } catch (e) {
        print('Cloud auto-backup failed (local backup persists): $e');
      }

      await persistence.setLastAutoBackupTimestamp(now.millisecondsSinceEpoch);
      print('Auto-backup routine completed.');
      return true;
    } catch (e) {
      print('Error during auto-backup: $e');
      return false;
    }
  }

  Future<void> _rotateLocalBackups({PersistenceService? persistence}) async {
    try {
      final String path;
      final customPath = persistence?.getCustomBackupPath();
      if (customPath != null) {
        path = customPath;
      } else {
        final docDir = await getApplicationDocumentsDirectory();
        path = '${docDir.path}/autobackups';
      }

      final backupDir = Directory(path);
      if (!await backupDir.exists()) return;

      final files = await backupDir.list().toList();
      final backupFiles = files
          .whereType<File>()
          .where((f) => f.path.contains('budgetti_autobackup_') && f.path.endsWith('.json'))
          .toList();

      // Sort by modification time (oldest first)
      backupFiles.sort((a, b) => a.lastModifiedSync().compareTo(b.lastModifiedSync()));

      // Keep only the latest 5
      if (backupFiles.length > 5) {
        final toDelete = backupFiles.sublist(0, backupFiles.length - 5);
        for (var f in toDelete) {
          await f.delete();
          print('Deleted old auto-backup: ${f.path}');
        }
      }
    } catch (e) {
      print('Error rotating backups: $e');
    }
  }

  Future<void> restoreFromDrive(String fileId) async {
    try {
      print('Starting restore from Google Drive (fileId: $fileId)...');
      final tempDir = await getTemporaryDirectory();
      final file = await _driveService.downloadBackup(
        fileId,
        '${tempDir.path}/restore_${DateTime.now().millisecondsSinceEpoch}.json',
      );
      print('Backup downloaded to: ${file.path}');
      await importDatabase(file);
      print('Restore from Google Drive completed successfully.');
    } catch (e, s) {
      print('Error during restoreFromDrive: $e\n$s');
      rethrow;
    }
  }

  Future<File> _createBackupFile({bool isAutoBackup = false, PersistenceService? persistence}) async {
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

    // 3. Write to file
    final String path;
    if (isAutoBackup) {
      final customPath = persistence?.getCustomBackupPath();
      if (customPath != null) {
        final backupDir = Directory(customPath);
        if (!await backupDir.exists()) {
          await backupDir.create(recursive: true);
        }
        path = '${backupDir.path}/budgetti_autobackup_${DateTime.now().millisecondsSinceEpoch}.json';
      } else {
        final docDir = await getApplicationDocumentsDirectory();
        final backupDir = Directory('${docDir.path}/autobackups');
        if (!await backupDir.exists()) {
          await backupDir.create(recursive: true);
        }
        path = '${backupDir.path}/budgetti_autobackup_${DateTime.now().millisecondsSinceEpoch}.json';
      }
    } else {
      final tempDir = await getTemporaryDirectory();
      path = '${tempDir.path}/budgetti_backup_${DateTime.now().millisecondsSinceEpoch}.json';
    }

    final file = File(path);
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
