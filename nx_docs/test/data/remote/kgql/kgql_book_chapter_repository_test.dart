import 'package:flutter_test/flutter_test.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nx_docs/data/remote/kgql/kgql_book_chapter_repository.dart';

final class _MockGraphQLClient extends Mock implements GraphQLClient {}

void main() {
  setUpAll(() {
    registerFallbackValue(QueryOptions(document: gql('query { __typename }')));
  });

  test(
    'loads ordered Book Chapter summaries and only selected bodies',
    () async {
      final client = _MockGraphQLClient();
      when(() => client.query(any())).thenAnswer((invocation) async {
        final options = invocation.positionalArguments.single as QueryOptions;
        final filter = options.variables['filter']! as Map<String, dynamic>;
        final modelType = filter['model_type'];
        if (modelType == kBookModelTypeName) {
          return _result(<String, Object?>{
            'getKgqlModels': <Object?>[
              <String, Object?>{
                'id': 7,
                'name': 'A Book',
                'model_type_id': 1,
                kBookChapterModelTypeName: <Object?>[
                  <String, Object?>{
                    'id': 12,
                    'name': 'Second',
                    'description': 'Second summary',
                    'model_type_id': 2,
                    kBookChapterNumberAttribute: 2,
                  },
                  <String, Object?>{
                    'id': 10,
                    'name': 'First',
                    'description': 'First summary',
                    'model_type_id': 2,
                    kBookChapterNumberAttribute: 1,
                  },
                ],
              },
            ],
          });
        }
        final filters = filter['filters']! as List<dynamic>;
        final chapterId = int.parse(
          ((filters.single as Map<String, dynamic>)['value']).toString(),
        );
        return _result(<String, Object?>{
          'getKgqlModels': <Object?>[
            <String, Object?>{
              'id': chapterId,
              'name': chapterId == 10 ? 'First' : 'Second',
              'model_type_id': 2,
              kBookChapterNumberAttribute: chapterId == 10 ? 1 : 2,
              'document': chapterId == 10 ? 'First body' : 'Second body',
            },
          ],
        });
      });

      final repository = KgqlBookChapterRepository(client);
      final summaries = await repository.listChapters(7);
      expect(summaries.map((chapter) => chapter.id), <int>[10, 12]);

      final chapters = await repository.loadSelectedChapters(
        bookId: 7,
        chapterIds: const <int>{12},
      );
      expect(chapters.single.id, 12);
      expect(chapters.single.content, 'Second body');
      verify(() => client.query(any())).called(2);
    },
  );

  test('rejects a selected chapter outside the Book relation', () async {
    final client = _MockGraphQLClient();
    when(() => client.query(any())).thenAnswer(
      (_) async => _result(<String, Object?>{
        'getKgqlModels': <Object?>[
          <String, Object?>{
            'id': 7,
            'name': 'A Book',
            'model_type_id': 1,
            kBookChapterModelTypeName: <Object?>[],
          },
        ],
      }),
    );
    final repository = KgqlBookChapterRepository(client);

    await expectLater(
      repository.loadSelectedChapters(bookId: 7, chapterIds: const <int>{99}),
      throwsStateError,
    );
  });
}

QueryResult<Object?> _result(Map<String, Object?> data) => QueryResult<Object?>(
  options: QueryOptions(document: gql('query { __typename }')),
  source: QueryResultSource.network,
  data: data,
);
