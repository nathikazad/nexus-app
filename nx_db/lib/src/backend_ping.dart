import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'graphql_http_config.dart';

/// Max time to wait for the GraphQL HTTP ping during login.
const Duration kBackendLoginPingTimeout = Duration(seconds: 2);

/// POSTs a minimal GraphQL document to [graphqlHttpUrl] with the same headers
/// as the app’s GraphQL client. Throws [Exception] with a short message if the
/// server is unreachable or returns an error.
Future<void> pingGraphqlBackend({
  required String graphqlHttpUrl,
  required String userId,
  Duration timeout = kBackendLoginPingTimeout,
}) async {
  final ep = normalizeHttpEndpointForCf(graphqlHttpUrl);
  final uri = Uri.parse(ep);
  final headers = <String, String>{
    'Content-Type': 'application/json',
    ...buildHttpLinkDefaultHeaders(ep, userId),
  };

  print('[BackendPing] POST $uri (timeout=${timeout.inSeconds}s)');

  late http.Response response;
  try {
    response = await http
        .post(
          uri,
          headers: headers,
          body: jsonEncode(const {'query': '{ __typename }'}),
        )
        .timeout(timeout);
  } on TimeoutException catch (e) {
    print('[BackendPing] timeout after ${timeout.inSeconds}s: $e');
    throw Exception(
      'Server did not respond within ${timeout.inSeconds}s. '
      'Check network and backend preset.',
    );
  } catch (e) {
    print('[BackendPing] request failed: $e');
    throw Exception('Cannot reach server: $e');
  }

  print(
    '[BackendPing] response status=${response.statusCode} '
    'bytes=${response.body.length}',
  );
  print('[BackendPing] body: ${response.body}');

  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw Exception(
      'Server returned HTTP ${response.statusCode}. '
      'Check that GraphQL is running at this preset.',
    );
  }

  dynamic decoded;
  try {
    decoded = jsonDecode(response.body);
  } catch (_) {
    throw Exception('Server did not return valid JSON (not a GraphQL endpoint?)');
  }

  if (decoded is Map && decoded['errors'] != null) {
    print('[BackendPing] GraphQL errors: ${decoded['errors']}');
    throw Exception('GraphQL error: ${decoded['errors']}');
  }

  print('[BackendPing] OK (parsed JSON, no GraphQL errors)');
}
