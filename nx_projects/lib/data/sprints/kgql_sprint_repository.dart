import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:nx_db/kgql.dart';

import 'package:nx_projects/data/sprints/sprint_attr_keys.dart';
import 'package:nx_projects/data/sprints/sprint_mapper.dart';
import 'package:nx_projects/domain/sprint/sprint.dart';
import 'package:nx_projects/domain/sprint/sprint_repository.dart';

class KgqlSprintRepository implements SprintRepository {
  KgqlSprintRepository({
    required GraphQLClient client,
    required Future<ModelType> Function() loadSprintSchema,
  }) : _client = client,
       _loadSprintSchema = loadSprintSchema;

  final GraphQLClient _client;
  final Future<ModelType> Function() _loadSprintSchema;

  Map<String, dynamic> _sprintStruct(ModelType schema) {
    return buildKgqlStructFromSchema(schema);
  }

  @override
  Future<List<Sprint>> listSprints() async {
    final schema = await _loadSprintSchema();
    final struct = _sprintStruct(schema);
    final models = await fetchKgqlModels(
      _client,
      filter: {'model_type': kSprintModelTypeName},
      struct: struct,
    );
    return models.map(sprintFromModel).toList();
  }

  @override
  Future<Sprint?> getById(int id) async {
    final schema = await _loadSprintSchema();
    final struct = _sprintStruct(schema);
    final m = await fetchKgqlModelById(
      _client,
      modelTypeName: kSprintModelTypeName,
      id: id,
      struct: struct,
    );
    return m == null ? null : sprintFromModel(m);
  }

  @override
  Future<Sprint> create(Sprint sprint) async {
    final id = await setKgqlModel(
      _client,
      setModelRequestForCreateSprint(sprint),
    );
    final created = await getById(id);
    if (created == null) {
      throw StateError('Created sprint $id but failed to re-fetch');
    }
    return created;
  }

  @override
  Future<void> update(Sprint sprint) async {
    await setKgqlModel(
      _client,
      SetModelRequest(
        id: sprint.id,
        attributes: setModelAttributesForSprintUpdate(sprint),
      ),
    );
  }
}
