import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_db/person.dart';
import 'package:nx_db/riverpod.dart';

import 'package:nx_time/domain/action/action_repository.dart';
import 'package:nx_time/domain/goals/goal_repository.dart';
import 'package:nx_time/domain/projects/project_repository.dart';
import 'package:nx_time/domain/tasks/task_repository.dart';
import 'package:nx_time/data/action/action_schema_provider.dart';
import 'package:nx_time/data/action/action_subtypes_provider.dart';
import 'package:nx_time/data/action/kgql_action_repository.dart';
import 'package:nx_time/data/goals/goal_schema_provider.dart';
import 'package:nx_time/data/goals/kgql_goal_repository.dart';
import 'package:nx_time/data/person/model_type_colors.dart';
import 'package:nx_time/data/projects/kgql_project_repository.dart';
import 'package:nx_time/data/projects/project_schema_provider.dart';
import 'package:nx_time/data/schema/kgql_action_schema_repository.dart';
import 'package:nx_time/data/tasks/kgql_task_repository.dart';
import 'package:nx_time/data/tasks/task_schema_provider.dart';

export 'package:nx_db/person.dart';
export 'package:nx_time/data/action/action_schema_provider.dart';
export 'package:nx_time/data/action/action_subtypes_provider.dart';
export 'package:nx_time/data/projects/project_schema_provider.dart';
export 'package:nx_time/data/tasks/task_schema_provider.dart';
export 'package:nx_time/data/goals/goal_schema_provider.dart';
export 'package:nx_time/data/person/model_type_colors.dart';

/// Model-type bar colors from Person `preference.model_type_colors` (with defaults).
final modelTypeColorsProvider = FutureProvider<ModelTypeColors>((ref) async {
  final person = await ref.watch(mainPersonProvider.future);
  final pref = person?.preference ?? <String, dynamic>{};
  await ref.watch(actionSubtypeModelTypesProvider.future);
  return ModelTypeColors.fromPreference(pref);
});

/// Default KGQL-backed [ActionRepository].
final actionRepositoryProvider = Provider<ActionRepository>(
  (ref) => KgqlActionRepository(
    client: ref.watch(graphqlClientProvider),
    loadActionSchema: () => ref.read(actionSchemaProvider.future),
  ),
);

/// KGQL-backed [TaskRepository].
final taskRepositoryProvider = Provider<TaskRepository>(
  (ref) => KgqlTaskRepository(
    client: ref.watch(graphqlClientProvider),
    loadTaskSchema: () => ref.read(taskSchemaProvider.future),
  ),
);

/// KGQL-backed [ProjectRepository].
final projectRepositoryProvider = Provider<ProjectRepository>(
  (ref) => KgqlProjectRepository(
    client: ref.watch(graphqlClientProvider),
    loadProjectSchema: () => ref.read(projectSchemaProvider.future),
  ),
);

/// KGQL-backed [GoalRepository] (`app.get_action_goals_*` / `app.get_expense_goals_month`).
final goalRepositoryProvider = Provider<GoalRepository>(
  (ref) => KgqlGoalRepository(
    client: ref.watch(graphqlClientProvider),
    loadGoalSchema: () => ref.read(goalSchemaProvider.future),
  ),
);

/// Cached Action root schema for callers that prefer a class over [actionSchemaProvider].
final kgqlActionSchemaRepositoryProvider =
    Provider<KgqlActionSchemaRepository>(
  (ref) => KgqlActionSchemaRepository(ref),
);
