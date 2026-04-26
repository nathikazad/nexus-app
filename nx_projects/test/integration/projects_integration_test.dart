import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_db/auth.dart';

import 'package:nx_projects/data/providers.dart';
import 'package:nx_projects/domain/task/task_bucket.dart';
import 'package:nx_projects/domain/task/task_kind.dart';
import 'package:nx_projects/domain/task/task_severity.dart';
import 'package:nx_projects/domain/task/task_status.dart';
import '../_support/integration_auth.dart';

void main() {
  group('nx_projects integration (live GraphQL)', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer(overrides: projectsIntegrationOverrides);
    });

    tearDown(() => container.dispose());

    test('projects: seeded roots and subprojects', () async {
      await container.read(authProvider.future);

      final projects = await container.read(projectRepositoryProvider).listRootProjects();
      final names = projects.map((p) => p.name).toSet();
      expect(names, contains('Nexus Web App'));
      expect(names, contains('Data Pipeline v2'));
      expect(names, contains('Mobile App'));

      final nexus = projects.firstWhere((p) => p.name == 'Nexus Web App');
      expect(nexus.parentId, isNull);

      final subs = await container.read(projectRepositoryProvider).getSubProjects(nexus.id);
      final subNames = subs.map((p) => p.name).toSet();
      expect(subNames, contains('UI Polish'));
      expect(subNames, contains('Auth Rewrite'));
      expect(subs.length, greaterThanOrEqualTo(2));
      for (final s in subs) {
        expect(s.parentId, nexus.id);
      }
    }, tags: ['integration'], skip: runProjectsIntegration ? null : kProjectsIntegrationSkipReason);

    test('sprints: 3 seeded sprints with correct state mapping', () async {
      await container.read(authProvider.future);

      final sprints = await container.read(sprintRepositoryProvider).listSprints();
      expect(sprints.length, greaterThanOrEqualTo(3));
      final byName = {for (final s in sprints) s.name: s};

      final s13 = byName['Sprint 13']!;
      expect(s13.state.name, 'done');
      expect(s13.length, 7);
      expect(s13.start, '2026-04-13');

      final s14 = byName['Sprint 14']!;
      expect(s14.state.name, 'active');
      expect(s14.goal, contains('dark mode'));

      final s15 = byName['Sprint 15']!;
      expect(s15.state.name, 'planned');

      // Deferred fields default properly
      expect(s13.capH, 0);
      expect(s13.retro, '');
      expect(s13.dayNotes, isEmpty);
    }, tags: ['integration'], skip: runProjectsIntegration ? null : kProjectsIntegrationSkipReason);

    test('tasks: seeded Feature/Bug with correct attribute mapping', () async {
      await container.read(authProvider.future);

      final tasks = await container.read(taskRepositoryProvider).listAll();
      expect(tasks.length, greaterThanOrEqualTo(22));
      expect(tasks.any((t) => t.kind == TaskKind.feat), isTrue);
      expect(tasks.any((t) => t.kind == TaskKind.bug), isTrue);

      final oom = tasks.firstWhere((t) => t.title == 'Nightly job OOM');
      expect(oom.kind, TaskKind.bug);
      expect(oom.severity, TaskSeverity.crit);
      expect(oom.status, TaskStatus.blocked);
      expect(oom.estimate, 6.0);
      expect(oom.plannedFor, '2026-04-24');
      expect(oom.sprintId, isNotNull);
      expect(oom.projectId, isNotNull);
      expect(oom.crumb, isNot('—'));

      final splash = tasks.firstWhere((t) => t.title == 'iOS splash flicker');
      expect(splash.status, TaskStatus.doing);
      expect(splash.kind, TaskKind.bug);
      expect(splash.severity, TaskSeverity.med);

      final darkMode = tasks.firstWhere((t) => t.title == 'Add dark mode');
      expect(darkMode.kind, TaskKind.feat);
      expect(darkMode.status, TaskStatus.doing);
      expect(darkMode.estimate, 8.0);
      expect(darkMode.bucket, TaskBucket.now);
      expect(darkMode.severity, isNull);
      expect(darkMode.sprintId, isNotNull);
    }, tags: ['integration'], skip: runProjectsIntegration ? null : kProjectsIntegrationSkipReason);

    test('task project/sprint relations resolve to real ids', () async {
      await container.read(authProvider.future);

      final projects = await container.read(projectRepositoryProvider).listRootProjects();
      final nexus = projects.firstWhere((p) => p.name == 'Nexus Web App');
      final subs = await container.read(projectRepositoryProvider).getSubProjects(nexus.id);
      final uiPolish = subs.firstWhere((p) => p.name == 'UI Polish');

      final tasks = await container.read(taskRepositoryProvider).listAll();

      final darkMode = tasks.firstWhere((t) => t.title == 'Add dark mode');
      expect(darkMode.subProjectId, uiPolish.id,
          reason: 'Add dark mode should be under UI Polish');
      expect(darkMode.projectId, nexus.id,
          reason: 'root projectId should be Nexus');

      final pipeline = projects.firstWhere((p) => p.name == 'Data Pipeline v2');
      final oom = tasks.firstWhere((t) => t.title == 'Nightly job OOM');
      expect(oom.projectId, pipeline.id,
          reason: 'Nightly job OOM should be under Data Pipeline v2');
      expect(oom.subProjectId, isNull);
    }, tags: ['integration'], skip: runProjectsIntegration ? null : kProjectsIntegrationSkipReason);

    test('tasks have KGQL relation ids for updates', () async {
      await container.read(authProvider.future);

      final tasks = await container.read(taskRepositoryProvider).listAll();
      final withProject = tasks.where((t) => t.projectId != null);
      expect(withProject, isNotEmpty);
      for (final t in withProject) {
        expect(t.inProjectRelationId, isNotNull,
            reason: '${t.title} has projectId but no inProjectRelationId');
      }
      final withSprint = tasks.where((t) => t.sprintId != null);
      expect(withSprint, isNotEmpty);
      for (final t in withSprint) {
        expect(t.inSprintRelationId, isNotNull,
            reason: '${t.title} has sprintId but no inSprintRelationId');
      }
    }, tags: ['integration'], skip: runProjectsIntegration ? null : kProjectsIntegrationSkipReason);
  });
}
