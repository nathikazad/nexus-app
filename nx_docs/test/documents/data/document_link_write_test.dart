import 'package:flutter_test/flutter_test.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:nx_db/kgql.dart';
import 'package:nx_docs/documents/data/kgql/kgql_document_repository.dart';
import 'package:nx_docs/documents/data/kgql/document_mapper.dart';
import 'package:nx_docs/documents/document_models.dart';

void main() {
  for (final detach in [false, true]) {
    for (final status in ['APPLIED', 'STALE', 'DELETED']) {
      test(
        '${detach ? 'detach' : 'attach'} reports $status and advances revision',
        () async {
          final prior = DateTime.now().toUtc().add(const Duration(days: 1));
          final writes = <Map<String, dynamic>>[];
          final client = GraphQLClient(
            cache: GraphQLCache(store: InMemoryStore()),
            link: Link.function((request, [forward]) async* {
              writes.add(request.variables);
              yield Response(
                response: const {},
                data: {
                  '__typename': 'Mutation',
                  'mutateDocument': {'id': 42, 'status': status},
                },
              );
            }),
          );
          final repo = _Repository(
            client,
            documentFromModel(
              Model.fromJson({
                'id': 42,
                'name': 'Document',
                'updated_at': prior.toIso8601String(),
              }),
            ),
          );
          final operation = detach
              ? repo.detachProject(42, 99)
              : repo.attachLinkedModel(
                  documentId: 42,
                  modelType: LinkableModelType.document,
                  modelId: 43,
                );
          if (status == 'APPLIED') {
            await operation;
          } else {
            await expectLater(operation, throwsStateError);
          }
          expect(
            DateTime.parse(
              writes.single['clientUpdatedAt'] as String,
            ).isAfter(prior),
            isTrue,
          );
        },
      );
    }
  }
}

class _Repository extends KgqlDocumentRepository {
  _Repository(GraphQLClient client, this.document)
    : super(
        client: client,
        loadDocumentSchema: () async => ModelType(id: 1, name: 'Document'),
        loadDocumentSnapSchema: () async =>
            ModelType(id: 2, name: 'DocumentSnap'),
      );
  final NxDocument document;
  @override
  Future<NxDocument?> getById(int id) async => document;
}
