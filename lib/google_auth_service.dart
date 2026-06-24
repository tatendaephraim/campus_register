import 'package:google_sign_in/google_sign_in.dart';

/// A service class to handle Google Sign-In authentication.
///
/// This class abstracts the functionality of the google_sign_in package,
/// providing simple methods to sign in and sign out.
class GoogleAuthService {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      'email',
      // Add the drive.file scope to allow creating files (the Google Sheet)
      'https://www.googleapis.com/auth/drive.file',
    ],
  );

  /// Initiates the Google Sign-In flow.
  ///
  /// Returns the [GoogleSignInAccount] of the signed-in user,
  /// or `null` if the sign-in process was canceled or failed.
  Future<GoogleSignInAccount?> signIn() async {
    try {
      return await _googleSignIn.signIn();
    } catch (error) {
      print("Google Sign-In Error: $error");
      return null;
    }
  }

  /// Signs the current user out.
  Future<void> signOut() => _googleSignIn.disconnect();
}
