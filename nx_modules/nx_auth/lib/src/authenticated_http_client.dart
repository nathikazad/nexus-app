import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'backend_presets.dart';
import 'oidc_service.dart';

/// Adds the correct Nexus identity to every HTTP request.
class NexusAuthenticatedClient extends http.BaseClient {
  NexusAuthenticatedClient({
    required this.preset,
    required this.userId,
    this.domainId,
    http.Client? inner,
    Future<Map<String, String>> Function(bool forceRefresh)? authHeaders,
  }) : _inner = inner ?? http.Client(),
       _authHeaders =
           authHeaders ??
           ((forceRefresh) =>
               nexusAuthHeaders(preset, userId, forceRefresh: forceRefresh));

  bool _closed = false;
  final BackendPreset preset;
  final String userId;
  final int? domainId;
  final http.Client _inner;
  final Future<Map<String, String>> Function(bool forceRefresh) _authHeaders;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final body = await request.finalize().toBytes();
    final first = await _sendCopy(request, body, forceRefresh: false);
    if (!preset.requiresOidc || first.statusCode != 401) return first;
    await first.stream.drain<void>();
    return _sendCopy(request, body, forceRefresh: true);
  }

  Future<http.StreamedResponse> _sendCopy(
    http.BaseRequest original,
    Uint8List body, {
    required bool forceRefresh,
  }) async {
    if (_closed) throw StateError('Domain session closed');
    final copy = http.Request(original.method, original.url)
      ..followRedirects = original.followRedirects
      ..maxRedirects = original.maxRedirects
      ..persistentConnection = original.persistentConnection
      ..headers.addAll(original.headers)
      ..bodyBytes = body;
    copy.headers.remove('x-user-id');
    copy.headers.remove('authorization');
    copy.headers.addAll(await _authHeaders(forceRefresh));
    if (_closed) throw StateError('Domain session closed');
    if (domainId != null) copy.headers['x-nexus-domain-id'] = '$domainId';
    return _inner.send(copy);
  }

  @override
  void close() {
    _closed = true;
    _inner.close();
  }
}
