import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:nx_db/auth.dart';
import 'package:nx_notes/application/ports/session_store.dart';
import 'package:nx_notes/application/session/offline_session_restorer.dart';

class HttpSessionProbe {
  HttpSessionProbe({
    http.Client? client,
    this.timeout = const Duration(seconds: 2),
  }) : _client = client ?? http.Client(),
       _ownsClient = client == null;

  final http.Client _client;
  final bool _ownsClient;
  final Duration timeout;

  Future<SessionProbeResult> call(CachedSession session) async {
    final preset = BackendPreset.fromKey(session.backendPreset);
    if (preset == null) return SessionProbeResult.unauthorized;
    try {
      final response = await _client
          .post(
            Uri.parse(resolve(preset).graphqlHttp),
            headers: <String, String>{
              'Content-Type': 'application/json',
              ...buildHttpLinkDefaultHeaders(
                resolve(preset).graphqlHttp,
                session.userId,
              ),
            },
            body: jsonEncode(const <String, String>{'query': '{ __typename }'}),
          )
          .timeout(timeout);
      if (response.statusCode == 401 || response.statusCode == 403) {
        return SessionProbeResult.unauthorized;
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return SessionProbeResult.unreachable;
      }
      return SessionProbeResult.available;
    } on TimeoutException {
      return SessionProbeResult.unreachable;
    } catch (_) {
      return SessionProbeResult.unreachable;
    }
  }

  void close() {
    if (_ownsClient) _client.close();
  }
}
