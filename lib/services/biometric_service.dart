import 'package:local_auth/local_auth.dart';
import 'package:local_auth/error_codes.dart' as auth_error;

class BiometricService {
  final LocalAuthentication _auth = LocalAuthentication();
  String? _lastError;

  String? get lastError => _lastError;

  Future<bool> authenticate() async {
    try {
      _lastError = null;

      // Check if device supports biometrics
      final isDeviceSupported = await _auth.isDeviceSupported();
      if (!isDeviceSupported) {
        _lastError = 'Device does not support biometric authentication';
        return false;
      }

      // Check if biometrics can be used
      final canCheckBiometrics = await _auth.canCheckBiometrics;
      if (!canCheckBiometrics) {
        _lastError = 'Biometric authentication is not available';
        return false;
      }

      // Get available biometrics
      final availableBiometrics = await _auth.getAvailableBiometrics();
      if (availableBiometrics.isEmpty) {
        _lastError =
            'No biometrics enrolled. Please set up fingerprint or face unlock in device settings';
        return false;
      }

      print('📱 Available biometrics: $availableBiometrics');

      // Attempt authentication with fallback to PIN/password
      return await _auth.authenticate(
        localizedReason: 'Authenticate to mark your attendance',
        options: const AuthenticationOptions(
          useErrorDialogs: false, // We'll handle errors ourselves
          stickyAuth: true,
          biometricOnly: false, // Allow PIN/password fallback
        ),
      );
    } on Exception catch (e) {
      print('🔒 Biometric authentication error: $e');

      // Handle specific error codes
      if (e.toString().contains(auth_error.notAvailable)) {
        _lastError = 'Biometric authentication is not available';
      } else if (e.toString().contains(auth_error.notEnrolled)) {
        _lastError = 'No biometrics enrolled on this device';
      } else if (e.toString().contains(auth_error.lockedOut) ||
          e.toString().contains(auth_error.permanentlyLockedOut)) {
        _lastError = 'Too many failed attempts. Please try again later';
      } else {
        _lastError = 'Authentication cancelled or failed';
      }
      return false;
    } catch (e) {
      print('🔒 Unexpected biometric error: $e');
      _lastError = 'Unexpected error: ${e.toString()}';
      return false;
    }
  }
}
