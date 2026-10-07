import 'package:flutter/foundation.dart' show debugPrint;
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
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
      debugPrint('Starting backup to Google Drive...');
      final file = await _createBackupFile(isAutoBackup: false);
      debugPrint('Local backup file created: ${file.path}');
      await _driveService.uploadBackup(file);
      debugPrint('Backup to Google Drive completed successfully.');
    } catch (e, s) {
      debugPrint('Error during backupToDrive: $e\n$s');
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
        debugPrint('Auto-backup already performed today.');
        return false;
      }

      debugPrint('Starting automatic backup...');
      
      // 1. Create local persistent backup (using custom path if set)
      final file = await _createBackupFile(isAutoBackup: true, persistence: persistence);
      debugPrint('Local persistent auto-backup created: ${file.path}');
      
      // 2. Manage local backup rotation (keep last 5)
      await _rotateLocalBackups(persistence: persistence);

      // 3. Attempt cloud backup if possible
      try {
        await _authService.signInSilently();
        if (_authService.currentUser != null) {
          await _driveService.uploadBackup(file);
          debugPrint('Auto-backup uploaded to Google Drive.');
        } else {
          debugPrint('Auto-backup skipped cloud upload: User not signed in to Google Drive');
        }
      } catch (e) {
        debugPrint('Cloud auto-backup failed (local backup persists): $e');
      }

      await persistence.setLastAutoBackupTimestamp(now.millisecondsSinceEpoch);
      await persistence.setLastAutoBackupError(null);
      debugPrint('Auto-backup routine completed.');
      return true;
    } catch (e, s) {
      debugPrint('Error during auto-backup: $e\n$s');
      // Settings shows it next to the last-backup time; until then a broken
      // backup looked exactly like a working one.
      await persistence.setLastAutoBackupError(e.toString().split('\n').first);
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
          debugPrint('Deleted old auto-backup: ${f.path}');
        }
      }
    } catch (e) {
      debugPrint('Error rotating backups: $e');
    }
  }

  Future<void> restoreFromDrive(String fileId) async {
    try {
      debugPrint('Starting restore from Google Drive (fileId: $fileId)...');
      final tempDir = await getTemporaryDirectory();
      final file = await _driveService.downloadBackup(
        fileId,
        '${tempDir.path}/restore_${DateTime.now().millisecondsSinceEpoch}.json',
      );
      debugPrint('Backup downloaded to: ${file.path}');
      await importDatabase(file);
      debugPrint('Restore from Google Drive completed successfully.');
    } catch (e, s) {
      debugPrint('Error during restoreFromDrive: $e\n$s');
      rethrow;
    }
  }

  Future<File> _createBackupFile({bool isAutoBackup = false, PersistenceService? persistence}) async {
    // 1. Fetch all data inside one transaction — loose reads could span
    // an auto-sync write and ship a torn snapshot (categories from before an
    // edit, transactions from after).
    final data = await _db.transaction(() async {
      final accounts = await _db.select(_db.accounts).get();
      final transactions = await _db.select(_db.transactions).get();
      final categories = await _db.select(_db.categories).get();
      final tags = await _db.select(_db.tags).get();
      final budgets = await _db.select(_db.budgets).get();
      final installments = await _db.select(_db.installments).get();
      final pivaProfiles = await _db.select(_db.pivaProfiles).get();
      final pivaPayments = await _db.select(_db.pivaPayments).get();

      // 2. Convert to JSON. The Partita IVA keys are the *collection* names
      // (`piva_profile`, singular) — the format the web Ledger reads and writes.
      return {
        'generated_at': DateTime.now().toIso8601String(),
        'accounts': accounts.map((e) => e.toJson()).toList(),
        'transactions': transactions.map((e) => e.toJson()).toList(),
        'categories': categories.map((e) => e.toJson()).toList(),
        'tags': tags.map((e) => e.toJson()).toList(),
        'budgets': budgets.map((e) => e.toJson()).toList(),
        'installments': installments.map((e) => e.toJson()).toList(),
        'piva_profile': pivaProfiles.map((e) => e.toJson()).toList(),
        'piva_payments': pivaPayments.map((e) => e.toJson()).toList(),
      };
    });

    // A full ledger is megabytes of JSON — encode off the UI isolate.
    final jsonString = await _encodeOffThread(data);

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

  // Off-isolate JSON, kept out of the async methods on purpose: a closure made
  // there shares the method's Context, which holds `this` (the sibling
  // `_db.transaction(() async {...})` captures it) -> BackupService ->
  // AppDatabase -> live Futures/finalizers, and Isolate.run then throws
  // "object is unsendable". Static and non-async, the context holds only the arg.
  static Future<String> _encodeOffThread(Object data) =>
      Isolate.run(() => jsonEncode(data));
  static Future<Map<String, dynamic>> _decodeOffThread(String json) =>
      Isolate.run(() => jsonDecode(json) as Map<String, dynamic>);

  Future<void> importDatabase(File file) async {
    final jsonString = await file.readAsString();
    final data = await _decodeOffThread(jsonString);

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
        debugPrint('Error parsing transaction: $e');
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
    // Optional: backups written before installments existed simply have none.
    final installments = ((data['installments'] as List?) ?? const [])
        .map((e) => Installment.fromJson(e as Map<String, dynamic>))
        .toList();
    // Optional, and "absent" is not "empty": unlike installments, a backup that
    // never names the Partita IVA says nothing about it (the profile is a row
    // typed in by hand from the accountant's figures), so null here means the
    // table is left alone, while a key that is present — even `[]` — replaces it.
    final pivaProfiles = (data['piva_profile'] as List?)?.map((e) {
      final map = e as Map<String, dynamic>;
      // Same as `tags`: jsonDecode hands back a List<dynamic>, fromJson wants a
      // List<String>. Anything that is not a list reads as "no categories".
      final cats = map['incomeCategories'];
      map['incomeCategories'] = cats is List ? List<String>.from(cats) : null;
      return PivaProfile.fromJson(map);
    }).toList();
    final pivaPayments = (data['piva_payments'] as List?)
        ?.map((e) => PivaPayment.fromJson(e as Map<String, dynamic>))
        .toList();

    // 3. Replace data in transaction
    await _db.transaction(() async {
      // Clear all tables
      await _db.delete(_db.transactions).go();
      await _db.delete(_db.budgets).go();
      await _db.delete(_db.installments).go();
      // Only the Partita IVA tables the file actually carried (see above).
      if (pivaProfiles != null) await _db.delete(_db.pivaProfiles).go();
      if (pivaPayments != null) await _db.delete(_db.pivaPayments).go();
      await _db.delete(_db.accounts).go();
      await _db.delete(_db.categories).go();
      await _db.delete(_db.tags).go();

      // Insert new data
      await _db.batch((batch) {
        batch.insertAll(_db.accounts, accounts);
        batch.insertAll(_db.categories, categories);
        batch.insertAll(_db.tags, tags);
        batch.insertAll(_db.budgets, budgets);
        batch.insertAll(_db.installments, installments);
        if (pivaProfiles != null) {
          batch.insertAll(_db.pivaProfiles, pivaProfiles);
        }
        if (pivaPayments != null) {
          batch.insertAll(_db.pivaPayments, pivaPayments);
        }
        batch.insertAll(_db.transactions, transactions);
      });
    });
  }
}
