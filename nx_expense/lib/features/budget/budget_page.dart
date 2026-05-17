import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nx_db/goals.dart';
import 'package:nx_db/kgql.dart';

import 'package:nx_expense/core/layout/layout.dart';
import 'package:nx_expense/core/theme/app_theme.dart';
import 'package:nx_expense/data/providers.dart';
import 'package:nx_expense/domain/expense/expense_filter.dart';
import 'package:nx_expense/domain/schema/model_type_view.dart';
import 'package:nx_expense/features/expense/widgets/expense_card.dart';
import 'package:nx_expense/features/expense/widgets/expense_date_range_bar.dart';
import 'package:nx_expense/features/expense/widgets/tag_picker.dart';
import 'package:nx_expense/features/shell/expense_app_end_drawer.dart';

class _BudgetRowData {
  const _BudgetRowData({
    required this.id,
    required this.group,
    required this.name,
    required this.spent,
    required this.limit,
    required this.goal,
  });

  final int id;
  final String? group;
  final String name;
  final int spent;
  final int limit;
  final ExpenseGoalMonthItem goal;

  int get overBy => spent - limit;
  int get remaining => limit - spent;
  double get progress => limit <= 0 ? 0 : spent / limit;
  bool get isOver => spent > limit;

  factory _BudgetRowData.fromGoal(ExpenseGoalMonthItem item) {
    final parts = item.label.split('->');
    final group = parts.length > 1 ? parts.first.trim() : null;
    final name = parts.length > 1
        ? parts.sublist(1).join('->').trim()
        : item.label.trim();

    return _BudgetRowData(
      id: item.id,
      group: group == null || group.isEmpty ? null : group,
      name: name.isEmpty ? 'Budget' : name,
      spent: (item.periodValue ?? 0).abs().round(),
      limit: item.target.value.round(),
      goal: item,
    );
  }
}

String _monthLabel(DateTime value) {
  const names = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  return '${names[value.month - 1]} ${value.year}';
}

Map<String, dynamic>? _tagFilterForGoal(ExpenseGoalMonthItem goal) {
  final tagFilters = goal.filter?['tag_filters'];
  if (tagFilters is! List || tagFilters.isEmpty) return null;

  final tagFilter = tagFilters.first;
  if (tagFilter is! Map) return null;

  return Map<String, dynamic>.from(tagFilter);
}

ExpenseFilter _expenseFilterForGoal(ExpenseGoalMonthItem goal) {
  final tagFilter = _tagFilterForGoal(goal);
  if (tagFilter == null) return const ExpenseFilter();
  return ExpenseFilter(tagFilters: [tagFilter]);
}

String? _goalCategoryNode(ExpenseGoalMonthItem goal) {
  return _tagFilterForGoal(goal)?['node']?.toString();
}

SetModelRequest _goalSetModelRequest({
  int? id,
  required String label,
  required String categoryNode,
  required num amount,
}) {
  return SetModelRequest(
    id: id,
    modelType: id == null ? 'Goal' : null,
    name: label,
    attributes: [
      SetModelAttribute(key: 'label', value: label),
      SetModelAttribute(key: 'active', value: true),
      SetModelAttribute(key: 'cadence', value: 'monthly'),
      SetModelAttribute(key: 'model_type', value: 'Expense'),
      SetModelAttribute(
        key: 'filter',
        value: {
          'tag_filters': [
            {
              'system': 'Spending Category',
              'node': categoryNode,
              'include_descendants': true,
            },
          ],
        },
      ),
      SetModelAttribute(key: 'selected_attribute', value: 'date'),
      SetModelAttribute(key: 'aggregation', value: 'sum'),
      SetModelAttribute(key: 'metric', value: 'cost'),
      SetModelAttribute(key: 'threshold_op', value: '<='),
      SetModelAttribute(key: 'threshold_value', value: amount),
      SetModelAttribute(key: 'meta', value: null),
    ],
  );
}

