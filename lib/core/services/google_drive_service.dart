import 'dart:io';

import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;

class GoogleDriveService {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      drive.DriveApi.driveFileScope,
      drive.DriveApi.driveAppdataScope,
    ],
  );

  GoogleSignInAccount? _currentUser;

  // Expose current user
  GoogleSignInAccount? get currentUser => _currentUser;

  Stream<GoogleSignInAccount?> get onCurrentUserChanged =>
      _googleSignIn.onCurrentUserChanged;

  Future<void> signIn() async {
    try {
      _currentUser = await _googleSignIn.signIn();
    } catch (e) {
      // print('Error signing in: $e');
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    _currentUser = null;
  }

  // Get authenticated Drive API client
  Future<drive.DriveApi?> _getDriveApi() async {
    final httpClient = await _googleSignIn.authenticatedClient();
    if (httpClient == null) {
      return null;
    }
    return drive.DriveApi(httpClient);
  }

  // Helper to find or create the 'budgetti' folder
  Future<String?> _getOrCreateBackupFolder(drive.DriveApi driveApi) async {
    const folderName = 'budgetti';
    const mimeType = 'application/vnd.google-apps.folder';

    try {
      // 1. Search for existing folder
      final fileList = await driveApi.files.list(
        q: "mimeType = '$mimeType' and name = '$folderName' and trashed = false",
        $fields: 'files(id, name)',
      );

      if (fileList.files != null && fileList.files!.isNotEmpty) {
        return fileList.files!.first.id;
      }

      // 2. Create folder if not found
      final folderToCreate = drive.File()
        ..name = folderName
        ..mimeType = mimeType;

      final createdFolder = await driveApi.files.create(folderToCreate);
      return createdFolder.id;
    } catch (e) {
      // print('Error getting/creating folder: $e');
      return null;
    }
  }

  // Upload backup file
  Future<void> uploadBackup(File file) async {
    final driveApi = await _getDriveApi();
    if (driveApi == null) throw Exception('User not signed in');

    final folderId = await _getOrCreateBackupFolder(driveApi);
    if (folderId == null) throw Exception('Could not create backup folder');

    final fileName = 'budgetti_backup_${DateTime.now().toIso8601String()}.json';
    final fileToUpload = drive.File()
      ..name = fileName
      ..parents = [folderId];

    final media = drive.Media(file.openRead(), file.lengthSync());

    await driveApi.files.create(
      fileToUpload,
      uploadMedia: media,
    );
  }

  // List backups
  Future<List<drive.File>> listBackups() async {
    final driveApi = await _getDriveApi();
    if (driveApi == null) throw Exception('User not signed in');

    final folderId = await _getOrCreateBackupFolder(driveApi);
    if (folderId == null) return [];

    final fileList = await driveApi.files.list(
      q: "'$folderId' in parents and trashed = false",
      $fields: 'files(id, name, createdTime, size)',
      orderBy: 'createdTime desc',
    );

    return fileList.files ?? [];
  }

  // Download backup
  Future<File> downloadBackup(String fileId, String savePath) async {
    final driveApi = await _getDriveApi();
    if (driveApi == null) throw Exception('User not signed in');

    final driveFile = await driveApi.files.get(
      fileId,
      downloadOptions: drive.DownloadOptions.fullMedia,
    ) as drive.Media;

    final file = File(savePath);
    final IOSink sink = file.openWrite();
    await driveFile.stream.pipe(sink);
    await sink.close();
    
    return file;
  }
  
  // Restore silent sign in
  Future<void> signInSilently() async {
      try {
        _currentUser = await _googleSignIn.signInSilently();
      } catch (e) {
          // print("Error signing in silently: $e");
      }
  }
}
