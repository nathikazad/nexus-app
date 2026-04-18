import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_db/nx_db.dart';

import 'package:nx_time/core/theme/action_color_palette.dart';
import 'package:nx_time/domain/action/action_repository.dart';
import 'package:nx_time/domain/tasks/task_repository.dart';
import 'package:nx_time/data/action/action_schema_provider.dart';
import 'package:nx_time/data/action/kgql_action_repository.dart';
import 'package:nx_time/data/action_category_option.dart';
import 'package:nx_time/data/schema/kgql_action_schema_repository.dart';
import 'package:nx_time/data/tasks/kgql_task_repository.dart';

export 'package:nx_time/data/action/action_kgql_struct.dart';
export 'package:nx_time/data/action/action_schema_provider.dart';

/// Default KGQL-backed [ActionRepository].
final actionRepositoryProvider = Provider<ActionRepository>(
  (ref) => KgqlActionRepository(ref),
);

/// KGQL-backed [TaskRepository] (relation picker lists).
final taskRepositoryProvider = Provider<TaskRepository>(
  (ref) => KgqlTaskRepository(ref),
);

/// Cached Action root schema for callers that prefer a class over [actionSchemaProvider].
final kgqlActionSchemaRepositoryProvider =
    Provider<KgqlActionSchemaRepository>(
  (ref) => KgqlActionSchemaRepository(ref),
);


/// Resolves only when auth has loaded a non-null user.
///
/// Data providers that hit KGQL should depend on this provider so requests don't
/// race ahead with default unauthenticated client config.
final authenticatedUserProvider = FutureProvider<User>((ref) async {
  const tag = '[nx_time session]';
  debugPrint('$tag waiting for authProvider.future...');
  final user = await ref.watch(authProvider.future);
  if (user == null) {
    throw StateError('Not authenticated');
  }
  debugPrint('$tag ready userId=${user.userId} preset=${user.preset}');
  return user;
});

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
final actionSubtypeModelTypesProvider = FutureProvider<List<ModelType>>((ref) async {
  final action = await ref.watch(actionSchemaProvider.future);
  return collectActionSubtypeModelTypes(action);
});

/// Picker rows: DB-backed type names + [barColorForModelTypeId] dots (aligned with Today list).
final actionCategoryOptionsProvider =
    FutureProvider<List<ActionCategoryOption>>((ref) async {
  final types = await ref.watch(actionSubtypeModelTypesProvider.future);
  return types
      .map(
        (t) => ActionCategoryOption(
          modelTypeId: t.id,
          name: t.name,
          dotColor: barColorForModelTypeId(t.id),
        ),
      )
      .toList();
});
