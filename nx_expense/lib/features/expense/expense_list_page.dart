
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nx_expense/core/theme/app_theme.dart';
import 'package:nx_expense/core/formatting/format.dart';
import 'package:nx_expense/core/layout/layout.dart';
import 'package:nx_expense/data/providers.dart';
import 'package:nx_expense/data/schema/kgql_schema_helpers.dart';
import 'package:nx_expense/features/expense/expense_list_view_model.dart';
import 'package:nx_expense/domain/expense/expense.dart';
import 'package:nx_expense/domain/expense/expense_filter.dart';
import 'package:nx_expense/domain/expense/related_model.dart';
import 'package:nx_expense/domain/schema/model_type_view.dart';
import 'package:nx_expense/features/desktop/desktop_nav.dart';
import 'package:nx_expense/features/shell/expense_app_end_drawer.dart';
import 'widgets/expense_card.dart';
import 'widgets/expense_date_range_bar.dart';
import 'expense_list_bulk_actions.dart';
import 'expense_list_filter_sheet.dart';
import 'expense_list_sort_sheet.dart';

class ExpenseListScreen extends ConsumerStatefulWidget {
  const ExpenseListScreen({
    super.key,
    this.title,
    this.initialFilter,
    this.showFilterIcon = true,
    this.showDateRange = true,
    this.showSearch = true,
    this.showSelect = true,
    this.showDrawer = true,
    this.showActiveFilterChips = true,
    /// When set (e.g. desktop panel 3 scoped list), taps open without changing column 2.
    this.onExpenseTap,
  });

  final String? title;
  final ExpenseFilter? initialFilter;
  final bool showFilterIcon;
  final bool showDateRange;
  final bool showSearch;
  final bool showSelect;
  final bool showDrawer;
  /// When false, the horizontal filter chip row (and "Clear all") is hidden.
  final bool showActiveFilterChips;
  final void Function(int expenseId)? onExpenseTap;

  @override
  ConsumerState<ExpenseListScreen> createState() => _ExpenseListScreenState();
}

