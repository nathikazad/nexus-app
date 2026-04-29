import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/auth_providers.dart';
import '../../core/client/graphql_client_provider.dart';
import '../models/model_type.dart';
import '../repositories/model_types_repository.dart';

/// [getKgqlModelType] for [name] in the user's **personal** domain (entered at login).
final kgqlModelTypeForPersonalDomain =
    FutureProvider.family<ModelType, String>((ref, name) async {
  final id = ref.watch(personalDomainIdProvider);
  if (id == null) {
    throw StateError('personalDomainId required (login)');
  }
  return fetchKgqlModelTypeByName(
    ref.watch(graphqlClientProvider),
    name,
    domainId: id,
  );
});

/// [getKgqlModelType] for [name] in the user's **home** domain (entered at login).
final kgqlModelTypeForHomeDomain =
    FutureProvider.family<ModelType, String>((ref, name) async {
  final id = ref.watch(homeDomainIdProvider);
  if (id == null) {
    throw StateError('homeDomainId required (login)');
  }
  return fetchKgqlModelTypeByName(
    ref.watch(graphqlClientProvider),
    name,
    domainId: id,
  );
});
