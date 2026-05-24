import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nexus_voice_assistant/core/widgets/error_widget.dart';
import 'package:nexus_voice_assistant/core/widgets/loading_indicator.dart';
import 'package:nexus_voice_assistant/data/providers.dart';
import 'package:nexus_voice_assistant/domain/schema/attribute_definition_draft.dart';
import 'package:nexus_voice_assistant/domain/schema/schema_model_list_query.dart';
import 'package:nexus_voice_assistant/domain/schema/schema_model_type.dart';
import 'package:nexus_voice_assistant/features/schema_navigator/widgets/model_row.dart';

class ModelsListPage extends ConsumerStatefulWidget {
  const ModelsListPage({
    super.key,
    required this.modelTypeId,
    required this.initialRouteQuery,
  });

  final int modelTypeId;
  final SchemaModelRouteQuery initialRouteQuery;

  @override
  ConsumerState<ModelsListPage> createState() => _ModelsListPageState();
}

class _ModelsListPageState extends ConsumerState<ModelsListPage> {
  final _searchController = TextEditingController();
  Timer? _searchDebounce;
  bool _searchExpanded = false;
  bool _didApplyInitialRouteQuery = false;
  bool _isApplyingRouteQuery = false;

  @override
  void didUpdateWidget(covariant ModelsListPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.modelTypeId != widget.modelTypeId ||
        oldWidget.initialRouteQuery != widget.initialRouteQuery) {
      _didApplyInitialRouteQuery = false;
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _setSearch(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 250), () {
      ref
          .read(schemaModelListQueryProvider(widget.modelTypeId).notifier)
          .setSearch(value);
    });
  }

  void _syncRoute(SchemaModelListQuery query) {
    final params = query.toRouteQueryParameters();
    final uri = Uri(
      path: '/models/${widget.modelTypeId}',
      queryParameters: params.isEmpty ? null : params,
    );
    final target = uri.toString();
    final current = GoRouterState.of(context).uri.toString();
    if (current != target) {
      context.replace(target);
    }
  }

  void _clearSearch() {
    _searchDebounce?.cancel();
    _searchController.clear();
    ref
        .read(schemaModelListQueryProvider(widget.modelTypeId).notifier)
        .setSearch('');
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(schemaModelListQueryProvider(widget.modelTypeId));
    final modelTypeAsync =
        ref.watch(schemaModelTypeProvider(widget.modelTypeId));
    final modelType = modelTypeAsync.whenOrNull(data: (value) => value);
    var effectiveQuery = query;
    final waitingForRouteHydration = !_didApplyInitialRouteQuery &&
        !widget.initialRouteQuery.isEmpty &&
        modelType == null &&
        modelTypeAsync.isLoading;

    if (!_didApplyInitialRouteQuery && modelType != null) {
      _didApplyInitialRouteQuery = true;
      if (!widget.initialRouteQuery.isEmpty) {
        final initialQuery = widget.initialRouteQuery.hydrate(
          modelTypeId: widget.modelTypeId,
          modelType: modelType,
        );
        effectiveQuery = initialQuery;
        _isApplyingRouteQuery = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          ref
              .read(schemaModelListQueryProvider(widget.modelTypeId).notifier)
              .replace(initialQuery);
          _searchExpanded = initialQuery.search.trim().isNotEmpty;
          _searchController.text = initialQuery.search;
          _isApplyingRouteQuery = false;
        });
      }
    }
    final modelsAsync = waitingForRouteHydration
        ? null
        : ref.watch(schemaModelsForQueryProvider(effectiveQuery));

    ref.listen<SchemaModelListQuery>(
      schemaModelListQueryProvider(widget.modelTypeId),
      (previous, next) {
        if (_isApplyingRouteQuery) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _syncRoute(next);
        });
      },
    );

    if (_searchController.text != effectiveQuery.search) {
      _searchController.text = effectiveQuery.search;
      _searchController.selection = TextSelection.collapsed(
        offset: _searchController.text.length,
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/');
            }
          },
        ),
        title: modelTypeAsync.when(
          data: (data) => Text(data?.name ?? 'Models'),
          loading: () => const Text('Models'),
          error: (_, __) => const Text('Models'),
        ),
        actions: [
          IconButton(
            tooltip: 'Search',
            icon: Icon(
              Icons.search_rounded,
              color: effectiveQuery.search.trim().isNotEmpty || _searchExpanded
                  ? Theme.of(context).colorScheme.primary
                  : null,
            ),
            onPressed: () {
              setState(() => _searchExpanded = !_searchExpanded);
              if (!_searchExpanded) _clearSearch();
            },
          ),
          IconButton(
            tooltip: 'Filter',
            icon: Badge.count(
              count: effectiveQuery.filters.length,
              isLabelVisible: effectiveQuery.filters.isNotEmpty,
              child: Icon(
                Icons.filter_alt_outlined,
                color: effectiveQuery.filters.isNotEmpty
                    ? Theme.of(context).colorScheme.primary
                    : null,
              ),
            ),
            onPressed: modelType == null
                ? null
                : () =>
                    _showFilterSheet(context, ref, modelType, effectiveQuery),
          ),
          IconButton(
            tooltip: 'Sort',
            icon: Icon(
              Icons.sort_rounded,
              color: effectiveQuery.sort != null
                  ? Theme.of(context).colorScheme.primary
                  : null,
            ),
            onPressed: modelType == null
                ? null
                : () => _showSortSheet(context, ref, modelType, effectiveQuery),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_searchExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                onChanged: _setSearch,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Search by name...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _searchController.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: _clearSearch,
                        ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          if (effectiveQuery.isActive)
            _ActiveQueryChips(
              query: effectiveQuery,
              onClearSearch: _clearSearch,
              onRemoveFilter: (index) => ref
                  .read(
                      schemaModelListQueryProvider(widget.modelTypeId).notifier)
                  .removeFilter(index),
              onClearSort: () => ref
                  .read(
                      schemaModelListQueryProvider(widget.modelTypeId).notifier)
                  .setSort(null),
              onClearAll: () {
                _searchController.clear();
                ref
                    .read(schemaModelListQueryProvider(widget.modelTypeId)
                        .notifier)
                    .clearAll();
              },
            ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final async = modelsAsync;
                if (async == null) {
                  return const LoadingIndicator();
                }
                return async.when(
                  data: (page) => _ModelsContent(
                    page: page,
                    constraints: constraints,
                    modelTypeId: widget.modelTypeId,
                    query: effectiveQuery,
                    onPageChanged: (nextPage) => ref
                        .read(schemaModelListQueryProvider(widget.modelTypeId)
                            .notifier)
                        .setPage(nextPage),
                    onRefresh: () async {
                      ref.invalidate(
                          schemaModelsForQueryProvider(effectiveQuery));
                      await ref.read(
                          schemaModelsForQueryProvider(effectiveQuery).future);
                    },
                  ),
                  loading: () => const LoadingIndicator(),
                  error: (error, stack) => ErrorDisplay(
                    message: error.toString(),
                    onRetry: () {
                      ref.invalidate(schemaModelsForQueryProvider(query));
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          context.push('/model-form?modelTypeId=${widget.modelTypeId}');
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _ModelsContent extends StatelessWidget {
  const _ModelsContent({
    required this.page,
    required this.constraints,
    required this.modelTypeId,
    required this.query,
    required this.onPageChanged,
    required this.onRefresh,
  });

  final SchemaModelListPage page;
  final BoxConstraints constraints;
  final int modelTypeId;
  final SchemaModelListQuery query;
  final void Function(int page) onPageChanged;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final models = page.models;
    if (models.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.18),
            Icon(
              query.isActive ? Icons.search_off_rounded : Icons.inbox_rounded,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                query.isActive ? 'No matching models found' : 'No models found',
              ),
            ),
            if (!query.isActive) ...[
              const SizedBox(height: 16),
              Center(
                child: ElevatedButton(
                  onPressed: () {
                    context.push('/model-form?modelTypeId=$modelTypeId');
                  },
                  child: const Text('Create Model'),
                ),
              ),
            ],
          ],
        ),
      );
    }

    if (constraints.maxWidth < 600) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView.builder(
          itemCount: models.length + 1,
          itemBuilder: (context, index) {
            if (index == models.length) {
              return _PaginationControls(
                page: page,
                onPageChanged: onPageChanged,
              );
            }
            final model = models[index];
            return ModelRow(
              model: model,
              onTap: () => context.push('/model-detail/${model.id}'),
            );
          },
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            DataTable(
              columns: const [
                DataColumn(label: Text('Name')),
                DataColumn(label: Text('Type')),
                DataColumn(label: Text('Description')),
                DataColumn(label: Text('Created')),
                DataColumn(label: Text('Updated')),
              ],
              rows: models.map((model) {
                return DataRow(
                  cells: [
                    DataCell(Text(model.name)),
                    DataCell(Text(model.modelType?.name ?? '')),
                    DataCell(
                      Text(
                        (model.description ?? '').length > 50
                            ? '${model.description!.substring(0, 50)}...'
                            : (model.description ?? ''),
                      ),
                    ),
                    DataCell(Text(model.createdAt ?? '')),
                    DataCell(Text(model.updatedAt ?? '')),
                  ],
                  onSelectChanged: (selected) {
                    if (selected == true) {
                      context.push('/model-detail/${model.id}');
                    }
                  },
                );
              }).toList(),
            ),
            _PaginationControls(
              page: page,
              onPageChanged: onPageChanged,
            ),
          ],
        ),
      ),
    );
  }
}

