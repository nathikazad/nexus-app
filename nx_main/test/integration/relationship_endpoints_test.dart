import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:nx_db/kgql.dart';
import 'package:nexus_voice_assistant/data/schema/schema_entity_mappers.dart';
import 'package:nexus_voice_assistant/domain/schema/model_type_form_state.dart';

void main() {
  test('named endpoints create, read both sides, update and self-relate',
      () async {
    final endpoint = Platform.environment['NX_RELATIONSHIP_TEST_URL']!;
    expect(Uri.parse(endpoint).host, anyOf('localhost', '127.0.0.1'));
    final client = createClient(endpoint, '1', domainId: 2);
    final suffix = DateTime.now().microsecondsSinceEpoch;
    final source = 'EndpointSource$suffix';
    final target = 'EndpointTarget$suffix';
    final ids = <int>[];
    addTearDown(() async {
      for (final id in ids.reversed) {
        final result = await client.mutate(
            MutationOptions(document: gql(r'''mutation DeleteType($id: Int!) {
            deleteModelTypeById(input: {id: $id}) { deletedModelTypeId }
          }'''), variables: {'id': id}));
        if (result.hasException) throw result.exception!;
      }
    });
    final targetId = await setKgqlModelType(
        client, SetModelTypeRequest(name: target, typeKind: 'base'));
    ids.add(targetId);
    final endpoints = {
      'owner': RelationshipEndpoint(type: source, count: 'one'),
      'items': RelationshipEndpoint(type: target, count: 'many'),
    };
    final sourceId = await setKgqlModelType(
        client,
        SetModelTypeRequest(name: source, typeKind: 'base', relationshipTypes: [
          RelationshipType(relationName: 'owns', endpoints: endpoints),
        ]));
    ids.add(sourceId);
    final forward = (await fetchKgqlModelTypeById(client, sourceId))!;
    final reverse = (await fetchKgqlModelTypeById(client, targetId))!;
    expect(forward.relations!.single.targetEndpoint!.value.count, 'many');
    expect(reverse.relations!.single.targetEndpoint!.value.count, 'one');
    expect(reverse.relations!.single.definingModelTypeId, sourceId);
    expect(
        ModelTypeFormFields.fromSchemaModelType(schemaModelTypeFromNx(reverse))
            .relationshipTypes,
        isEmpty);
    await setKgqlModelType(
        client,
        SetModelTypeRequest(
            id: sourceId,
            name: source,
            typeKind: 'base',
            relationshipTypes: [
              RelationshipType(
                  id: forward.relations!.single.id,
                  relationName: 'owns',
                  endpoints: {
                    ...endpoints,
                    'items': RelationshipEndpoint(type: target, count: 'one')
                  }),
              RelationshipType(relationName: 'hierarchy', endpoints: {
                'parent': RelationshipEndpoint(type: source, count: 'one'),
                'children': RelationshipEndpoint(type: source, count: 'many'),
              }),
            ]));
    final updated = (await fetchKgqlModelTypeById(client, sourceId))!;
    expect(
        updated.relations!
            .firstWhere((r) => r.relationName == 'owns')
            .targetEndpoint!
            .value
            .count,
        'one');
    final self =
        updated.relations!.firstWhere((r) => r.relationName == 'hierarchy');
    expect(self.endpoints.keys, containsAll(['parent', 'children']));
    expect(self.targetEndpoint, isNull);
  },
      skip: Platform.environment['NX_RELATIONSHIP_TEST_URL'] == null,
      tags: ['integration']);
}
