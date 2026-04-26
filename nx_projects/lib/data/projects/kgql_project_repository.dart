import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:nx_db/kgql.dart';

import 'package:nx_projects/data/projects/project_attr_keys.dart';
import 'package:nx_projects/data/projects/project_mapper.dart';
import 'package:nx_projects/domain/project/project.dart';
import 'package:nx_projects/domain/project/project_repository.dart';

/// Loads [Project] rows via `get_kgql_models` and mutates via `set_kgql_models`.
class KgqlProjectRepository implements ProjectRepository {
  KgqlProjectRepository({
    required GraphQLClient client,
    required Future<ModelType> Function() loadProjectSchema,
  })  : _client = client,
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
  Future<List<Project>> listRootProjects() async {
    final all = await _listAll();
    return all.where((p) => p.parentId == null).toList();
  }

  Future<List<Project>> _listAll() async {
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
  Future<Project?> getProject(int id) async {
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
  Future<List<Project>> getSubProjects(int parentId) async {
    final all = await _listAll();
    return all.where((p) => p.parentId == parentId).toList();
  }

  @override
  Future<Project> addProject(Project project) async {
    final newId = await setKgqlModel(
      _client,
      setModelRequestForCreateProject(project),
    );
    final created = await getProject(newId);
    if (created == null) {
      throw StateError('Created project $newId but failed to re-fetch');
    }
    return created;
  }

  @override
  Future<Project> addSubProject(int parentId, Project sub) async {
    final newId = await setKgqlModel(
      _client,
      setModelRequestForCreateProject(sub),
    );
    await setKgqlModel(
      _client,
      SetModelRequest(
        id: parentId,
        relations: [
          ModelRelation(
            modelType: kProjectRelationKey,
            link: [newId],
          ),
        ],
      ),
    );
    final created = await getProject(newId);
    if (created == null) {
      throw StateError('Created subproject $newId but failed to re-fetch');
    }
    return created;
  }
}
