import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:nx_db/kgql.dart';

import 'package:nx_time/data/projects/project_attr_keys.dart';
import 'package:nx_time/data/projects/project_mapper.dart';
import 'package:nx_time/domain/projects/project.dart';
import 'package:nx_time/domain/projects/project_repository.dart';

/// Loads Project rows via `get_kgql_models` and mutates via `set_kgql_models`.
class KgqlProjectRepository implements ProjectRepository {
  KgqlProjectRepository({
    required GraphQLClient client,
    required Future<ModelType> Function() loadProjectSchema,
  }) : _client = client,
       _loadProjectSchema = loadProjectSchema;

  final GraphQLClient _client;
  final Future<ModelType> Function() _loadProjectSchema;
  Map<String, dynamic> _projectFetchStruct(ModelType schema) {
    final base = buildKgqlStructFromSchema(schema);
    final merged = Map<String, dynamic>.from(base);
    merged[kProjectRelationKey] = {'id': true, 'name': true, 'relation': true};
    return merged;
  }

  @override
  Future<List<Project>> listAll() async {
    final schema = await _loadProjectSchema();
    final struct = _projectFetchStruct(schema);
    final models = await fetchKgqlModels(
      _client,
      filter: {'model_type': kProjectModelTypeName},
      struct: struct,
    );
    return models.map(projectFromModel).toList();
  }

  @override
  Future<Project?> getById(int id) async {
    final schema = await _loadProjectSchema();
    final struct = _projectFetchStruct(schema);
    final m = await fetchKgqlModelById(
      _client,
      modelTypeName: kProjectModelTypeName,
      id: id,
      struct: struct,
    );
    return m == null ? null : projectFromModel(m);
  }

  @override
  Future<int> create(Project project, {int? parentProjectId}) async {
    final req = setModelRequestForCreateProject(
      project,
      parentProjectId: parentProjectId,
    );
    return setKgqlModel(_client, req);
  }

  @override
  Future<int> update(Project project) async {
    return setKgqlModel(_client, setModelRequestForUpdateProject(project));
  }

  @override
  Future<void> delete(int id) async {
    await setKgqlModel(_client, setModelRequestForDeleteProject(id));
  }

  @override
  Future<int> linkChildProject({
    required int parentId,
    required int childId,
  }) async {
    return setKgqlModel(
      _client,
      SetModelRequest(
        id: parentId,
        relations: [
          ModelRelation(modelType: kProjectRelationKey, link: [childId]),
        ],
      ),
    );
  }

  @override
  Future<void> unlinkChildProject({
    required int parentId,
    required int relationId,
  }) async {
    await setKgqlModel(
      _client,
      SetModelRequest(
        id: parentId,
        relations: [ModelRelation(id: relationId, delete: true)],
      ),
    );
  }
}
