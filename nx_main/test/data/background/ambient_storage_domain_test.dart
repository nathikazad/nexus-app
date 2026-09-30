import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nexus_voice_assistant/data/background/ambient_storage_domain.dart';

void main() {
  test('storage resolves personal even when shared domain is first', () async {
    final client = MockClient((request) async {
      expect(request.headers.containsKey('x-domain-id'), isFalse);
      return http.Response(
          jsonEncode({
            'domains': [
              {'id': 8, 'kind': 'shared', 'role': 'owner'},
              {'id': 9, 'kind': 'personal', 'role': 'owner'}
            ]
          }),
          200);
    });
    expect(
        await loadAmbientStorageDomain(
            httpBaseUrl: 'https://test',
            authHeaders: (_) async => {'authorization': 'Bearer test'},
            client: client),
        9);
  });
  test('ambiguous or absent personal domain fails closed', () async {
    for (final domains in [
      [],
      [
        {'id': 1, 'kind': 'shared', 'role': 'owner'}
      ],
      [
        {'id': 1, 'kind': 'personal', 'role': 'owner'},
        {'id': 2, 'kind': 'personal', 'role': 'owner'}
      ]
    ]) {
      await expectLater(
          loadAmbientStorageDomain(
              httpBaseUrl: 'https://test',
              authHeaders: (_) async => {},
              client: MockClient((_) async =>
                  http.Response(jsonEncode({'domains': domains}), 200))),
          throwsStateError);
    }
  });
  test('unauthorized lookup retries with refreshed authentication', () async {
    final refreshed = <bool>[];
    var calls = 0;
    final id = await loadAmbientStorageDomain(
        httpBaseUrl: 'https://test',
        authHeaders: (refresh) async {
          refreshed.add(refresh);
          return {};
        },
        client: MockClient((_) async {
          if (++calls == 1) return http.Response('', 401);
          return http.Response(
              '{"domains":[{"id":3,"kind":"personal","role":"owner"}]}', 200);
        }));
    expect(id, 3);
    expect(refreshed, [false, true]);
  });
}
