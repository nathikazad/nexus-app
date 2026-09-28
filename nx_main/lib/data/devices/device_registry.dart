import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:nx_db/auth.dart';

/// User-scoped management. Never uses the selected domain's HTTP client.
class DeviceRegistry {
  DeviceRegistry(this.user,
      {http.Client? client,
      Future<Map<String, String>> Function(bool)? headers})
      : _client = client ?? http.Client(),
        _headers = headers ??
            ((refresh) => nexusAuthHeaders(user.preset, user.userId,
                forceRefresh: refresh));
  final User user;
  final http.Client _client;
  final Future<Map<String, String>> Function(bool) _headers;
  bool _closed = false;

  Future<Map<String, dynamic>> _request(String method, String path,
      [Map<String, dynamic>? body]) async {
    for (var attempt = 0; attempt < 2; attempt++) {
      if (_closed) throw StateError('Device session closed');
      final headers = await _headers(attempt > 0);
      if (_closed) throw StateError('Device session closed');
      final request = http.Request(
          method, Uri.parse('${resolve(user.preset).imageHttp}$path'))
        ..headers.addAll(headers)
        ..headers['content-type'] = 'application/json';
      if (body != null) request.body = jsonEncode(body);
      final response =
          await http.Response.fromStream(await _client.send(request));
      if (_closed) throw StateError('Device session closed');
      if (response.statusCode == 401 &&
          attempt == 0 &&
          user.preset.requiresOidc) continue;
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StateError(
            'Device request failed (${response.statusCode}). Please retry.');
      }
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw StateError('Please log in again');
  }

  Future<List<Map<String, dynamic>>> list() async =>
      ((await _request('GET', '/v1/devices'))['devices'] as List)
          .cast<Map<String, dynamic>>();
  Future<Map<String, dynamic>> pair(String type) =>
      _request('POST', '/v1/devices', {'device_type': type});
  Future<Map<String, dynamic>> renewPairing(String id) =>
      _request('POST', '/v1/devices/$id');
  Future<void> revoke(String id) async {
    await _request('DELETE', '/v1/devices/$id');
  }

  void close() {
    _closed = true;
    _client.close();
  }
}
