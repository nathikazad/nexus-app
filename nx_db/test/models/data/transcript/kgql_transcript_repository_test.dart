@Tags(['repository'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nx_db/internal.dart';
import 'package:nx_db/transcript.dart';
import 'package:test/test.dart' show Tags;

import '../../../_support/mock_graphql_client.dart';

void main() {
  setUpAll(registerGraphqlFallbacks);

  group('kgql_transcript_repository', () {
    test('PX10.1 getCurrentTranscript query shape', () {
      expect(getCurrentTranscriptQuery, contains('getCurrentTranscript'));
      expect(getCurrentTranscriptQuery, contains(r'$userIdParam'));
      expect(getCurrentTranscriptQuery, contains('userIdParam'));
    });

    test('PX10.3 unauthenticated getCurrent throws', () async {
      final mock = MockGraphQLClient();
      final repo = KgqlTranscriptRepository(
        client: mock,
        currentUserId: () => throw StateError('Not authenticated'),
      );
      await expectLater(
        repo.getCurrent(),
        throwsA(
          isA<StateError>().having(
            (e) => e.toString(),
            'msg',
            contains('Not authenticated'),
          ),
        ),
      );
    });

    test('getCurrent issues query with user id', () async {
      final mock = MockGraphQLClient();
      QueryOptions? captured;
      when(() => mock.query(any())).thenAnswer((inv) async {
        captured = inv.positionalArguments[0] as QueryOptions;
        return QueryResult(
          options: QueryOptions(document: gql('query { x }')),
          source: QueryResultSource.network,
          data: {
            'getCurrentTranscript': null,
          },
        );
      });
      final repo = KgqlTranscriptRepository(
        client: mock,
        currentUserId: () => 7,
      );
      await repo.getCurrent();
      expect(captured, isNotNull);
      expect(captured!.variables['userIdParam'], 7);
      verify(() => mock.query(any())).called(1);
    });

    test('PX10.4 addMessageToTranscript mutation shape', () {
      expect(
          addMessageToTranscriptMutation, contains('addMessageToTranscript'));
      expect(addMessageToTranscriptMutation, contains(r'$input'));
      expect(
        addMessageToTranscriptMutation,
        contains('AddMessageToTranscriptInput'),
      );
    });

    test('transcriptMessageAddedSubscription shape', () {
      expect(transcriptMessageAddedSubscription,
          contains('transcriptMessageAdded'));
      expect(transcriptMessageAddedSubscription, contains(r'$transcriptId'));
    });
  });
}
