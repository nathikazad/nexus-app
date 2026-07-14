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
  }) : _client = client,
       _loadPersonSchema = loadPersonSchema;

  final GraphQLClient _client;
  final Future<ModelType> Function() _loadPersonSchema;
  @override
  Future<Person?> getById(int id) async {
    final schema = await _loadPersonSchema();
    final model = await fetchKgqlModelById(
      _client,
      modelTypeName: kPersonModelTypeName,
      id: id,
      struct: personFetchStruct(schema),
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
  Future<int> createPerson(PersonDraft draft) async {
    return setKgqlModel(
      _client,
      setKgqlCreate(
        modelType: kPersonModelTypeName,
        name: draft.name.trim(),
        description: draft.summary.trim(),
        attributes: _draftAttributes(draft),
      ),
    );
  }

  @override
  Future<void> updatePerson(int id, PersonDraft draft) async {
    await setKgqlModel(
      _client,
      setKgqlUpdate(
        id: id,
        modelType: kPersonModelTypeName,
        name: draft.name.trim(),
        description: draft.summary.trim(),
        attributes: _draftAttributes(draft),
      ),
    );
  }

  @override
  Future<void> resolveOrganizationSuggestion({
    required int personId,
    required PersonSuggestionKind kind,
    required int suggestionIndex,
    required PersonSuggestionResolution selected,
  }) async {
    final person = await getById(personId);
    if (person == null) {
      throw StateError('Person $personId was not found.');
    }
    final relation = _suggestionRelation(person, kind, suggestionIndex);
    if (relation != null && selected.isValid) {
      await setKgqlModel(
        _client,
        SetModelRequest(
          id: personId,
          relations: [
            ModelRelation(
              modelType: 'Company',
              relationName: relation.name,
              link: [selected.id],
              attributes: relation.attributes,
            ),
          ],
        ),
      );
    }
    final nextSuggestions = person.suggestions.resolve(
      kind: kind,
      index: suggestionIndex,
      selected: selected,
    );
    await setKgqlModel(
      _client,
      SetModelRequest(id: personId, suggestion: nextSuggestions.toJson()),
    );
  }

  @override
  Future<int> createCompanyForSuggestion({
    required int personId,
    required PersonSuggestionKind kind,
    required int suggestionIndex,
    required String name,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(name, 'name', 'Company name cannot be empty.');
    }
    final companyId = await setKgqlModel(
      _client,
      SetModelRequest(modelType: 'Company', name: trimmed),
    );
    await resolveOrganizationSuggestion(
      personId: personId,
      kind: kind,
      suggestionIndex: suggestionIndex,
      selected: PersonSuggestionResolution(
        id: companyId,
        name: trimmed,
        source: 'created',
      ),
    );
    return companyId;
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

  List<SetModelAttribute> _draftAttributes(PersonDraft draft) {
    return [
      SetModelAttribute(key: kPersonAttrCompany, value: draft.company.trim()),
      SetModelAttribute(key: kPersonAttrSummary, value: draft.summary.trim()),
    ];
  }
}

_SuggestionRelation? _suggestionRelation(
  Person person,
  PersonSuggestionKind kind,
  int index,
) {
  switch (kind) {
    case PersonSuggestionKind.work:
      if (index < 0 || index >= person.suggestions.work.length) return null;
      final suggestion = person.suggestions.work[index];
      return _SuggestionRelation(
        name: kWorkForRelationName,
        attributes: _relationAttributes({
          'title': suggestion.title,
          'start_date': suggestion.startDate,
          'end_date': suggestion.endDate,
          'notes': suggestion.notes,
        }),
      );
    case PersonSuggestionKind.education:
      if (index < 0 || index >= person.suggestions.education.length) {
        return null;
      }
      final suggestion = person.suggestions.education[index];
      return _SuggestionRelation(
        name: kStudyAtRelationName,
        attributes: _relationAttributes({
          'type': suggestion.type,
          'start_date': suggestion.startDate,
          'end_date': suggestion.endDate,
          'notes': suggestion.notes,
        }),
      );
  }
}

List<RelationAttribute> _relationAttributes(Map<String, Object?> values) {
  return [
    for (final entry in values.entries)
      if ((entry.value?.toString().trim() ?? '').isNotEmpty)
        RelationAttribute(key: entry.key, value: entry.value),
  ];
}

class _SuggestionRelation {
  const _SuggestionRelation({required this.name, required this.attributes});

  final String name;
  final List<RelationAttribute> attributes;
}
