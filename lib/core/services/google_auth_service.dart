import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:http/http.dart' as http;

class GoogleAuthService {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      drive.DriveApi.driveFileScope,
      drive.DriveApi.driveAppdataScope,
      sheets.SheetsApi.spreadsheetsScope,
    ],
  );

  GoogleSignInAccount? _currentUser;

  GoogleSignInAccount? get currentUser => _currentUser;

  Stream<GoogleSignInAccount?> get onCurrentUserChanged =>
      _googleSignIn.onCurrentUserChanged;

  Future<void> signIn() async {
    try {
      final user = await _googleSignIn.signIn();
      if (user == null) {
        throw Exception('Sign-in was cancelled by user');
      }
      _currentUser = user;
      debugPrint('Successfully signed in: ${_currentUser!.email}');
    } catch (e, s) {
      debugPrint('Error signing in: $e\n$s');
      _handleSignInError(e);
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    _currentUser = null;
  }

  Future<void> signInSilently() async {
    try {
      debugPrint('Attempting silent sign-in');
      _currentUser = await _googleSignIn.signInSilently();
      if (_currentUser != null) {
        debugPrint('Silent sign-in successful: ${_currentUser!.email}');
      } else {
        debugPrint('No previously signed-in user found');
      }
    } catch (e, s) {
      debugPrint('Error signing in silently: $e\n$s');
    }
  }

  Future<http.Client?> authenticatedClient() async {
    try {
      return await _googleSignIn.authenticatedClient();
    } catch (e, s) {
      debugPrint('Error getting authenticated client: $e\n$s');
      return null;
    }
  }

  void _handleSignInError(Object error) {
    final errorString = error.toString().toLowerCase();

    if (errorString.contains('apiexception: 10') ||
        errorString.contains('developer_error')) {
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
      4. Google Drive API or Sheets API not enabled

      Please follow the setup guide in GOOGLE_DRIVE_SETUP.md
      ========================================
      ''');
    } else if (errorString.contains('network')) {
      debugPrint('Network error during sign-in. Check internet connection.');
    } else if (errorString.contains('sign_in_cancelled')) {
      debugPrint('Sign-in was cancelled by user.');
    } else {
      debugPrint('Unexpected error during sign-in: $errorString');
    }
  }
}
