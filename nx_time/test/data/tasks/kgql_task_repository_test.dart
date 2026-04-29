import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nx_db/auth.dart';
import 'package:nx_db/kgql.dart';
import 'package:nx_db/riverpod.dart';
import 'package:nx_time/data/providers.dart';
import 'package:nx_time/data/tasks/kgql_task_repository.dart';
import 'package:nx_time/data/projects/project_attr_keys.dart';
import 'package:nx_time/data/tasks/task_attr_keys.dart';
import 'package:nx_time/domain/tasks/task_status.dart';

import '../../_support/mock_graphql_client.dart';

class _AuthLoggedIn extends AuthController {
  _AuthLoggedIn() : super(initialDelay: Duration.zero, skipBackendPing: true);
  @override
  Future<User?> build() async => User(
        userId: '1',
        personalDomainId: 1,
        homeDomainId: 2,
        preset: BackendPreset.localhost,
      );
}

ModelType _minimalTaskSchema() => ModelType(id: 1, name: 'Task');

void main() {
  setUpAll(registerGraphqlFallbacks);

  test('listForPicker loads Task rows', () async {
    final mock = MockGraphQLClient();
    when(() => mock.query(any())).thenAnswer((_) async => okQueryResult({
          'getKgqlModels': [
            {'id': 1, 'name': 'Refactor token validation', 'model_type_id': 9},
          ],
        }));

    final container = ProviderContainer(
      overrides: [
        authProvider.overrideWith(_AuthLoggedIn.new),
        graphqlClientProvider.overrideWithValue(mock),
      ],
    );
    addTearDown(container.dispose);
    await container.read(authProvider.future);

    final repo = container.read(taskRepositoryProvider);
    final tasks = await repo.listForPicker();
    expect(tasks.length, 1);
    expect(tasks.first.name, 'Refactor token validation');
    expect(tasks.first.modelTypeId, 9);
    verify(() => mock.query(any())).called(2);
  });

  test('linkChildTask sends set_kgql_models with Task link', () async {
    final mock = MockGraphQLClient();
    when(() => mock.mutate(any())).thenAnswer((_) async => okMutationResult({
          'setKgqlModels': {
            'json': {'id': 99},
          },
        }));

    final repo = KgqlTaskRepository(
      client: mock,
      loadTaskSchema: () async => throw UnsupportedError('not used'),
      personalDomainId: 1,
      homeDomainId: 2,
    );

    final id = await repo.linkChildTask(parentId: 10, childId: 20);
    expect(id, 99);

    final captured =
        verify(() => mock.mutate(captureAny())).captured.single as MutationOptions;
    final input = captured.variables!['input'] as Map<String, dynamic>;
    final data = input['data'] as Map<String, dynamic>;
    expect(data['id'], 10);
    final rels = data['relations'] as List<dynamic>;
    expect(rels.single['model_type'], kTaskRelationKey);
    expect(rels.single['link'], [20]);
  });

  test('unlinkChildTask sends relation delete by id', () async {
    final mock = MockGraphQLClient();
    when(() => mock.mutate(any())).thenAnswer((_) async => okMutationResult({
          'setKgqlModels': {
            'json': {'id': 10},
          },
        }));

    final repo = KgqlTaskRepository(
      client: mock,
      loadTaskSchema: () async => throw UnsupportedError('not used'),
      personalDomainId: 1,
      homeDomainId: 2,
    );

    await repo.unlinkChildTask(parentId: 10, relationId: 777);

    final captured = verify(() => mock.mutate(captureAny())).captured.single
        as MutationOptions;
    final input = captured.variables!['input'] as Map<String, dynamic>;
    final data = input['data'] as Map<String, dynamic>;
    expect(data['id'], 10);
    final rels = data['relations'] as List<dynamic>;
    expect(rels.single['id'], 777);
    expect(rels.single['delete'], isTrue);
  });

  test('linkProject sends Project relation', () async {
    final mock = MockGraphQLClient();
    when(() => mock.mutate(any())).thenAnswer((_) async => okMutationResult({
          'setKgqlModels': {
            'json': {'id': 1},
          },
        }));

    final repo = KgqlTaskRepository(
      client: mock,
      loadTaskSchema: () async => throw UnsupportedError('not used'),
      personalDomainId: 1,
      homeDomainId: 2,
    );

    await repo.linkProject(taskId: 5, projectId: 8);

    final captured = verify(() => mock.mutate(captureAny())).captured.single
        as MutationOptions;
    final input = captured.variables!['input'] as Map<String, dynamic>;
    final data = input['data'] as Map<String, dynamic>;
    final rels = data['relations'] as List<dynamic>;
    expect(rels.single['model_type'], kProjectRelationKey);
    expect(rels.single['link'], [8]);
  });

  test('linkActivity sends concrete activity model_type', () async {
    final mock = MockGraphQLClient();
    when(() => mock.mutate(any())).thenAnswer((_) async => okMutationResult({
          'setKgqlModels': {
            'json': {'id': 1},
          },
        }));

    final repo = KgqlTaskRepository(
      client: mock,
      loadTaskSchema: () async => throw UnsupportedError('not used'),
      personalDomainId: 1,
      homeDomainId: 2,
    );

    await repo.linkActivity(
      taskId: 3,
      activityId: 100,
      activityModelTypeName: 'Meet',
    );

    final captured = verify(() => mock.mutate(captureAny())).captured.single
        as MutationOptions;
    final input = captured.variables!['input'] as Map<String, dynamic>;
    final data = input['data'] as Map<String, dynamic>;
    final rels = data['relations'] as List<dynamic>;
    expect(rels.single['model_type'], 'Meet');
    expect(rels.single['link'], [100]);
  });

  test('listAll loads schema then models with status filter', () async {
    final mock = MockGraphQLClient();
    var queryCount = 0;
    when(() => mock.query(any())).thenAnswer((_) async {
      queryCount++;
      if (queryCount == 1) {
        return okQueryResult({
          'getKgqlModelType': [
            {
              'id': 1,
              'name': 'Task',
              'attributes': [
                {'key': 'status', 'value_type': 'string'},
              ],
            },
          ],
        });
      }
      return okQueryResult({
        'getKgqlModels': [
          {
            'id': 7,
            'name': 'Do thing',
            'model_type_id': 9,
            'status': 'todo',
            'model_type': {'id': 9, 'name': 'Task', 'type_kind': 'base'},
          },
        ],
      });
    });

    final repo = KgqlTaskRepository(
      client: mock,
      loadTaskSchema: () async {
        final r = await mock.query(
          QueryOptions(document: gql('query { __typename }')),
        );
        final rows = r.data!['getKgqlModelType'] as List<dynamic>;
        return ModelType.fromJson(
          Map<String, dynamic>.from(rows.first as Map),
        );
      },
      personalDomainId: 1,
      homeDomainId: 2,
    );

    final list = await repo.listAll(status: TaskStatus.todo);
    expect(list.length, 1);
    expect(list.first.name, 'Do thing');
    expect(queryCount, 3);
  });

  test('updateStatus sends only status attribute', () async {
    final mock = MockGraphQLClient();
    when(() => mock.mutate(any())).thenAnswer((_) async => okMutationResult({
          'setKgqlModels': {
            'json': {'id': 7},
          },
        }));

    final repo = KgqlTaskRepository(
      client: mock,
      loadTaskSchema: () async => _minimalTaskSchema(),
      personalDomainId: 1,
      homeDomainId: 2,
    );

    final id = await repo.updateStatus(id: 7, status: TaskStatus.done);
    expect(id, 7);

    final captured =
        verify(() => mock.mutate(captureAny())).captured.single as MutationOptions;
    final input = captured.variables!['input'] as Map<String, dynamic>;
    final data = input['data'] as Map<String, dynamic>;
    final attrs = data['attributes'] as List<dynamic>;
    expect(attrs.length, 1);
    expect(attrs.single['key'], kTaskAttrStatus);
    expect(attrs.single['value'], 'done');
  });

  test('moveTaskToProject no-op when project unchanged', () async {
    final mock = MockGraphQLClient();
    when(() => mock.query(any())).thenAnswer((_) async => okQueryResult({
          'getKgqlModels': [
            {
              'id': 5,
              'name': 'T',
              'model_type_id': 9,
              'status': 'todo',
              'model_type': {'id': 9, 'name': 'Task', 'type_kind': 'base'},
              'relations': [
                {'relation_id': 200, 'model_id': 10, 'model_type': 'Project'},
              ],
            },
          ],
        }));

    final repo = KgqlTaskRepository(
      client: mock,
      loadTaskSchema: () async => _minimalTaskSchema(),
      personalDomainId: 1,
      homeDomainId: 2,
    );

    await repo.moveTaskToProject(taskId: 5, projectId: 10);

    verifyNever(() => mock.mutate(any()));
  });

  test('moveTaskToProject unlinks then links when project changes', () async {
    final mock = MockGraphQLClient();
    when(() => mock.mutate(any())).thenAnswer((_) async => okMutationResult({
          'setKgqlModels': {
            'json': {'id': 5},
          },
        }));

    when(() => mock.query(any())).thenAnswer((_) async => okQueryResult({
          'getKgqlModels': [
            {
              'id': 5,
              'name': 'T',
              'model_type_id': 9,
              'status': 'todo',
              'model_type': {'id': 9, 'name': 'Task', 'type_kind': 'base'},
              'relations': [
                {'relation_id': 200, 'model_id': 10, 'model_type': 'Project'},
              ],
            },
          ],
        }));

    final repo = KgqlTaskRepository(
      client: mock,
      loadTaskSchema: () async => _minimalTaskSchema(),
      personalDomainId: 1,
      homeDomainId: 2,
    );

    await repo.moveTaskToProject(taskId: 5, projectId: 99);

    final captured = verify(() => mock.mutate(captureAny())).captured;
    expect(captured.length, 2);
    final first = captured[0] as MutationOptions;
    final firstData =
        (first.variables!['input'] as Map<String, dynamic>)['data']
            as Map<String, dynamic>;
    final firstRels = firstData['relations'] as List<dynamic>;
    expect(firstRels.single['id'], 200);
    expect(firstRels.single['delete'], isTrue);

    final second = captured[1] as MutationOptions;
    final secondData =
        (second.variables!['input'] as Map<String, dynamic>)['data']
            as Map<String, dynamic>;
    final secondRels = secondData['relations'] as List<dynamic>;
    expect(secondRels.single['model_type'], kProjectRelationKey);
    expect(secondRels.single['link'], [99]);
  });

  test('moveTaskToProject only unlinks when projectId is null', () async {
    final mock = MockGraphQLClient();
    when(() => mock.mutate(any())).thenAnswer((_) async => okMutationResult({
          'setKgqlModels': {
            'json': {'id': 5},
          },
        }));

    when(() => mock.query(any())).thenAnswer((_) async => okQueryResult({
          'getKgqlModels': [
            {
              'id': 5,
              'name': 'T',
              'model_type_id': 9,
              'status': 'todo',
              'model_type': {'id': 9, 'name': 'Task', 'type_kind': 'base'},
              'relations': [
                {'relation_id': 200, 'model_id': 10, 'model_type': 'Project'},
              ],
            },
          ],
        }));

    final repo = KgqlTaskRepository(
      client: mock,
      loadTaskSchema: () async => _minimalTaskSchema(),
      personalDomainId: 1,
      homeDomainId: 2,
    );

    await repo.moveTaskToProject(taskId: 5, projectId: null);

    final capturedList = verify(() => mock.mutate(captureAny())).captured;
    expect(capturedList.length, 1);
    final captured = capturedList.single as MutationOptions;
    final data =
        (captured.variables!['input'] as Map<String, dynamic>)['data']
            as Map<String, dynamic>;
    final rels = data['relations'] as List<dynamic>;
    expect(rels.single['id'], 200);
    expect(rels.single['delete'], isTrue);
  });
}
