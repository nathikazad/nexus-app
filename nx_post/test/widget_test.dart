import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:nx_db/auth.dart';
import 'package:nx_db/riverpod.dart';
import 'package:nx_post/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('reads only tags from the requested public system', () {
    expect(
      tagsForSystem({
        'Topic': ['Business', 'Spiritual', 'Business'],
        'Category': ['Activity'],
      }, kDocumentTopicTagSystem),
      ['Business', 'Spiritual'],
    );

    expect(
      tagsForSystem({
        'Topic': ['Ignored'],
        'Category': ['Activity', 'Quotes', 'Activity'],
      }, kMicroblogCategoryTagSystem),
      ['Activity', 'Quotes'],
    );
  });

  test('microblog content hash normalizes Category tags', () {
    final first = microblogContentHash(
      text: 'hello',
      media: const [],
      categories: const ['Quotes', 'Activity', 'Activity'],
    );
    final second = microblogContentHash(
      text: 'hello',
      media: const [],
      categories: const ['Activity', 'Quotes'],
    );
    final untagged = microblogContentHash(
      text: 'hello',
      media: const [],
      categories: const [],
    );

    expect(first, second);
    expect(first, isNot(untagged));
  });

  test('microblog repository uses MCP microblog endpoints', () async {
    final requests = <http.BaseRequest>[];
    final client = _RecordingClient((request) async {
      requests.add(request);
      if (request is http.MultipartRequest) {
        expect(request.headers['x-user-id'], '7');
        expect(request.fields['text'], isNotEmpty);
        expect(request.fields['categories'], isNotNull);
      }
      return http.Response(
        jsonEncode({
          'ok': true,
          'microblog_id': 4627,
          'publish': {
            'enabled': true,
            'status': 'succeeded',
            'last_error': null,
          },
          'x_sync': {'enabled': false, 'status': 'skipped'},
          'warnings': [],
        }),
        200,
      );
    });
    final repository = MicroblogPostRepository(
      'http://mcp.local',
      graphqlUrl: 'http://graphql.local/graphql',
      userId: '7',
      client: client,
    );

    await repository.createMicroblog(
      text: 'hello',
      postedAt: DateTime.utc(2026, 7, 9),
      mediaUrl: '',
      images: const [],
      categories: const ['Activity'],
      publishEnabled: true,
      xSyncEnabled: true,
    );
    await repository.updateMicroblog(
      id: 4627,
      text: 'edited',
      postedAt: DateTime.utc(2026, 7, 9),
      mediaUrl: '',
      existingMedia: const [],
      images: const [],
      categories: const ['Reflection'],
      publishEnabled: true,
    );
    await repository.deleteMicroblog(4627);

    expect(requests.map((request) => request.method), [
      'POST',
      'PUT',
      'DELETE',
    ]);
    expect(requests.map((request) => request.url.path), [
      '/microblogs',
      '/microblogs/4627',
      '/microblogs/4627',
    ]);
  });

  testWidgets('renders feed shell and opens compose sheet', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(
            () => AuthController(
              initialDelay: Duration.zero,
              skipBackendPing: true,
            ),
          ),
          dbAuditSourceKindProvider.overrideWithValue('nx_post'),
        ],
        child: const NexusPostApp(),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('nx_post'), findsOneWidget);
    expect(find.text('Log In'), findsOneWidget);

    await tester.tap(find.text('Log In'));
    await tester.pump();

    expect(find.text('Feed'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(find.text('New microblog'), findsOneWidget);
    expect(find.text('Save microblog'), findsOneWidget);
  });
}

class _RecordingClient extends http.BaseClient {
  _RecordingClient(this.handler);

  final FutureOr<http.Response> Function(http.BaseRequest request) handler;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await handler(request);
    return http.StreamedResponse(
      Stream<List<int>>.value(response.bodyBytes),
      response.statusCode,
      headers: response.headers,
      request: request,
      reasonPhrase: response.reasonPhrase,
    );
  }
}
