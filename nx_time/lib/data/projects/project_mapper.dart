import 'package:nx_db/kgql.dart';

import 'package:nx_time/data/projects/project_attr_keys.dart';
import 'package:nx_time/domain/projects/project.dart';

String? _descriptionFromModel(Model model) {
  final top = model.description?.trim();
  if (top != null && top.isNotEmpty) return model.description;
  return null;
}

List<int> _childProjectIdsFromModel(Model m) {
  final nested = m.relations?[kProjectRelationKey];
  if (nested != null && nested.isNotEmpty) {
    return nested.map((c) => c.id).toList();
  }
  final list = m.relationsList;
  if (list == null || list.isEmpty) return [];
  return [
    for (final r in list)
      if (r.modelType == kProjectRelationKey || r.modelType == kProjectModelTypeName)
        r.modelId,
  ];
}

Map<int, int> _relationIdsByChildFromModel(Model m) {
  final list = m.relationsList;
  if (list == null || list.isEmpty) return {};
  final out = <int, int>{};
  for (final r in list) {
    if (r.modelType == kProjectRelationKey || r.modelType == kProjectModelTypeName) {
      out[r.modelId] = r.relationId;
    }
  }
  return out;
}

int? _parentProjectIdFromModel(Model m, List<int> childIds) {
  final list = m.relationsList;
  if (list == null || list.isEmpty) return null;
  final candidates = <int>[];
  for (final r in list) {
    if (r.modelType == kProjectRelationKey || r.modelType == kProjectModelTypeName) {
      if (r.modelId != m.id && !childIds.contains(r.modelId)) {
        candidates.add(r.modelId);
      }
    }
  }
  if (candidates.length == 1) return candidates.first;
  return null;
}

Project projectFromModel(Model m) {
  final childIds = _childProjectIdsFromModel(m);
  return Project(
    id: m.id,
    name: m.name,
    description: _descriptionFromModel(m),
    modelTypeId: m.modelTypeId,
    modelTypeName: m.modelType?.name,
    parentProjectId: _parentProjectIdFromModel(m, childIds),
    childProjectIds: childIds,
    relationIdByChildId: _relationIdsByChildFromModel(m),
  );
}

SetModelRequest setModelRequestForCreateProject(
  Project project, {
  int? parentProjectId,
}) {
  final rels = <ModelRelation>[
    if (parentProjectId != null)
      ModelRelation(
        modelType: kProjectRelationKey,
        link: [parentProjectId],
      ),
  ];

  return SetModelRequest(
    modelType: kProjectModelTypeName,
    name: project.name,
    description: project.description,
    relations: rels.isEmpty ? null : rels,
  );
}

SetModelRequest setModelRequestForUpdateProject(Project project) {
  return SetModelRequest(
    id: project.id,
    modelType:
        project.modelTypeName != kProjectModelTypeName ? project.modelTypeName : null,
    name: project.name,
    description: project.description,
  );
}

SetModelRequest setModelRequestForDeleteProject(int id) => setKgqlDelete(id);
