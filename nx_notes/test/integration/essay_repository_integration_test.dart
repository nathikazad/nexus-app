import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:nx_db/auth.dart';
import 'package:nx_db/kgql.dart';
import 'package:nx_notes/data/essay/essay_attr_keys.dart';
import 'package:nx_notes/data/essay/kgql_essay_repository.dart';
import 'package:nx_notes/domain/essay/essay_query.dart';
import 'package:nx_notes/domain/links/linked_model.dart';

void main() {
  test(
    'loads Essay schema and tag systems from localhost',
    () async {
      final harness = _IntegrationHarness();

      final systems = await harness.repo.listTagSystems();
      final status = systems.singleWhere(
        (system) => system.name == kEssayStatusTagSystem,
      );
      final topic = systems.singleWhere(
        (system) => system.name == kEssayTopicTagSystem,
      );

      expect(status.hierarchical, isFalse);
      expect(status.nodes.map((node) => node.name), contains('Draft'));
      expect(topic.hierarchical, isFalse);
      expect(topic.nodes.map((node) => node.name), isNotEmpty);
      expect(
        systems.map((system) => system.name),
        isNot(contains(kEssayAreaTagSystem)),
      );
    },
    skip: runNotesIntegration ? null : kNotesIntegrationSkipReason,
    tags: ['integration'],
  );

  test(
    'Essay repository main actions round trip through localhost',
    () async {
      final harness = _IntegrationHarness();
      final cleanupIds = <int>[];
      addTearDown(() => harness.deleteModels(cleanupIds.reversed));

      final systems = await harness.repo.listTagSystems();
      final topicSystem = systems.singleWhere(
        (system) => system.name == kEssayTopicTagSystem,
      );
      final topicName = topicSystem.nodes.first.name;
      final marker =
          'nx_notes integration ${DateTime.now().microsecondsSinceEpoch}';

      final created = await harness.repo.create();
      cleanupIds.add(created.id);

      expect(created.title, 'Untitled essay');
      expect(created.status, 'Draft');
      expect(created.topics, isEmpty);

      final updated = await harness.repo.updateDraft(
        created.copyWith(
          title: 'Essay repository round trip $marker',
          document: 'This body belongs to $marker and should be searchable.',
          jsonDocument: _appflowyDocumentJson(
            'This body belongs to $marker and should be searchable.',
          ),
          topics: [topicName],
          pinned: true,
        ),
      );

      expect(updated.title, contains(marker));
      expect(updated.document, contains(marker));
      expect(updated.status, 'Draft');
      expect(updated.topics, contains(topicName));
      expect(updated.pinned, isTrue);

      final loaded = await harness.repo.getById(updated.id);
      expect(loaded, isNotNull);
      expect(loaded!.title, updated.title);

      final searchResults = await harness.repo.search(marker);
      expect(searchResults.map((essay) => essay.id), contains(updated.id));

      final recent = await harness.repo.listRecent(limit: 50);
      expect(recent.map((essay) => essay.id), contains(updated.id));

      final pinned = await harness.repo.listPinned(limit: 50);
      expect(pinned.map((essay) => essay.id), contains(updated.id));

      final statusTagged = await harness.repo.listByTag(
        const EssayTagFilter(system: kEssayStatusTagSystem, node: 'Draft'),
      );
      expect(statusTagged.map((essay) => essay.id), contains(updated.id));

      final topicTagged = await harness.repo.listByTag(
        EssayTagFilter(system: kEssayTopicTagSystem, node: topicName),
      );
      expect(topicTagged.map((essay) => essay.id), contains(updated.id));

      final projects = await harness.repo.listProjects();
      expect(projects, isNotEmpty);
      final project = projects.first;
      final projectSearch = await harness.repo.searchLinkableModels(
        modelType: LinkableModelType.project,
        query: project.name,
      );
      expect(projectSearch.map((model) => model.id), contains(project.id));

      final withProject = await harness.repo.attachLinkedModel(
        essayId: updated.id,
        modelType: LinkableModelType.project,
        modelId: project.id,
      );
      final projectLink = withProject.links.firstWhere(
        (link) => link.modelType == 'Project' && link.id == project.id,
      );
      expect(projectLink.name, project.name);
      expect(projectLink.relationId, isNotNull);

      final withoutProject = await harness.repo.detachProject(
        updated.id,
        projectLink.relationId!,
      );
      expect(
        withoutProject.links.where(
          (link) => link.modelType == 'Project' && link.id == project.id,
        ),
        isEmpty,
      );

      final snapshot = await harness.repo.createSnapshot(
        updated.id,
        source: 'integration_test',
        changeSummary: 'first checkpoint',
      );
      cleanupIds.add(snapshot.id);

      expect(snapshot.essayId, updated.id);
      expect(snapshot.versionNumber, greaterThanOrEqualTo(1));
      expect(snapshot.document, updated.document);
      expect(snapshot.changeSummary, 'first checkpoint');

      final snapshots = await harness.repo.listSnapshots(updated.id);
      expect(snapshots.map((snap) => snap.id), contains(snapshot.id));
    },
    skip: runNotesIntegration ? null : kNotesIntegrationSkipReason,
    tags: ['integration'],
  );
}

class _IntegrationHarness {
  _IntegrationHarness() : client = createClient(_graphqlEndpoint, _userId) {
    repo = KgqlEssayRepository(
      client: client,
      loadEssaySchema: () => fetchKgqlModelTypeByName(
        client,
        kEssayModelTypeName,
        domainId: _domainId,
      ),
      loadEssaySnapSchema: () => fetchKgqlModelTypeByName(
        client,
        kEssaySnapModelTypeName,
        domainId: _domainId,
      ),
      domainId: _domainId,
    );
  }

  final GraphQLClient client;
  late final KgqlEssayRepository repo;

  Future<void> deleteModels(Iterable<int> ids) async {
    for (final id in ids) {
      try {
        await setKgqlModel(client, setKgqlDelete(id), domainId: _domainId);
      } catch (_) {
        // Cleanup should not hide the assertion that originally failed.
      }
    }
  }
}

Map<String, dynamic> _appflowyDocumentJson(String text) {
  return <String, dynamic>{
    'format': 'appflowy_document',
    'document': <String, dynamic>{
      'type': 'page',
      'children': <Map<String, dynamic>>[
        <String, dynamic>{
          'type': 'paragraph',
          'data': <String, dynamic>{
            'delta': <Map<String, dynamic>>[
              <String, dynamic>{'insert': text},
            ],
          },
        },
      ],
    },
  };
}

bool get runNotesIntegration =>
    Platform.environment['RUN_NX_NOTES_INTEGRATION'] == 'true';

const kNotesIntegrationSkipReason =
    'Set RUN_NX_NOTES_INTEGRATION=true and run PGDB on localhost.';

String get _graphqlEndpoint =>
    Platform.environment['NX_NOTES_INTEGRATION_GRAPHQL_HTTP'] ??
    kIntegrationTestBackendUrls.graphqlHttp;

String get _userId =>
    Platform.environment['NX_NOTES_INTEGRATION_USER_ID'] ?? '1';

int get _domainId =>
    int.tryParse(
      Platform.environment['NX_NOTES_INTEGRATION_DOMAIN_ID'] ?? '',
    ) ??
    1;
