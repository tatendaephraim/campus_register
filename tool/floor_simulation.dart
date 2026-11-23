// Monte-Carlo test of floor separation. Reproducible: the seed is fixed.
//
//   dart run tool/floor_simulation.dart
//
// It runs the app's own AltitudeFilter and HeightBand. The room is on the first
// floor (one storey above ground) and storeys are 3.5 m. GPS altitude error is a
// constant bias per place plus a little jitter, because fixes taken seconds
// apart share the same satellites and reflections. The captured room altitude
// has its own error.
import 'dart:io';
import 'dart:math' as math;

import 'package:campus_register/domain/altitude_filter.dart';
import 'package:campus_register/domain/volumetric_check.dart';

const storeyM = 3.5;
const trials = 20000;
const seed = 20260629;
const captureSigma = 1.5;
const outdoorSigma = 3.0;
const floors = [-1, 0, 1, 2, 3, 5];

final random = math.Random(seed);

double gauss() =>
    math.sqrt(-2 * math.log(1 - random.nextDouble())) *
    math.cos(2 * math.pi * random.nextDouble());

final origin = DateTime.utc(2026);
DateTime at(double s) => origin.add(Duration(milliseconds: (s * 1000).round()));

/// Altitude after walking from outdoors to [height] above the room's floor.
AltitudeEstimate attempt({
  required double height,
  required double indoorSigma,
  required bool barometer,
}) {
  final filter = AltitudeFilter();
  const ground = -storeyM;
  var t = 0.0;
  var drift = 0.0;
  double pressure(double h) {
    final reference = pressureToAltitude(850);
    final sensed = reference + h + drift + 0.15 * gauss();
    return 1013.25 * math.pow(1 - sensed / 44330, 5.255);
  }

  if (barometer) {
    // The app is open outdoors, where GPS is good, and stays open indoors.
    final bias = outdoorSigma * gauss();
    for (var i = 0; i < 3; i++) {
      filter.addPressure(pressure(ground), at(t));
      filter.addGnss(
        ground + bias + 0.3 * outdoorSigma * gauss(),
        outdoorSigma,
        at(t),
      );
      t++;
    }
    for (var i = 1; i <= 180; i++) {
      drift += 0.05 * gauss(); // 3 m after one hour, as the filter assumes.
      final climbed = math.min(1.0, i / 60);
      filter.addPressure(pressure(ground + (height - ground) * climbed), at(t));
      t++;
    }
  }
  final bias = indoorSigma * gauss();
  for (var i = 0; i < 3; i++) {
    filter.addGnss(
      height + bias + 0.3 * indoorSigma * gauss(),
      indoorSigma,
      at(t),
    );
    t++;
  }
  return filter.estimate!;
}

void main() {
  stdout
    ..writeln(
      'Share of attempts accepted. $trials trials per cell, seed $seed.',
    )
    ..writeln();
  for (final band in const [HeightBand(8, 12), HeightBand(2, 2)]) {
    stdout
      ..writeln('Band -${band.below.round()} to +${band.above.round()} m')
      ..writeln()
      ..writeln(
        '| Altitude source | ${floors.map((f) => f == 0 ? 'Same floor' : '${f > 0 ? '+' : ''}$f').join(' | ')} |',
      )
      ..writeln('|---|${floors.map((_) => '---:').join('|')}|');
    for (final (label, sigma, barometer) in const [
      ('GPS only, 4 m', 4.0, false),
      ('GPS only, 10 m', 10.0, false),
      ('GPS 10 m + barometer', 10.0, true),
    ]) {
      final cells = floors.map((f) {
        var accepted = 0;
        for (var i = 0; i < trials; i++) {
          final e = attempt(
            height: f * storeyM,
            indoorSigma: sigma,
            barometer: barometer,
          );
          final h = e.metres - captureSigma * gauss();
          if (band.probability(h, e.sigma) >=
              const VolumetricCheck().acceptProbability) {
            accepted++;
          }
        }
        return '${(accepted * 100 / trials).toStringAsFixed(1)}%';
      });
      stdout.writeln('| $label | ${cells.join(' | ')} |');
    }
    stdout.writeln();
  }
}
