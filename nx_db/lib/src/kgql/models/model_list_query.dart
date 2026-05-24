class ModelListFilter {
  const ModelListFilter({
    required this.key,
    required this.op,
    required this.value,
  });

  final String key;
  final String op;
  final Object value;

  Map<String, dynamic> toJson() => {
        'key': key,
        'op': op,
        'value': value,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ModelListFilter &&
          key == other.key &&
          op == other.op &&
          value == other.value;

  @override
  int get hashCode => Object.hash(key, op, value);
}

class ModelListSort {
  const ModelListSort({
    required this.key,
    required this.descending,
  });

  final String key;
  final bool descending;

  Map<String, dynamic> toJson() => {
        'key': key,
        'direction': descending ? 'DESC' : 'ASC',
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ModelListSort &&
          key == other.key &&
          descending == other.descending;

  @override
  int get hashCode => Object.hash(key, descending);
}

class ModelListQuery {
  const ModelListQuery({
    required this.modelTypeId,
    this.search = '',
    this.filters = const [],
    this.sort,
    this.limit,
    this.offset = 0,
  });

  final int modelTypeId;
  final String search;
  final List<ModelListFilter> filters;
  final ModelListSort? sort;
  final int? limit;
  final int offset;

  ModelListQuery copyWith({
    int? modelTypeId,
    String? search,
    List<ModelListFilter>? filters,
    ModelListSort? sort,
    int? limit,
    int? offset,
    bool clearSort = false,
  }) {
    return ModelListQuery(
      modelTypeId: modelTypeId ?? this.modelTypeId,
      search: search ?? this.search,
      filters: filters ?? this.filters,
      sort: clearSort ? null : sort ?? this.sort,
      limit: limit ?? this.limit,
      offset: offset ?? this.offset,
    );
  }

  Map<String, dynamic> toKgqlFilter() {
    final filter = <String, dynamic>{'model_type': modelTypeId};
    final allFilters = <Map<String, dynamic>>[
      if (search.trim().isNotEmpty)
        {
          'key': 'name',
          'op': 'LIKE',
          'value': '%${search.trim()}%',
        },
      for (final item in filters) item.toJson(),
    ];
    if (allFilters.isNotEmpty) {
      filter['filters'] = allFilters;
    }
    if (sort != null) {
      filter['order_by'] = sort!.toJson();
    }
    if (limit != null && limit! > 0) {
      filter['limit'] = limit;
    }
    if (offset > 0) {
      filter['offset'] = offset;
    }
    return filter;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ModelListQuery &&
          modelTypeId == other.modelTypeId &&
          search == other.search &&
          _listEquals(filters, other.filters) &&
          sort == other.sort &&
          limit == other.limit &&
          offset == other.offset;

  @override
  int get hashCode => Object.hash(
        modelTypeId,
        search,
        Object.hashAll(filters),
        sort,
        limit,
        offset,
      );
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i += 1) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
