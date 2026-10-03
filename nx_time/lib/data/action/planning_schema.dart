import 'package:nx_db/kgql.dart';

/// Effective Plannable membership, including inherited membership.
Set<String> plannableTypeNames(ModelType root) {
  final names = <String>{};
  bool hasMixin(ModelType t) =>
      t.name == 'Plannable' || (t.mixins ?? const <ModelType>[]).any(hasMixin);
  void walk(ModelType t, bool inherited) {
    final planned = inherited || hasMixin(t);
    if (planned && t.typeKind != 'mixin') names.add(t.name);
    for (final child in t.children ?? const <ModelType>[]) {
      walk(child, planned);
    }
  }

  walk(root, false);
  return names;
}
