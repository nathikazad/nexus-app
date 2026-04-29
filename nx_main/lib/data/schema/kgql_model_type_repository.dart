import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:nx_db/nx_db.dart' as nx;

import 'package:nexus_voice_assistant/data/schema/schema_entity_mappers.dart';
import 'package:nexus_voice_assistant/domain/schema/attribute_definition_draft.dart';
import 'package:nexus_voice_assistant/domain/schema/model_type_write_repository.dart';
import 'package:nexus_voice_assistant/domain/schema/relation_definition_draft.dart';

const String _setKgqlModelTypesMutation = '''
mutation SetKgqlModelTypes(\$input: SetKgqlModelTypesInput!) {
  setKgqlModelTypes(input: \$input) {
    json
  }
}
''';

const String _deleteModelTypeByIdMutation = '''
mutation DeleteModelTypeById(\$input: DeleteModelTypeByIdInput!) {
  deleteModelTypeById(input: \$input) {
    modelType {
      id
    }
  }
}
''';

class KgqlModelTypeRepository implements ModelTypeWriteRepository {
  KgqlModelTypeRepository(this._ref);

  final Ref _ref;

  @override
  Future<int> setModelType({
    int? id,
    required String name,
    required String typeKind,
    String? description,
    int? parentId,
    required List<AttributeDefinitionDraft> attributeDefinitions,
    required List<RelationDefinitionDraft> relationshipTypes,
  }) async {
    final client = _ref.read(nx.graphqlClientProvider);
    final request = nx.SetModelTypeRequest(
      id: id,
      name: name,
      typeKind: typeKind,
      description: description,
      parent: parentId != null ? nx.ParentLink.fromId(parentId) : null,
      attributeDefinitions: attributeDefinitions.isNotEmpty
          ? attributeDefinitions.map(attributeDraftToNx).toList()
          : null,
      relationshipTypes: relationshipTypes.isNotEmpty
          ? relationshipTypes.map(relationDraftToNx).toList()
          : null,
    );

    final requestJson = request.toJson();
    final domainId = _ref.read(nx.personalDomainIdProvider);
    if (domainId == null) {
      throw StateError('personalDomainId required (login)');
    }
    final result = await client.mutate(
      MutationOptions(
        document: gql(_setKgqlModelTypesMutation),
        variables: {
          'input': {'data': requestJson, 'domainId': domainId},
        },
      ),
    );

    if (result.hasException) {
      throw Exception(result.exception.toString());
    }

    final responseData =
        result.data?['setKgqlModelTypes'] as Map<String, dynamic>?;
    if (responseData == null) {
      throw Exception('No data returned from setKgqlModelTypes mutation');
    }

    final jsonResult = responseData['json'];
    final jsonData = jsonResult is String
        ? json.decode(jsonResult) as Map<String, dynamic>
        : jsonResult as Map<String, dynamic>;

    final savedId = jsonData['id'] as int?;
    if (savedId == null) {
      throw Exception('No ID returned from setKgqlModelTypes mutation');
    }
    return savedId;
  }

  @override
  Future<void> deleteModelType(int id) async {
    final client = _ref.read(nx.graphqlClientProvider);
    final result = await client.mutate(
      MutationOptions(
        document: gql(_deleteModelTypeByIdMutation),
        variables: {
          'input': {'id': id},
        },
      ),
    );

    if (result.hasException) {
      throw Exception(result.exception.toString());
    }
  }
}

final modelTypeWriteRepositoryProvider =
    Provider<ModelTypeWriteRepository>((ref) {
  return KgqlModelTypeRepository(ref);
});
