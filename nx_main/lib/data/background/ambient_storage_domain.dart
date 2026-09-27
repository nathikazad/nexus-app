import 'dart:convert';
import 'package:http/http.dart' as http;

/// HTTP telemetry still needs explicit storage scope, independent of app selection.
Future<int> loadAmbientStorageDomain({
  required String httpBaseUrl,
  required Future<Map<String, String>> Function(bool) authHeaders,
  http.Client? client,
}) async {
  final transport = client ?? http.Client();
  try {
    var response = await transport
        .get(Uri.parse('$httpBaseUrl/v1/domains'),
            headers: await authHeaders(false))
        .timeout(const Duration(seconds: 15));
    if (response.statusCode == 401) {
      response = await transport
          .get(Uri.parse('$httpBaseUrl/v1/domains'),
              headers: await authHeaders(true))
          .timeout(const Duration(seconds: 15));
    }
    if (response.statusCode != 200) {
      throw StateError(
          'Personal storage lookup failed (${response.statusCode}).');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final personal = (payload['domains'] as List)
        .where(
            (d) => d is Map && d['kind'] == 'personal' && d['role'] == 'owner')
        .toList();
    if (personal.length != 1 ||
        personal.single['id'] is! int ||
        personal.single['id'] <= 0) {
      throw StateError(
          'Exactly one owned personal domain is required for device storage.');
    }
    return personal.single['id'] as int;
  } finally {
    if (client == null) transport.close();
  }
}
