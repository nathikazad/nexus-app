import 'package:flutter_test/flutter_test.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nx_db/kgql.dart';
import 'package:nx_docs/documents/data/kgql/kgql_document_repository.dart';

final class _MockGraphQLClient extends Mock implements GraphQLClient {}

void main() {
  setUpAll(() {
    registerFallbackValue(QueryOptions(document: gql('query { __typename }')));
  });

  test(
    'general document listings are completed by a separate Book query',
    () async {
      final client = _MockGraphQLClient();
      when(() => client.query(any())).thenAnswer((invocation) async {
        final options = invocation.positionalArguments.single as QueryOptions;
        final filter = options.variables['filter']! as Map<String, dynamic>;
        final isBookQuery = filter['model_type'] == 'Book';
        return _result(<String, Object?>{
          'getKgqlModels': isBookQuery
              ? <Object?>[
                  _model(
                    id: 2,
                    name: 'Complete Book',
                    modelType: 'Book',
                    readingState: 'reading',
                    rank: 4,
                  ),
                ]
              : <Object?>[
                  _model(id: 1, name: 'Document', modelType: 'Document'),
                  _model(id: 2, name: 'Incomplete Book', modelType: 'Book'),
                ],
        });
      });
      final repository = KgqlDocumentRepository(
        client: client,
        loadDocumentSchema: _unusedSchema,
        loadDocumentSnapSchema: _unusedSchema,
      );

      final rows = await repository.listAll();

      expect(rows, hasLength(2));
      final book = rows.singleWhere((row) => row.isBook);
      expect(book.title, 'Complete Book');
      expect(book.readingState, 'reading');
      expect(book.bookRank, 4);
      verify(() => client.query(any())).called(2);
    },
  );
}

Future<ModelType> _unusedSchema() =>
    Future<ModelType>.error(StateError('Schema is not used by listAll'));

Map<String, Object?> _model({
  required int id,
  required String name,
  required String modelType,
  String? readingState,
  int? rank,
}) => <String, Object?>{
  'id': id,
  'name': name,
  'model_type_id': modelType == 'Book' ? 2 : 1,
  'model_type': <String, Object?>{
    'id': modelType == 'Book' ? 2 : 1,
    'name': modelType,
  },
  'created_at': '2026-08-10T00:00:00Z',
  'updated_at': '2026-08-10T00:00:00Z',
  if (readingState != null) 'reading_state': readingState,
  if (rank != null) 'rank': rank,
};

QueryResult<Object?> _result(Map<String, Object?> data) => QueryResult<Object?>(
  options: QueryOptions(document: gql('query { __typename }')),
  source: QueryResultSource.network,
  data: data,
);
