import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:nx_db/kgql.dart'
    show
        ModelType,
        SetModelAttribute,
        buildKgqlStructFromSchema,
        fetchKgqlModels,
        setKgqlModel,
        setKgqlUpdate;

import '../../domain/person/person.dart';
import '../../domain/person/person_repository.dart';
import 'person_attr_keys.dart';
import 'person_mapper.dart';

/// KGQL [Person] fetch + `preference` updates.
class KgqlPersonRepository implements PersonRepository {
  KgqlPersonRepository({
    required GraphQLClient client,
    required Future<ModelType> Function() loadPersonSchema,
  })  : _client = client,
        _loadPersonSchema = loadPersonSchema;

  final GraphQLClient _client;
  final Future<ModelType> Function() _loadPersonSchema;

  @override
  Future<Person?> getMain() async {
    final schema = await _loadPersonSchema();
    final struct = buildKgqlStructFromSchema(schema);
    final list = await fetchKgqlModels(
      _client,
      filter: const {'model_type': 'Person'},
      struct: struct,
    );
    if (list.isEmpty) return null;
    return personFromModel(list.first);
  }

  @override
  Future<Person> updatePreference(
    Person person,
    Map<String, dynamic> preference,
  ) async {
    await setKgqlModel(
      _client,
      setKgqlUpdate(
        id: person.id,
        modelType: 'Person',
        name: person.name,
        description: person.description,
        attributes: [
          SetModelAttribute(
            key: kPersonAttrPreference,
            value: preference,
          ),
        ],
      ),
    );
    return person.copyWith(preference: Map<String, dynamic>.from(preference));
  }
}