List<_BudgetCategoryOption> _budgetCategoryOptions(ModelTypeView schema) {
  final system = tagSystemByName(schema, 'Spending Category');
  if (system == null) return const [];

  final out = <_BudgetCategoryOption>[];
  void walk(List<TagNodeView> nodes, List<String> path) {
    for (final node in nodes) {
      final nextPath = [...path, node.name];
      out.add(
        _BudgetCategoryOption(
          node: node.name,
          label: nextPath.join(' -> '),
          goalLabel: nextPath.length > 1
              ? '${nextPath.first} -> ${nextPath.last}'
              : nextPath.last,
        ),
      );
      final children = node.children;
      if (children != null && children.isNotEmpty) {
        walk(children, nextPath);
      }
    }
  }

  walk(system.nodes, const []);
  return out;
}

class _BudgetCategoryOption {
  const _BudgetCategoryOption({
    required this.node,
    required this.label,
    required this.goalLabel,
  });

  final String node;
  final String label;
  final String goalLabel;
}

class _BudgetHistoryPoint {
  const _BudgetHistoryPoint({
    required this.monthStart,
    required this.spent,
    required this.limit,
  });

  final DateTime monthStart;
  final int spent;
  final int limit;
}

final budgetGoalHistoryProvider =
    FutureProvider.family<
      List<_BudgetHistoryPoint>,
      ({int goalId, DateTime monthStart})
    >((ref, params) async {
      final client = ref.watch(expenseGraphqlClientProvider);
      final domainId = await ref.watch(expenseDomainIdProvider.future);
      final currentMonth = DateTime(
        params.monthStart.year,
        params.monthStart.month,
      );
      final months = [
        for (var i = 11; i >= 0; i--)
          DateTime(currentMonth.year, currentMonth.month - i),
      ];

      final out = <_BudgetHistoryPoint>[];
      for (final month in months) {
        final response = await fetchExpenseGoalsMonth(
          client,
          monthStart: month,
          domainId: domainId,
          goalId: params.goalId,
        );
        ExpenseGoalMonthItem? item;
        for (final goal in response.items) {
          if (goal.id == params.goalId) {
            item = goal;
            break;
          }
        }
        out.add(
          _BudgetHistoryPoint(
            monthStart: month,
            spent: ((item?.periodValue ?? 0).abs()).round(),
            limit: (item?.target.value ?? 0).round(),
          ),
        );
      }
      return out;
    });

final budgetAllGoalsHistoryProvider =
    FutureProvider.family<List<_BudgetHistoryPoint>, DateTime>((
      ref,
      monthStart,
    ) async {
      final client = ref.watch(expenseGraphqlClientProvider);
      final domainId = await ref.watch(expenseDomainIdProvider.future);
      final currentMonth = DateTime(monthStart.year, monthStart.month);
      final months = [
        for (var i = 11; i >= 0; i--)
          DateTime(currentMonth.year, currentMonth.month - i),
      ];

      final out = <_BudgetHistoryPoint>[];
      for (final month in months) {
        final response = await fetchExpenseGoalsMonth(
          client,
          monthStart: month,
          domainId: domainId,
        );
        final spent = response.items.fold<int>(
          0,
          (sum, item) => sum + ((item.periodValue ?? 0).abs()).round(),
        );
        final limit = response.items.fold<int>(
          0,
          (sum, item) => sum + item.target.value.round(),
        );
        out.add(
          _BudgetHistoryPoint(monthStart: month, spent: spent, limit: limit),
        );
      }
      return out;
    });

Future<void> _saveBudgetGoal(
  WidgetRef ref, {
  int? id,
  required String label,
  required String categoryNode,
  required num amount,
}) async {
  final client = ref.read(expenseGraphqlClientProvider);
  final domainId = await ref.read(expenseDomainIdProvider.future);
  await setKgqlModel(
    client,
    _goalSetModelRequest(
      id: id,
      label: label,
      categoryNode: categoryNode,
      amount: amount,
    ),
    domainId: domainId,
    auditSourceKind: 'nx_expense_budget',
  );
  ref.invalidate(budgetExpenseGoalsMonthProvider);
}

Future<void> _deleteBudgetGoal(WidgetRef ref, int id) async {
  final client = ref.read(expenseGraphqlClientProvider);
  final domainId = await ref.read(expenseDomainIdProvider.future);
  await setKgqlModel(
    client,
    SetModelRequest(id: id, delete: true),
    domainId: domainId,
    auditSourceKind: 'nx_expense_budget',
  );
  ref.invalidate(budgetExpenseGoalsMonthProvider);
}

