import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../core/config/backend_presets.dart';
import 'oidc_service.dart';

/// Adds the correct Nexus identity to every HTTP request.
///
/// Hosted requests use a short-lived bearer token and get exactly one forced
/// refresh/retry after a 401. Direct Pi/development requests retain the legacy
/// trusted `x-user-id` header until direct mode is retired.
class NexusAuthenticatedClient extends http.BaseClient {
  NexusAuthenticatedClient({
    required this.preset,
    required this.userId,
    http.Client? inner,
    Future<Map<String, String>> Function(bool forceRefresh)? authHeaders,
  }) : _inner = inner ?? http.Client(),
       _authHeaders =
           authHeaders ??
           ((forceRefresh) =>
               nexusAuthHeaders(preset, userId, forceRefresh: forceRefresh));

  final BackendPreset preset;
  final String userId;
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
    final copy = http.Request(original.method, original.url)
      ..followRedirects = original.followRedirects
      ..maxRedirects = original.maxRedirects
      ..persistentConnection = original.persistentConnection
      ..headers.addAll(original.headers)
      ..bodyBytes = body;
    copy.headers.remove('x-user-id');
    copy.headers.remove('authorization');
    copy.headers.addAll(await _authHeaders(forceRefresh));
    return _inner.send(copy);
  }

  @override
  void close() => _inner.close();
}
