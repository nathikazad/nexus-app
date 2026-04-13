import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:nx_db/nx_db.dart';

import '../../app_theme.dart';
import '../../bulk_expense_apply.dart';
import '../../expense_schema.dart';
import '../../format.dart';
import '../../providers/expense_providers.dart';
import '../../reference_layout.dart';
import '../../widgets/expense_card.dart';
import '../../widgets/expense_app_end_drawer.dart';
import '../../widgets/expense_date_range_bar.dart';
import '../../widgets/relation_picker.dart';
import '../../widgets/tag_picker.dart';

class ExpenseListScreen extends ConsumerStatefulWidget {
  const ExpenseListScreen({super.key});

  @override
  ConsumerState<ExpenseListScreen> createState() => _ExpenseListScreenState();
}

class _ExpenseListScreenState extends ConsumerState<ExpenseListScreen> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    ref.invalidate(expenseSchemaProvider);
    ref.invalidate(expenseListForUiProvider);
    ref.invalidate(expenseListSummaryProvider);
  }

  void _clearSearchField() {
    _searchController.clear();
    ref.read(expenseListSearchQueryProvider.notifier).clear();
    ref.read(expenseListSearchFieldExpandedProvider.notifier).setExpanded(false);
  }

  @override
  Widget build(BuildContext context) {
    final schemaAsync = ref.watch(expenseSchemaProvider);
    final listAsync = ref.watch(expenseListDisplayedProvider);
    final summaryAsync = ref.watch(expenseListSummaryProvider);
    final filter = ref.watch(expenseListFilterProvider);
    final sortMode = ref.watch(expenseListSortProvider);
    final selecting = ref.watch(expenseListSelectionModeProvider);
    final selectedIds = ref.watch(expenseListSelectedIdsProvider);
    final searchExpanded = ref.watch(expenseListSearchFieldExpandedProvider);
    final searchQuery = ref.watch(expenseListSearchQueryProvider);
    final selSummary = ref.watch(expenseListSelectionSummaryProvider);

    ref.listen(expenseListDisplayedProvider, (previous, next) {
      next.maybeWhen(
        data: (models) {
          final vis = models.map((m) => m.id).toSet();
          final before = ref.read(expenseListSelectedIdsProvider);
          ref.read(expenseListSelectedIdsProvider.notifier).pruneToVisible(vis);
          final after = ref.read(expenseListSelectedIdsProvider);
          if (before.length != after.length) {
            debugPrint(
              '[ExpenseList] pruneToVisible: visibleIds=${vis.length} '
              'selected ${before.length} -> ${after.length}',
            );
          }
        },
        orElse: () {},
      );
    });

    final ExpenseFilter effectiveFilter = filter ?? const ExpenseFilter();
    final filterActive = filter != null && !effectiveFilter.isEmpty;
    final sortActive = sortMode != ExpenseSortMode.dateAsc;
    final searchIconActive = searchExpanded || searchQuery.isNotEmpty;

    debugPrint(
      '[ExpenseList] build: selecting=$selecting selectedCount=${selectedIds.length} '
      'showBulkBar=${selecting && selectedIds.isNotEmpty}',
    );

    return Scaffold(
      backgroundColor: Colors.white,
      endDrawer: const ExpenseAppEndDrawer(),
      body: schemaAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: SelectableText('Schema: $e')),
        data: (schema) {
          // Shell uses extendBody: false — body ends above bottom nav.
          final mq = MediaQuery.of(context);
          final bulkActionBottom = mq.viewPadding.bottom + 6;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // App bar
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                      RefLayout.px5, RefLayout.appBarTop, RefLayout.px5, RefLayout.pb4),
                  child: selecting
                      ? Row(
                          children: [
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                  minWidth: 40, minHeight: 40),
                              icon: const Icon(Icons.close,
                                  color: AppColors.slate400, size: 26),
                              onPressed: () => ref
                                  .read(expenseListSelectionModeProvider
                                      .notifier)
                                  .setSelecting(false),
                            ),
                            Expanded(
                              child: Text(
                                '${selectedIds.length} selected',
                                textAlign: TextAlign.center,
                                style: refAppBarTitleBase(),
                              ),
                            ),
                            TextButton(
                              onPressed: listAsync.maybeWhen(
                                data: (models) {
                                  final vis =
                                      models.map((m) => m.id).toSet();
                                  return () {
                                    if (selectedIds.length == vis.length &&
                                        vis.isNotEmpty) {
                                      ref
                                          .read(expenseListSelectedIdsProvider
                                              .notifier)
                                          .clear();
                                    } else {
                                      ref
                                          .read(expenseListSelectedIdsProvider
                                              .notifier)
                                          .selectAll(vis);
                                    }
                                  };
                                },
                                orElse: () => null,
                              ),
                              child: Text(
                                listAsync.maybeWhen(
                                  data: (models) {
                                    final vis =
                                        models.map((m) => m.id).toSet();
                                    if (selectedIds.length == vis.length &&
                                        vis.isNotEmpty) {
                                      return 'Deselect all';
                                    }
                                    return 'Select all';
                                  },
                                  orElse: () => 'Select all',
                                ),
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.teal600,
                                ),
                              ),
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            Expanded(
                                child: Text('Expenses',
                                    style: refAppBarTitleLarge())),
                            const ExpenseDateRangeCalendarButton(),
                            const SizedBox(width: 4),
                            const ExpenseAppMenuButton(),
                          ],
                        ),
                ),
              ),

              if (!selecting)
                const ExpenseDateRangeBar(bottomPadding: 12),

              // Summary line + search / select / filter / sort
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    RefLayout.px5, 0, RefLayout.px5, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: selecting
                          ? (selSummary != null
                              ? Text(
                                  selSummary.sumTotal != null
                                      ? '${selSummary.count} of ${listAsync.maybeWhen(data: (m) => m.length, orElse: () => 0)} \u00b7 ${formatMoney(selSummary.sumTotal)}'
                                      : '${selSummary.count} of ${listAsync.maybeWhen(data: (m) => m.length, orElse: () => 0)}',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.slate500,
                                  ),
                                )
                              : const SizedBox.shrink())
                          : summaryAsync.when(
                              data: (s) => Text(
                                s.sumTotal != null
                                    ? '${s.count} \u00b7 ${formatMoney(s.sumTotal)}'
                                    : '${s.count}',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.slate500,
                                ),
                              ),
                              loading: () => Text(
                                '...',
                                style: GoogleFonts.inter(
                                    fontSize: 14, color: AppColors.slate500),
                              ),
                              error: (_, __) => const SizedBox.shrink(),
                            ),
                    ),
                    if (!selecting) ...[
                      GestureDetector(
                        onTap: () {
                          final next = !searchExpanded;
                          ref
                              .read(expenseListSearchFieldExpandedProvider
                                  .notifier)
                              .setExpanded(next);
                          if (next) {
                            _searchController.text =
                                ref.read(expenseListSearchQueryProvider);
                          }
                        },
                        child: Icon(
                          Icons.search,
                          color: searchIconActive
                              ? AppColors.teal600
                              : AppColors.slate400,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 14),
                      GestureDetector(
                        onTap: () => ref
                            .read(expenseListSelectionModeProvider.notifier)
                            .setSelecting(true),
                        child: Icon(
                          Icons.checklist_outlined,
                          color: AppColors.slate400,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 14),
                    ],
                    Opacity(
                      opacity: selecting ? 0.45 : 1,
                      child: IgnorePointer(
                        ignoring: selecting,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            GestureDetector(
                              onTap: () =>
                                  _showFilterSheet(context, ref, schema),
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Icon(
                                    filterActive
                                        ? Icons.filter_alt
                                        : Icons.filter_alt_outlined,
                                    color: filterActive
                                        ? AppColors.teal600
                                        : AppColors.slate400,
                                    size: 20,
                                  ),
                                  if (filterActive)
                                    Positioned(
                                      top: -4,
                                      right: -6,
                                      child: Container(
                                        width: 14,
                                        height: 14,
                                        decoration: const BoxDecoration(
                                          color: AppColors.teal600,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Center(
                                          child: Text(
                                            '${effectiveFilter.activeCount}',
                                            style: GoogleFonts.inter(
                                              fontSize: 8,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 14),
                            GestureDetector(
                              onTap: () => _showSortSheet(context),
                              child: Icon(
                                Icons.sort,
                                color: sortActive
                                    ? AppColors.teal600
                                    : AppColors.slate400,
                                size: 20,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              if (!selecting && searchExpanded)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      RefLayout.px5, 0, RefLayout.px5, 8),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (v) => ref
                        .read(expenseListSearchQueryProvider.notifier)
                        .setQuery(v),
                    style: GoogleFonts.inter(
                        fontSize: 14, color: AppColors.slate900),
                    decoration: InputDecoration(
                      hintText: 'Search transactions…',
                      hintStyle: GoogleFonts.inter(
                          fontSize: 14, color: AppColors.slate400),
                      prefixIcon: const Icon(Icons.search,
                          size: 20, color: AppColors.slate400),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.close,
                            size: 20, color: AppColors.slate400),
                        onPressed: _clearSearchField,
                      ),
                      filled: true,
                      fillColor: AppColors.slate100,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                    ),
                  ),
                ),

              // Active filter chips
              if (filterActive)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      RefLayout.px5, 0, RefLayout.px5, 4),
                  child: _ActiveFilterChips(
                    filter: effectiveFilter,
                    schema: schema,
                    onClearAll: () {
                      ref
                          .read(expenseListFilterProvider.notifier)
                          .setFilter(null);
                    },
                    onRemoveTag: (index) {
                      final tags = [...?effectiveFilter.tagFilters];
                      tags.removeAt(index);
                      ref
                          .read(expenseListFilterProvider.notifier)
                          .setFilter(ExpenseFilter(
                            tagFilters: tags.isEmpty ? null : tags,
                            minAmount: effectiveFilter.minAmount,
                            maxAmount: effectiveFilter.maxAmount,
                            relationFilters: effectiveFilter.relationFilters,
                            relationFilterLabels:
                                effectiveFilter.relationFilterLabels,
                          ));
                    },
                    onRemoveMinAmount: () {
                      ref
                          .read(expenseListFilterProvider.notifier)
                          .setFilter(ExpenseFilter(
                            tagFilters: effectiveFilter.tagFilters,
                            maxAmount: effectiveFilter.maxAmount,
                            relationFilters: effectiveFilter.relationFilters,
                            relationFilterLabels:
                                effectiveFilter.relationFilterLabels,
                          ));
                    },
                    onRemoveMaxAmount: () {
                      ref
                          .read(expenseListFilterProvider.notifier)
                          .setFilter(ExpenseFilter(
                            tagFilters: effectiveFilter.tagFilters,
                            minAmount: effectiveFilter.minAmount,
                            relationFilters: effectiveFilter.relationFilters,
                            relationFilterLabels:
                                effectiveFilter.relationFilterLabels,
                          ));
                    },
                    onRemoveRelation: (relType, modelId) {
                      final rels = Map<String, Set<int>>.from(
                          effectiveFilter.relationFilters ?? {});
                      rels[relType]?.remove(modelId);
                      if (rels[relType]?.isEmpty ?? false) rels.remove(relType);
                      final labels = <String, Map<int, String>>{};
                      final existing = effectiveFilter.relationFilterLabels;
                      if (existing != null) {
                        for (final e in existing.entries) {
                          if (e.key == relType) {
                            final m = Map<int, String>.from(e.value)
                              ..remove(modelId);
                            if (m.isNotEmpty) labels[e.key] = m;
                          } else {
                            labels[e.key] = Map<int, String>.from(e.value);
                          }
                        }
                      }
                      ref
                          .read(expenseListFilterProvider.notifier)
                          .setFilter(ExpenseFilter(
                            tagFilters: effectiveFilter.tagFilters,
                            minAmount: effectiveFilter.minAmount,
                            maxAmount: effectiveFilter.maxAmount,
                            relationFilters: rels.isEmpty ? null : rels,
                            relationFilterLabels:
                                labels.isEmpty ? null : labels,
                          ));
                    },
                  ),
                ),

              // Expense list with date section headers
              Expanded(
                child: ColoredBox(
                  color: AppColors.slate50.withValues(alpha: 0.5),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      RefreshIndicator(
                        onRefresh: _refresh,
                        color: AppColors.teal600,
                        child: listAsync.when(
                          loading: () =>
                              const Center(child: CircularProgressIndicator()),
                          error: (e, _) => Center(
                              child: Text('Error: $e',
                                  style: GoogleFonts.inter(
                                      fontSize: 13,
                                      color: AppColors.slate500))),
                          data: (models) {
                            if (models.isEmpty) {
                              return Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.receipt_long_outlined,
                                        size: 48, color: AppColors.slate300),
                                    const SizedBox(height: 12),
                                    Text(
                                      'No expenses found',
                                      style: GoogleFonts.inter(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.slate400,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }
                            final bottomPad = selecting &&
                                    selectedIds.isNotEmpty
                                ? bulkActionBottom + 56
                                : RefLayout.pb24;
                            final items = _buildDateGroupedItems(
                              models,
                              schema,
                              selectionMode: selecting,
                              selectedIds: selectedIds,
                            );
                            return ListView.builder(
                              padding: EdgeInsets.fromLTRB(
                                  RefLayout.px5, 8, RefLayout.px5, bottomPad),
                              itemCount: items.length,
                              itemBuilder: (context, i) => items[i],
                            );
                          },
                        ),
                      ),
                      if (selecting && selectedIds.isNotEmpty)
                        Positioned(
                          left: RefLayout.px5,
                          right: RefLayout.px5,
                          bottom: bulkActionBottom,
                          child: Material(
                            elevation: 6,
                            borderRadius: BorderRadius.circular(16),
                            color: AppColors.teal600,
                            child: InkWell(
                              onTap: () => _showBulkApplyMenu(context, schema),
                              borderRadius: BorderRadius.circular(16),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 14, horizontal: 16),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.label_outline,
                                        color: Colors.white, size: 22),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        'Apply tag, company, or attribute',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.center,
                                        style: GoogleFonts.inter(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _buildDateGroupedItems(
    List<Model> models,
    ModelType schema, {
    required bool selectionMode,
    required Set<int> selectedIds,
  }) {
    final items = <Widget>[];
    String? lastDate;

    for (final m in models) {
      final dateStr = _dateLabel(m.createdAt);
      if (dateStr != lastDate) {
        items.add(Padding(
          padding: EdgeInsets.only(
              top: lastDate == null ? 4 : 12, bottom: 4),
          child: Text(
            dateStr,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
              color: AppColors.slate400,
            ),
          ),
        ));
        lastDate = dateStr;
      }
      items.add(Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: ExpenseCard(
          model: m,
          schema: schema,
          selectionMode: selectionMode,
          selected: selectedIds.contains(m.id),
          onTap: () {
            if (selectionMode) {
              ref.read(expenseListSelectedIdsProvider.notifier).toggle(m.id);
            } else {
              context.push('/expense/${m.id}');
            }
          },
        ),
      ));
    }
    return items;
  }

  Future<void> _showBulkApplyMenu(BuildContext context, ModelType schema) async {
    final n = ref.read(expenseListSelectedIdsProvider).length;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding:
                      const EdgeInsets.fromLTRB(RefLayout.px5, 8, RefLayout.px5, 4),
                  child: Text(
                    'Apply to $n expenses',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.slate400,
                    ),
                  ),
                ),
                Padding(
                  padding:
                      const EdgeInsets.fromLTRB(RefLayout.px5, 0, RefLayout.px5, 8),
                  child: Text(
                    'Choose what to set',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.slate900,
                    ),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.label_outline,
                      color: AppColors.teal600),
                  title: const Text('Tag'),
                  subtitle: Text(
                    'Category, priority, or any tag system',
                    style: GoogleFonts.inter(
                        fontSize: 12, color: AppColors.slate500),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _bulkPickTag(context, schema);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.business_outlined,
                      color: AppColors.slate600),
                  title: const Text('Company or project'),
                  subtitle: Text(
                    'Link to an existing record',
                    style: GoogleFonts.inter(
                        fontSize: 12, color: AppColors.slate500),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _bulkPickRelation(context, schema);
                  },
                ),
                ListTile(
                  leading:
                      const Icon(Icons.tune, color: AppColors.slate600),
                  title: const Text('Attribute'),
                  subtitle: Text(
                    'Pick a tag system, then a value',
                    style: GoogleFonts.inter(
                        fontSize: 12, color: AppColors.slate500),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _bulkPickTag(context, schema);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _bulkPickTag(BuildContext context, ModelType schema) async {
    final systems = schema.tagSystems ?? [];
    if (systems.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No tag systems defined')),
        );
      }
      return;
    }

    TagSystem? pick;
    if (systems.length == 1) {
      pick = systems.first;
    } else {
      pick = await showModalBottomSheet<TagSystem>(
        context: context,
        showDragHandle: true,
        backgroundColor: Colors.white,
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final ts in systems)
                ListTile(
                  title: Text(ts.name),
                  onTap: () => Navigator.pop(ctx, ts),
                ),
            ],
          ),
        ),
      );
    }
    if (pick == null || !context.mounted) return;

    final nodes = await showTagPickerSheet(
      context,
      system: pick,
      initial: const [],
    );
    if (nodes == null || !context.mounted) return;

    final ids = ref.read(expenseListSelectedIdsProvider).toList();
    if (ids.isEmpty) return;

    final messenger = ScaffoldMessenger.of(context);

    final result = await bulkApplyTag(
      ref: ref,
      ids: ids,
      systemName: pick.name,
      nodes: nodes,
    );

    if (!context.mounted) return;

    for (final id in ids) {
      ref.invalidate(expenseDetailProvider(id));
    }
    ref.invalidate(expenseListForUiProvider);
    ref.invalidate(expenseListSummaryProvider);
    ref.read(expenseListSelectionModeProvider.notifier).setSelecting(false);

    if (result.hasFailures) {
      messenger.showSnackBar(
        SnackBar(
            content: Text(
                'Updated with ${result.failures.length} error(s). ${result.failures.values.first}')),
      );
    } else {
      messenger.showSnackBar(
        const SnackBar(content: Text('Tags updated')),
      );
    }
  }

  Future<void> _bulkPickRelation(BuildContext context, ModelType schema) async {
    final relNames = allRelationTargetTypeNames(schema).toList();
    if (relNames.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No relation types defined')),
        );
      }
      return;
    }

    String? target;
    if (relNames.length == 1) {
      target = relNames.first;
    } else {
      target = await showModalBottomSheet<String>(
        context: context,
        showDragHandle: true,
        backgroundColor: Colors.white,
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final n in relNames)
                ListTile(
                  title: Text(n),
                  onTap: () => Navigator.pop(ctx, n),
                ),
            ],
          ),
        ),
      );
    }
    if (target == null || !context.mounted) return;

    final res = await showRelationPickerSheet(
      context,
      targetModelTypeName: target,
      initialIds: const [],
      allowMultiple: false,
    );
    if (res == null || !context.mounted) return;
    if (res is RelationPickCreate) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Creating new records in bulk is not supported')),
      );
      return;
    }
    final link = res as RelationPickLink;
    final ids = ref.read(expenseListSelectedIdsProvider).toList();
    if (ids.isEmpty) return;

    final messenger = ScaffoldMessenger.of(context);

    final result = await bulkApplyRelation(
      ref: ref,
      ids: ids,
      targetTypeName: target,
      linkIds: link.ids,
    );

    if (!context.mounted) return;

    for (final id in ids) {
      ref.invalidate(expenseDetailProvider(id));
    }
    ref.invalidate(relatedModelsProvider(target));
    ref.invalidate(expenseListForUiProvider);
    ref.invalidate(expenseListSummaryProvider);
    ref.read(expenseListSelectionModeProvider.notifier).setSelecting(false);

    if (result.hasFailures) {
      messenger.showSnackBar(
        SnackBar(
            content: Text(
                'Updated with ${result.failures.length} error(s). ${result.failures.values.first}')),
      );
    } else {
      messenger.showSnackBar(
        const SnackBar(content: Text('Relations updated')),
      );
    }
  }

  static String _dateLabel(String? iso) {
    if (iso == null || iso.isEmpty) return 'Unknown';
    try {
      final d = DateTime.parse(iso);
      return DateFormat('MMM d, y').format(d);
    } catch (_) {
      return iso;
    }
  }

  // ──────────────────────── Filter Bottom Sheet ────────────────────────

  Future<void> _showFilterSheet(
      BuildContext context, WidgetRef ref, ModelType schema) async {
    final currentFilter = ref.read(expenseListFilterProvider);

    // Load all relation targets (Company, etc.) before opening — AsyncValue.whenData
    // only runs if data is already cached, so the sheet was opening with empty lists.
    final relationNames = allRelationTargetTypeNames(schema);
    final allRelModels = <String, List<Model>>{};
    try {
      for (final name in relationNames) {
        allRelModels[name] =
            await ref.read(relatedModelsProvider(name).future);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load companies: $e')),
        );
      }
      return;
    }

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FilterSheet(
        schema: schema,
        initial: currentFilter,
        allRelationModels: allRelModels,
        onApply: (f) {
          ref.read(expenseListFilterProvider.notifier).setFilter(
                f == null || f.isEmpty ? null : f,
              );
        },
      ),
    );
  }

  // ──────────────────────── Sort Bottom Sheet ────────────────────────

  void _showSortSheet(BuildContext context) {
    final currentSort = ref.read(expenseListSortProvider);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _SortSheet(
        current: currentSort,
        onPick: (mode) {
          ref.read(expenseListSortProvider.notifier).setSort(mode);
          Navigator.pop(context);
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Active filter chips (dismissible row)
// ═══════════════════════════════════════════════════════════════════════════

class _ActiveFilterChips extends StatelessWidget {
  const _ActiveFilterChips({
    required this.filter,
    required this.schema,
    required this.onClearAll,
    required this.onRemoveTag,
    required this.onRemoveMinAmount,
    required this.onRemoveMaxAmount,
    required this.onRemoveRelation,
  });

  final ExpenseFilter filter;
  final ModelType schema;
  final VoidCallback onClearAll;
  final void Function(int index) onRemoveTag;
  final VoidCallback onRemoveMinAmount;
  final VoidCallback onRemoveMaxAmount;
  final void Function(String relType, int modelId) onRemoveRelation;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 30,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          if (filter.tagFilters != null)
            for (var i = 0; i < filter.tagFilters!.length; i++)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: _chipWidget(
                  _tagFilterLabel(filter.tagFilters![i]),
                  () => onRemoveTag(i),
                ),
              ),
          if (filter.minAmount != null)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: _chipWidget(
                'Min \$${filter.minAmount!.toStringAsFixed(0)}',
                onRemoveMinAmount,
              ),
            ),
          if (filter.maxAmount != null)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: _chipWidget(
                'Max \$${filter.maxAmount!.toStringAsFixed(0)}',
                onRemoveMaxAmount,
              ),
            ),
          if (filter.relationFilters != null)
            for (final entry in filter.relationFilters!.entries)
              for (final id in entry.value)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: _chipWidget(
                    '${entry.key}: ${filter.relationFilterLabels?[entry.key]?[id] ?? '#$id'}',
                    () => onRemoveRelation(entry.key, id),
                  ),
                ),
          GestureDetector(
            onTap: onClearAll,
            child: Center(
              child: Text(
                'Clear all',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.slate400,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chipWidget(String label, VoidCallback onRemove) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDFA),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF99F6E4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppColors.teal700,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(Icons.close, size: 14, color: AppColors.teal500),
          ),
        ],
      ),
    );
  }

  String _tagFilterLabel(Map<String, dynamic> tf) {
    final system = tf['system'] as String? ?? '';
    final node = tf['node'] as String? ?? '';
    return '$system: $node';
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Filter Bottom Sheet
// ═══════════════════════════════════════════════════════════════════════════

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({
    required this.schema,
    required this.initial,
    required this.allRelationModels,
    required this.onApply,
  });

  final ModelType schema;
  final ExpenseFilter? initial;
  final Map<String, List<Model>> allRelationModels;
  final void Function(ExpenseFilter?) onApply;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late Map<String, Set<String>> _tagSelections;
  final _minController = TextEditingController();
  final _maxController = TextEditingController();
  final Map<String, Set<String>> _expandedNodes = {};

  // Relation selections: relation type name → set of selected model IDs
  late Map<String, Set<int>> _relationSelections;
  // Relation search: relation type name → current search query
  final Map<String, String> _relationSearchQueries = {};
  // Relation search: text controllers per relation type
  final Map<String, TextEditingController> _relationSearchControllers = {};
  // Relation search: relation type name → selected model names (for chip display)
  final Map<String, Map<int, String>> _relationSelectedNames = {};

  // Section collapse state — all collapsed by default
  final Set<String> _expandedSections = {};

  @override
  void initState() {
    super.initState();
    _tagSelections = {};
    _relationSelections = {};
    final existing = widget.initial;
    if (existing?.tagFilters != null) {
      for (final tf in existing!.tagFilters!) {
        final system = tf['system'] as String? ?? '';
        final node = tf['node'] as String? ?? '';
        _tagSelections.putIfAbsent(system, () => {}).add(node);
      }
    }
    if (existing?.minAmount != null) {
      _minController.text = existing!.minAmount!.toStringAsFixed(0);
    }
    if (existing?.maxAmount != null) {
      _maxController.text = existing!.maxAmount!.toStringAsFixed(0);
    }
    if (existing?.relationFilters != null) {
      for (final entry in existing!.relationFilters!.entries) {
        _relationSelections[entry.key] = Set.from(entry.value);
        // Try to resolve names from allRelationModels
        final models = widget.allRelationModels[entry.key] ?? [];
        final names = <int, String>{};
        for (final id in entry.value) {
          final m = models.where((m) => m.id == id).firstOrNull;
          if (m != null) names[id] = m.name;
        }
        _relationSelectedNames[entry.key] = names;
      }
    }
    // Auto-expand sections that have active selections
    for (final ts in widget.schema.tagSystems ?? const <TagSystem>[]) {
      if ((_tagSelections[ts.name] ?? {}).isNotEmpty) {
        _expandedSections.add('tag:${ts.name}');
      }
    }
    if (_minController.text.isNotEmpty || _maxController.text.isNotEmpty) {
      _expandedSections.add('amount');
    }
    for (final entry in _relationSelections.entries) {
      if (entry.value.isNotEmpty) {
        _expandedSections.add('rel:${entry.key}');
      }
    }
  }

  @override
  void dispose() {
    _minController.dispose();
    _maxController.dispose();
    for (final c in _relationSearchControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _reset() {
    setState(() {
      _tagSelections.clear();
      _minController.clear();
      _maxController.clear();
      _relationSelections.clear();
      _relationSelectedNames.clear();
      _relationSearchQueries.clear();
    });
  }

  void _apply() {
    final tagFilters = <Map<String, dynamic>>[];
    for (final entry in _tagSelections.entries) {
      for (final node in entry.value) {
        tagFilters.add({
          'system': entry.key,
          'node': node,
          'include_descendants': true,
        });
      }
    }

    final minAmt = double.tryParse(_minController.text);
    final maxAmt = double.tryParse(_maxController.text);

    Map<String, Set<int>>? relFilters;
    Map<String, Map<int, String>>? relLabels;
    if (_relationSelections.isNotEmpty) {
      relFilters = Map.from(_relationSelections);
      relFilters.removeWhere((_, ids) => ids.isEmpty);
      if (relFilters.isEmpty) relFilters = null;
      if (relFilters != null) {
        relLabels = {};
        for (final entry in relFilters.entries) {
          final names = _relationSelectedNames[entry.key];
          if (names == null) continue;
          final m = <int, String>{};
          for (final id in entry.value) {
            final n = names[id];
            if (n != null) m[id] = n;
          }
          if (m.isNotEmpty) relLabels[entry.key] = m;
        }
        if (relLabels.isEmpty) relLabels = null;
      }
    }

    final filter = ExpenseFilter(
      tagFilters: tagFilters.isEmpty ? null : tagFilters,
      minAmount: minAmt,
      maxAmount: maxAmt,
      relationFilters: relFilters,
      relationFilterLabels: relLabels,
    );

    widget.onApply(filter);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final tagSystems = widget.schema.tagSystems ?? const <TagSystem>[];
    final relationNames = allRelationTargetTypeNames(widget.schema);

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 48,
              height: 5,
              decoration: BoxDecoration(
                color: AppColors.slate200,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Text(
                  'Filters',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.slate900,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: _reset,
                  child: Text(
                    'Reset',
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.slate400),
                  ),
                ),
                const SizedBox(width: 16),
                GestureDetector(
                  onTap: _apply,
                  child: Text(
                    'Apply',
                    style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.teal600),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.slate100),
          // Scrollable content
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              children: [
                // Tag system sections
                for (final ts in tagSystems)
                  _collapsibleSection(
                    key: 'tag:${ts.name}',
                    title: ts.name,
                    selectedCount: (_tagSelections[ts.name] ?? {}).length,
                    child: ts.isHierarchical
                        ? _buildHierarchicalContent(ts)
                        : _buildFlatContent(ts),
                  ),
                // Amount section
                _collapsibleSection(
                  key: 'amount',
                  title: 'Amount',
                  selectedCount: (_minController.text.isNotEmpty ? 1 : 0) +
                      (_maxController.text.isNotEmpty ? 1 : 0),
                  child: _buildAmountContent(),
                ),
                // Relation sections
                for (final relName in relationNames)
                  _collapsibleSection(
                    key: 'rel:$relName',
                    title: relName,
                    selectedCount:
                        (_relationSelections[relName] ?? {}).length,
                    child: _buildRelationContent(relName),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Collapsible section wrapper ───

  Widget _collapsibleSection({
    required String key,
    required String title,
    required int selectedCount,
    required Widget child,
  }) {
    final isExpanded = _expandedSections.contains(key);
    return Column(
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            setState(() {
              if (isExpanded) {
                _expandedSections.remove(key);
              } else {
                _expandedSections.add(key);
              }
            });
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              children: [
                Text(
                  title.toUpperCase(),
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                    color: AppColors.slate400,
                  ),
                ),
                if (selectedCount > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppColors.teal600,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$selectedCount',
                      style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.white),
                    ),
                  ),
                ],
                const Spacer(),
                Icon(
                  isExpanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  size: 20,
                  color: AppColors.slate400,
                ),
              ],
            ),
          ),
        ),
        if (isExpanded)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: child,
          ),
        const Divider(height: 1, color: AppColors.slate100),
      ],
    );
  }

  // ─── Hierarchical tag system content ───

  Widget _buildHierarchicalContent(TagSystem ts) {
    final selected = _tagSelections[ts.name] ?? {};
    final expanded = _expandedNodes.putIfAbsent(ts.name, () => {});
    return Container(
      decoration: const BoxDecoration(
        border:
            Border(left: BorderSide(color: AppColors.slate100, width: 2)),
      ),
      padding: const EdgeInsets.only(left: 12),
      child: Column(
        children: [
          for (final node in ts.nodes)
            _buildTreeNode(ts, node, selected, expanded, depth: 0),
        ],
      ),
    );
  }

  Widget _buildTreeNode(
    TagSystem ts,
    TagNode node,
    Set<String> selected,
    Set<String> expanded, {
    required int depth,
  }) {
    final hasChildren = node.children != null && node.children!.isNotEmpty;
    final isExpanded = expanded.contains(node.name);
    final isSelected = selected.contains(node.name);
    final isExclusive = ts.selectionMode == 'exclusive';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            setState(() {
              final sel = _tagSelections.putIfAbsent(ts.name, () => {});
              if (isSelected) {
                sel.remove(node.name);
              } else {
                if (isExclusive) sel.clear();
                sel.add(node.name);
              }
            });
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                _checkbox(isSelected, size: depth == 0 ? 20.0 : 18.0),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    node.name,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight:
                          depth == 0 ? FontWeight.w600 : FontWeight.w500,
                      color:
                          depth == 0 ? AppColors.slate900 : AppColors.slate700,
                    ),
                  ),
                ),
                if (hasChildren)
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        if (isExpanded) {
                          expanded.remove(node.name);
                        } else {
                          expanded.add(node.name);
                        }
                      });
                    },
                    child: Icon(
                      isExpanded
                          ? Icons.keyboard_arrow_down
                          : Icons.chevron_right,
                      size: 18,
                      color: AppColors.slate300,
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (hasChildren && isExpanded)
          Container(
            margin: const EdgeInsets.only(left: 20),
            decoration: const BoxDecoration(
              border: Border(
                  left: BorderSide(color: AppColors.slate100, width: 2)),
            ),
            padding: const EdgeInsets.only(left: 12),
            child: Column(
              children: [
                for (final child in node.children!)
                  _buildTreeNode(ts, child, selected, expanded,
                      depth: depth + 1),
              ],
            ),
          ),
      ],
    );
  }

  // ─── Flat tag system content ───

  Widget _buildFlatContent(TagSystem ts) {
    final selected = _tagSelections[ts.name] ?? {};
    final isExclusive = ts.selectionMode == 'exclusive';

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final node in ts.nodes)
          GestureDetector(
            onTap: () {
              setState(() {
                final sel = _tagSelections.putIfAbsent(ts.name, () => {});
                if (selected.contains(node.name)) {
                  sel.remove(node.name);
                } else {
                  if (isExclusive) sel.clear();
                  sel.add(node.name);
                }
              });
            },
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: selected.contains(node.name)
                    ? AppColors.teal600
                    : Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: selected.contains(node.name)
                      ? AppColors.teal600
                      : AppColors.slate200,
                ),
              ),
              child: Text(
                node.name,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: selected.contains(node.name)
                      ? Colors.white
                      : AppColors.slate600,
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ─── Amount content ───

  Widget _buildAmountContent() {
    final fieldStyle = GoogleFonts.inter(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: AppColors.slate900,
    );
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Min',
                  style: GoogleFonts.inter(
                      fontSize: 12, color: AppColors.slate400)),
              const SizedBox(height: 6),
              TextField(
                controller: _minController,
                keyboardType: TextInputType.number,
                style: fieldStyle,
                decoration: InputDecoration(
                  prefixText: '\$ ',
                  prefixStyle: GoogleFonts.inter(
                      fontSize: 14, color: AppColors.slate400),
                  hintText: '0',
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.slate200),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.slate200),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Max',
                  style: GoogleFonts.inter(
                      fontSize: 12, color: AppColors.slate400)),
              const SizedBox(height: 6),
              TextField(
                controller: _maxController,
                keyboardType: TextInputType.number,
                style: fieldStyle,
                decoration: InputDecoration(
                  prefixText: '\$ ',
                  prefixStyle: GoogleFonts.inter(
                      fontSize: 14, color: AppColors.slate400),
                  hintText: 'No limit',
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.slate200),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.slate200),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── Relation search + chips content ───

  Widget _buildRelationContent(String relName) {
    final allModels = widget.allRelationModels[relName] ?? [];
    final selectedIds = _relationSelections[relName] ?? {};
    final selectedNames = _relationSelectedNames[relName] ?? {};
    final query =
        (_relationSearchQueries[relName] ?? '').toLowerCase();
    final searchController = _relationSearchControllers.putIfAbsent(
        relName, () => TextEditingController());

    // Candidates: not yet selected, sorted by name for browsing.
    final candidates = allModels
        .where((m) => !selectedIds.contains(m.id))
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    // Empty field: show first batch so users can pick without typing; typing narrows the list.
    final suggestions = query.isEmpty
        ? candidates.take(20).toList()
        : candidates
            .where((m) => m.name.toLowerCase().contains(query))
            .take(20)
            .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search field
        TextField(
          controller: searchController,
          onChanged: (v) => setState(() {
            _relationSearchQueries[relName] = v;
          }),
          style: GoogleFonts.inter(fontSize: 14, color: AppColors.slate900),
          decoration: InputDecoration(
            hintText: 'Search ${relName.toLowerCase()}...',
            hintStyle:
                GoogleFonts.inter(fontSize: 14, color: AppColors.slate300),
            prefixIcon: const Icon(Icons.search,
                size: 20, color: AppColors.slate400),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.slate200),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.slate200),
            ),
          ),
        ),

        // Search suggestions
        if (suggestions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.slate200),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                for (var i = 0; i < suggestions.length; i++) ...[
                  InkWell(
                    onTap: () {
                      setState(() {
                        final ids = _relationSelections.putIfAbsent(
                            relName, () => {});
                        ids.add(suggestions[i].id);
                        final names = _relationSelectedNames.putIfAbsent(
                            relName, () => {});
                        names[suggestions[i].id] = suggestions[i].name;
                        _relationSearchQueries[relName] = '';
                        searchController.clear();
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              suggestions[i].name,
                              style: GoogleFonts.inter(
                                  fontSize: 14, color: AppColors.slate700),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (i < suggestions.length - 1)
                    const Divider(height: 1, color: AppColors.slate100),
                ],
              ],
            ),
          ),

        // Selected chips
        if (selectedIds.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final id in selectedIds)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDFA),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF99F6E4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          selectedNames[id] ?? '#$id',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppColors.teal700,
                          ),
                        ),
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _relationSelections[relName]?.remove(id);
                              _relationSelectedNames[relName]?.remove(id);
                            });
                          },
                          child: const Icon(Icons.close,
                              size: 14, color: AppColors.teal500),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _checkbox(bool checked, {double size = 20}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: checked ? AppColors.teal600 : Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: checked ? AppColors.teal600 : AppColors.slate300,
          width: 2,
        ),
      ),
      child: checked
          ? Icon(Icons.check, size: size - 6, color: Colors.white)
          : null,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Sort Bottom Sheet