Future<void> _showBudgetGoalSheet(
  BuildContext context,
  WidgetRef ref, {
  _BudgetRowData? row,
}) async {
  final schema = await ref.read(expenseSchemaViewProvider.future);
  if (!context.mounted) return;

  final result = await showModalBottomSheet<_BudgetGoalSheetResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) => _BudgetGoalSheet(schema: schema, row: row),
  );
  if (result == _BudgetGoalSheetResult.deleted &&
      row != null &&
      context.mounted &&
      context.canPop()) {
    context.pop();
  }
}

enum _BudgetGoalSheetResult { saved, deleted }

class BudgetScreen extends ConsumerWidget {
  const BudgetScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goals = ref.watch(budgetExpenseGoalsMonthProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
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
              child: Row(
                children: [
                  Expanded(child: Text('Budget', style: refAppBarTitleLarge())),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 40,
                      minHeight: 40,
                    ),
                    icon: const Icon(
                      Icons.add_circle_outline,
                      color: AppColors.teal600,
                      size: 24,
                    ),
                    onPressed: () => _showBudgetGoalSheet(context, ref),
                  ),
                  const ExpenseAppMenuButton(),
                ],
              ),
            ),
          ),
          const ExpenseDateRangeBar(bottomPadding: 12),
          Expanded(
            child: ColoredBox(
              color: AppColors.slate50,
              child: goals.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                error: (error, _) => _BudgetError(error: error),
                data: (month) => _BudgetContent(month: month),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BudgetContent extends ConsumerWidget {
  const _BudgetContent({required this.month});

  final ExpenseGoalMonthResponse month;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = month.items.map(_BudgetRowData.fromGoal).toList();
    rows.sort((a, b) {
      final groupCompare = (a.group ?? '~').compareTo(b.group ?? '~');
      if (groupCompare != 0) return groupCompare;
      return a.name.compareTo(b.name);
    });

    final totalSpent = rows.fold<int>(0, (sum, r) => sum + r.spent);
    final totalLimit = rows.fold<int>(0, (sum, r) => sum + r.limit);
    final overCount = rows.where((r) => r.isOver).length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        RefLayout.px5,
        10,
        RefLayout.px5,
        RefLayout.pb24,
      ),
      children: [
        _BudgetSummary(
          monthStart: month.monthStart,
          spent: totalSpent,
          limit: totalLimit,
          overCount: overCount,
        ),
        const SizedBox(height: 18),
        Text(
          'Categories',
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
            color: AppColors.slate400,
          ),
        ),
        const SizedBox(height: 8),
        if (rows.isEmpty)
          const _BudgetEmpty()
        else
          for (var i = 0; i < rows.length; i++) ...[
            _BudgetRow(
              row: rows[i],
              onTap: () => context.push('/budget/detail/${rows[i].id}'),
            ),
            if (i != rows.length - 1) const SizedBox(height: 10),
          ],
      ],
    );
  }
}

class BudgetDetailScreen extends ConsumerWidget {
  const BudgetDetailScreen({super.key, required this.goalId});

