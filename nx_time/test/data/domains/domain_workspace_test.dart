import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:nx_db/auth.dart';
import 'package:nx_db/kgql.dart';
import 'package:nx_time/data/domains/domain_workspace.dart';
import 'package:nx_time/data/domains/multi_task_repository.dart';
import 'package:nx_time/data/domains/multi_goal_repository.dart';
import 'package:nx_time/data/domains/personal_action_repository.dart';
import 'package:nx_time/domain/tasks/task_status.dart';
import 'package:nx_time/features/domains/time_domain_gate.dart';
import 'package:shared_preferences/shared_preferences.dart';

const memberships = [
  DomainMembership(id: 3, name: 'Personal', role: 'owner', kind: 'personal'),
  DomainMembership(id: 1, name: 'Home', role: 'member', kind: 'shared'),
  DomainMembership(id: 2, name: 'Read only', role: 'viewer', kind: 'shared'),
];

class TestAuth extends AuthController {
  @override
  Future<User?> build() async =>
      User(userId: '3', preset: BackendPreset.localhost, domainId: 3);
}

class Workspace extends DomainWorkspace {
  Workspace(Map<int, GraphQLClient> clients, {Set<int> selected = const {1, 3}})
    : super(
        user: User(userId: '3', preset: BackendPreset.localhost),
        memberships: memberships,
        personalId: 3,
        selectedIds: selected,
        clients: clients,
      );
  @override
  Future<ModelType> schema(int id, String type) async =>
      ModelType.fromJson({'id': 9, 'name': type, 'type_kind': 'base'});
}

class FixedDomains extends TimeDomains {
  FixedDomains(this.workspace);
  final DomainWorkspace workspace;
  @override
  Future<DomainWorkspace> build() async => workspace;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late List<({int domain, Request request})> calls;
  late Map<int, GraphQLClient> clients;
  setUp(() {
    calls = [];
    SharedPreferences.setMockInitialValues({});
    clients = {
      for (final d in memberships)
        d.id: GraphQLClient(
          cache: GraphQLCache(),
          link: Link.function((request, [forward]) async* {
            calls.add((domain: d.id, request: request));
            final vars = request.variables;
            if (vars.containsKey('input')) {
              yield Response(
                response: const {},
                data: {
                  '__typename': 'Mutation',
                  'setKgqlModels': {
                    '__typename': 'SetKgqlModelsPayload',
                    'json': {'id': d.id * 10},
                  },
                },
              );
              return;
            }
            if (vars.containsKey('filter')) {
              expect(
                vars['domainId'],
                d.id,
                reason: 'Every KGQL read must explicitly scope its domain',
              );
              final filter = vars['filter'] as Map;
              final ids = (filter['filters'] as List? ?? []).where(
                (f) => f['key'] == 'id',
              );
              final found =
                  ids.isEmpty || '${ids.first['value']}' == '${d.id * 10}';
              yield Response(
                response: const {},
                data: {
                  '__typename': 'Query',
                  'getKgqlModels': found
                      ? [
                          {
                            'id': d.id * 10,
                            'name': '${d.name} record',
                            'model_type_id': 9,
                            'status': 'todo',
                            'start_time': '2026-10-03T09:00:00',
                            'end_time': '2026-10-03T10:00:00',
                          },
                        ]
                      : [],
                },
              );
              return;
            }
            expect(
              vars['domainId'],
              d.id,
              reason: 'Goal reads must explicitly scope their domain',
            );
            yield Response(
              response: const {},
              data: {
                '__typename': 'Query',
                'getActionGoalsWeek': {'week_start': '2026-09-28', 'items': []},
              },
            );
          }),
        ),
    };
  });
  tearDown(() {
    for (final c in clients.values) c.link.dispose();
  });
  test(
    'tasks combine selected domains and remember write destinations',
    () async {
      final w = Workspace(clients);
      final repo = MultiTaskRepository(w);
      expect((await repo.listAll()).map((t) => t.id).toSet(), {10, 30});
      await repo.updateStatus(id: 10, status: TaskStatus.done);
      final mutation = calls.last;
      expect(mutation.domain, 1);
      expect((mutation.request.variables['input'] as Map)['domainId'], 1);
    },
  );
  test(
    'Today and History action reads stay personal when only Home is selected',
    () async {
      final w = Workspace(clients, selected: {1});
      final rows = await PersonalActionRepository(
        w,
      ).listForCalendarDay(DateTime(2026, 10, 3));
      expect(rows.map((a) => a.id), [30]);
      expect(calls.map((c) => c.domain).toSet(), {3});
    },
  );
  test(
    'uncached ownership probes each explicit domain before writing',
    () async {
      final w = Workspace(clients);
      expect(await w.owner(30, write: true), 3);
      expect(calls.map((c) => c.domain), [1, 3]);
    },
  );
  test('read-only domains can load but cannot mutate', () async {
    final w = Workspace(clients, selected: {2});
    final repo = MultiTaskRepository(w);
    expect((await repo.listAll()).single.id, 20);
    await expectLater(
      repo.updateStatus(id: 20, status: TaskStatus.done),
      throwsStateError,
    );
    expect(
      calls.where((c) => c.request.variables.containsKey('input')),
      isEmpty,
    );
  });
  test('cross-domain relationships are rejected before writing', () async {
    final w = Workspace(clients)
      ..remember(1, [10])
      ..remember(3, [30]);
    await expectLater(
      MultiTaskRepository(w).linkChildTask(parentId: 10, childId: 30),
      throwsStateError,
    );
    expect(calls, isEmpty);
  });
  test('goal summaries query each selected domain explicitly', () async {
    await MultiGoalRepository(
      Workspace(clients),
    ).getActionGoalsWeek(weekStart: DateTime(2026, 9, 28));
    expect(calls.map((c) => c.domain).toSet(), {1, 3});
  });
  test(
    'saved selections persist and inaccessible domains are discarded',
    () async {
      SharedPreferences.setMockInitialValues({
        'nx_time.domains.${BackendPreset.localhost.serverId}.3': ['1', '999'],
      });
      final c = ProviderContainer(
        overrides: [
          authProvider.overrideWith(TestAuth.new),
          domainLoaderProvider.overrideWithValue((_) async => memberships),
          timeDomainClientFactoryProvider.overrideWithValue(
            (_, id) => clients[id]!,
          ),
        ],
      );
      addTearDown(c.dispose);
      expect((await c.read(timeDomainsProvider.future)).selectedIds, {1});
      await c.read(timeDomainsProvider.notifier).select({1, 3});
      expect(
        (await SharedPreferences.getInstance()).getStringList(
          'nx_time.domains.${BackendPreset.localhost.serverId}.3',
        ),
        containsAll(['1', '3']),
      );
    },
  );
  testWidgets(
    'creation presents writable destinations and returns the chosen domain',
    (tester) async {
      int? picked;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            timeDomainsProvider.overrideWith(
              () => FixedDomains(Workspace(clients, selected: {1, 2, 3})),
            ),
          ],
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, _) => Scaffold(
                body: TextButton(
                  onPressed: () async {
                    picked = await chooseCreationDomain(context, ref);
                  },
                  child: const Text('Create'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();
      expect(find.text('Read only'), findsNothing);
      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();
      expect(picked, 1);
    },
  );
}
