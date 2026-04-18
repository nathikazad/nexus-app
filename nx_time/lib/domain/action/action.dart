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
  });

  final int id;
  final String name;
  final String? description;
  final int modelTypeId;
  final String? modelTypeName;

  /// Local wall-clock start of the interval (same semantics as KGQL `start_time`).
  final DateTime? startTime;
  final DateTime? endTime;

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
          endTime == other.endTime;

  @override
  int get hashCode => Object.hash(
        id,
        name,
        description,
        modelTypeId,
        modelTypeName,
        startTime,
        endTime,
      );
}
