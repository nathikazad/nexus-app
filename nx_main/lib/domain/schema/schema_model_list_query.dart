import 'dart:convert';

import 'package:nx_db/nx_db.dart' as nx;
import 'package:nexus_voice_assistant/domain/schema/attribute_definition_draft.dart';
import 'package:nexus_voice_assistant/domain/schema/schema_model.dart';
import 'package:nexus_voice_assistant/domain/schema/schema_model_type.dart';

const int schemaModelListPageSize = 50;

enum SchemaModelFilterOperator {
  equals('=', 'equals'),
  like('LIKE', 'contains'),
  greaterThan('>', 'greater than'),
  lessThan('<', 'less than'),
  greaterThanOrEqual('>=', 'greater or equal'),
  lessThanOrEqual('<=', 'less or equal');

  const SchemaModelFilterOperator(this.kgqlOp, this.label);

  final String kgqlOp;
  final String label;

  static SchemaModelFilterOperator? fromKgqlOp(String value) {
    for (final op in values) {
      if (op.kgqlOp == value) return op;
    }
    return null;
  }
}

class SchemaModelFilter {
  const SchemaModelFilter({
    required this.key,
    required this.valueType,
    required this.operator,
    required this.value,
  });

  final String key;
  final String valueType;
  final SchemaModelFilterOperator operator;
  final String value;

  String get label => '$key ${operator.label} $value';

