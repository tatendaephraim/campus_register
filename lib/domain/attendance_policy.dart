import 'geofence.dart';

/// A position fix, independent of any location plugin.
class PositionSample {
  const PositionSample({
    required this.latitude,
    required this.longitude,
    required this.accuracyM,
    required this.timestamp,
    this.isMocked = false,
  });

  final double latitude;
  final double longitude;
  final double accuracyM;
  final DateTime timestamp;
  final bool isMocked;
}

/// Machine-readable outcome of an attempt. The name of each value is written to
/// the log, so renaming one changes the data format.
enum Decision {
  accepted('Attendance recorded.'),
  noPosition('Your position could not be determined.'),
  mockedPosition('A mock-location provider is active. Turn it off.'),
  staleFix('The position is out of date. Please try again.'),
  poorAccuracy('The GPS signal is too weak. Move near a window or outdoors.'),
  outsideCampus('You are outside the campus boundary.'),
  boundaryUncertain(
    'You are too close to the campus boundary to be sure. Move further in.',
  ),
  clockInconsistent('The device clock is wrong. Turn on automatic time.'),
  biometricFailed('Biometric verification was not completed.'),
  biometricUnavailable('No usable biometric is enrolled on this device.');

  const Decision(this.message);
  final String message;

  bool get isAccepted => this == Decision.accepted;
}

class PolicyResult {
  const PolicyResult(this.decision, {this.distanceM});
  final Decision decision;
  final double? distanceM;
}

/// The location and time rules, as a pure function of their inputs.
class AttendancePolicy {
  const AttendancePolicy({
    required this.latitude,
    required this.longitude,
    required this.radiusM,
    this.maxAccuracyM = 50,
    this.maxFixAge = const Duration(seconds: 30),
    this.clockTolerance = const Duration(seconds: 5),
  });

  final double latitude;
  final double longitude;
  final double radiusM;
  final double maxAccuracyM;
  final Duration maxFixAge;
  final Duration clockTolerance;

  /// The first rule that fails is the one recorded. [lastEventAt] is the time
  /// of the newest entry in the local log.
  PolicyResult evaluate({
    required PositionSample? position,
    required DateTime now,
    DateTime? lastEventAt,
  }) {
    if (lastEventAt != null &&
        now.isBefore(lastEventAt.subtract(clockTolerance))) {
      return const PolicyResult(Decision.clockInconsistent);
    }
    if (position == null ||
        !position.latitude.isFinite ||
        !position.longitude.isFinite) {
      return const PolicyResult(Decision.noPosition);
    }
    final distance = haversineMetres(
      position.latitude,
      position.longitude,
      latitude,
      longitude,
    );
    PolicyResult result(Decision d) => PolicyResult(d, distanceM: distance);

    if (position.isMocked) return result(Decision.mockedPosition);
    final age = now.difference(position.timestamp);
    if (age > maxFixAge) return result(Decision.staleFix);
    // The fix carries its own time, so a fix from the future means the device
    // clock has been set back.
    if (age < -maxFixAge) return result(Decision.clockInconsistent);
    // Zero and negative mean "unknown" on Android and iOS respectively, so
    // they must not be read as perfect accuracy.
    final accuracy = position.accuracyM;
    if (!accuracy.isFinite || accuracy <= 0) {
      return result(Decision.poorAccuracy);
    }
    final fence = classifyFence(
      distanceM: distance,
      accuracyM: accuracy,
      radiusM: radiusM,
    );
    // A fix clearly outside stays outside however coarse it is.
    if (fence == FenceResult.outside) return result(Decision.outsideCampus);
    if (accuracy > maxAccuracyM) return result(Decision.poorAccuracy);
    return result(
      fence == FenceResult.inside
          ? Decision.accepted
          : Decision.boundaryUncertain,
    );
  }
}
