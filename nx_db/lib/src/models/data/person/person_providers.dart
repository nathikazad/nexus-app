import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_db/auth.dart';
import 'package:nx_db/riverpod.dart';

import '../../domain/person/person.dart';
import '../../domain/person/person_repository.dart';
import 'kgql_person_repository.dart';

/// Cached [ModelType] for `Person` (from [getKgqlModelType] / schema tree).
final personSchemaProvider = kgqlModelTypeForPersonalDomain('Person');

/// Resolves only when auth has loaded a non-null user.
final authenticatedUserProvider = FutureProvider<User>((ref) async {
  final user = await ref.watch(authProvider.future);
  if (user == null) {
    throw StateError('Not authenticated');
  }
  return user;
});

/// KGQL [Person] fetch and `preference` updates.
final personRepositoryProvider = Provider<PersonRepository>(
  (ref) {
    final personal = ref.watch(personalDomainIdProvider);
    if (personal == null) {
      throw StateError('personalDomainId required (login)');
    }
    return KgqlPersonRepository(
      client: ref.watch(graphqlClientProvider),
      loadPersonSchema: () => ref.read(personSchemaProvider.future),
      domainId: personal,
    );
  },
);

/// First Person row for the current user (RLS); includes `preference` JSON.
final mainPersonProvider = FutureProvider<Person?>((ref) async {
  await ref.watch(authenticatedUserProvider.future);
  return ref.watch(personRepositoryProvider).getMain();
});
