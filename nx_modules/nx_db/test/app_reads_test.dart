import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nx_db/app_reads.dart';

void main() {
  test(
    'live reads deduplicate, page only on demand, and invalidate after changes',
    () async {
      final requests = <Uri>[];
      final reads = AppReads(
        MockClient((request) async {
          requests.add(request.url);
          final second = request.url.queryParameters['cursor'] == 'next';
          return http.Response(
            jsonEncode({
              'items': [
                {'id': second ? 2 : 1},
              ],
              'next_cursor': second ? null : 'next',
            }),
            200,
          );
        }),
        Uri.parse('https://example.test'),
        'docs',
      );
      addTearDown(reads.close);
      expect(await reads.items(limit: 1), [
        {'id': 1},
      ]);
      expect(requests, hasLength(1));
      await reads.items(limit: 1);
      expect(requests, hasLength(1));
      reads.invalidate();
      expect((await reads.items()).map((r) => r['id']), [1, 2]);
      expect(requests.last.queryParameters['cursor'], 'next');
    },
  );
  test('Chinese invalidation does not refetch Malayalam', () async {
    var calls = 0;
    final reads = AppReads(
      MockClient((request) async {
        calls++;
        return http.Response('{"items":[],"next_cursor":null}', 200);
      }),
      Uri.parse('https://example.test'),
      'cards',
    );
    addTearDown(reads.close);
    Map<String, dynamic> groups(String hash) => {
      'tag:1': {
        'hash': hash,
        'metadata': {'kind': 'Language', 'name': 'Chinese'},
      },
      'tag:2': {
        'hash': 'same',
        'metadata': {'kind': 'Language', 'name': 'Malayalam'},
      },
    };
    final chinese = {'tag_system': 'Language', 'tag': 'Chinese'};
    final malayalam = {'tag_system': 'Language', 'tag': 'Malayalam'};
    await reads.items(query: chinese);
    await reads.items(query: malayalam);
    reads.invalidateChanges(groups('one'), groups('two'));
    await reads.items(query: malayalam);
    expect(calls, 2);
    await reads.items(query: chinese);
    expect(calls, 3);
  });
  test('errors remain retryable and missing items are explicit', () async {
    var status = 404;
    final reads = AppReads(
      MockClient((_) async => http.Response('{}', status)),
      Uri.parse('https://example.test'),
      'books',
    );
    addTearDown(reads.close);
    await expectLater(
      reads.read('1'),
      throwsA(
        isA<AppReadException>().having((e) => e.statusCode, 'status', 404),
      ),
    );
    status = 200;
    expect(await reads.read('1'), isEmpty);
  });
}
