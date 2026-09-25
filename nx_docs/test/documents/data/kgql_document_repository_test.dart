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
    'document catalog omits books and chapters before limiting results',
    () async {
      final client = _MockGraphQLClient();
      when(() => client.query(any())).thenAnswer((invocation) async {
        final options = invocation.positionalArguments.single as QueryOptions;
        final filter = options.variables['filter'] as Map;
        expect(filter['model_type'], 'Document');
        expect(filter.containsKey('limit'), isFalse);
        final struct = options.variables['struct'] as Map;
        expect(struct.containsKey('document'), isFalse);
        expect(struct.containsKey('json_document'), isFalse);
        return _result({
          'getKgqlModels': [
            _model(id: 2, name: 'Book', modelType: 'Book'),
            _model(id: 3, name: 'Chapter', modelType: 'Book Chapter'),
            _model(id: 1, name: 'My document', modelType: 'Document'),
          ],
        });
      });
      final repository = KgqlDocumentRepository(
        client: client,
        loadDocumentSchema: _unusedSchema,
        loadDocumentSnapSchema: _unusedSchema,
      );
      expect((await repository.listAll()).map((d) => d.id), [1]);
      expect((await repository.listRecent(limit: 1)).map((d) => d.id), [1]);
      expect((await repository.listPinned(limit: 1)).map((d) => d.id), [1]);
      verify(() => client.query(any())).called(3);
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
