import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:nx_offline/nx_offline.dart';
import 'package:nx_time/data/sync/time_session.dart';
import 'package:nx_time/domain/projects/project_repository.dart';
import 'package:nx_time/domain/goals/goal_repository.dart';
import 'package:nx_time/domain/action/action_repository.dart';
import 'package:nx_time/domain/tasks/task_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:nx_db/auth.dart';
import 'package:nx_db/kgql.dart';
// Domain-specific clients deliberately have separate caches and headers.
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nx_time/data/action/kgql_action_repository.dart';
import 'package:nx_time/data/tasks/kgql_task_repository.dart';
import 'package:nx_time/data/goals/kgql_goal_repository.dart';
import 'package:nx_time/data/projects/kgql_project_repository.dart';
import 'package:nx_time/data/calendar/kgql_calendar_repository.dart';

final timeDomainClientFactoryProvider =
    Provider<GraphQLClient Function(User, int)>(
      (ref) =>
          (user, id) => createClient(
            resolve(user.preset).graphqlHttp,
            user.userId,
            preset: user.preset,
            domainId: id,
            auditSourceKind: 'nx_time',
          ),
    );
final timeDomainsProvider = AsyncNotifierProvider<TimeDomains, DomainWorkspace>(
  TimeDomains.new,
);

class TimeDomains extends AsyncNotifier<DomainWorkspace> {
  @override
  Future<DomainWorkspace> build() async {
    final user = await ref.watch(authProvider.future);
    if (user == null) throw StateError('Sign in first');
    final prefs = await SharedPreferences.getInstance();
    final membershipKey =
        'nx_time.memberships.${user.preset.serverId}.${user.userId}';
    final loader = ref.watch(domainLoaderProvider);
    String encode(List<DomainMembership> rows) => jsonEncode([
      for (final d in rows)
        {'id': d.id, 'name': d.name, 'role': d.role, 'kind': d.kind},
    ]);
    final cached = prefs.getString(membershipKey);
    final memberships = cached == null
        ? await loader(user)
        : (jsonDecode(cached) as List)
              .map(
                (d) => DomainMembership.fromJson(
                  Map<String, dynamic>.from(d as Map),
                ),
              )
              .toList();
    if (cached == null)
      await prefs.setString(membershipKey, encode(memberships));
    final personal = memberships.where((d) => d.kind == 'personal').toList();
    if (personal.length != 1) {
      throw StateError('Expected exactly one personal domain');
    }
    final key = 'nx_time.domains.${user.preset.serverId}.${user.userId}';
    final saved = prefs.getStringList(key);
    final ids =
        saved
            ?.map(int.parse)
            .where((id) => memberships.any((d) => d.id == id))
            .toSet() ??
        {personal.single.id};
    if (ids.isEmpty) ids.add(personal.single.id);
    final factory = ref.watch(timeDomainClientFactoryProvider);
    final clients = {for (final d in memberships) d.id: factory(user, d.id)};
    final sessions = <int, TimeSession>{
      if (!kIsWeb)
        for (final id in {...ids, personal.single.id})
          id: TimeSession(user, id, clients[id]!),
    };
    for (final entry in sessions.entries)
      clients[entry.key] = entry.value.client;
    final workspace = DomainWorkspace(
      user: user,
      memberships: memberships,
      personalId: personal.single.id,
      selectedIds: ids,
      needsSelection: saved == null && memberships.length > 1,
      clients: clients,
      sessions: sessions,
    );
    ref.onDispose(workspace.dispose);
    if (cached != null) {
      unawaited(
        loader(user)
            .then((fresh) async {
              if (!ref.mounted) return;
              final next = encode(fresh);
              if (next != cached) {
                await prefs.setString(membershipKey, next);
                if (ref.mounted) ref.invalidateSelf();
              }
            })
            .catchError((Object error) async {
              if (error is AuthSessionRejected) {
                await prefs.remove(membershipKey);
                workspace.dispose();
                if (ref.mounted) state = AsyncError(error, StackTrace.current);
              }
            }),
      );
    }
    return workspace;
  }

