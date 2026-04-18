/// Domain task row (picker / drill-down); not KGQL [Model].
class Task {
  const Task({
    required this.id,
    required this.name,
  });

  final int id;
  final String name;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Task && runtimeType == other.runtimeType && id == other.id && name == other.name;

  @override
  int get hashCode => Object.hash(id, name);
}
