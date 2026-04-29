import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/auth_providers.dart';
import '../../core/client/graphql_client_provider.dart';
import '../models/model_type.dart';
import '../repositories/model_types_repository.dart';
import '../requests/set_model_type_request.dart';

int _requirePersonalDomain(Ref ref) {
  final id = ref.watch(personalDomainIdProvider);
  if (id == null) {
    throw StateError('personalDomainId required (login)');
  }
  return id;
}

final modelTypesProvider = FutureProvider<List<ModelType>>((ref) async {
  final client = ref.watch(graphqlClientProvider);
  final domainId = _requirePersonalDomain(ref);
  return fetchAllModelTypes(client, domainId: domainId);
});

/// Maps model type display name → id for navigation (e.g. relation targets).
final modelTypeNameToIdProvider = Provider<Map<String, int>>((ref) {
  final async = ref.watch(modelTypesProvider);
  return async.whenOrNull(
        data: (types) {
          final map = <String, int>{};
          void walk(List<ModelType> list) {
            for (final t in list) {
              map[t.name] = t.id;
              if (t.children != null) walk(t.children!);
            }
          }

          walk(types);
          return map;
        },
      ) ??
      {};
});

/// Maps model type id → display name (roots, children, and traits).
final modelTypeIdToNameProvider = Provider<Map<int, String>>((ref) {
  final async = ref.watch(modelTypesProvider);
  return async.whenOrNull(
        data: (types) {
          final map = <int, String>{};
          void walk(List<ModelType> list) {
            for (final t in list) {
              map[t.id] = t.name;
              if (t.children != null) walk(t.children!);
              if (t.traits != null) walk(t.traits!);
            }
          }

          walk(types);
          return map;
        },
      ) ??
      {};
});

final modelTypeProvider = FutureProvider.family<ModelType?, int>((ref, modelTypeId) async {
  final client = ref.watch(graphqlClientProvider);
  final domainId = _requirePersonalDomain(ref);
  return fetchKgqlModelTypeById(client, modelTypeId, domainId: domainId);
});

Future<int> createModelType(
  ProviderContainer container,
  SetModelTypeRequest request,
) async {
  final client = container.read(graphqlClientProvider);
  final domainId = container.read(personalDomainIdProvider);
  if (domainId == null) {
    throw StateError('personalDomainId required (login)');
  }
  return setKgqlModelType(client, request, domainId: domainId);
}

Future<int> updateModelType(
  ProviderContainer container,
  SetModelTypeRequest request,
) async {
  if (request.id == null) {
    throw Exception('id is required for update operations');
  }
  return createModelType(container, request);
}
