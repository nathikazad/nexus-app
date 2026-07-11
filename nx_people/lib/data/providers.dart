import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_db/auth.dart' show imageBaseUrlProvider, userIdProvider;
import 'package:nx_db/nx_db.dart' show imageHeaders;
import 'package:nx_db/riverpod.dart';
import 'package:nx_people/data/person/kgql_people_repository.dart';
import 'package:nx_people/data/person/person_schema_provider.dart';
import 'package:nx_people/domain/person/person.dart';
import 'package:nx_people/domain/person/person_query.dart';

class PeopleImageConfig {
  const PeopleImageConfig({required this.baseUrl, required this.headers});

  final String baseUrl;
  final Map<String, String> headers;
}

final peopleImageConfigProvider = Provider<PeopleImageConfig?>((ref) {
  final baseUrl = ref.watch(imageBaseUrlProvider);
  final userId = ref.watch(userIdProvider);
  if (baseUrl == null || baseUrl.trim().isEmpty || userId == null) {
    return null;
  }
  return PeopleImageConfig(
    baseUrl: baseUrl,
    headers: imageHeaders(baseUrl, userId),
  );
});

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
