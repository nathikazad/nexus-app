import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_db/nx_db.dart' as nx;

import 'package:nexus_voice_assistant/data/schema/schema_entity_mappers.dart';
import 'package:nexus_voice_assistant/domain/schema/schema_model.dart';
import 'package:nexus_voice_assistant/domain/schema/schema_model_list_query.dart';
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

class SchemaModelListQueryController extends Notifier<SchemaModelListQuery> {
  int? _modelTypeId;

  set modelTypeId(int value) {
    _modelTypeId = value;
  }

  @override
  SchemaModelListQuery build() {
    return SchemaModelListQuery(modelTypeId: _modelTypeId!);
  }

  void setSearch(String value) {
    state = state.copyWith(search: value, page: 0);
  }

  void setFilters(List<SchemaModelFilter> filters) {
    state = state.copyWith(filters: filters, page: 0);
  }

  void removeFilter(int index) {
    final next = [...state.filters]..removeAt(index);
    setFilters(next);
  }

  void setSort(SchemaModelSort? sort) {
    state = sort == null
        ? state.copyWith(clearSort: true, page: 0)
        : state.copyWith(sort: sort, page: 0);
  }

  void setPage(int page) {
    state = state.copyWith(page: page < 0 ? 0 : page);
  }

  void clearAll() {
    state = SchemaModelListQuery(modelTypeId: state.modelTypeId);
  }

  void replace(SchemaModelListQuery query) {
    if (state == query) return;
    state = query;
  }
}

final schemaModelListQueryProvider = NotifierProvider.family<
    SchemaModelListQueryController, SchemaModelListQuery, int>((modelTypeId) {
  final controller = SchemaModelListQueryController();
  controller.modelTypeId = modelTypeId;
  return controller;
});

final schemaModelsForQueryProvider =
    FutureProvider.family<SchemaModelListPage, SchemaModelListQuery>(
        (ref, query) async {
  final list = await ref.watch(nx.modelListProvider(query.toNx()).future);
  return SchemaModelListPage.fromProbe(
    models: list.map(schemaModelFromNx).toList(),
    page: query.page,
  );
});

final schemaModelProvider =
    FutureProvider.family<SchemaModel?, int>((ref, modelId) async {
  final m = await ref.watch(nx.modelProvider(modelId).future);
  return m == null ? null : schemaModelFromNx(m);
});