class _PaginationControls extends StatelessWidget {
  const _PaginationControls({
    required this.page,
    required this.onPageChanged,
  });

  final SchemaModelListPage page;
  final void Function(int page) onPageChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          OutlinedButton.icon(
            onPressed: page.hasPreviousPage
                ? () => onPageChanged(page.page - 1)
                : null,
            icon: const Icon(Icons.chevron_left_rounded),
            label: const Text('Previous'),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Text(
              'Page ${page.page + 1}',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          OutlinedButton.icon(
            onPressed:
                page.hasNextPage ? () => onPageChanged(page.page + 1) : null,
            icon: const Icon(Icons.chevron_right_rounded),
            label: const Text('Next'),
          ),
        ],
      ),
    );
  }
}

class _ActiveQueryChips extends StatelessWidget {
  const _ActiveQueryChips({
    required this.query,
    required this.onClearSearch,
    required this.onRemoveFilter,
    required this.onClearSort,
    required this.onClearAll,
  });

  final SchemaModelListQuery query;
  final VoidCallback onClearSearch;
  final void Function(int index) onRemoveFilter;
  final VoidCallback onClearSort;
  final VoidCallback onClearAll;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        scrollDirection: Axis.horizontal,
        children: [
          if (query.search.trim().isNotEmpty)
            _QueryChip(
                label: 'Name contains ${query.search}',
                onDeleted: onClearSearch),
          for (var i = 0; i < query.filters.length; i += 1)
            _QueryChip(
              label: query.filters[i].label,
              onDeleted: () => onRemoveFilter(i),
            ),
          if (query.sort != null)
            _QueryChip(
                label: 'Sort ${query.sort!.label}', onDeleted: onClearSort),
          TextButton(
            onPressed: onClearAll,
            child: const Text('Clear all'),
          ),
        ],
      ),
    );
  }
}

