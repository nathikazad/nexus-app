import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:nx_db/auth.dart';
import 'package:nx_db/kgql.dart';
import 'package:nx_people/data/person/kgql_people_repository.dart';
import 'package:nx_people/data/person/person_attr_keys.dart';

void main() {
  test(
    'loads Person schema and optional tag systems from localhost',
    () async {
      final harness = _IntegrationHarness();

      final systems = await harness.repo.listTagSystems();
      expect(systems.map((system) => system.name), isNot(contains('Essay')));

      final recent = await harness.repo.listRecent(limit: 5);
      expect(recent, isA<List>());
    },
    skip: runPeopleIntegration ? null : kPeopleIntegrationSkipReason,
    tags: ['integration'],
  );

  test(
    'Person repository round trips a live KGQL person row',
    () async {
      final harness = _IntegrationHarness();
      final cleanupIds = <int>[];
      addTearDown(() => harness.deleteModels(cleanupIds.reversed));

      final schema = await harness.loadPersonSchema();
      final attrKeys = _attributeKeys(schema);
      final tagSystems = schema.tagSystems ?? const <TagSystem>[];
      final statusSystem = tagSystems.where(
        (system) => system.name == kPeopleStatusTagSystem,
      );
      final statusNode =
          statusSystem.isEmpty || statusSystem.first.nodes.isEmpty
          ? null
          : statusSystem.first.nodes.first.name;

      final marker =
          'nx_people integration ${DateTime.now().microsecondsSinceEpoch}';
      final id = await setKgqlModel(
        harness.client,
        SetModelRequest(
          modelType: kPersonModelTypeName,
          name: 'People repository $marker',
          description: 'Live person row for $marker',
          attributes: [
            if (attrKeys.contains(kPersonAttrRole))
              SetModelAttribute(
                key: kPersonAttrRole,
                value: 'Integration Tester',
              ),
            if (attrKeys.contains(kPersonAttrCompany))
              SetModelAttribute(key: kPersonAttrCompany, value: 'Nexus'),
            if (attrKeys.contains(kPersonAttrLocation))
              SetModelAttribute(key: kPersonAttrLocation, value: 'Test Lab'),
            if (attrKeys.contains(kPersonAttrStatus))
              SetModelAttribute(
                key: kPersonAttrStatus,
                value: statusNode ?? 'Active',
              ),
            if (attrKeys.contains(kPersonAttrPinned))
              SetModelAttribute(key: kPersonAttrPinned, value: true),
            if (attrKeys.contains(kPersonAttrEmail))
              SetModelAttribute(
                key: kPersonAttrEmail,
                value: 'people.integration@example.com',
              ),
            if (attrKeys.contains(kPersonAttrSummary))
              SetModelAttribute(
                key: kPersonAttrSummary,
                value: 'Searchable summary for $marker',
              ),
          ],
          tags: [
            if (statusNode != null)
              SetModelTag(system: kPeopleStatusTagSystem, nodes: [statusNode]),
          ],
        ),
        domainId: harness.domainId,
      );
      cleanupIds.add(id);

      final loaded = await harness.repo.getById(id);
      expect(loaded, isNotNull);
      expect(loaded!.name, contains(marker));
      expect(loaded.summary, contains(marker));

      final searchResults = await harness.repo.search(marker);
      expect(searchResults.map((person) => person.id), contains(id));

      final recent = await harness.repo.listRecent(limit: 100);
      expect(recent.map((person) => person.id), contains(id));

      if (attrKeys.contains(kPersonAttrPinned)) {
        final pinned = await harness.repo.listPinned(limit: 100);
        expect(pinned.map((person) => person.id), contains(id));
      }

      if (attrKeys.contains(kPersonAttrCompany)) {
        final context = await harness.repo.context('Company', 'Nexus');
        expect(context.personIds, contains(id));
        final rows = await harness.repo.peopleFor(context);
        expect(rows.map((person) => person.id), contains(id));
      }

      if (statusNode != null) {
        final context = await harness.repo.context(
          kPeopleStatusTagSystem,
          statusNode,
        );
        expect(context.personIds, contains(id));
      }
    },
    skip: runPeopleIntegration ? null : kPeopleIntegrationSkipReason,
    tags: ['integration'],
  );
}

class _IntegrationHarness {
  _IntegrationHarness() : client = createClient(_graphqlEndpoint, _userId) {
    repo = KgqlPeopleRepository(
      client: client,
      loadPersonSchema: loadPersonSchema,
      domainId: domainId,
    );
  }

  final GraphQLClient client;
  late final KgqlPeopleRepository repo;
  int get domainId => _domainId;

  Future<ModelType> loadPersonSchema() {
    return fetchKgqlModelTypeByName(
      client,
      kPersonModelTypeName,
      domainId: domainId,
    );
  }

  Future<void> deleteModels(Iterable<int> ids) async {
    for (final id in ids) {
      try {
        await setKgqlModel(client, setKgqlDelete(id), domainId: domainId);
      } catch (_) {
        // Cleanup should not hide the original assertion failure.
      }
    }
  }
}

Set<String> _attributeKeys(ModelType schema) {
  return {
    for (final attr in schema.attributes ?? const <AttributeDefinition>[])
      if (attr.key != null) attr.key!,
  };
}

bool get runPeopleIntegration =>
    Platform.environment['RUN_NX_PEOPLE_INTEGRATION'] == 'true';

const kPeopleIntegrationSkipReason =
    'Set RUN_NX_PEOPLE_INTEGRATION=true and run PGDB on localhost.';

String get _graphqlEndpoint =>
    Platform.environment['NX_PEOPLE_INTEGRATION_GRAPHQL_HTTP'] ??
    kIntegrationTestBackendUrls.graphqlHttp;

String get _userId =>
    Platform.environment['NX_PEOPLE_INTEGRATION_USER_ID'] ?? '1';

int get _domainId =>
    int.tryParse(
      Platform.environment['NX_PEOPLE_INTEGRATION_DOMAIN_ID'] ?? '',
    ) ??
    1;
