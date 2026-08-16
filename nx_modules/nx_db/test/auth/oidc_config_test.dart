import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nx_db/auth.dart';

void main() {
  test('parses hosted public OIDC discovery without a client secret', () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/v1/auth/config');
      return http.Response(
        jsonEncode({
          'mode': 'oidc',
          'issuer': 'https://auth.example.com',
          'client_id': 'native-client',
          'redirect_uri': 'nexus://oauth/callback',
          'logout_uri': 'nexus://oauth/logout',
          'scopes': ['openid', 'offline_access', 'nexus-api'],
        }),
        200,
      );
    });

    final config = await fetchNexusOidcConfig(
      BackendPreset.piWan,
      client: client,
    );

    expect(config.issuer, Uri.parse('https://auth.example.com'));
    expect(config.clientId, 'native-client');
    expect(config.scopes, contains('offline_access'));
  });

  test('rejects direct-mode config when OIDC is requested', () async {
    final client = MockClient(
      (_) async => http.Response(jsonEncode({'mode': 'direct'}), 200),
    );

    expect(
      fetchNexusOidcConfig(BackendPreset.piWan, client: client),
      throwsA(isA<Exception>()),
    );
  });

  test('rejects insecure issuer metadata', () {
    expect(
      () => NexusOidcConfig.fromJson({
        'issuer': 'http://auth.example.com',
        'client_id': 'native-client',
        'redirect_uri': 'nexus://oauth/callback',
        'logout_uri': 'nexus://oauth/logout',
        'scopes': ['openid'],
      }),
      throwsFormatException,
    );
  });
}