  final int goalId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goals = ref.watch(budgetExpenseGoalsMonthProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
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
              child: Row(
                children: [
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(
                      Icons.arrow_back,
                      color: AppColors.slate500,
                    ),
                    onPressed: () => context.pop(),
                  ),
                  Expanded(child: Text('Budget', style: refAppBarTitleLarge())),
                  goals.maybeWhen(
                    data: (month) {
                      for (final item in month.items) {
                        if (item.id == goalId) {
                          final row = _BudgetRowData.fromGoal(item);
                          return IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 40,
                              minHeight: 40,
                            ),
                            icon: const Icon(
                              Icons.edit_outlined,
                              color: AppColors.slate500,
                              size: 22,
                            ),
                            onPressed: () =>
                                _showBudgetGoalSheet(context, ref, row: row),
                          );
                        }
                      }
                      return const SizedBox(width: 40);
                    },
                    orElse: () => const SizedBox(width: 40),
                  ),
                ],
              ),
            ),
          ),
          const ExpenseDateRangeBar(bottomPadding: 12),
          Expanded(
            child: ColoredBox(
              color: AppColors.slate50,
              child: goals.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                error: (error, _) => _BudgetError(error: error),
                data: (month) {
                  ExpenseGoalMonthItem? goal;
                  for (final item in month.items) {
                    if (item.id == goalId) {
                      goal = item;
                      break;
                    }
                  }
                  if (goal == null) return const _BudgetDetailMissing();
                  return _BudgetDetailContent(
                    row: _BudgetRowData.fromGoal(goal),
                    monthStart: month.monthStart,
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BudgetSummary extends ConsumerStatefulWidget {
  const _BudgetSummary({
    required this.monthStart,
    required this.spent,
    required this.limit,
    required this.overCount,
  });

  final DateTime monthStart;
  final int spent;
  final int limit;
  final int overCount;

  @override
  ConsumerState<_BudgetSummary> createState() => _BudgetSummaryState();
}

class _BudgetSummaryState extends ConsumerState<_BudgetSummary> {
  bool _showChart = false;

  @override
  Widget build(BuildContext context) {
    final over = widget.spent - widget.limit;
    final isOver = over > 0;
    final historyAsync = ref.watch(
      budgetAllGoalsHistoryProvider(widget.monthStart),
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.teal600,
        borderRadius: BorderRadius.circular(RefLayout.rounded2xl),
        border: Border.all(color: AppColors.teal700),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${_monthLabel(widget.monthStart)} budget',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                    color: AppColors.teal100,
                  ),
                ),
              ),
              IconButton(
                tooltip: _showChart ? 'Summary' : 'History',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                onPressed: () => setState(() => _showChart = !_showChart),
                icon: Icon(
                  _showChart
                      ? Icons.view_agenda_outlined
                      : Icons.bar_chart_rounded,
                  size: 20,
                  color: AppColors.teal100,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_showChart)
            historyAsync.when(
              loading: () => const SizedBox(
                height: 168,
                child: Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
              ),
              error: (_, __) => Text(
                'Could not load history.',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.teal100,
                ),
              ),
              data: (points) =>
                  _BudgetHistoryChart(points: points, onDark: true),
            )
          else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '\$${widget.spent}',
                  style: GoogleFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.5,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Text(
                    'of \$${widget.limit}',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.teal100,
                    ),
                  ),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Text(
                    isOver
                        ? '+\$$over'
                        : '\$${widget.limit - widget.spent} left',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isOver ? AppColors.red100 : AppColors.teal100,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _BudgetProgressBar(
              progress: widget.limit <= 0 ? 0 : widget.spent / widget.limit,
              color: isOver ? AppColors.red100 : Colors.white,
              backgroundColor: AppColors.teal700,
              height: 7,
            ),
          ],
        ],
      ),
    );
  }
}

class _BudgetRow extends StatelessWidget {
  const _BudgetRow({required this.row, required this.onTap});

