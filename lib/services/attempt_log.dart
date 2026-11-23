import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../domain/volumetric_check.dart';
import '../venue.dart';
import 'volumetric_verifier.dart';

/// One logged 3D decision.
class Attempt {
  const Attempt(this.fields);
  final List<String> fields;

  String _at(String column) => fields[AttemptLog.columns.indexOf(column)];
  String get timestamp => _at('timestamp');
  String get source => _at('source');
  String get venue => _at('venue');
  String get expected => _at('expected');
  String get decision => _at('decision');
  String get height => _at('height_m');
  String get sigma => _at('sigma_m');
  String get note => _at('note');

  bool get accepted => decision == VolumetricDecision.inside.name;
}

/// Local CSV of every 3D decision, accepted or not, for evaluating accuracy.
/// It stays on the phone, and holds no coordinates or identities.
class AttemptLog {
  AttemptLog({Future<Directory> Function()? directory})
    : _directory = directory ?? getApplicationDocumentsDirectory;

  static final AttemptLog instance = AttemptLog();

  static const List<String> columns = [
    'timestamp',
    'source',
    'venue',
    'expected',
    'decision',
    'height_m',
    'sigma_m',
    'probability',
    'band_below_m',
    'band_above_m',
    'gps_altitude_m',
    'gps_altitude_accuracy_m',
    'pressure_hpa',
    'barometer_used',
    'horizontal_accuracy_m',
    'note',
  ];

  final Future<Directory> Function() _directory;

  Future<File> file() async =>
      File('${(await _directory()).path}/volumetric_attempts.csv');

  Future<void> add({
    required VolumetricReading reading,
    required Venue? venue,
    required String source,
    String expected = '',
    String note = '',
  }) {
    String n(double? v, [int digits = 2]) =>
        v == null || !v.isFinite ? '' : v.toStringAsFixed(digits);
    final band = venue == null ? null : HeightBand.forVenue(venue);
    final r = reading.result;
    return addRow([
      DateTime.now().toUtc().toIso8601String(),
      source,
      venue?.name ?? '',
      expected,
      r.decision.name,
      n(r.heightM),
      n(r.sigmaM),
      n(r.probability, 4),
      n(band?.below),
      n(band?.above),
      n(reading.position.altitude),
      n(reading.position.altitudeAccuracy),
      n(reading.pressureHpa),
      '${reading.altitude?.usedBarometer ?? false}',
      n(reading.position.accuracy),
      note,
    ]);
  }

  Future<void> addRow(List<String> row) async {
    final f = await file();
    final header = await f.exists() ? '' : '${columns.join(',')}\n';
    await f.writeAsString(
      '$header${row.map(_escape).join(',')}\n',
      mode: FileMode.append,
      flush: true,
    );
  }

  Future<List<Attempt>> load() async {
    final f = await file();
    if (!await f.exists()) return [];
    return [
      for (final line in (await f.readAsLines()).skip(1))
        if (_parse(line) case final fields when fields.length == columns.length)
          Attempt(fields),
    ];
  }

  /// Newlines are removed so that one line is always one row.
  static String _escape(String value) {
    var v = value.replaceAll(RegExp(r'[\r\n]+'), ' ');
    // Typed text must not run as a formula in a spreadsheet. A negative number
    // is not a formula.
    if (RegExp(r'^[=+\-@\t]').hasMatch(v) && double.tryParse(v) == null) {
      v = "'$v";
    }
    return v.contains(RegExp('[",]')) ? '"${v.replaceAll('"', '""')}"' : v;
  }

  static List<String> _parse(String line) {
    final out = <String>[];
    final cell = StringBuffer();
    var quoted = false;
    for (var i = 0; i < line.length; i++) {
      final c = line[i];
      if (quoted) {
        if (c != '"') {
          cell.write(c);
        } else if (i + 1 < line.length && line[i + 1] == '"') {
          cell.write('"');
          i++;
        } else {
          quoted = false;
        }
      } else if (c == '"') {
        quoted = true;
      } else if (c == ',') {
        out.add(cell.toString());
        cell.clear();
      } else {
        cell.write(c);
      }
    }
    return out..add(cell.toString());
  }
}
