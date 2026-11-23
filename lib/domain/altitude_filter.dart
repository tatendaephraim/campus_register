import 'dart:math' as math;

/// Altitude with its uncertainty (one standard deviation), in metres.
class AltitudeEstimate {
  const AltitudeEstimate(this.metres, this.sigma, {this.usedBarometer = false});

  final double metres;
  final double sigma;

  /// Whether barometer readings contributed to this estimate.
  final bool usedBarometer;
}

/// Converts pressure to altitude with the international barometric formula.
///
/// The absolute value is only meaningful if [seaLevelHpa] is the true sea-level
/// pressure. The *difference* between two readings taken close together in time
/// is far more reliable, and is all [AltitudeFilter] uses.
double pressureToAltitude(double pressureHpa, {double seaLevelHpa = 1013.25}) {
  if (!pressureHpa.isFinite || pressureHpa <= 0) return 0;
  return 44330.0 * (1 - math.pow(pressureHpa / seaLevelHpa, 1 / 5.255));
}

/// One-dimensional Kalman filter that fuses GPS altitude with the barometer.
///
/// The two sensors fail in opposite ways. GPS altitude is absolute but noisy. A
/// barometer is precise over minutes but drifts with the weather, so its
/// absolute altitude is unusable. The barometer therefore predicts *changes* in
/// altitude and GPS corrects the level. Phones without a barometer use the same
/// filter with a motion model that assumes the user may be climbing stairs.
class AltitudeFilter {
  /// Variance added per second when the barometer tracks motion. Corresponds to
  /// 3 m of weather drift after one hour.
  static const double barometerNoise = 9 / 3600;

  /// Variance added per second without a barometer: 0.5 m per root-second.
  static const double motionNoise = 0.25;

  /// Assumed error when a phone reports altitude without an accuracy.
  static const double unknownSigma = 15;

  static const Duration maxBarometerGap = Duration(seconds: 5);
  static const Duration resetAfter = Duration(minutes: 10);

  double? _z;
  double _variance = 0;
  double? _lastPressure;
  DateTime? _lastPressureAt;
  DateTime? _predictedTo;
  DateTime? _lastGnssAt;
  bool _usedBarometer = false;

  AltitudeEstimate? get estimate => _z == null
      ? null
      : AltitudeEstimate(
          _z!,
          math.sqrt(_variance),
          usedBarometer: _usedBarometer,
        );

  void reset() {
    _z = null;
    _variance = 0;
    _usedBarometer = false;
    _lastGnssAt = null;
    _predictedTo = null;
  }

  void addPressure(double hpa, DateTime at) {
    // Outside this range the sensor is faulty, not at altitude.
    if (!hpa.isFinite || hpa < 300 || hpa > 1100) return;
    final previous = _lastPressure;
    final previousAt = _lastPressureAt;
    if (previousAt != null && at.isBefore(previousAt)) return;
    if (_z != null && previous != null && previousAt != null) {
      final gap = at.difference(previousAt);
      if (gap <= maxBarometerGap) {
        _z = _z! + pressureToAltitude(hpa) - pressureToAltitude(previous);
        _advance(at, barometerNoise);
        _usedBarometer = true;
      } else {
        _advance(at, motionNoise);
      }
    }
    _lastPressure = hpa;
    _lastPressureAt = at;
  }

  void addGnss(double altitude, double? sigma, DateTime at) {
    if (!altitude.isFinite) return;
    final s = sigma != null && sigma.isFinite && sigma > 0
        ? sigma
        : unknownSigma;
    final r = s * s;
    if (_lastGnssAt != null && at.difference(_lastGnssAt!) > resetAfter) {
      reset();
    }
    if (_z == null) {
      _z = altitude;
      _variance = r;
      _predictedTo = at;
      _lastGnssAt = at;
      return;
    }
    final barometerFresh =
        _lastPressureAt != null &&
        at.difference(_lastPressureAt!).abs() <= maxBarometerGap;
    _advance(at, barometerFresh ? barometerNoise : motionNoise);

    final innovation = altitude - _z!;
    if (innovation.abs() > 5 * math.sqrt(_variance + r)) {
      // The two cannot both be right. Trust neither history nor momentum.
      _z = altitude;
      _variance = r;
      _usedBarometer = false;
    } else {
      final gain = _variance / (_variance + r);
      _z = _z! + gain * innovation;
      // Consecutive fixes share the same satellites and reflections, so their
      // errors are correlated and averaging cannot remove them. They may not
      // improve the estimate to more than twice as good as a single fix. A fix
      // never makes a better estimate worse.
      final before = _variance;
      _variance = math.max(before * (1 - gain), math.min(before, r / 4));
    }
    _lastGnssAt = at;
  }

  void _advance(DateTime to, double noisePerSecond) {
    final from = _predictedTo ?? to;
    final seconds = to.difference(from).inMilliseconds / 1000;
    if (seconds <= 0) return;
    _variance += noisePerSecond * seconds;
    _predictedTo = to;
  }
}