class _ExpenseListScreenState extends ConsumerState<ExpenseListScreen> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    final initial = widget.initialFilter;
    if (initial != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(expenseListFilterProvider.notifier).setFilter(initial);
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    ref.invalidate(expenseSchemaProvider);
    ref.invalidate(expenseSchemaViewProvider);
    invalidateExpenseListCache(ref);
  }

  void _clearSearchField() {
    _searchController.clear();
    ref.read(expenseListSearchQueryProvider.notifier).clear();
    ref
        .read(expenseListSearchFieldExpandedProvider.notifier)
        .setExpanded(false);
  }

  @override
  Widget build(BuildContext context) {
    final schemaAsync = ref.watch(expenseSchemaViewProvider);
    final listAsync = ref.watch(expenseListDisplayedProvider);
    final summaryAsync = ref.watch(expenseListSummaryProvider);
    final filter = ref.watch(expenseListFilterProvider);
    final dateRange = ref.watch(expenseDateRangeProvider);
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
    final sortActive = expenseListSortIsActive(sortMode, dateRange);
    final searchIconActive = searchExpanded || searchQuery.isNotEmpty;

    final appBarTitle = widget.title ?? 'Expenses';

    return Scaffold(
      backgroundColor: Colors.white,
      endDrawer: widget.showDrawer ? const ExpenseAppEndDrawer() : null,
      body: schemaAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: SelectableText('Schema: $e')),
        data: (schema) {
          final mq = MediaQuery.of(context);
          final bulkActionBottom = mq.viewPadding.bottom + 6;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    RefLayout.px5,
                    RefLayout.appBarTop,
                    RefLayout.px5,
                    RefLayout.pb4,
                  ),
                  child: selecting
                      ? Row(
                          children: [
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 40,
                                minHeight: 40,
                              ),
                              icon: const Icon(
                                Icons.close,
                                color: AppColors.slate400,
                                size: 26,
                              ),
                              onPressed: () => ref
                                  .read(
                                    expenseListSelectionModeProvider.notifier,
                                  )
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
                                  final vis = models.map((m) => m.id).toSet();
                                  return () {
                                    if (selectedIds.length == vis.length &&
                                        vis.isNotEmpty) {
                                      ref
                                          .read(
                                            expenseListSelectedIdsProvider
                                                .notifier,
                                          )
                                          .clear();
                                    } else {
                                      ref
                                          .read(
                                            expenseListSelectedIdsProvider
                                                .notifier,
                                          )
                                          .selectAll(vis);
                                    }
                                  };
                                },
                                orElse: () => null,
                              ),
                              child: Text(
                                listAsync.maybeWhen(
                                  data: (models) {
                                    final vis = models.map((m) => m.id).toSet();
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
                            if (widget.title != null)
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                  minWidth: 40,
                                  minHeight: 40,
                                ),
                                icon: const Icon(
                                  Icons.arrow_back,
                                  color: AppColors.slate400,
                                  size: 22,
                                ),
                                onPressed: () => context.pop(),
                              ),
                            if (widget.title != null) const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                appBarTitle,
                                style: refAppBarTitleLarge(),
                              ),
                            ),
                            if (widget.showDateRange) ...[
                              const ExpenseDateRangeCalendarButton(),
                              const SizedBox(width: 4),
                            ],
                            if (widget.showDrawer) const ExpenseAppMenuButton(),
                          ],
                        ),
                ),
              ),

              if (!selecting && widget.showDateRange)
                const ExpenseDateRangeBar(bottomPadding: 12),

              Padding(
                padding: const EdgeInsets.fromLTRB(
                  RefLayout.px5,
                  0,
                  RefLayout.px5,
                  4,
                ),
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
                                  fontSize: 14,
                                  color: AppColors.slate500,
                                ),
                              ),
                              error: (_, __) => const SizedBox.shrink(),
                            ),
                    ),
                    if (!selecting && widget.showSearch) ...[
                      GestureDetector(
                        onTap: () {
                          final next = !searchExpanded;
                          ref
                              .read(
                                expenseListSearchFieldExpandedProvider.notifier,
                              )
                              .setExpanded(next);
                          if (next) {
                            _searchController.text = ref.read(
                              expenseListSearchQueryProvider,
                            );
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
                    ],
                    if (!selecting && widget.showSelect) ...[
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
                            if (widget.showFilterIcon) ...[
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
                            ],
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

              if (!selecting && widget.showSearch && searchExpanded)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    RefLayout.px5,
                    0,
                    RefLayout.px5,
                    8,
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (v) => ref
                        .read(expenseListSearchQueryProvider.notifier)
                        .setQuery(v),
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: AppColors.slate900,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search transactions…',
                      hintStyle: GoogleFonts.inter(
                        fontSize: 14,
                        color: AppColors.slate400,
                      ),
                      prefixIcon: const Icon(
                        Icons.search,
                        size: 20,
                        color: AppColors.slate400,
                      ),
                      suffixIcon: IconButton(
                        icon: const Icon(
                          Icons.close,
                          size: 20,
                          color: AppColors.slate400,
                        ),
                        onPressed: _clearSearchField,
                      ),
                      filled: true,
                      fillColor: AppColors.slate100,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),

              if (widget.showActiveFilterChips && filterActive)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    RefLayout.px5,
                    0,
                    RefLayout.px5,
                    4,
                  ),
                  child: ActiveFilterChips(
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
                          .setFilter(
                            ExpenseFilter(
                              tagFilters: tags.isEmpty ? null : tags,
                              minAmount: effectiveFilter.minAmount,
                              maxAmount: effectiveFilter.maxAmount,
                              relationFilters: effectiveFilter.relationFilters,
                              relationFilterLabels:
                                  effectiveFilter.relationFilterLabels,
                            ),
                          );
                    },
                    onRemoveMinAmount: () {
                      ref
                          .read(expenseListFilterProvider.notifier)
                          .setFilter(
                            ExpenseFilter(
                              tagFilters: effectiveFilter.tagFilters,
                              maxAmount: effectiveFilter.maxAmount,
                              relationFilters: effectiveFilter.relationFilters,
                              relationFilterLabels:
                                  effectiveFilter.relationFilterLabels,
                            ),
                          );
                    },
                    onRemoveMaxAmount: () {
                      ref
                          .read(expenseListFilterProvider.notifier)
                          .setFilter(
                            ExpenseFilter(
                              tagFilters: effectiveFilter.tagFilters,
                              minAmount: effectiveFilter.minAmount,
                              relationFilters: effectiveFilter.relationFilters,
                              relationFilterLabels:
                                  effectiveFilter.relationFilterLabels,
                            ),
                          );
                    },
                    onRemoveRelation: (relType, modelId) {
                      final rels = Map<String, Set<int>>.from(
                        effectiveFilter.relationFilters ?? {},
                      );
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
                          .setFilter(
                            ExpenseFilter(
                              tagFilters: effectiveFilter.tagFilters,
                              minAmount: effectiveFilter.minAmount,
                              maxAmount: effectiveFilter.maxAmount,
                              relationFilters: rels.isEmpty ? null : rels,
                              relationFilterLabels: labels.isEmpty
                                  ? null
                                  : labels,
                            ),
                          );
                    },
                  ),
                ),

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
                            child: Text(
                              'Error: $e',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: AppColors.slate500,
                              ),
                            ),
                          ),
                          data: (models) {
                            if (models.isEmpty) {
                              return Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.receipt_long_outlined,
                                      size: 48,
                                      color: AppColors.slate300,
                                    ),
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
                            final bottomPad =
                                selecting && selectedIds.isNotEmpty
                                ? bulkActionBottom + 56
                                : RefLayout.pb24;
                            final showDailyTotals =
                                sortMode == ExpenseSortMode.dateAsc ||
                                sortMode == ExpenseSortMode.dateDesc;
                            final items = _buildDateGroupedItems(
                              models,
                              schema,
                              selectionMode: selecting,
                              selectedIds: selectedIds,
                              showDailyTotals: showDailyTotals,
                            );
                            return ListView.builder(
                              padding: EdgeInsets.fromLTRB(
                                RefLayout.px5,
                                8,
                                RefLayout.px5,
                                bottomPad,
                              ),
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
                              onTap: () =>
                                  showBulkApplyMenu(context, ref, schema),
                              borderRadius: BorderRadius.circular(16),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                  horizontal: 16,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.label_outline,
                                      color: Colors.white,
                                      size: 22,
                                    ),
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
    List<Expense> models,
    ModelTypeView schema, {
    required bool selectionMode,
    required Set<int> selectedIds,
    required bool showDailyTotals,
  }) {
    final items = <Widget>[];
    String? lastDate;

    final amountKey = schema.primaryNumberAttributeKey;
    final Map<String, num> dailyTotals = {};
    if (showDailyTotals && amountKey != null) {
      for (final m in models) {
        if (expenseIgnoredForTotals(m)) continue;
        final key = expenseDateCellLabel(m);
        dailyTotals[key] = (dailyTotals[key] ?? 0) + numAttr(m, amountKey);
      }
    }

    for (final m in models) {
      final dateStr = expenseDateCellLabel(m);
      if (dateStr != lastDate) {
        final dayTotal = dailyTotals[dateStr];
        items.add(
          Padding(
            padding: EdgeInsets.only(top: lastDate == null ? 4 : 12, bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Expanded(
                  child: Text(
                    dateStr,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
                      color: AppColors.slate400,
                    ),
                  ),
                ),
                if (dayTotal != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    formatMoney(dayTotal),
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                      color: AppColors.teal600,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
        lastDate = dateStr;
      }
      items.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: ExpenseCard(
            expense: m,
            schema: schema,
            selectionMode: selectionMode,
            selected: selectedIds.contains(m.id),
            onTap: () {
              if (selectionMode) {
                ref.read(expenseListSelectedIdsProvider.notifier).toggle(m.id);
              } else if (widget.onExpenseTap != null) {
                widget.onExpenseTap!(m.id);
              } else {
                navToExpenseDetail(context, ref, m.id);
              }
            },
          ),
        ),
      );
    }
    return items;
  }

  Future<void> _showFilterSheet(
    BuildContext context,
    WidgetRef ref,
    ModelTypeView schema,
  ) async {
    final currentFilter = ref.read(expenseListFilterProvider);

    final relationNames = allRelationTargetTypeNames(schema);
    final allRelModels = <String, List<RelatedModel>>{};
    try {
      for (final name in relationNames) {
        allRelModels[name] = await ref.read(relatedModelsProvider(name).future);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not load companies: $e')));
      }
      return;
    }

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FilterSheet(
        schema: schema,
        initial: currentFilter,
        allRelationModels: allRelModels,
        onApply: (ExpenseFilter? f) {
          ref
              .read(expenseListFilterProvider.notifier)
              .setFilter(f == null || f.isEmpty ? null : f);
        },
      ),
    );
  }

  void _showSortSheet(BuildContext context) {
    final currentSort = ref.read(expenseListSortProvider);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SortSheet(
        current: currentSort,
        onPick: (mode) {
          ref.read(expenseListSortProvider.notifier).setSort(mode);
          Navigator.pop(context);
        },
      ),
    );
  }
}