  final _BudgetRowData row;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = row.isOver ? AppColors.red600 : AppColors.teal600;
    final background = row.isOver ? AppColors.red50 : AppColors.slate100;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(RefLayout.rounded2xl),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(RefLayout.rounded2xl),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(RefLayout.rounded2xl),
            border: Border.all(color: AppColors.slate100),
            boxShadow: refCardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          row.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.slate900,
                          ),
                        ),
                        if (row.group != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            row.group!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: AppColors.slate500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '\$${row.spent}/\$${row.limit}',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.slate900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        row.isOver
                            ? '+\$${row.overBy}'
                            : '\$${row.remaining} left',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: row.isOver
                              ? AppColors.red600
                              : AppColors.slate500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _BudgetProgressBar(
                progress: row.progress,
                color: color,
                backgroundColor: background,
                height: 7,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BudgetDetailContent extends ConsumerStatefulWidget {
  const _BudgetDetailContent({required this.row, required this.monthStart});

  final _BudgetRowData row;
  final DateTime monthStart;

  @override
  ConsumerState<_BudgetDetailContent> createState() =>
      _BudgetDetailContentState();
}

class _BudgetDetailContentState extends ConsumerState<_BudgetDetailContent> {
  late DateTimeRange _range;
  late ExpenseFilter _filter;
  bool _showChart = false;

  @override
  void initState() {
    super.initState();
    _syncProviderParams();
  }

  @override
  void didUpdateWidget(covariant _BudgetDetailContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.row.id != widget.row.id ||
        oldWidget.monthStart != widget.monthStart) {
      _syncProviderParams();
    }
  }

  void _syncProviderParams() {
    _range = DateTimeRange(
      start: widget.monthStart,
      end: DateTime(
        widget.monthStart.year,
        widget.monthStart.month + 1,
      ).subtract(const Duration(days: 1)),
    );
    _filter = _expenseFilterForGoal(widget.row.goal);
  }

  @override
  Widget build(BuildContext context) {
    final row = widget.row;
    final color = row.isOver ? AppColors.red600 : AppColors.teal600;
    final schemaAsync = ref.watch(expenseSchemaViewProvider);
    final expensesAsync = ref.watch(
      expenseListProvider((filter: _filter, dateRange: _range)),
    );
    final historyAsync = ref.watch(
      budgetGoalHistoryProvider((
        goalId: row.id,
        monthStart: widget.monthStart,
      )),
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        RefLayout.px5,
        10,
        RefLayout.px5,
        RefLayout.pb24,
      ),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(RefLayout.rounded2xl),
            border: Border.all(color: AppColors.slate100),
            boxShadow: refCardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (row.group != null) ...[
                          Text(
                            row.group!,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.slate500,
                            ),
                          ),
                          const SizedBox(height: 4),
                        ],
                        Text(
                          row.name,
                          style: GoogleFonts.inter(
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                            color: AppColors.slate900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: _showChart ? 'Summary' : 'History',
                    onPressed: () => setState(() => _showChart = !_showChart),
                    icon: Icon(
                      _showChart
                          ? Icons.view_agenda_outlined
                          : Icons.bar_chart_rounded,
                      color: _showChart
                          ? AppColors.teal600
                          : AppColors.slate500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_showChart)
                historyAsync.when(
                  loading: () => const SizedBox(
                    height: 168,
                    child: Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                  error: (error, _) => _BudgetEmptyMessage(
                    text: 'Could not load history.\n$error',
                  ),
                  data: (points) => _BudgetHistoryChart(points: points),
                )
              else ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '\$${row.spent}',
                      style: GoogleFonts.inter(
                        fontSize: 28,
                        fontWeight: FontWeight.w600,
                        color: AppColors.slate900,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 5),
                      child: Text(
                        'of \$${row.limit}',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.slate500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _BudgetProgressBar(
                  progress: row.progress,
                  color: color,
                  backgroundColor: row.isOver
                      ? AppColors.red50
                      : AppColors.slate100,
                  height: 8,
                ),
                const SizedBox(height: 16),
                _BudgetDetailStat(
                  label: row.isOver ? 'Over budget' : 'Remaining',
                  value: row.isOver ? '+\$${row.overBy}' : '\$${row.remaining}',
                  color: row.isOver ? AppColors.red600 : AppColors.teal600,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Expenses',
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
            color: AppColors.slate400,
          ),
        ),
        const SizedBox(height: 8),
        schemaAsync.when(
          loading: () => const _BudgetInlineLoading(),
          error: (error, _) => _BudgetInlineError(error: error),
          data: (schema) => expensesAsync.when(
            loading: () => const _BudgetInlineLoading(),
            error: (error, _) => _BudgetInlineError(error: error),
            data: (expenses) {
              if (expenses.isEmpty) {
                return const _BudgetEmptyMessage(
                  text: 'No expenses for this budget.',
                );
              }
              return Column(
                children: [
                  for (var i = 0; i < expenses.length; i++) ...[
                    ExpenseCard(
                      expense: expenses[i],
                      schema: schema,
                      onTap: () => context.push('/expense/${expenses[i].id}'),
                    ),
                    if (i != expenses.length - 1) const SizedBox(height: 10),
                  ],
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _BudgetDetailStat extends StatelessWidget {
  const _BudgetDetailStat({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.slate50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.slate500,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _BudgetHistoryChart extends StatelessWidget {
  const _BudgetHistoryChart({required this.points, this.onDark = false});

  final List<_BudgetHistoryPoint> points;
  final bool onDark;

  static const _monthLabels = [
    'J',
    'F',
    'M',
    'A',
    'M',
    'J',
    'J',
    'A',
    'S',
    'O',
    'N',
    'D',
  ];

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) return const SizedBox(height: 168);

    final maxSpent = points
        .map((p) => p.spent)
        .fold<int>(0, (a, b) => a > b ? a : b);
    final maxLimit = points
        .map((p) => p.limit)
        .fold<int>(0, (a, b) => a > b ? a : b);
    final maxY = (maxSpent > maxLimit ? maxSpent : maxLimit).toDouble();
    final chartMaxY = maxY <= 0 ? 1.0 : maxY * 1.18;
    final labelIndices = <int>{0, points.length ~/ 2, points.length - 1};
    final labelColor = onDark ? AppColors.teal100 : AppColors.slate400;
    final gridColor = onDark
        ? AppColors.teal700.withValues(alpha: 0.55)
        : AppColors.slate100;
    final limitColor = onDark
        ? AppColors.teal100.withValues(alpha: 0.5)
        : AppColors.slate300;

    return SizedBox(
      height: 168,
      child: BarChart(
        BarChartData(
          maxY: chartMaxY,
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              tooltipBorderRadius: BorderRadius.circular(10),
              tooltipPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              getTooltipColor: (_) => AppColors.slate900,
              getTooltipItem: (group, _, rod, __) {
                final i = group.x;
                if (i < 0 || i >= points.length) return null;
                final p = points[i];
                return BarTooltipItem(
                  '${_monthLabel(p.monthStart)}\n',
                  GoogleFonts.inter(
                    fontSize: 11,
                    color: AppColors.slate300,
                    fontWeight: FontWeight.w500,
                  ),
                  children: [
                    TextSpan(
                      text: '\$${p.spent} of \$${p.limit}',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          barGroups: [
            for (var i = 0; i < points.length; i++)
              BarChartGroupData(
                x: i,
                barsSpace: 3,
                barRods: [
                  BarChartRodData(
                    toY: points[i].spent.toDouble(),
                    color: points[i].spent > points[i].limit
                        ? AppColors.red600
                        : onDark
                        ? Colors.white
                        : AppColors.teal600,
                    width: 7,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(2),
                    ),
                  ),
                  BarChartRodData(
                    toY: points[i].limit.toDouble(),
                    color: limitColor,
                    width: 3,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(2),
                    ),
                  ),
                ],
              ),
          ],
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                getTitlesWidget: (v, _) {
                  final i = v.toInt();
                  if (!labelIndices.contains(i) ||
                      i < 0 ||
                      i >= points.length) {
                    return const SizedBox.shrink();
                  }
                  final month = points[i].monthStart.month;
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      _monthLabels[month - 1],
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: labelColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );
                },
              ),
            ),
            leftTitles: const AxisTitles(),
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: chartMaxY / 4,
            getDrawingHorizontalLine: (_) =>
                FlLine(color: gridColor, strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
        ),
      ),
    );
  }
}

class _BudgetInlineLoading extends StatelessWidget {
  const _BudgetInlineLoading();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 28),
      child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
    );
  }
}

class _BudgetInlineError extends StatelessWidget {
  const _BudgetInlineError({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return _BudgetEmptyMessage(text: 'Could not load expenses.\n$error');
  }
}

class _BudgetEmptyMessage extends StatelessWidget {
  const _BudgetEmptyMessage({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(RefLayout.rounded2xl),
        border: Border.all(color: AppColors.slate100),
        boxShadow: refCardShadow,
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: AppColors.slate500,
        ),
      ),
    );
  }
}

class _BudgetGoalSheet extends ConsumerStatefulWidget {
  const _BudgetGoalSheet({required this.schema, this.row});

  final ModelTypeView schema;
  final _BudgetRowData? row;

  @override
  ConsumerState<_BudgetGoalSheet> createState() => _BudgetGoalSheetState();
}

class _BudgetGoalSheetState extends ConsumerState<_BudgetGoalSheet> {
  late final TextEditingController _amountController;
  late List<_BudgetCategoryOption> _options;
  late final TagSystemView? _categorySystem;
  String? _selectedNode;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _categorySystem = tagSystemByName(widget.schema, 'Spending Category');
    _options = _budgetCategoryOptions(widget.schema);
    _selectedNode = widget.row == null
        ? null
        : _goalCategoryNode(widget.row!.goal);
    _selectedNode ??= _options.isEmpty ? null : _options.first.node;
    _amountController = TextEditingController(
      text: widget.row == null ? '' : widget.row!.limit.toString(),
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final selected = _selectedOption;
    final amount = num.tryParse(_amountController.text.trim());
    if (selected == null || amount == null || amount <= 0) return;

    setState(() => _saving = true);
    try {
      await _saveBudgetGoal(
        ref,
        id: widget.row?.id,
        label: selected.goalLabel,
        categoryNode: selected.node,
        amount: amount.round(),
      );
      if (mounted) Navigator.pop(context, _BudgetGoalSheetResult.saved);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  _BudgetCategoryOption? get _selectedOption {
    final node = _selectedNode;
    if (node == null) return null;
    for (final option in _options) {
      if (option.node == node) return option;
    }
    return null;
  }

  Future<void> _delete() async {
    final row = widget.row;
    if (row == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete budget?'),
        content: Text(row.name),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _saving = true);
    try {
      await _deleteBudgetGoal(ref, row.id);
      if (mounted) {
        Navigator.pop(context, _BudgetGoalSheetResult.deleted);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.of(context).viewInsets.bottom;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          RefLayout.px5,
          18,
          RefLayout.px5,
          inset + 18,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.row == null ? 'Add budget' : 'Edit budget',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.slate900,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _saving ? null : () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: AppColors.slate500),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text('Category', style: refSectionTitle(context)),
            const SizedBox(height: 8),
            if (_categorySystem == null)
              const _BudgetEmptyMessage(text: 'No Spending Category system.')
            else
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(RefLayout.rounded2xl),
                  border: Border.all(color: AppColors.slate100),
                  boxShadow: refCardShadow,
                ),
                child: TagPickerRow(
                  system: _categorySystem,
                  value: _selectedNode == null ? const [] : [_selectedNode!],
                  onChanged: _saving
                      ? (_) {}
                      : (value) {
                          setState(() {
                            _selectedNode = value.isEmpty ? null : value.first;
                          });
                        },
                ),
              ),
            const SizedBox(height: 12),
            TextField(
              controller: _amountController,
              enabled: !_saving,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: false,
              ),
              decoration: const InputDecoration(
                labelText: 'Amount',
                prefixText: '\$',
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                if (widget.row != null)
                  TextButton.icon(
                    onPressed: _saving ? null : _delete,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Delete'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.red600,
                    ),
                  ),
                const Spacer(),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.teal600,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(_saving ? 'Saving' : 'Save'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BudgetEmpty extends StatelessWidget {
  const _BudgetEmpty();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(RefLayout.rounded2xl),
        border: Border.all(color: AppColors.slate100),
        boxShadow: refCardShadow,
      ),
      child: Text(
        'No budget goals for this month.',
        style: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: AppColors.slate500,
        ),
      ),
    );
  }
}

class _BudgetDetailMissing extends StatelessWidget {
  const _BudgetDetailMissing();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'Budget goal not found.',
        style: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: AppColors.slate500,
        ),
      ),
    );
  }
}

class _BudgetError extends StatelessWidget {
  const _BudgetError({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(RefLayout.px5),
        child: Text(
          'Could not load budget goals.\n$error',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppColors.red600,
          ),
        ),
      ),
    );
  }
}

class _BudgetProgressBar extends StatelessWidget {
  const _BudgetProgressBar({
    required this.progress,
    required this.color,
    required this.backgroundColor,
    required this.height,
  });

  final double progress;
  final Color color;
  final Color backgroundColor;
  final double height;

  @override
  Widget build(BuildContext context) {
    final value = progress.clamp(0, 1).toDouble();
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: [
            Container(
              height: height,
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: constraints.maxWidth * value,
              height: height,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ],
        );
      },
    );
  }
}
