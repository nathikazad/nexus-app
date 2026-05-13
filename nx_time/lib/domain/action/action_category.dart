/// Domain label for a concrete Action subtype (Meet, Sleep, …).
///
/// Pure Dart — no Flutter / KGQL. UI maps [modelTypeId] to color via
/// [barColorForModelTypeId] in the presentation layer.
class ActionCategory {
  const ActionCategory({required this.modelTypeId, required this.name});

  final int modelTypeId;
  final String name;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ActionCategory &&
          runtimeType == other.runtimeType &&
          modelTypeId == other.modelTypeId &&
          name == other.name;

  @override
  int get hashCode => Object.hash(modelTypeId, name);
}
