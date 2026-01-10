import 'dart:io';

import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;

class GoogleDriveService {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      drive.DriveApi.driveFileScope,
      drive.DriveApi.driveAppdataScope,
    ],
    // Optional: Uncomment and add your web client ID if needed for backend auth
    // serverClientId: 'YOUR-WEB-CLIENT-ID.apps.googleusercontent.com',
  );

  GoogleSignInAccount? _currentUser;

  // Expose current user - synchronously returns the current state
  GoogleSignInAccount? get currentUser => _currentUser;

  // Stream that emits when user state changes
  // NOTE: This stream from GoogleSignIn plugin may not emit immediately after signIn()
  Stream<GoogleSignInAccount?> get onCurrentUserChanged =>
      _googleSignIn.onCurrentUserChanged;

  Future<void> signIn() async {
    try {
      final user = await _googleSignIn.signIn();
      if (user == null) {
        throw Exception('Sign-in was cancelled by user');
      }

      // CRITICAL: Update our local state immediately
      _currentUser = user;
      debugPrint('Successfully signed in: ${_currentUser!.email}');

      // Note: The onCurrentUserChanged stream should also emit, but we update
      // _currentUser immediately to ensure synchronous access via currentUser getter
    } on Exception catch (e) {
      debugPrint('Error signing in: $e');
      _handleSignInError(e);
      rethrow;
    }
  }

  void _handleSignInError(Exception error) {
    final errorString = error.toString();

    if (errorString.contains('apiException: 10') || errorString.contains('DEVELOPER_ERROR')) {
      debugPrint('''
      ========================================
      GOOGLE SIGN-IN CONFIGURATION ERROR
      ========================================
      Error: API Exception 10 (DEVELOPER_ERROR)

      This error means OAuth 2.0 is not properly configured.

      Common causes:
      1. Missing Android OAuth client ID with SHA-1 fingerprint
      2. Missing iOS URL scheme in Info.plist
      3. Incorrect package name or bundle ID
      4. Google Drive API not enabled

      Please follow the setup guide in GOOGLE_DRIVE_SETUP.md

      Quick fixes:
      - Android: Run ./get_sha1.sh to get your SHA-1 fingerprint
      - iOS: Add URL scheme to Info.plist
      - Verify Google Drive API is enabled in Cloud Console
      ========================================
      ''');
    } else if (errorString.contains('network')) {
      debugPrint('Network error during sign-in. Check internet connection.');
    } else if (errorString.contains('SIGN_IN_CANCELLED')) {
      debugPrint('Sign-in was cancelled by user.');
    } else {
      debugPrint('Unexpected error during sign-in: $errorString');
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    _currentUser = null;
  }

  // Get authenticated Drive API client
  Future<drive.DriveApi?> _getDriveApi() async {
    try {
      final httpClient = await _googleSignIn.authenticatedClient();
      if (httpClient == null) {
        debugPrint('No authenticated HTTP client available');
        return null;
      }
      return drive.DriveApi(httpClient);
    } catch (e) {
      debugPrint('Error getting authenticated Drive API client: $e');
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
    } catch (e) {
      debugPrint('Error getting/creating folder: $e');
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
    } catch (e) {
      debugPrint('Error uploading backup: $e');
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
    } catch (e) {
      debugPrint('Error listing backups: $e');
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
    } catch (e) {
      debugPrint('Error downloading backup: $e');
      rethrow;
    }
  }

  // Restore silent sign in
  Future<void> signInSilently() async {
    try {
      debugPrint('Attempting silent sign-in');
      _currentUser = await _googleSignIn.signInSilently();
      if (_currentUser != null) {
        debugPrint('Silent sign-in successful: ${_currentUser!.email}');
      } else {
        debugPrint('No previously signed-in user found');
      }
    } catch (e) {
      debugPrint('Error signing in silently: $e');
    }
  }
}
