/// Domain entity for a Project row in KGQL.
///
class _ProjectCopyUnset {
  const _ProjectCopyUnset();
}

const _projectCopyUnset = _ProjectCopyUnset();

/// Pure Dart — no Flutter / nx_db.
class Project {
  const Project({
    required this.id,
    required this.name,
    this.description,
    required this.modelTypeId,
    this.modelTypeName,
    this.parentProjectId,
    this.childProjectIds = const [],
    this.relationIdByChildId = const {},
  });

  final int id;
  final String name;
  final String? description;
  final int modelTypeId;
  final String? modelTypeName;

  /// Set client-side when needed; usually null from KGQL mapper.
  final int? parentProjectId;

  /// Outgoing `has_subproject` children.
  final List<int> childProjectIds;

  /// `relations` row id per child project id (for unlink).
  final Map<int, int> relationIdByChildId;

  Project copyWith({
    int? id,
    String? name,
    Object? description = _projectCopyUnset,
    int? modelTypeId,
    Object? modelTypeName = _projectCopyUnset,
    Object? parentProjectId = _projectCopyUnset,
    List<int>? childProjectIds,
    Map<int, int>? relationIdByChildId,
  }) {
    return Project(
      id: id ?? this.id,
      name: name ?? this.name,
      description: identical(description, _projectCopyUnset)
          ? this.description
          : description as String?,
      modelTypeId: modelTypeId ?? this.modelTypeId,
      modelTypeName: identical(modelTypeName, _projectCopyUnset)
          ? this.modelTypeName
          : modelTypeName as String?,
      parentProjectId: identical(parentProjectId, _projectCopyUnset)
          ? this.parentProjectId
          : parentProjectId as int?,
      childProjectIds: childProjectIds ?? this.childProjectIds,
      relationIdByChildId: relationIdByChildId ?? this.relationIdByChildId,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Project &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          description == other.description &&
          modelTypeId == other.modelTypeId &&
          modelTypeName == other.modelTypeName &&
          parentProjectId == other.parentProjectId &&
          _listEq(childProjectIds, other.childProjectIds) &&
          _mapEq(relationIdByChildId, other.relationIdByChildId);

  @override
  int get hashCode => Object.hash(
        id,
        name,
        description,
        modelTypeId,
        modelTypeName,
        parentProjectId,
        Object.hashAll(childProjectIds),
        Object.hashAllUnordered(relationIdByChildId.entries),
      );
}

bool _listEq(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

bool _mapEq(Map<int, int> a, Map<int, int> b) {
  if (a.length != b.length) return false;
  for (final e in a.entries) {
    if (b[e.key] != e.value) return false;
  }
  return true;
}
