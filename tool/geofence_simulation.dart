// Monte-Carlo comparison of geofence rules. Reproducible: the seed is fixed.
//
//   dart run tool/geofence_simulation.dart
//
// Model. A student stands at a true distance d from the centre of a circular
// fence. The fix is displaced by isotropic Gaussian error and the phone reports
// a radius that contains the truth 68% of the time, as Android documents. For
// such an error the 68% radius is sigma * sqrt(-2 ln 0.32).
// `misreport` scales the reported radius to model an over-confident phone.
import 'dart:io';
import 'dart:math' as math;

import 'package:campus_register/domain/geofence.dart';

const radiusM = 100.0;
const trials = 200000;
const seed = 20260206;

final k68 = math.sqrt(-2 * math.log(0.32));

class Scenario {
  const Scenario(this.label, this.accuracyM, [this.misreport = 1]);
  final String label;

  /// True 68% error radius.
  final double accuracyM;
  final double misreport;
}

class Rates {
  const Rates(this.naive, this.aware, this.uncertain);

  /// Fraction accepted when only the point estimate is compared.
  final double naive;

  /// Fraction accepted by the uncertainty-aware rule.
  final double aware;

  /// Fraction the uncertainty-aware rule declines to decide.
  final double uncertain;
}

Rates simulate(
  math.Random random,
  Scenario s, {
  required double from,
  required double to,
}) {
  final sigma = s.accuracyM / k68;
  final reported = s.accuracyM * s.misreport;
  var naive = 0, aware = 0, uncertain = 0;
  for (var i = 0; i < trials; i++) {
    // Uniform over the area of the annulus [from, to].
    final u = random.nextDouble();
    final d = math.sqrt(from * from + u * (to * to - from * from));
    final r = sigma * math.sqrt(-2 * math.log(1 - random.nextDouble()));
    final theta = 2 * math.pi * random.nextDouble();
    final x = d + r * math.cos(theta);
    final y = r * math.sin(theta);
    final estimate = math.sqrt(x * x + y * y);
    if (estimate <= radiusM) naive++;
    switch (classifyFence(
      distanceM: estimate,
      accuracyM: reported,
      radiusM: radiusM,
    )) {
      case FenceResult.inside:
        aware++;
      case FenceResult.uncertain:
        uncertain++;
      case FenceResult.outside:
        break;
    }
  }
  return Rates(naive / trials, aware / trials, uncertain / trials);
}

void main() {
  const scenarios = [
    Scenario('Open sky, 5 m', 5),
    Scenario('Urban, 15 m', 15),
    Scenario('Indoors, 30 m', 30),
    Scenario('Deep indoors, 50 m', 50),
    Scenario('Indoors 30 m, reported as 15 m', 30, 0.5),
  ];
  String pct(double v) => '${(v * 100).toStringAsFixed(2)}%';
  final out = StringBuffer()
    ..writeln(
      'Fence radius ${radiusM.round()} m, $trials trials per cell, seed $seed.',
    )
    ..writeln(
      'Outside = uniform over 100-150 m; inside = uniform over 0-100 m.',
    )
    ..writeln()
    ..writeln(
      '| Error (68% radius) | FAR naive | FAR aware | FRR naive | FRR aware '
      '| of which "uncertain" |',
    )
    ..writeln('|---|---:|---:|---:|---:|---:|');
  final random = math.Random(seed);
  for (final s in scenarios) {
    final outside = simulate(random, s, from: radiusM, to: 150);
    final inside = simulate(random, s, from: 0, to: radiusM);
    out.writeln(
      '| ${s.label} | ${pct(outside.naive)} | ${pct(outside.aware)} '
      '| ${pct(1 - inside.naive)} | ${pct(1 - inside.aware)} '
      '| ${pct(inside.uncertain)} |',
    );
  }
  stdout.write(out);
}
