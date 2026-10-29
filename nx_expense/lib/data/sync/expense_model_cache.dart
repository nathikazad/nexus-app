import 'dart:convert';
import 'package:nx_db/kgql.dart';
import 'package:nx_db/auth.dart';
import '../expense/expense_file_cache.dart';
import 'expense_data_repository.dart';

Model expenseSyncModel(Map<String, dynamic> row) {
  final json = Map<String, dynamic>.from(row);
  for (final edge in row['relations'] as List? ?? const []) {
    final type = edge['model_type'] as String;
    (json.putIfAbsent(type, () => <dynamic>[]) as List).add({
      'id': edge['model_id'],
      'name': edge['name'] ?? '',
      'description': edge['description'],
      'attributes': edge['related_attributes'] ?? {},
    });
  }
  return Model.fromJson(json);
}

/// Keeps the existing screen mappers while reading the synchronized library.
class ExpenseModelCache extends ExpenseFileCache {
  ExpenseModelCache(
    super.library,
    this.data, {
    super.onChanged,
    this.onInvalidated,
  });
  final ExpenseDataRepository data;
  final void Function()? onInvalidated;
  String? _invalidatedCoverage;

  Future<bool> _libraryCurrent() async {
    final coverage = await data.store?.library.read(
      'expense_state',
      'coverage',
    );
    return coverage != null && coverage != _invalidatedCoverage;
  }

  @override
  Future<void> invalidate() async {
    _invalidatedCoverage = await data.store?.library.read(
      'expense_state',
      'coverage',
    );
    await super.invalidate();
    onInvalidated?.call();
  }

  @override
  Future<ModelType> schema(
    String name,
    Future<ModelType> Function() load,
  ) async {
    final references = await data.store?.get('0');
    final raw = references?['schemas'];
    final schemas = raw is String ? jsonDecode(raw) : raw;
    if (schemas is List) {
      final match = schemas.where((s) => s['name'] == name).firstOrNull;
      if (match is Map) {
        StartupTiming.mark('offline_schema_ready');
        return ModelType.fromJson(Map<String, dynamic>.from(match));
      }
    }
    return super.schema(name, load);
  }

  @override
  Future<Model?> model(
    String type,
    int id,
    Future<Model?> Function() load,
  ) async {
    if (await _libraryCurrent()) {
      final row = await data.get(id);
      return row == null || row['model_type']?['name'] != type
          ? null
          : expenseSyncModel(row);
    }
    return super.model(type, id, load);
  }

  @override
  Future<List<Model>> models(
    String type,
    Map<String, dynamic> filter,
    Map<String, dynamic> struct,
    Future<List<Model>> Function() load,
  ) async {
    if (!await _libraryCurrent()) {
      return super.models(type, filter, struct, load);
    }
    final rows = await data.list(type);
    StartupTiming.mark('offline_rows_ready');
    final references = (filter['tag_filters'] as List? ?? []).isEmpty
        ? null
        : await data.get(0);
    return [
      for (final row in rows)
        if (matchesExpenseSyncFilter(row, filter, references))
          expenseSyncModel(row),
    ];
  }
}

bool matchesExpenseSyncFilter(
  Map<String, dynamic> row,
  Map<String, dynamic> filter,
  Map<String, dynamic>? references,
) {
  final attrs = row['attributes'] as Map? ?? {};
  for (final f in filter['filters'] as List? ?? []) {
    final key = f['key'];
    dynamic value = key == 'id' ? row['id'] : attrs[key];
    final target = f['value'];
    if (key == 'date' || key == 'order_date') {
      value = value?.toString().split('T').first;
    }
    final comparison = value == null
        ? -1
        : value is num && target is num
        ? value.compareTo(target)
        : value.toString().compareTo(target.toString());
    final equal =
        value == target ||
        (value != null && value.toString() == target.toString());
    if (switch (f['op']) {
      '=' => !equal,
      '!=' => equal,
      '>=' => value == null || comparison < 0,
      '<=' => value == null || comparison > 0,
      _ => throw UnsupportedError('Unsupported expense filter ${f['op']}'),
    }) {
      return false;
    }
  }
  for (final f in filter['relation_filters'] as List? ?? []) {
    final ids = f['model_ids'] as List;
    if (!(row['relations'] as List? ?? []).any(
      (r) => r['model_type'] == f['model_type'] && ids.contains(r['model_id']),
    )) {
      return false;
    }
  }
  for (final f in filter['tag_filters'] as List? ?? []) {
    final assigned = row['tags']?[f['system']] as List? ?? [];
    // Match KGQL's synthetic bucket: no assignment in this tag system.
    if (f['node'] == 'Uncategorized') {
      if (assigned.isNotEmpty) return false;
      continue;
    }
    final names = <String>{f['node'] as String};
    if (f['include_descendants'] == true) {
      final systems = references?['tag_systems'] as List? ?? [];
      final system = systems.where((s) => s['name'] == f['system']).firstOrNull;
      final nodes = system?['nodes'] as List? ?? [];
      final ids = <dynamic>{
        for (final n in nodes)
          if (names.contains(n['name'])) n['id'],
      };
      bool changed;
      do {
        changed = false;
        for (final n in nodes) {
          if (ids.contains(n['parent_id']) && ids.add(n['id'])) {
            names.add(n['name']);
            changed = true;
          }
        }
      } while (changed);
    }
    if (!assigned.any(names.contains)) {
      return false;
    }
  }
  return true;
}
