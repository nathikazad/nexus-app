import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_db/kgql.dart';
import 'package:nx_projects/data/tasks/kgql_task_repository.dart';
import 'package:nx_projects/domain/task/task.dart';

void main() {
  test(
    'reassign and clear project/sprint without violating one-per-task',
    () async {
      final endpoint = Platform.environment['NX_RELATIONSHIP_TEST_URL']!;
      expect(Uri.parse(endpoint).host, anyOf('localhost', '127.0.0.1'));
      final client = createClient(endpoint, '1', domainId: 2);
      final ids = <int>[];
      addTearDown(() async {
        for (final id in ids.reversed) {
          await setKgqlModel(client, setKgqlDelete(id));
        }
      });
      Future<int> create(String type, int n) async {
        final id = await setKgqlModel(
          client,
          SetModelRequest(
            modelType: type,
            name: 'Membership test $type $n',
            attributes: type == 'Sprint'
                ? [
                    SetModelAttribute(
                      key: 'start_date',
                      value: '2026-10-01T00:00:00',
                    ),
                    SetModelAttribute(
                      key: 'end_date',
                      value: '2026-10-07T00:00:00',
                    ),
                    SetModelAttribute(key: 'status', value: 'planned'),
                  ]
                : null,
          ),
        );
        ids.add(id);
        return id;
      }

      final p1 = await create('Project', 1), p2 = await create('Project', 2);
      final s1 = await create('Sprint', 1), s2 = await create('Sprint', 2);
      final repo = KgqlTaskRepository(
        client: client,
        loadProjectTaskSchema: () =>
            fetchKgqlModelTypeByName(client, 'ProjectTask'),
        loadBugSchema: () => fetchKgqlModelTypeByName(client, 'Bug'),
        loadFeatureSchema: () => fetchKgqlModelTypeByName(client, 'Feature'),
      );
      var task = await repo.upsert(
        Task(id: 0, title: 'Membership test task', projectId: p1, sprintId: s1),
      );
      ids.add(task.id);
      expect(task.projectId, p1);
      expect(task.sprintId, s1);
      task = await repo.upsert(task.copyWith(projectId: p2, sprintId: s2));
      expect(task.projectId, p2);
      expect(task.sprintId, s2);
      task = await repo.upsert(
        Task(id: task.id, title: task.title),
      );
      expect(task.projectId, isNull);
      expect(task.sprintId, isNull);
    },
    skip: Platform.environment['NX_RELATIONSHIP_TEST_URL'] == null,
    tags: ['integration'],
  );
}
