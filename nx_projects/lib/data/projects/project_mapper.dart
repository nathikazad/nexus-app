import 'package:nx_db/kgql.dart';

import 'package:nx_projects/data/projects/project_attr_keys.dart';
import 'package:nx_projects/domain/project/project.dart';

String? _edgeRelationFromNestedModel(Model m) {
  final a = m.attributes?['relation'];
  if (a is String) return a;
  return null;
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
    if ((r.modelType == kProjectRelationKey || r.modelType == kProjectModelTypeName) &&
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
    color: m.attrInt('color') ?? 0xFF6AA3FF,
    parentId: _parentProjectIdFromModel(m),
    description: m.description?.trim() ?? '',
  );
}

List<SetModelAttribute> setModelAttributesForProject(Project p) {
  return [
    if (p.color != 0xFF6AA3FF)
      SetModelAttribute(key: 'color', value: p.color),
  ];
}

SetModelRequest setModelRequestForCreateProject(Project p) {
  return SetModelRequest(
    modelType: kProjectModelTypeName,
    name: p.name,
    description: p.description.isEmpty ? null : p.description,
    attributes: setModelAttributesForProject(p).isEmpty ? null : setModelAttributesForProject(p),
  );
}

SetModelRequest setModelRequestForUpdateProject(Project p) {
  return SetModelRequest(
    id: p.id,
    name: p.name,
    description: p.description.isEmpty ? null : p.description,
    attributes: setModelAttributesForProject(p).isEmpty ? null : setModelAttributesForProject(p),
  );
}
