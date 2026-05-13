import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_db/riverpod.dart';
import 'package:nx_people/data/person/kgql_people_repository.dart';
import 'package:nx_people/data/person/person_schema_provider.dart';
import 'package:nx_people/domain/person/person.dart';
import 'package:nx_people/domain/person/person_query.dart';

final peopleRepositoryProvider = Provider<PersonRepository>((ref) {
  return KgqlPeopleRepository(
    client: ref.watch(graphqlClientProvider),
    loadPersonSchema: () => ref.read(personSchemaProvider.future),
  );
});

final recentPeopleProvider = FutureProvider<List<Person>>(
  (ref) => ref.watch(peopleRepositoryProvider).listRecent(limit: 20),
);

final pinnedPeopleProvider = FutureProvider<List<Person>>(
  (ref) => ref.watch(peopleRepositoryProvider).listPinned(limit: 20),
);

final followUpPeopleProvider = FutureProvider<List<Person>>(
  (ref) => ref.watch(peopleRepositoryProvider).listFollowUp(limit: 20),
);

final peopleTagSystemsProvider = FutureProvider<List<PeopleTagSystem>>(
  (ref) => ref.watch(peopleRepositoryProvider).listTagSystems(),
);

final personByIdProvider = FutureProvider.family<Person?, int>(
  (ref, id) => ref.watch(peopleRepositoryProvider).getById(id),
);

final companiesProvider = FutureProvider<List<String>>(
  (ref) => ref.watch(peopleRepositoryProvider).listCompanies(),
);

final meetingsProvider = FutureProvider<List<String>>(
  (ref) => ref.watch(peopleRepositoryProvider).listMeetings(),
);

final plannedProvider = FutureProvider<List<String>>(
  (ref) => ref.watch(peopleRepositoryProvider).listPlanned(),
);
