import 'package:nx_db/kgql.dart';

import 'package:nx_time/data/projects/project_attr_keys.dart';
import 'package:nx_time/domain/projects/project.dart';

String? _descriptionFromModel(Model model) {
  final top = model.description?.trim();
  if (top != null && top.isNotEmpty) return model.description;
  return null;
}

/// Nested `Project` rows from KGQL carry `relation` in [Model.attributes].
String? _edgeRelationFromNestedModel(Model m) {
  final a = m.attributes?['relation'];
  if (a is String) return a;
  return null;
}

bool _nestedProjectNeighborIsChild(Model c) {
  final rel = _edgeRelationFromNestedModel(c);
  return rel == null || rel == 'child';
}

bool _isProjectNeighborChild(Relation r) {
  if (r.modelType != kProjectRelationKey &&
      r.modelType != kProjectModelTypeName) {
    return false;
  }
  if (r.relation == 'parent') return false;
  if (r.relation == 'child') return true;
  // Legacy responses without `relation`: keep prior behavior (all Project neighbors as children).
  return r.relation == null;
}

List<int> _childProjectIdsFromModel(Model m) {
  final nested = m.relations?[kProjectRelationKey];
  if (nested != null && nested.isNotEmpty) {
    return [
      for (final c in nested)
        if (_nestedProjectNeighborIsChild(c)) c.id,
    ];
  }
  final list = m.relationsList;
  if (list == null || list.isEmpty) return [];
  return [
    for (final r in list)
      if (_isProjectNeighborChild(r)) r.modelId,
  ];
}

Map<int, int> _relationIdsByChildFromModel(Model m) {
  final list = m.relationsList;
  if (list == null || list.isEmpty) return {};
  final out = <int, int>{};
  for (final r in list) {
    if (_isProjectNeighborChild(r)) {
      out[r.modelId] = r.relationId;
    }
  }
  return out;
}

int? _parentProjectIdFromModel(Model m) {
  final nested = m.relations?[kProjectRelationKey];
  if (nested != null) {
    for (final c in nested) {
      if (_edgeRelationFromNestedModel(c) == 'parent') return c.id;
    }
  }
  final list = m.relationsList;
  if (list == null || list.isEmpty) return null;
  for (final r in list) {
    if ((r.modelType == kProjectRelationKey ||
            r.modelType == kProjectModelTypeName) &&
        r.relation == 'parent') {
      return r.modelId;
    }
  }
  return null;
}

Project projectFromModel(Model m) {
  return Project(
    id: m.id,
    name: m.name,
    description: _descriptionFromModel(m),
    modelTypeId: m.modelTypeId,
    modelTypeName: m.modelType?.name,
    parentProjectId: _parentProjectIdFromModel(m),
    childProjectIds: _childProjectIdsFromModel(m),
    relationIdByChildId: _relationIdsByChildFromModel(m),
  );
}

SetModelRequest setModelRequestForCreateProject(
  Project project, {
  int? parentProjectId,
}) {
  final rels = <ModelRelation>[
    if (parentProjectId != null)
      ModelRelation(modelType: kProjectRelationKey, link: [parentProjectId]),
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
    modelType: project.modelTypeName != kProjectModelTypeName
        ? project.modelTypeName
        : null,
    name: project.name,
    description: project.description,
  );
}

SetModelRequest setModelRequestForDeleteProject(int id) => setKgqlDelete(id);
