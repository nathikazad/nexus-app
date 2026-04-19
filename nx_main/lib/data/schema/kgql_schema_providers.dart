import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_db/nx_db.dart' as nx;

import 'package:nexus_voice_assistant/data/schema/schema_entity_mappers.dart';
import 'package:nexus_voice_assistant/domain/schema/schema_model.dart';
import 'package:nexus_voice_assistant/domain/schema/schema_model_type.dart';

/// App-level schema navigator read models (no `nx_db` types in `features/`).
final schemaModelTypesProvider =
    FutureProvider<List<SchemaModelType>>((ref) async {
  final list = await ref.watch(nx.modelTypesProvider.future);
  return list.map(schemaModelTypeFromNx).toList();
});

final schemaModelTypeProvider =
    FutureProvider.family<SchemaModelType?, int>((ref, modelTypeId) async {
  final mt = await ref.watch(nx.modelTypeProvider(modelTypeId).future);
  return mt == null ? null : schemaModelTypeFromNx(mt);
});

final schemaModelTypeNameToIdProvider = Provider<Map<String, int>>((ref) {
  final async = ref.watch(schemaModelTypesProvider);
  return async.whenOrNull(
        data: (types) {
          final map = <String, int>{};
          void walk(List<SchemaModelType> list) {
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

final schemaModelTypeIdToNameProvider = Provider<Map<int, String>>((ref) {
  final async = ref.watch(schemaModelTypesProvider);
  return async.whenOrNull(
        data: (types) {
          final map = <int, String>{};
          void walk(List<SchemaModelType> list) {
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

final schemaModelsProvider =
    FutureProvider.family<List<SchemaModel>, int>((ref, modelTypeId) async {
  final list = await ref.watch(nx.modelsProvider(modelTypeId).future);
  return list.map(schemaModelFromNx).toList();
});

final schemaModelProvider =
    FutureProvider.family<SchemaModel?, int>((ref, modelId) async {
  final m = await ref.watch(nx.modelProvider(modelId).future);
  return m == null ? null : schemaModelFromNx(m);
});
