import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_db/kgql.dart';
import 'package:nx_time/domain/action/action_subtype_option.dart';

import 'package:nx_time/data/action/action_schema_provider.dart';

/// Collects concrete (`type_kind` base) descendants under [Action] from `get_kgql_model_type`.
List<ModelType> collectActionSubtypeModelTypes(ModelType actionRoot) {
  final out = <ModelType>[];
  void walk(ModelType node) {
    for (final c in node.children ?? const []) {
      final kind = (c.typeKind ?? '').toLowerCase();
      if (kind == 'base' && c.name != 'Action') {
        out.add(c);
      }
      walk(c);
    }
  }

  walk(actionRoot);
  out.sort((a, b) => a.name.compareTo(b.name));
  return out;
}

/// Action subtypes from the DB (same tree as [actionSchemaProvider]).
final actionSubtypeModelTypesProvider =
    FutureProvider<List<ModelType>>((ref) async {
  final action = await ref.watch(actionSchemaProvider.future);
  return collectActionSubtypeModelTypes(action);
});

/// Same as [actionSubtypeModelTypesProvider] in domain-shaped form (no [ModelType] in features).
final actionSubtypeOptionsProvider =
    FutureProvider<List<ActionSubtypeOption>>((ref) async {
  final raw = await ref.watch(actionSubtypeModelTypesProvider.future);
  return [for (final t in raw) ActionSubtypeOption(id: t.id, name: t.name)];
});
