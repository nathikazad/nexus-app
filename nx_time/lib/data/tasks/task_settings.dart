import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:nx_db/kgql.dart';
import 'package:nx_time/data/domains/domain_workspace.dart';
import 'package:nx_time/domain/tasks/task.dart';
import 'package:nx_time/features/tasks/task_view_models.dart';

final taskDomainMembersProvider = FutureProvider.family<Map<String, String>, int>((
  ref,
  domainId,
) async {
  final workspace = await ref.watch(timeDomainsProvider.future);
  final result = await workspace.clients[domainId]!.query(
    QueryOptions(
      document: gql(
        r'query TaskMembers($id: Int!) { getTaskDomainMembers(pDomainId: $id) }',
      ),
      variables: {'id': domainId},
      fetchPolicy: FetchPolicy.networkOnly,
    ),
  );
  if (result.hasException) throw result.exception!;
  final raw = result.data?['getTaskDomainMembers'];
  final values = raw is String ? jsonDecode(raw) : raw;
  return {
    for (final member in values as List)
      '${member['id']}': member['name'] as String,
  };
});

String taskRank(Task task, DomainWorkspace workspace) {
  final shared = workspace.origins[task.id] != workspace.personalId;
  final participant = task.participants['${workspace.user.userId}'] as Map?;
  final value = shared ? (participant ?? {})['rank'] : task.rank;
  // Stable fallback places newer, unranked tasks before older unranked tasks.
  return value as String? ??
      '${(999999999999 - task.id).toString().padLeft(12, '0')}U';
}

/// Lexicographic fractional indexing, without floating point precision loss.
String rankBetween(String? lower, String? upper) {
  const digits =
      '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz';
  if (lower != null && upper != null && lower.compareTo(upper) >= 0) {
    throw StateError(
      'These tasks have equal ranks. Move one to the top first.',
    );
  }
  var prefix = '';
  for (var i = 0; i < 255; i++) {
    final low = lower != null && i < lower.length
        ? digits.indexOf(lower[i])
        : 0;
    final high = upper != null && i < upper.length
        ? digits.indexOf(upper[i])
        : 61;
    if (high - low > 1) return prefix + digits[(low + high) ~/ 2];
    prefix += digits[low];
    if (low < high) upper = null;
  }
  throw StateError('Ordering is too dense. Move this task to the top first.');
}

Future<void> patchTaskSettings(
  WidgetRef ref,
  Task task,
  Map<String, dynamic> attributes,
) async {
  final workspace = await ref.read(timeDomainsProvider.future);
  final id = await workspace.owner(task.id, write: true);
  await setKgqlModel(
    workspace.clients[id]!,
    SetModelRequest(
      id: task.id,
      attributes: [
        for (final entry in attributes.entries)
          SetModelAttribute(key: entry.key, value: entry.value),
      ],
    ),
    domainId: id,
  );
  invalidateTasksAfterMutation(ref);
}

Future<void> saveTaskRank(WidgetRef ref, Task task, String rank) async {
  final workspace = await ref.read(timeDomainsProvider.future);
  final domainId = await workspace.owner(task.id);
  await patchTaskSettings(
    ref,
    task,
    domainId == workspace.personalId
        ? {'rank': rank}
        : {
            'participants': {
              '${workspace.user.userId}': {'rank': rank},
            },
          },
  );
}