// ═══════════════════════════════════════════════════════════════════════════

class _SortSheet extends StatelessWidget {
  const _SortSheet({required this.current, required this.onPick});

  final ExpenseSortMode current;
  final void Function(ExpenseSortMode) onPick;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 48,
              height: 5,
              decoration: BoxDecoration(
                color: AppColors.slate200,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Sort by',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.slate900,
                ),
              ),
            ),
          ),
          const Divider(height: 1, color: AppColors.slate100),
          // Date row
          _sortRow(
            icon: Icons.calendar_today_outlined,
            label: 'Date',
            ascMode: ExpenseSortMode.dateAsc,
            descMode: ExpenseSortMode.dateDesc,
          ),
          // Amount row
          _sortRow(
            icon: Icons.account_balance_wallet_outlined,
            label: 'Amount',
            ascMode: ExpenseSortMode.amountAsc,
            descMode: ExpenseSortMode.amountDesc,
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _sortRow({
    required IconData icon,
    required String label,
    required ExpenseSortMode ascMode,
    required ExpenseSortMode descMode,
  }) {
    final isAsc = current == ascMode;
    final isDesc = current == descMode;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.slate400),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.slate900,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: AppColors.slate50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.slate200),
            ),
            padding: const EdgeInsets.all(2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _toggleButton('Asc', isAsc, () => onPick(ascMode)),
                _toggleButton('Desc', isDesc, () => onPick(descMode)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _toggleButton(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.teal600 : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppColors.slate600,
          ),
        ),
      ),
    );
  }
}
