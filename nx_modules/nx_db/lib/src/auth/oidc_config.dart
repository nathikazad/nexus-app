import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/config/backend_presets.dart';

class NexusOidcConfig {
  const NexusOidcConfig({
    required this.issuer,
    required this.clientId,
    required this.redirectUri,
    required this.logoutUri,
    required this.audience,
    required this.allowedAudiences,
    required this.scopes,
  });

  final Uri issuer;
  final String clientId;
  final Uri redirectUri;
  final Uri logoutUri;
  final String audience;
  final List<String> allowedAudiences;
  final List<String> scopes;

  static NexusOidcConfig fromJson(
    Map<String, dynamic> json, {
    required String clientAppId,
  }) {
    final issuer = Uri.parse(json['issuer'] as String? ?? '');
    final redirectUri = Uri.parse(json['redirect_uri'] as String? ?? '');
    final logoutUri = Uri.parse(json['logout_uri'] as String? ?? '');
    final clientId = json['client_id'] as String? ?? '';
    final audience = json['audience'] as String? ?? '';
    final allowedAudiences =
        (json['allowed_audiences'] as List<dynamic>? ?? const [])
            .whereType<String>()
            .toList(growable: false);
    final scopes = (json['scopes'] as List<dynamic>? ?? const [])
        .whereType<String>()
        .toList(growable: false);
    final expectedScheme = clientAppId.replaceAll('_', '-');
    if (json['app_id'] != clientAppId ||
        issuer.scheme != 'https' ||
        clientId.isEmpty ||
        audience.isEmpty ||
        !allowedAudiences.contains(audience) ||
        redirectUri.scheme != expectedScheme ||
        logoutUri.scheme != expectedScheme ||
        !scopes.contains('openid')) {
      throw const FormatException(
        'Nexus returned an invalid OIDC configuration',
      );
    }
    return NexusOidcConfig(
      issuer: issuer,
      clientId: clientId,
      redirectUri: redirectUri,
      logoutUri: logoutUri,
      audience: audience,
      allowedAudiences: allowedAudiences,
      scopes: scopes,
    );
  }
}

Future<NexusOidcConfig> fetchNexusOidcConfig(
  BackendPreset preset, {
  required String clientAppId,
  http.Client? client,
}) async {
  final ownedClient = client == null;
  final httpClient = client ?? http.Client();
  try {
    final uri = Uri.parse(
      '${resolve(preset).imageHttp}/v1/auth/config',
    ).replace(queryParameters: {'app': clientAppId});
    final response = await httpClient
        .get(uri)
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw Exception(
        'Authentication configuration is unavailable (${response.statusCode})',
      );
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    if (json['mode'] != 'oidc') {
      throw Exception('This backend does not provide OIDC authentication');
    }
    return NexusOidcConfig.fromJson(json, clientAppId: clientAppId);
  } finally {
    if (ownedClient) httpClient.close();
  }
}
