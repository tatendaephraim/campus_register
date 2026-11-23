import 'package:local_auth/local_auth.dart';

enum BiometricOutcome { verified, failed, unavailable }

class BiometricService {
  final LocalAuthentication _auth = LocalAuthentication();

  Future<BiometricOutcome> authenticate() async {
    try {
      final verified = await _auth.authenticate(
        localizedReason: 'Verify your identity to sign the register',
        // A PIN can be told to a friend; a biometric cannot.
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
      return verified ? BiometricOutcome.verified : BiometricOutcome.failed;
    } on LocalAuthException catch (e) {
      return switch (e.code) {
        LocalAuthExceptionCode.noBiometricHardware ||
        LocalAuthExceptionCode.noBiometricsEnrolled ||
        LocalAuthExceptionCode.noCredentialsSet ||
        LocalAuthExceptionCode.biometricHardwareTemporarilyUnavailable ||
        LocalAuthExceptionCode.uiUnavailable => BiometricOutcome.unavailable,
        _ => BiometricOutcome.failed,
      };
    } catch (_) {
      return BiometricOutcome.unavailable; // Fail closed.
    }
  }
}