  Future<void> select(Set<int> ids) async {
    final current = state.requireValue;
    if (ids.isEmpty ||
        ids.any((id) => !current.memberships.any((d) => d.id == id))) {
      throw StateError('Select at least one accessible domain');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'nx_time.domains.${current.user.preset.serverId}.${current.user.userId}',
      ids.map((id) => '$id').toList(),
    );
    ref.invalidateSelf();
  }
}

class DomainWorkspace {
  DomainWorkspace({
    required this.user,
    required this.memberships,
    required this.personalId,
    required this.selectedIds,
    required this.clients,
    this.needsSelection = false,
    this.sessions = const {},
  });
  final Map<int, TimeSession> sessions;
  final bool needsSelection;
  bool _disposed = false;
  Future<void> synchronize(SyncReason reason) => Future.wait(
    sessions.values.map((s) => s.synchronize(reason)),
  ).then((_) {});
  final User user;
  final List<DomainMembership> memberships;
  final int personalId;
  final Set<int> selectedIds;
  final Map<int, GraphQLClient> clients;
  final Map<int, int> origins = {};
  final Map<String, Future<ModelType>> _schemas = {};
  String name(int id) => memberships.singleWhere((d) => d.id == id).name;
  String? nameFor(int id) => origins[id] == null || origins[id] == personalId
      ? null
      : name(origins[id]!);
  Future<ModelType> schema(int id, String type) => _schemas.putIfAbsent(
    '$id:$type',
    () => fetchKgqlModelTypeByName(clients[id]!, type),
  );
  TaskRepository tasks(int id) => KgqlTaskRepository(
    client: clients[id]!,
    domainId: id,
    loadTaskSchema: () => schema(id, 'Task'),
  );
  ActionRepository actions(int id) => KgqlActionRepository(
    client: clients[id]!,
    domainId: id,
    loadActionSchema: () => schema(id, 'Action'),
  );
  GoalRepository goals(int id) => KgqlGoalRepository(
    client: clients[id]!,
    domainId: id,
    loadGoalSchema: () => schema(id, 'Goal'),
  );
  ProjectRepository projects(int id) => KgqlProjectRepository(
    client: clients[id]!,
    domainId: id,
    loadProjectSchema: () => schema(id, 'Project'),
  );
  KgqlCalendarRepository calendar(int id) =>
      KgqlCalendarRepository(clients[id]!, domainId: id);
  void remember(int id, Iterable<int> models) {
    for (final model in models) {
      origins[model] = id;
    }
  }

  bool canWriteModel(int modelId) =>
      memberships.any((d) => d.id == origins[modelId] && d.writable);
  void writable(int id) {
    if (!memberships.any((d) => d.id == id && d.writable)) {
      throw StateError('This domain is read only');
    }
  }

  Future<int> owner(int modelId, {bool write = false}) async {
    int? id = origins[modelId];
    if (id == null) {
      for (final candidate in {...selectedIds, personalId}) {
        final rows = await fetchKgqlModels(
          clients[candidate]!,
          domainId: candidate,
          filter: {
            'filters': [
              {'key': 'id', 'op': '=', 'value': modelId},
            ],
          },
          struct: {'id': true},
        );
        if (rows.isNotEmpty) {
          id = candidate;
          origins[modelId] = id;
          break;
        }
      }
    }
    if (id == null) {
      throw StateError('Record is not available in the selected domains');
    }
    if (write) writable(id);
    return id;
  }

  Future<void> sameDomain(int source, int target) async {
    if (await owner(source) != await owner(target)) {
      throw StateError('Choose related records from the same domain');
    }
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    for (final e in clients.entries) {
      final session = sessions[e.key];
      if (session == null) {
        e.value.link.dispose();
      } else {
        unawaited(session.close());
      }
    }
  }
}

final timeLocalChangesProvider = StreamProvider.autoDispose<void>((ref) async* {
  final workspace = await ref.watch(timeDomainsProvider.future);
  final controller = StreamController<void>();
  final subscriptions = [
    for (final s in workspace.sessions.values)
      s.store.changes.listen((_) {
        if (!controller.isClosed) controller.add(null);
      }),
  ];
  ref.onDispose(() {
    for (final s in subscriptions) {
      unawaited(s.cancel());
    }
    unawaited(controller.close());
  });
  yield* controller.stream;
});
