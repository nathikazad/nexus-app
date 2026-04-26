/// Project or subproject row (subprojects are [Project] with [parentId] set).
class Project {
  const Project({
    required this.id,
    required this.name,
    this.color = 0xFF6AA3FF,
    this.parentId,
    this.description = '',
  });

  final int id;
  final String name;
  /// ARGB, e.g. 0xFF6AA3FF
  final int color;
  final int? parentId;
  final String description;

  bool get isSubProject => parentId != null;

  Project copyWith({
    int? id,
    String? name,
    int? color,
    int? parentId,
    bool clearParentId = false,
    String? description,
  }) {
    return Project(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
      parentId: clearParentId ? null : (parentId ?? this.parentId),
      description: description ?? this.description,
    );
  }
}
