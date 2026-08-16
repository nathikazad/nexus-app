import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nx_db/auth.dart';

void main() {
  test('parses hosted public OIDC discovery without a client secret', () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/v1/auth/config');
      expect(request.url.queryParameters['app'], 'nx_docs');
      return http.Response(
        jsonEncode({
          'mode': 'oidc',
          'app_id': 'nx_docs',
          'issuer': 'https://auth.example.com',
          'client_id': 'native-client',
          'redirect_uri': 'nx-docs://oauth/callback',
          'logout_uri': 'nx-docs://oauth/logout',
          'audience': 'project-1',
          'allowed_audiences': ['project-1', 'resource-api', 'native-client'],
          'scopes': ['openid', 'offline_access', 'nexus-api'],
        }),
        200,
      );
    });

    final config = await fetchNexusOidcConfig(
      BackendPreset.piWan,
      clientAppId: 'nx_docs',
      client: client,
    );

    expect(config.issuer, Uri.parse('https://auth.example.com'));
    expect(config.clientId, 'native-client');
    expect(config.audience, 'project-1');
    expect(config.allowedAudiences, contains('resource-api'));
    expect(config.scopes, contains('offline_access'));
  });

  test('rejects direct-mode config when OIDC is requested', () async {
    final client = MockClient(
      (_) async => http.Response(jsonEncode({'mode': 'direct'}), 200),
    );

    expect(
      fetchNexusOidcConfig(
        BackendPreset.piWan,
        clientAppId: 'nx_docs',
        client: client,
      ),
      throwsA(isA<Exception>()),
    );
  });

  test('rejects insecure issuer metadata', () {
    expect(
      () => NexusOidcConfig.fromJson({
        'app_id': 'nx_docs',
        'issuer': 'http://auth.example.com',
        'client_id': 'native-client',
        'redirect_uri': 'nx-docs://oauth/callback',
        'logout_uri': 'nx-docs://oauth/logout',
        'audience': 'project-1',
        'allowed_audiences': ['project-1'],
        'scopes': ['openid'],
      }, clientAppId: 'nx_docs'),
      throwsFormatException,
    );
  });
}
