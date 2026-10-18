import 'dart:convert';
import 'dart:async';
import 'package:graphql_flutter/graphql_flutter.dart';

import 'package:nx_db/kgql.dart';
import 'package:nx_offline/nx_offline_storage.dart';

/// Stores each model separately; query files describe only membership/coverage.
/// Expense and Order keep their KGQL meaning in this one adapter.
class ExpenseFileCache {
  ExpenseFileCache(
    this.library, {
    this.cacheFirst = true,
    this.onChanged,
    this.canSave,
  });
  final FileLibrary library;
  final bool cacheFirst;
  final bool Function()? canSave;
  int _generation = 0;
  ExpenseFileCache get _live {
    final generation = _generation;
    return ExpenseFileCache(
      library,
      cacheFirst: false,
      canSave: () => !_closed && generation == _generation,
    );
  }

  final void Function()? onChanged;
  final Map<String, DateTime> _checked = {};
  final Map<String, Future<void>> _refreshing = {};
  bool _closed = false;

  void refresh(String key, Future<bool> Function() work) {
    if (_closed ||
        _refreshing.containsKey(key) ||
        DateTime.now().difference(_checked[key] ?? DateTime(1970)) <
            const Duration(seconds: 30)) {
      return;
    }
    final generation = _generation;
    _checked[key] = DateTime.now();
    _refreshing[key] = Future<void>(() async {
      try {
        if (await work() && !_closed && generation == _generation) {
          onChanged?.call();
        }
      } catch (_) {
        // Keep the displayed snapshot when the background refresh is unavailable.
      } finally {
        _refreshing.remove(key);
      }
    });
  }

  Future<void> close() async {
    _closed = true;
    await Future.wait(_refreshing.values.toList());
  }

  Future<List<Model>> _catalog(String key) async {
    final rows = <Model>[];
    var offset = 0;
    while (true) {
      final page = await library.catalog(key, offset: offset);
      for (final item in page) {
        rows.add(
          Model.fromJson(
            Map<String, dynamic>.from(
              jsonDecode(await library.files.read(item.reference)) as Map,
            ),
          ),
        );
      }
      if (page.length < 50) return rows;
      offset += page.length;
    }
  }

  Future<List<Model>> models(
    String type,
    Map<String, dynamic> filter,
    Map<String, dynamic> struct,
    Future<List<Model>> Function() load,
  ) async {
    final queryKey = jsonEncode({
      'type': type,
      'filter': filter,
      'struct': struct,
    });
    if (cacheFirst && await library.hasCatalog(queryKey)) {
      final cached = await _catalog(queryKey);
      refresh(queryKey, () async {
        final fresh = await _live.models(type, filter, struct, load);
        return jsonEncode(fresh.map((m) => m.toJson()).toList()) !=
            jsonEncode(cached.map((m) => m.toJson()).toList());
      });
      return cached;
    }
    List<Model> rows;
    try {
      rows = await load();
    } catch (_) {
      if (!await library.hasCatalog(queryKey)) rethrow;
      final cached = <Model>[];
      var offset = 0;
      while (true) {
        final page = await library.catalog(queryKey, offset: offset);
        for (final item in page) {
          final body = await library.files.read(item.reference);
          cached.add(
            Model.fromJson(Map<String, dynamic>.from(jsonDecode(body) as Map)),
          );
        }
        if (page.length < 50) break;
        offset += page.length;
      }
      return cached;
    }
    if (canSave?.call() == false) return rows;
    await library.replaceCatalog(queryKey, [
      for (final row in rows)
        LibraryRecord(
          collection: type,
          id: '${row.id}',
          content: jsonEncode(row.toJson()),
          summary: {'id': row.id, 'name': row.name, 'revision': row.updatedAt},
        ),
    ]);
    return rows;
  }

