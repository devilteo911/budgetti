import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:googleapis/drive/v3.dart' as drive;

import 'google_auth_service.dart';

class GoogleDriveService {
  final GoogleAuthService _authService;

  GoogleDriveService(this._authService);

  // Get authenticated Drive API client
  Future<drive.DriveApi?> _getDriveApi() async {
    try {
      final httpClient = await _authService.authenticatedClient();
      if (httpClient == null) {
        debugPrint('No authenticated HTTP client available');
        return null;
      }
      return drive.DriveApi(httpClient);
    } catch (e, s) {
      debugPrint('Error getting authenticated Drive API client: $e\n$s');
      return null;
    }
  }

  // Helper to find or create the 'budgetti' folder
  Future<String?> _getOrCreateBackupFolder(drive.DriveApi driveApi) async {
    const folderName = 'budgetti';
    const mimeType = 'application/vnd.google-apps.folder';

    try {
      debugPrint('Searching for backup folder: $folderName');

      // 1. Search for existing folder
      final fileList = await driveApi.files.list(
        q: "mimeType = '$mimeType' and name = '$folderName' and trashed = false",
        $fields: 'files(id, name)',
      );

      if (fileList.files != null && fileList.files!.isNotEmpty) {
        final folderId = fileList.files!.first.id;
        debugPrint('Found existing backup folder: $folderId');
        return folderId;
      }

      // 2. Create folder if not found
      debugPrint('Creating new backup folder: $folderName');
      final folderToCreate = drive.File()
        ..name = folderName
        ..mimeType = mimeType;

      final createdFolder = await driveApi.files.create(folderToCreate);
      debugPrint('Created backup folder: ${createdFolder.id}');
      return createdFolder.id;
    } catch (e, s) {
      debugPrint('Error getting/creating folder: $e\n$s');
      return null;
    }
  }

  // Upload backup file
  Future<void> uploadBackup(File file) async {
    try {
      debugPrint('Starting backup upload to Google Drive');

      final driveApi = await _getDriveApi();
      if (driveApi == null) {
        throw Exception('User not signed in to Google Drive. Please sign in first.');
      }

      final folderId = await _getOrCreateBackupFolder(driveApi);
      if (folderId == null) {
        throw Exception('Could not create or access backup folder in Google Drive');
      }

      final fileName = 'budgetti_backup_${DateTime.now().toIso8601String()}.json';
      final fileSize = await file.length();
      debugPrint('Uploading file: $fileName (${fileSize ~/ 1024} KB)');

      final fileToUpload = drive.File()
        ..name = fileName
        ..parents = [folderId];

      final media = drive.Media(file.openRead(), file.lengthSync());

      final uploadedFile = await driveApi.files.create(
        fileToUpload,
        uploadMedia: media,
      );

      debugPrint('Backup uploaded successfully: ${uploadedFile.id}');
    } catch (e, s) {
      debugPrint('Error uploading backup: $e\n$s');
      rethrow;
    }
  }

  // List backups
  Future<List<drive.File>> listBackups() async {
    try {
      debugPrint('Fetching list of backups from Google Drive');

      final driveApi = await _getDriveApi();
      if (driveApi == null) {
        throw Exception('User not signed in to Google Drive');
      }

      final folderId = await _getOrCreateBackupFolder(driveApi);
      if (folderId == null) {
        debugPrint('No backup folder found');
        return [];
      }

      final fileList = await driveApi.files.list(
        q: "'$folderId' in parents and trashed = false",
        $fields: 'files(id, name, createdTime, size)',
        orderBy: 'createdTime desc',
      );

      final backups = fileList.files ?? [];
      debugPrint('Found ${backups.length} backup(s)');
      return backups;
    } catch (e, s) {
      debugPrint('Error listing backups: $e\n$s');
      rethrow;
    }
  }

  // Download backup
  Future<File> downloadBackup(String fileId, String savePath) async {
    try {
      debugPrint('Downloading backup: $fileId');

      final driveApi = await _getDriveApi();
      if (driveApi == null) {
        throw Exception('User not signed in to Google Drive');
      }

      final driveFile = await driveApi.files.get(
        fileId,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media;

      final file = File(savePath);
      final IOSink sink = file.openWrite();
      await driveFile.stream.pipe(sink);
      await sink.close();

      final fileSize = await file.length();
      debugPrint('Backup downloaded successfully: ${fileSize ~/ 1024} KB');

      return file;
    } catch (e, s) {
      debugPrint('Error downloading backup: $e\n$s');
      rethrow;
    }
  }
}
