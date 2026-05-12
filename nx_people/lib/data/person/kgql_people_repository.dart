import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:nx_db/kgql.dart';
import 'package:nx_people/data/person/person_attr_keys.dart';
import 'package:nx_people/data/person/person_mapper.dart';
import 'package:nx_people/domain/person/person.dart';
import 'package:nx_people/domain/person/person_query.dart';

class KgqlPeopleRepository implements PersonRepository {
  KgqlPeopleRepository({
    required GraphQLClient client,
    required Future<ModelType> Function() loadPersonSchema,
    required int domainId,
  }) : _client = client,
       _loadPersonSchema = loadPersonSchema,
       _domainId = domainId;

  final GraphQLClient _client;
  final Future<ModelType> Function() _loadPersonSchema;
  final int _domainId;

  @override
  Future<Person?> getById(int id) async {
    final schema = await _loadPersonSchema();
    final model = await fetchKgqlModelById(
      _client,
      modelTypeName: kPersonModelTypeName,
      id: id,
      struct: personFetchStruct(schema),
      domainId: _domainId,
    );
    return model == null ? null : personFromModel(model);
  }

  @override
  Future<List<Person>> listRecent({int limit = 20}) async {
    return (await _listAll()).take(limit).toList();
  }

  @override
  Future<List<Person>> listPinned({int limit = 20}) async {
    return (await _listAll())
        .where((person) => person.pinned)
        .take(limit)
        .toList();
  }

  @override
  Future<List<Person>> listFollowUp({int limit = 20}) async {
    return (await _listAll())
        .where((person) => person.status == 'Follow up')
        .take(limit)
        .toList();
  }

  @override
  Future<List<Person>> search(String query) async {
    final q = query.trim();
    if (q.isEmpty) return const <Person>[];
    return (await _listAll()).where((person) => person.matches(q)).toList();
  }

  @override
  Future<PeopleResultContext> context(String type, String label) async {
    final rows = await _filter(type, label);
    return PeopleResultContext(
      type: type,
      label: label,
      personIds: rows.map((person) => person.id).toList(),
    );
  }

  @override
  Future<List<Person>> peopleFor(PeopleResultContext context) async {
    final byId = {for (final person in await _listAll()) person.id: person};
    return [
      for (final id in context.personIds)
        if (byId[id] case final person?) person,
    ];
  }

  @override
  Future<int> count(String type, String label) async {
    return (await _filter(type, label)).length;
  }

  @override
  Future<List<String>> listCompanies() async {
    return _unique((await _listAll()).map((person) => person.company));
  }

  @override
  Future<List<String>> listMeetings() async {
    return _unique((await _listAll()).expand((person) => person.meetings));
  }

  @override
  Future<List<String>> listPlanned() async {
    return _unique((await _listAll()).expand((person) => person.planned));
  }

  @override
  Future<List<PeopleTagSystem>> listTagSystems() async {
    final schema = await _loadPersonSchema();
    final people = await _listAll();
    return [
      for (final system in schema.tagSystems ?? const <TagSystem>[])
        PeopleTagSystem(
          name: system.name,
          hierarchical: system.isHierarchical,
          exclusive: system.selectionMode == 'exclusive',
          tags: [
            for (final node in system.nodes)
              if (_countForTag(people, system.name, node.name) > 0) node.name,
          ],
        ),
    ].where((system) => system.tags.isNotEmpty).toList();
  }

  Future<List<Person>> _filter(String type, String label) async {
    final people = await _listAll();
    return switch (type) {
      'Search' => search(label),
      'Recent' => Future<List<Person>>.value(people),
      'Company' => Future<List<Person>>.value(
        people.where((person) => person.company == label).toList(),
      ),
      'Meeting' => Future<List<Person>>.value(
        people.where((person) => person.meetings.contains(label)).toList(),
      ),
      'Planned' => Future<List<Person>>.value(
        people.where((person) => person.planned.contains(label)).toList(),
      ),
      kPeopleStatusTagSystem => Future<List<Person>>.value(
        people.where((person) => person.status == label).toList(),
      ),
      _ => Future<List<Person>>.value(
        people.where((person) => person.tags.contains(label)).toList(),
      ),
    };
  }

  Future<List<Person>> _listAll() async {
    final schema = await _loadPersonSchema();
    final models = await fetchKgqlModels(
      _client,
      filter: const {'model_type': kPersonModelTypeName},
      struct: personFetchStruct(schema),
      domainId: _domainId,
    );
    final rows = [for (final model in models) personFromModel(model)];
    rows.sort((a, b) => a.name.compareTo(b.name));
    return rows;
  }

  int _countForTag(List<Person> people, String system, String node) {
    if (system == kPeopleStatusTagSystem) {
      return people.where((person) => person.status == node).length;
    }
    return people.where((person) => person.tags.contains(node)).length;
  }

  List<String> _unique(Iterable<String> values) {
    return values
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
  }
}
