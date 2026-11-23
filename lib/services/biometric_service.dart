import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

class BiometricService {
  final LocalAuthentication _auth = LocalAuthentication();
  String? _lastError;

  String? get lastError => _lastError;

  /// Returns true only for a fingerprint or face match. A PIN can be told to a
  /// friend, so it must not count.
  Future<bool> authenticate() async {
    _lastError = null;
    try {
      final verified = await _auth.authenticate(
        localizedReason: 'Authenticate to mark your attendance',
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
      if (!verified) _lastError = 'Authentication failed.';
      return verified;
    } on LocalAuthException catch (e) {
      debugPrint('Biometric authentication error: ${e.code}');
      _lastError = switch (e.code) {
        LocalAuthExceptionCode.noBiometricHardware =>
          'Device does not support biometric authentication',
        LocalAuthExceptionCode.noBiometricsEnrolled ||
        LocalAuthExceptionCode.noCredentialsSet =>
          'No biometrics enrolled. Please set up fingerprint or face unlock in device settings',
        LocalAuthExceptionCode.temporaryLockout ||
        LocalAuthExceptionCode.biometricLockout =>
          'Too many failed attempts. Please try again later',
        LocalAuthExceptionCode.biometricHardwareTemporarilyUnavailable =>
          'Biometric authentication is not available',
        _ => 'Authentication cancelled or failed',
      };
      return false;
    } catch (e) {
      debugPrint('Unexpected biometric error: $e');
      _lastError = 'Biometric authentication is not available';
      return false;
    }
  }
}
