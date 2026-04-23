import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_db/auth.dart';
import 'package:nx_db/riverpod.dart';

import 'package:nx_time/domain/action/action_repository.dart';
import 'package:nx_time/domain/goals/goal_repository.dart';
import 'package:nx_time/domain/projects/project_repository.dart';
import 'package:nx_time/domain/tasks/task_repository.dart';
import 'package:nx_time/data/action/action_schema_provider.dart';
import 'package:nx_time/data/action/kgql_action_repository.dart';
import 'package:nx_time/data/goals/goal_schema_provider.dart';
import 'package:nx_time/data/goals/kgql_goal_repository.dart';
import 'package:nx_time/data/projects/kgql_project_repository.dart';
import 'package:nx_time/data/projects/project_schema_provider.dart';
import 'package:nx_time/data/schema/kgql_action_schema_repository.dart';
import 'package:nx_time/data/tasks/kgql_task_repository.dart';
import 'package:nx_time/data/tasks/task_schema_provider.dart';

export 'package:nx_time/data/action/action_schema_provider.dart';
export 'package:nx_time/data/action/action_subtypes_provider.dart';
export 'package:nx_time/data/projects/project_schema_provider.dart';
export 'package:nx_time/data/tasks/task_schema_provider.dart';
export 'package:nx_time/data/goals/goal_schema_provider.dart';

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

/// Resolves only when auth has loaded a non-null user.
///
/// Data providers that hit KGQL should depend on this provider so requests don't
/// race ahead with default unauthenticated client config.
final authenticatedUserProvider = FutureProvider<User>((ref) async {
  final user = await ref.watch(authProvider.future);
  if (user == null) {
    throw StateError('Not authenticated');
  }
  return user;
});
