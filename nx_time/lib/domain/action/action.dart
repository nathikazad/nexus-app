/// Domain entity for a logged time block (Action row in KGQL).
///
/// Pure Dart — no Flutter / nx_db.
class Action {
  const Action({
    required this.id,
    required this.name,
    this.description,
    required this.modelTypeId,
    this.modelTypeName,
    this.startTime,
    this.endTime,
    this.parentActionId,
    this.childActionIds = const [],
    this.relationIdByChildId = const {},
  });

  final int id;
  final String name;
  final String? description;
  final int modelTypeId;
  final String? modelTypeName;

  /// Local wall-clock start of the interval (same semantics as KGQL `start_time`).
  final DateTime? startTime;
  final DateTime? endTime;

  /// Set client-side after [foldDayActions] when needed; usually null from KGQL mapper.
  final int? parentActionId;

  /// Outgoing `action_action` children (from nested `Action` relation on fetch).
  final List<int> childActionIds;

  /// `relations` row id per child model id (for unlink), when KGQL returns `relationsList`.
  final Map<int, int> relationIdByChildId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Action &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          description == other.description &&
          modelTypeId == other.modelTypeId &&
          modelTypeName == other.modelTypeName &&
          startTime == other.startTime &&
          endTime == other.endTime &&
          parentActionId == other.parentActionId &&
          _listEq(childActionIds, other.childActionIds) &&
          _mapEq(relationIdByChildId, other.relationIdByChildId);

  @override
  int get hashCode => Object.hash(
    id,
    name,
    description,
    modelTypeId,
    modelTypeName,
    startTime,
    endTime,
    parentActionId,
    Object.hashAll(childActionIds),
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