class _QueryChip extends StatelessWidget {
  const _QueryChip({required this.label, required this.onDeleted});

  final String label;
  final VoidCallback onDeleted;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Chip(
        label: Text(label),
        deleteIcon: const Icon(Icons.close_rounded, size: 16),
        onDeleted: onDeleted,
      ),
    );
  }
}

Future<void> _showFilterSheet(
  BuildContext context,
  WidgetRef ref,
  SchemaModelType modelType,
  SchemaModelListQuery query,
) async {
  final result = await showModalBottomSheet<List<SchemaModelFilter>>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) =>
        _FilterSheet(modelType: modelType, initial: query.filters),
  );
  if (result != null) {
    ref
        .read(schemaModelListQueryProvider(modelType.id).notifier)
        .setFilters(result);
  }
}

Future<void> _showSortSheet(
  BuildContext context,
  WidgetRef ref,
  SchemaModelType modelType,
  SchemaModelListQuery query,
) async {
  final result = await showModalBottomSheet<_SortSheetResult>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => _SortSheet(modelType: modelType, initial: query.sort),
  );
  if (result == null) return;
  final notifier =
      ref.read(schemaModelListQueryProvider(modelType.id).notifier);
  switch (result) {
    case _SortSheetResultClear():
      notifier.setSort(null);
    case _SortSheetResultApply(:final sort):
      notifier.setSort(sort);
  }
}

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({required this.modelType, required this.initial});

  final SchemaModelType modelType;
  final List<SchemaModelFilter> initial;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late List<SchemaModelFilter> _filters;
  late _FieldOption _field;
  late SchemaModelFilterOperator _operator;
  final _valueController = TextEditingController();
  bool _boolValue = true;

  @override
  void initState() {
    super.initState();
    _filters = [...widget.initial];
    _field = _filterFields(widget.modelType).first;
    _operator = _operatorsFor(_field.valueType).first;
  }

  @override
  void dispose() {
    _valueController.dispose();
    super.dispose();
  }

  void _setField(_FieldOption field) {
    setState(() {
      _field = field;
      _operator = _operatorsFor(field.valueType).first;
      _valueController.clear();
      _boolValue = true;
    });
  }

  void _addFilter() {
    final value = _isBoolean(_field.valueType)
        ? _boolValue.toString()
        : _valueController.text.trim();
    if (value.isEmpty) return;
    setState(() {
      _filters = [
        ..._filters,
        SchemaModelFilter(
          key: _field.key,
          valueType: _field.valueType,
          operator: _operator,
          value: value,
        ),
      ];
      _valueController.clear();
      _boolValue = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final operators = _operatorsFor(_field.valueType);
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, bottom + 16),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.82,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SheetTitle(title: 'Filter ${widget.modelType.name}'),
            const SizedBox(height: 12),
            DropdownButtonFormField<_FieldOption>(
              initialValue: _field,
              decoration: const InputDecoration(labelText: 'Field'),
              items: [
                for (final field in _filterFields(widget.modelType))
                  DropdownMenuItem(value: field, child: Text(field.label)),
              ],
              onChanged: (value) {
                if (value != null) _setField(value);
              },
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<SchemaModelFilterOperator>(
              initialValue: _operator,
              decoration: const InputDecoration(labelText: 'Operator'),
              items: [
                for (final op in operators)
                  DropdownMenuItem(value: op, child: Text(op.label)),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _operator = value);
              },
            ),
            const SizedBox(height: 10),
            if (_isBoolean(_field.valueType))
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: true, label: Text('True')),
                  ButtonSegment(value: false, label: Text('False')),
                ],
                selected: {_boolValue},
                onSelectionChanged: (values) {
                  setState(() => _boolValue = values.first);
                },
              )
            else
              TextField(
                controller: _valueController,
                keyboardType: _isNumber(_field.valueType)
                    ? const TextInputType.numberWithOptions(decimal: true)
                    : TextInputType.text,
                inputFormatters: _isNumber(_field.valueType)
                    ? [_DecimalInputFormatter()]
                    : null,
                decoration: InputDecoration(
                  labelText: _isTime(_field.valueType)
                      ? 'Value (ISO date/time)'
                      : 'Value',
                ),
              ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: _addFilter,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add filter'),
              ),
            ),
            const Divider(height: 28),
            Expanded(
              child: _filters.isEmpty
                  ? const Center(child: Text('No filters added'))
                  : ListView.builder(
                      itemCount: _filters.length,
                      itemBuilder: (context, index) {
                        final filter = _filters[index];
                        return ListTile(
                          dense: true,
                          title: Text(filter.label),
                          trailing: IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () {
                              setState(() => _filters.removeAt(index));
                            },
                          ),
                        );
                      },
                    ),
            ),
            Row(
              children: [
                TextButton(
                  onPressed: () =>
                      Navigator.of(context).pop(<SchemaModelFilter>[]),
                  child: const Text('Reset'),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(_filters),
                  child: const Text('Apply'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SortSheet extends StatefulWidget {
  const _SortSheet({required this.modelType, required this.initial});

  final SchemaModelType modelType;
  final SchemaModelSort? initial;

  @override
  State<_SortSheet> createState() => _SortSheetState();
}

class _SortSheetState extends State<_SortSheet> {
  late _FieldOption _field;
  late bool _descending;

  @override
  void initState() {
    super.initState();
    final fields = _sortFields(widget.modelType);
    _field = fields.firstWhere(
      (field) => field.key == widget.initial?.key,
      orElse: () => fields.first,
    );
    _descending = widget.initial?.descending ?? true;
  }

  @override
  Widget build(BuildContext context) {
    final fields = _sortFields(widget.modelType);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SheetTitle(title: 'Sort ${widget.modelType.name}'),
          const SizedBox(height: 12),
          DropdownButtonFormField<_FieldOption>(
            initialValue: _field,
            decoration: const InputDecoration(labelText: 'Field'),
            items: [
              for (final field in fields)
                DropdownMenuItem(value: field, child: Text(field.label)),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _field = value);
            },
          ),
          const SizedBox(height: 14),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('Asc')),
              ButtonSegment(value: true, label: Text('Desc')),
            ],
            selected: {_descending},
            onSelectionChanged: (values) {
              setState(() => _descending = values.first);
            },
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              TextButton(
                onPressed: () =>
                    Navigator.of(context).pop(const _SortSheetResultClear()),
                child: const Text('Clear'),
              ),
              const Spacer(),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(
                  _SortSheetResultApply(
                    SchemaModelSort(
                      key: _field.key,
                      valueType: _field.valueType,
                      descending: _descending,
                    ),
                  ),
                ),
                child: const Text('Apply'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SheetTitle extends StatelessWidget {
  const _SheetTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
    );
  }
}

class _FieldOption {
  const _FieldOption({
    required this.key,
    required this.label,
    required this.valueType,
  });

  final String key;
  final String label;
  final String valueType;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _FieldOption &&
          key == other.key &&
          label == other.label &&
          valueType == other.valueType;

  @override
  int get hashCode => Object.hash(key, label, valueType);
}

sealed class _SortSheetResult {
  const _SortSheetResult();
}

class _SortSheetResultClear extends _SortSheetResult {
  const _SortSheetResultClear();
}

class _SortSheetResultApply extends _SortSheetResult {
  const _SortSheetResultApply(this.sort);

  final SchemaModelSort sort;
}

List<_FieldOption> _filterFields(SchemaModelType modelType) {
  return [
    const _FieldOption(key: 'name', label: 'Name', valueType: 'string'),
    const _FieldOption(
      key: 'description',
      label: 'Description',
      valueType: 'string',
    ),
    const _FieldOption(
      key: 'created_at',
      label: 'Created at',
      valueType: 'datetime',
    ),
    const _FieldOption(
      key: 'updated_at',
      label: 'Updated at',
      valueType: 'datetime',
    ),
    for (final attr
        in modelType.attributes ?? const <AttributeDefinitionDraft>[])
      if ((attr.key ?? '').isNotEmpty && !_isJson(attr.valueType ?? ''))
        _FieldOption(
          key: attr.key!,
          label: _fieldLabel(attr.key!),
          valueType: attr.valueType ?? 'string',
        ),
  ];
}

List<_FieldOption> _sortFields(SchemaModelType modelType) {
  return [
    const _FieldOption(
      key: 'created_at',
      label: 'Created at',
      valueType: 'datetime',
    ),
    const _FieldOption(
      key: 'updated_at',
      label: 'Updated at',
      valueType: 'datetime',
    ),
    for (final attr
        in modelType.attributes ?? const <AttributeDefinitionDraft>[])
      if ((attr.key ?? '').isNotEmpty &&
          (_isNumber(attr.valueType ?? '') || _isTime(attr.valueType ?? '')))
        _FieldOption(
          key: attr.key!,
          label: _fieldLabel(attr.key!),
          valueType: attr.valueType ?? 'string',
        ),
  ];
}

List<SchemaModelFilterOperator> _operatorsFor(String valueType) {
  if (_isNumber(valueType) || _isTime(valueType)) {
    return const [
      SchemaModelFilterOperator.equals,
      SchemaModelFilterOperator.greaterThan,
      SchemaModelFilterOperator.lessThan,
      SchemaModelFilterOperator.greaterThanOrEqual,
      SchemaModelFilterOperator.lessThanOrEqual,
    ];
  }
  if (_isBoolean(valueType)) {
    return const [SchemaModelFilterOperator.equals];
  }
  return const [
    SchemaModelFilterOperator.equals,
    SchemaModelFilterOperator.like,
  ];
}

bool _isNumber(String valueType) => valueType.toLowerCase() == 'number';

bool _isBoolean(String valueType) => valueType.toLowerCase() == 'boolean';

bool _isJson(String valueType) => valueType.toLowerCase() == 'json';

bool _isTime(String valueType) {
  final lower = valueType.toLowerCase();
  return lower == 'datetime' || lower == 'date' || lower == 'time';
}

String _fieldLabel(String key) {
  return key
      .split('_')
      .where((part) => part.isNotEmpty)
      .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
}

class _DecimalInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    if (text.isEmpty || RegExp(r'^-?\d*\.?\d*$').hasMatch(text)) {
      return newValue;
    }
    return oldValue;
  }
}
