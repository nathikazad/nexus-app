import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:nx_db/nx_db.dart';

import '../app_theme.dart';
import '../format.dart';
import '../providers/expense_providers.dart';
import '../reference_layout.dart';
import '../widgets/expense_card.dart';

class ExpenseListScreen extends ConsumerStatefulWidget {
  const ExpenseListScreen({super.key});

  @override
  ConsumerState<ExpenseListScreen> createState() => _ExpenseListScreenState();
}

class _ExpenseListScreenState extends ConsumerState<ExpenseListScreen> {
  static const _monthLabels = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  late int _selectedMonth;
  late int _selectedYear;
  bool _isCustomRange = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = now.month;
    _selectedYear = now.year;
    WidgetsBinding.instance.addPostFrameCallback((_) => _applyMonthRange());
  }

  void _applyMonthRange() {
    final start = DateTime(_selectedYear, _selectedMonth);
    final end = DateTime(_selectedYear, _selectedMonth + 1)
        .subtract(const Duration(days: 1));
    ref
        .read(expenseListDateRangeProvider.notifier)
        .setRange(DateTimeRange(start: start, end: end));
  }

  Future<void> _refresh() async {
    ref.invalidate(expenseSchemaProvider);
    ref.invalidate(expenseListForUiProvider);
    ref.invalidate(expenseListSummaryProvider);
  }

  @override
  Widget build(BuildContext context) {
    final schemaAsync = ref.watch(expenseSchemaProvider);
    final listAsync = ref.watch(expenseListForUiProvider);
    final summaryAsync = ref.watch(expenseListSummaryProvider);
    final filter = ref.watch(expenseListFilterProvider);
    final sortMode = ref.watch(expenseListSortProvider);
    final range = ref.watch(expenseListDateRangeProvider);

    final ExpenseFilter effectiveFilter = filter ?? const ExpenseFilter();
    final filterActive = filter != null && !effectiveFilter.isEmpty;
    final sortActive = sortMode != ExpenseSortMode.dateDesc;

    return Scaffold(
      backgroundColor: Colors.white,
      body: schemaAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: SelectableText('Schema: $e')),
        data: (schema) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // App bar
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                      RefLayout.px5, RefLayout.appBarTop, RefLayout.px5, RefLayout.pb4),
                  child: Row(
                    children: [
                      Expanded(
                          child:
                              Text('Expenses', style: refAppBarTitleLarge())),
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints:
                            const BoxConstraints(minWidth: 40, minHeight: 40),
                        icon: Icon(
                          Icons.calendar_today_outlined,
                          color: _isCustomRange
                              ? AppColors.teal600
                              : AppColors.slate400,
                          size: 22,
                        ),
                        onPressed: () async {
                          final now = DateTime.now();
                          final picked = await showDateRangePicker(
                            context: context,
                            firstDate: DateTime(now.year - 2),
                            lastDate: DateTime(now.year + 1),
                            initialDateRange: range ??
                                DateTimeRange(
                                  start:
                                      now.subtract(const Duration(days: 30)),
                                  end: now,
                                ),
                          );
                          if (picked != null) {
                            setState(() => _isCustomRange = true);
                            ref
                                .read(expenseListDateRangeProvider.notifier)
                                .setRange(picked);
                          }
                        },
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints:
                            const BoxConstraints(minWidth: 40, minHeight: 40),
                        icon: const Icon(Icons.settings_outlined,
                            color: AppColors.slate400, size: 22),
                        onPressed: () => context.push('/tag-systems'),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints:
                            const BoxConstraints(minWidth: 40, minHeight: 40),
                        icon: const Icon(Icons.logout,
                            color: AppColors.slate400, size: 22),
                        onPressed: () async {
                          await ref.read(authProvider.notifier).logout();
                          if (context.mounted) context.go('/login');
                        },
                      ),
                    ],
                  ),
                ),
              ),

              // Year + month selector
              Padding(
                padding: const EdgeInsets.fromLTRB(RefLayout.px5, 0, RefLayout.px5, 12),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () async {
                        final now = DateTime.now();
                        final years =
                            List.generate(5, (i) => now.year - 2 + i);
                        final picked = await showModalBottomSheet<int>(
                          context: context,
                          builder: (_) => SafeArea(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                for (final y in years)
                                  ListTile(
                                    title: Text('$y',
                                        style: GoogleFonts.inter(
                                            fontWeight: FontWeight.w600)),
                                    selected: y == _selectedYear,
                                    selectedColor: AppColors.teal600,
                                    onTap: () => Navigator.pop(context, y),
                                  ),
                              ],
                            ),
                          ),
                        );
                        if (picked != null && picked != _selectedYear) {
                          setState(() {
                            _selectedYear = picked;
                            _isCustomRange = false;
                          });
                          _applyMonthRange();
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: AppColors.slate100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '$_selectedYear',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.slate900,
                              ),
                            ),
                            const SizedBox(width: 2),
                            const Icon(Icons.keyboard_arrow_down,
                                size: 18, color: AppColors.slate500),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: SizedBox(
                        height: 40,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: 12,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 6),
                          itemBuilder: (context, i) {
                            final month = i + 1;
                            final isSelected =
                                !_isCustomRange && month == _selectedMonth;
                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedMonth = month;
                                  _isCustomRange = false;
                                });
                                _applyMonthRange();
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 7),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppColors.teal600
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isSelected
                                        ? AppColors.teal600
                                        : AppColors.slate200,
                                  ),
                                  boxShadow: isSelected
                                      ? [
                                          BoxShadow(
                                            color: AppColors.teal600
                                                .withValues(alpha: 0.3),
                                            blurRadius: 4,
                                            offset: const Offset(0, 1),
                                          )
                                        ]
                                      : null,
                                ),
                                child: Text(
                                  _monthLabels[i],
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: isSelected
                                        ? Colors.white
                                        : AppColors.slate600,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Summary line + filter/sort icons
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    RefLayout.px5, 0, RefLayout.px5, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: summaryAsync.when(
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
                    GestureDetector(
                      onTap: () => _showFilterSheet(context, schema),
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
                        sortActive ? Icons.sort : Icons.sort,
                        color: sortActive
                            ? AppColors.teal600
                            : AppColors.slate400,
                        size: 20,
                      ),
                    ),
                  ],
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
                          ));
                    },
                    onRemoveMinAmount: () {
                      ref
                          .read(expenseListFilterProvider.notifier)
                          .setFilter(ExpenseFilter(
                            tagFilters: effectiveFilter.tagFilters,
                            maxAmount: effectiveFilter.maxAmount,
                          ));
                    },
                    onRemoveMaxAmount: () {
                      ref
                          .read(expenseListFilterProvider.notifier)
                          .setFilter(ExpenseFilter(
                            tagFilters: effectiveFilter.tagFilters,
                            minAmount: effectiveFilter.minAmount,
                          ));
                    },
                  ),
                ),

              // Expense list with date section headers
              Expanded(
                child: ColoredBox(
                  color: AppColors.slate50.withValues(alpha: 0.5),
                  child: RefreshIndicator(
                    onRefresh: _refresh,
                    color: AppColors.teal600,
                    child: listAsync.when(
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (e, _) => Center(
                          child: Text('Error: $e',
                              style: GoogleFonts.inter(
                                  fontSize: 13, color: AppColors.slate500))),
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
                        // Build grouped list with date headers
                        final items = _buildDateGroupedItems(models, schema);
                        return ListView.builder(
                          padding: const EdgeInsets.fromLTRB(
                              RefLayout.px5, 8, RefLayout.px5, RefLayout.pb24),
                          itemCount: items.length,
                          itemBuilder: (context, i) => items[i],
                        );
                      },
                    ),
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
      List<Model> models, ModelType schema) {
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
          onTap: () => context.push('/expense/${m.id}'),
        ),
      ));
    }
    return items;
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

  void _showFilterSheet(BuildContext context, ModelType schema) {
    final currentFilter = ref.read(expenseListFilterProvider);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FilterSheet(
        schema: schema,
        initial: currentFilter,
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
  });

  final ExpenseFilter filter;
  final ModelType schema;
  final VoidCallback onClearAll;
  final void Function(int index) onRemoveTag;
  final VoidCallback onRemoveMinAmount;
  final VoidCallback onRemoveMaxAmount;

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
        color: const Color(0xFFF0FDFA), // teal-50
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF99F6E4)), // teal-200
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
    required this.onApply,
  });

  final ModelType schema;
  final ExpenseFilter? initial;
  final void Function(ExpenseFilter?) onApply;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  // Tag selections: system name → set of selected node names
  late Map<String, Set<String>> _tagSelections;
  final _minController = TextEditingController();
  final _maxController = TextEditingController();

  // Track which hierarchical systems have expanded root nodes
  final Map<String, Set<String>> _expandedNodes = {};

  @override
  void initState() {
    super.initState();
    _tagSelections = {};
    // Populate from existing filter
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
  }

  @override
  void dispose() {
    _minController.dispose();
    _maxController.dispose();
    super.dispose();
  }

  void _reset() {
    setState(() {
      _tagSelections.clear();
      _minController.clear();
      _maxController.clear();
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

    final filter = ExpenseFilter(
      tagFilters: tagFilters.isEmpty ? null : tagFilters,
      minAmount: minAmt,
      maxAmount: maxAmt,
    );

    widget.onApply(filter);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final tagSystems = widget.schema.tagSystems ?? const <TagSystem>[];

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
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
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
                      color: AppColors.slate400,
                    ),
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
                      color: AppColors.teal600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.slate100),
          // Scrollable content
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                for (var i = 0; i < tagSystems.length; i++) ...[
                  if (i > 0)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Divider(height: 1, color: AppColors.slate100),
                    ),
                  _buildTagSystemSection(tagSystems[i]),
                ],
                if (tagSystems.isNotEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Divider(height: 1, color: AppColors.slate100),
                  ),
                _buildAmountSection(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTagSystemSection(TagSystem ts) {
    final selected = _tagSelections[ts.name] ?? {};

    if (ts.isHierarchical) {
      return _buildHierarchicalSection(ts, selected);
    } else {
      return _buildFlatSection(ts, selected);
    }
  }

  // ─── Hierarchical tag system ───

  Widget _buildHierarchicalSection(TagSystem ts, Set<String> selected) {
    final expanded = _expandedNodes.putIfAbsent(ts.name, () => {});

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          ts.name.toUpperCase(),
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
            color: AppColors.slate400,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: const BoxDecoration(
            border: Border(left: BorderSide(color: AppColors.slate100, width: 2)),
          ),
          padding: const EdgeInsets.only(left: 12),
          child: Column(
            children: [
              for (final node in ts.nodes)
                _buildTreeNode(ts, node, selected, expanded, depth: 0),
            ],
          ),
        ),
      ],
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
              if (isExclusive) {
                // Exclusive: clear others in this system, toggle this one
                final sel = _tagSelections.putIfAbsent(ts.name, () => {});
                if (isSelected) {
                  sel.remove(node.name);
                } else {
                  sel.clear();
                  sel.add(node.name);
                }
              } else {
                final sel = _tagSelections.putIfAbsent(ts.name, () => {});
                if (isSelected) {
                  sel.remove(node.name);
                } else {
                  sel.add(node.name);
                }
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
              border:
                  Border(left: BorderSide(color: AppColors.slate100, width: 2)),
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

  // ─── Flat tag system ───

  Widget _buildFlatSection(TagSystem ts, Set<String> selected) {
    final isExclusive = ts.selectionMode == 'exclusive';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          ts.name.toUpperCase(),
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
            color: AppColors.slate400,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final node in ts.nodes)
              GestureDetector(
                onTap: () {
                  setState(() {
                    final sel =
                        _tagSelections.putIfAbsent(ts.name, () => {});
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
        ),
      ],
    );
  }

  // ─── Amount section ───

  Widget _buildAmountSection() {
    final fieldStyle = GoogleFonts.inter(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: AppColors.slate900,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'AMOUNT',
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
            color: AppColors.slate400,
          ),
        ),
        const SizedBox(height: 12),
        Row(
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
                        borderSide:
                            const BorderSide(color: AppColors.slate200),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: AppColors.slate200),
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
                        borderSide:
                            const BorderSide(color: AppColors.slate200),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: AppColors.slate200),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
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
