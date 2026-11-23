import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/attendance_event.dart';

enum SyncStatus { ok, notConfigured, offline, rejected }

class SyncResult {
  const SyncResult(this.status, [this.detail]);
  final SyncStatus status;
  final String? detail;
}

class GoogleSheetsApi {
  GoogleSheetsApi({
    required this._url,
    this._token = '',
    http.Client? client,
    this._timeout = const Duration(seconds: 15),
  }) : _client = client ?? http.Client();

  final String _url;
  final String _token;
  final Duration _timeout;
  final http.Client _client;

  bool get isConfigured => _url.isNotEmpty;

  Future<SyncResult> send(AttendanceEvent event) async {
    if (!isConfigured) return const SyncResult(SyncStatus.notConfigured);
    try {
      final uri = Uri.parse(_url);
      final request = http.Request('POST', uri)
        ..followRedirects = false
        ..headers['Content-Type'] = 'application/json'
        ..body = jsonEncode({'token': _token, 'event': event.toJson()});
      var response = await _client
          .send(request)
          .then(http.Response.fromStream)
          .timeout(_timeout);

      // Apps Script runs the POST, then answers with a 302 to the output. Dart
      // does not follow redirects for POST, so fetch the output with a GET.
      final location = response.headers['location'];
      if (response.statusCode == 302 && location != null) {
        response = await _client.get(uri.resolve(location)).timeout(_timeout);
      }
      if (response.statusCode != 200) {
        return SyncResult(SyncStatus.offline, 'HTTP ${response.statusCode}');
      }
      // Apps Script answers 200 even for failures, so the body decides.
      final body = jsonDecode(response.body);
      if (body is Map && body['ok'] == true) {
        return const SyncResult(SyncStatus.ok);
      }
      return SyncResult(
        SyncStatus.rejected,
        body is Map ? '${body['error']}' : 'unexpected response',
      );
    } on FormatException {
      return const SyncResult(SyncStatus.rejected, 'response was not JSON');
    } on TimeoutException {
      return const SyncResult(SyncStatus.offline, 'timed out');
    } catch (e) {
      return SyncResult(SyncStatus.offline, '${e.runtimeType}');
    }
  }
}