  Future<Model?> model(
    String type,
    int id,
    Future<Model?> Function() load,
  ) async {
    if (cacheFirst) {
      final saved = await library.read(type, '$id');
      if (saved != null) {
        refresh('$type/$id', () async {
          final fresh = await _live.model(type, id, load);
          return jsonEncode(fresh?.toJson()) != saved;
        });
        return Model.fromJson(
          Map<String, dynamic>.from(jsonDecode(saved) as Map),
        );
      }
    }
    Model? row;
    try {
      row = await load();
    } catch (_) {
      final body = await library.read(type, '$id');
      if (body == null) rethrow;
      return Model.fromJson(Map<String, dynamic>.from(jsonDecode(body) as Map));
    }
    if (canSave?.call() == false) return row;
    if (row == null) {
      await library.removeRemote(type, '$id');
    } else {
      await library.saveRemote(
        type,
        '$id',
        jsonEncode(row.toJson()),
        summary: {'name': row.name},
        revision: row.updatedAt,
      );
    }
    return row;
  }

  Future<Map<String, dynamic>> aggregate(
    Map<String, dynamic> filter,
    Map<String, dynamic> operation,
    Future<Map<String, dynamic>> Function() load,
  ) async {
    final key = jsonEncode({'filter': filter, 'aggregate': operation});
    if (cacheFirst) {
      final saved = await library.metadata('aggregates', key);
      if (saved != null) {
        refresh(key, () async {
          final fresh = await _live.aggregate(filter, operation, load);
          return jsonEncode(fresh) != jsonEncode(saved.summary);
        });
        return Map<String, dynamic>.from(saved.summary);
      }
    }
    Map<String, dynamic> result;
    try {
      result = await load();
    } catch (_) {
      final saved = await library.metadata('aggregates', key);
      if (saved == null) rethrow;
      return Map<String, dynamic>.from(saved.summary);
    }
    if (canSave?.call() == false) return result;
    // Totals are a small query projection; no expense bodies are needed.
    await library.saveRemote('aggregates', key, '{}', summary: result);
    return result;
  }

  Future<ModelType> schema(
    String name,
    Future<ModelType> Function() load,
  ) async {
    if (cacheFirst) {
      final saved = await library.read('schemas', name);
      if (saved != null) {
        refresh('schema/$name', () async {
          final fresh = await _live.schema(name, load);
          return jsonEncode(fresh.toJson()) != saved;
        });
        return ModelType.fromJson(
          Map<String, dynamic>.from(jsonDecode(saved) as Map),
        );
      }
    }
    ModelType schema;
    try {
      schema = await load();
    } catch (_) {
      final body = await library.read('schemas', name);
      if (body == null) rethrow;
      return ModelType.fromJson(
        Map<String, dynamic>.from(jsonDecode(body) as Map),
      );
    }
    if (canSave?.call() == false) return schema;
    await library.saveRemote('schemas', name, jsonEncode(schema.toJson()));
    return schema;
  }

  /// Online mutations invalidate cached query coverage so old totals/lists
  /// cannot masquerade as the result of the just-completed mutation.
  Future<void> invalidate() async {
    _generation++;
    _checked.clear();
    await library.invalidateCatalogs();
    await library.database.customStatement(
      "DELETE FROM stored_items WHERE collection != 'schemas' AND pending = 0",
    );
  }
}

Future<List<Model>> fetchStoredModels(
  GraphQLClient client, {
  ExpenseFileCache? cache,
  required Map<String, dynamic> filter,
  required Map<String, dynamic> struct,
}) {
  Future<List<Model>> load() =>
      fetchKgqlModels(client, filter: filter, struct: struct);
  return cache?.models(filter['model_type'].toString(), filter, struct, load) ??
      load();
}

Future<Model?> fetchStoredModelById(
  GraphQLClient client, {
  ExpenseFileCache? cache,
  required String modelTypeName,
  required int id,
  required Map<String, dynamic> struct,
}) {
  Future<Model?> load() => fetchKgqlModelById(
    client,
    modelTypeName: modelTypeName,
    id: id,
    struct: struct,
  );
  return cache?.model(modelTypeName, id, load) ?? load();
}