  nx.ModelListFilter toNx() {
    return nx.ModelListFilter(
      key: key,
      op: operator.kgqlOp,
      value: operator == SchemaModelFilterOperator.like ? '%$value%' : value,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SchemaModelFilter &&
          key == other.key &&
          valueType == other.valueType &&
          operator == other.operator &&
          value == other.value;

  @override
  int get hashCode => Object.hash(key, valueType, operator, value);
}

class SchemaModelSort {
  const SchemaModelSort({
    required this.key,
    required this.valueType,
    required this.descending,
  });

  final String key;
  final String valueType;
  final bool descending;

  String get label => '$key ${descending ? 'desc' : 'asc'}';

  nx.ModelListSort toNx() {
    return nx.ModelListSort(key: key, descending: descending);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SchemaModelSort &&
          key == other.key &&
          valueType == other.valueType &&
          descending == other.descending;

  @override
  int get hashCode => Object.hash(key, valueType, descending);
}

class SchemaModelListQuery {
  const SchemaModelListQuery({
    required this.modelTypeId,
    this.search = '',
    this.filters = const [],
    this.sort,
    this.page = 0,
  });

  final int modelTypeId;
  final String search;
  final List<SchemaModelFilter> filters;
  final SchemaModelSort? sort;
  final int page;

  int get offset => page * schemaModelListPageSize;

  bool get isActive =>
      search.trim().isNotEmpty || filters.isNotEmpty || sort != null;

  int get activeCount =>
      (search.trim().isNotEmpty ? 1 : 0) +
      filters.length +
      (sort == null ? 0 : 1);

  SchemaModelListQuery copyWith({
    String? search,
    List<SchemaModelFilter>? filters,
    SchemaModelSort? sort,
    int? page,
    bool clearSort = false,
  }) {
    return SchemaModelListQuery(
      modelTypeId: modelTypeId,
      search: search ?? this.search,
      filters: filters ?? this.filters,
      sort: clearSort ? null : sort ?? this.sort,
      page: page ?? this.page,
    );
  }

  nx.ModelListQuery toNx() {
    return nx.ModelListQuery(
      modelTypeId: modelTypeId,
      search: search,
      filters: filters.map((filter) => filter.toNx()).toList(),
      sort: sort?.toNx(),
      limit: schemaModelListPageSize + 1,
      offset: offset,
    );
  }

  Map<String, String> toRouteQueryParameters() {
    final params = <String, String>{};
    final searchValue = search.trim();
    if (searchValue.isNotEmpty) {
      params['q'] = searchValue;
    }
    if (filters.isNotEmpty) {
      params['filters'] = jsonEncode([
        for (final filter in filters)
          {
            'key': filter.key,
            'op': filter.operator.kgqlOp,
            'value': filter.value,
          },
      ]);
    }
    if (sort != null) {
      params['sort'] = '${sort!.key}:${sort!.descending ? 'desc' : 'asc'}';
    }
    if (page > 0) {
      params['page'] = page.toString();
    }
    return params;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SchemaModelListQuery &&
          modelTypeId == other.modelTypeId &&
          search == other.search &&
          _listEquals(filters, other.filters) &&
          sort == other.sort &&
          page == other.page;

  @override
  int get hashCode => Object.hash(
        modelTypeId,
        search,
        Object.hashAll(filters),
        sort,
        page,
      );
}

class SchemaModelListPage {
  const SchemaModelListPage({
    required this.models,
    required this.page,
    required this.hasPreviousPage,
    required this.hasNextPage,
  });

  factory SchemaModelListPage.fromProbe({
    required List<SchemaModel> models,
    required int page,
  }) {
    return SchemaModelListPage(
      models: models.take(schemaModelListPageSize).toList(),
      page: page,
      hasPreviousPage: page > 0,
      hasNextPage: models.length > schemaModelListPageSize,
    );
  }

  final List<SchemaModel> models;
  final int page;
  final bool hasPreviousPage;
  final bool hasNextPage;
}

class SchemaModelRouteFilter {
  const SchemaModelRouteFilter({
    required this.key,
    required this.op,
    required this.value,
  });

  final String key;
  final String op;
  final String value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SchemaModelRouteFilter &&
          key == other.key &&
          op == other.op &&
          value == other.value;

  @override
  int get hashCode => Object.hash(key, op, value);
}

class SchemaModelRouteSort {
  const SchemaModelRouteSort({
    required this.key,
    required this.descending,
  });

  final String key;
  final bool descending;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SchemaModelRouteSort &&
          key == other.key &&
          descending == other.descending;

  @override
  int get hashCode => Object.hash(key, descending);
}

class SchemaModelRouteQuery {
  const SchemaModelRouteQuery({
    this.search = '',
    this.filters = const [],
    this.sort,
    this.page = 0,
  });

  factory SchemaModelRouteQuery.fromQueryParameters(
    Map<String, String> params,
  ) {
    return SchemaModelRouteQuery(
      search: params['q'] ?? '',
      filters: _parseRouteFilters(params['filters']),
      sort: _parseRouteSort(params['sort']),
      page: _parseRoutePage(params['page']),
    );
  }

  final String search;
  final List<SchemaModelRouteFilter> filters;
  final SchemaModelRouteSort? sort;
  final int page;

  bool get isEmpty =>
      search.trim().isEmpty && filters.isEmpty && sort == null && page == 0;

  SchemaModelListQuery hydrate({
    required int modelTypeId,
    required SchemaModelType modelType,
  }) {
    final fields = _fieldTypesFor(modelType);
    final hydratedFilters = <SchemaModelFilter>[];
    for (final filter in filters) {
      final valueType = fields[filter.key];
      final op = SchemaModelFilterOperator.fromKgqlOp(filter.op);
      if (valueType == null || op == null || filter.value.trim().isEmpty) {
        continue;
      }
      if (!_operatorsForValueType(valueType).contains(op)) continue;
      hydratedFilters.add(
        SchemaModelFilter(
          key: filter.key,
          valueType: valueType,
          operator: op,
          value: filter.value,
        ),
      );
    }

    SchemaModelSort? hydratedSort;
    final routeSort = sort;
    if (routeSort != null) {
      final valueType = fields[routeSort.key];
      if (valueType != null && _isSortableValueType(valueType)) {
        hydratedSort = SchemaModelSort(
          key: routeSort.key,
          valueType: valueType,
          descending: routeSort.descending,
        );
      }
    }

    return SchemaModelListQuery(
      modelTypeId: modelTypeId,
      search: search,
      filters: hydratedFilters,
      sort: hydratedSort,
      page: page,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SchemaModelRouteQuery &&
          search == other.search &&
          _listEquals(filters, other.filters) &&
          sort == other.sort &&
          page == other.page;

  @override
  int get hashCode => Object.hash(search, Object.hashAll(filters), sort, page);
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i += 1) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

List<SchemaModelRouteFilter> _parseRouteFilters(String? raw) {
  if (raw == null || raw.trim().isEmpty) return const [];
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    final filters = <SchemaModelRouteFilter>[];
    for (final item in decoded) {
      if (item is! Map) continue;
      final key = item['key']?.toString() ?? '';
      final op = item['op']?.toString() ?? '';
      final value = item['value']?.toString() ?? '';
      if (key.isEmpty || op.isEmpty || value.isEmpty) continue;
      filters.add(SchemaModelRouteFilter(key: key, op: op, value: value));
    }
    return filters;
  } catch (_) {
    return const [];
  }
}

SchemaModelRouteSort? _parseRouteSort(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  final parts = raw.split(':');
  if (parts.length != 2 || parts.first.isEmpty) return null;
  final direction = parts.last.toLowerCase();
  if (direction != 'asc' && direction != 'desc') return null;
  return SchemaModelRouteSort(
    key: parts.first,
    descending: direction == 'desc',
  );
}

int _parseRoutePage(String? raw) {
  final parsed = int.tryParse(raw ?? '');
  if (parsed == null || parsed < 0) return 0;
  return parsed;
}

Map<String, String> _fieldTypesFor(SchemaModelType modelType) {
  final fields = <String, String>{
    'name': 'string',
    'description': 'string',
    'created_at': 'datetime',
    'updated_at': 'datetime',
  };
  for (final attr
      in modelType.attributes ?? const <AttributeDefinitionDraft>[]) {
    final key = attr.key ?? '';
    final valueType = attr.valueType ?? 'string';
    if (key.isNotEmpty && valueType.toLowerCase() != 'json') {
      fields[key] = valueType;
    }
  }
  return fields;
}

List<SchemaModelFilterOperator> _operatorsForValueType(String valueType) {
  final lower = valueType.toLowerCase();
  if (lower == 'number' ||
      lower == 'datetime' ||
      lower == 'date' ||
      lower == 'time') {
    return const [
      SchemaModelFilterOperator.equals,
      SchemaModelFilterOperator.greaterThan,
      SchemaModelFilterOperator.lessThan,
      SchemaModelFilterOperator.greaterThanOrEqual,
      SchemaModelFilterOperator.lessThanOrEqual,
    ];
  }
  if (lower == 'boolean') {
    return const [SchemaModelFilterOperator.equals];
  }
  return const [
    SchemaModelFilterOperator.equals,
    SchemaModelFilterOperator.like,
  ];
}

bool _isSortableValueType(String valueType) {
  final lower = valueType.toLowerCase();
  return lower == 'number' ||
      lower == 'datetime' ||
      lower == 'date' ||
      lower == 'time';
}
