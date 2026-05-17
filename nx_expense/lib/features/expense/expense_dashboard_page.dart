import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nx_expense/core/formatting/format.dart';
import 'package:nx_expense/core/layout/layout.dart';
import 'package:nx_expense/core/theme/app_theme.dart';
import 'package:nx_expense/core/widgets/stat_card.dart';
import 'package:nx_expense/data/providers.dart';
import 'package:nx_expense/data/schema/kgql_schema_helpers.dart';
import 'package:nx_expense/domain/schema/model_type_view.dart';
import 'package:nx_expense/features/expense/expense_dashboard_view_model.dart';
import 'package:nx_expense/features/expense/expense_stats_dashboard_config.dart';
import 'package:nx_expense/features/shell/expense_app_end_drawer.dart';
import 'widgets/expense_date_range_bar.dart';

const _uncategorizedTagNode = 'Uncategorized';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schemaAsync = ref.watch(expenseSchemaViewProvider);
    final summaryAsync = ref.watch(dashboardExpenseSummaryProvider);
    final dayAsync = ref.watch(spendByDayProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      endDrawer: const ExpenseAppEndDrawer(),
      body: schemaAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (schema) {
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
                  child: Row(
                    children: [
                      Expanded(
                        child: Text('Stats', style: refAppBarTitleLarge()),
                      ),
                      const ExpenseDateRangeCalendarButton(),
                      const SizedBox(width: 4),
                      const ExpenseAppMenuButton(),
                    ],
                  ),
                ),
              ),
              const ExpenseDateRangeBar(),
              Expanded(
                child: summaryAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('$e')),
                  data: (s) {
                    // No data — show empty state
                    if (s.count == 0) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
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
                            const SizedBox(height: 4),
                            Text(
                              'Add some expenses to see your dashboard',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: AppColors.slate400,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    // Has data — show stats + charts
                    return ListView(
                      padding: const EdgeInsets.fromLTRB(
                        RefLayout.px5,
                        8,
                        RefLayout.px5,
                        RefLayout.pb24,
                      ),
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: StatCard(
                                title: 'Count',
                                value: '${s.count}',
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: StatCard(
                                title: 'Total',
                                value: s.sumTotal != null
                                    ? formatMoney(s.sumTotal)
                                    : '—',
                                highlight: true,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        dayAsync.when(
                          data: (raw) {
                            final entries = parseDaySpendEntries(raw);
                            if (entries.isEmpty) return const SizedBox.shrink();
                            return SizedBox(
                              height: 240,
                              child: _DayBarChart(entries: entries),
                            );
                          },
                          loading: () => const SizedBox(
                            height: 240,
                            child: Center(child: CircularProgressIndicator()),
                          ),
                          error: (_, __) => const SizedBox.shrink(),
                        ),
                        const SizedBox(height: 24),
                        for (final ts in schema.tagSystems.where(
                          (t) => statsDashboardTagSystemNames.contains(t.name),
                        )) ...[
                          _TagPieChart(tagSystem: ts),
                          const SizedBox(height: 24),
                        ],
                        for (final relName in allRelationTargetTypeNames(
                          schema,
                        ).where(statsDashboardRelationTypeNames.contains)) ...[
                          Consumer(
                            builder: (context, ref, _) {
                              final agg = ref.watch(
                                spendByRelationProvider(relName),
                              );
                              return agg.when(
                                data: (raw) {
                                  final entries = appendOtherResidualEntry(
                                    parseGroupedChartEntries(raw),
                                    s.sumTotal,
                                  );
                                  if (entries.isEmpty) {
                                    return const SizedBox.shrink();
                                  }
                                  final relatedModels = ref.watch(
                                    relatedModelsProvider(relName),
                                  );
                                  final relationIdsByName = relatedModels
                                      .maybeWhen(
                                        data: (models) => {
                                          for (final model in models)
                                            model.name: model.id,
                                        },
                                        orElse: () => const <String, int>{},
                                      );
                                  return _PieChartCard(
                                    title: relName,
                                    entries: entries,
                                    onSliceTap: relationIdsByName.isNotEmpty
                                        ? (sliceName) {
                                            final relId =
                                                relationIdsByName[sliceName];
                                            if (relId == null) return;
                                            _openExpensesForRelation(
                                              context,
                                              ref,
                                              relName: relName,
                                              relId: relId,
                                              displayName: sliceName,
                                            );
                                          }
                                        : null,
                                    sliceIsActionable: (sliceName) =>
                                        relationIdsByName.containsKey(
                                          sliceName,
                                        ),
                                  );
                                },
                                loading: () => const SizedBox(
                                  height: 180,
                                  child: Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                ),
                                error: (_, __) => const SizedBox.shrink(),
                              );
                            },
                          ),
                          const SizedBox(height: 24),
                        ],
                      ],
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

String _dateOnly(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';

String _dateRangeQuery(DateTimeRange range) =>
    'start=${Uri.encodeQueryComponent(_dateOnly(range.start))}'
    '&end=${Uri.encodeQueryComponent(_dateOnly(range.end))}';

void _openExpensesForRelation(
  BuildContext context,
  WidgetRef ref, {
  required String relName,
  required int relId,
  required String displayName,
}) {
  final range = ref.read(expenseDateRangeProvider);
  context.push(
    '/expenses/by-relation/${Uri.encodeComponent(relName)}/$relId/'
    '${Uri.encodeComponent(displayName)}?${_dateRangeQuery(range)}',
  );
}

/// Drill-down pie chart for tag systems.
/// For hierarchical systems: starts at root level, tap a slice to drill into
/// its children. Breadcrumb trail shows path; tap to go back.
/// For flat systems: just shows the pie chart with no drill-down.
class _TagPieChart extends ConsumerStatefulWidget {
  const _TagPieChart({required this.tagSystem});
  final TagSystemView tagSystem;

  @override
  ConsumerState<_TagPieChart> createState() => _TagPieChartState();
}

class _TagPieChartState extends ConsumerState<_TagPieChart> {
  /// Stack of drilled-into node names. Empty = root level.
  final List<String> _breadcrumbs = [];

  TagNodeView? _findNode(String nodeName) {
    TagNodeView? find(List<TagNodeView> nodes) {
      for (final n in nodes) {
        if (n.name == nodeName) return n;
        if (n.children != null) {
          final r = find(n.children!);
          if (r != null) return r;
        }
      }
      return null;
    }

    return find(widget.tagSystem.nodes);
  }

  /// Check if a node name has children in the tag system tree.
  bool _hasChildren(String nodeName) {
    final node = _findNode(nodeName);
    return node?.children != null && node!.children!.isNotEmpty;
  }

  void _openExpensesForTag(
    String tagNode, {
    bool includeDescendants = true,
    String? title,
  }) {
    final range = ref.read(expenseDateRangeProvider);
    final query = [
      _dateRangeQuery(range),
      if (!includeDescendants) 'includeDescendants=false',
      if (title != null) 'title=${Uri.encodeQueryComponent(title)}',
    ].join('&');
    context.push(
      '/expenses/by-tag/${Uri.encodeComponent(widget.tagSystem.name)}/'
      '${Uri.encodeComponent(tagNode)}?$query',
    );
  }

  void _handleSliceTap(String sliceName) {
    final parentNode = _breadcrumbs.isNotEmpty ? _breadcrumbs.last : null;
    if (sliceName == _uncategorizedTagNode) {
      if (parentNode == null) {
        _openExpensesForTag(_uncategorizedTagNode);
      } else {
        _openExpensesForTag(
          parentNode,
          includeDescendants: false,
          title: _uncategorizedTagNode,
        );
      }
      return;
    }

    final node = _findNode(sliceName);
    if (node == null) return;
    if (_hasChildren(sliceName)) {
      setState(() => _breadcrumbs.add(sliceName));
      return;
    }
    _openExpensesForTag(node.name);
  }

  @override
  Widget build(BuildContext context) {
    final ts = widget.tagSystem;
    final isHierarchical = ts.isHierarchical;
    final parentNode = _breadcrumbs.isNotEmpty ? _breadcrumbs.last : null;

    final agg = ref.watch(
      spendByTagSystemProvider((
        systemName: ts.name,
        parentNode: parentNode,
        level: null,
      )),
    );

    return agg.when(
      data: (raw) {
        var entries = parseGroupedChartEntries(raw);

        if (entries.isEmpty) return const SizedBox.shrink();

        // Build title with breadcrumbs
        final titleParts = [ts.name, ..._breadcrumbs];
        final title = titleParts.join(' › ');

        return _PieChartCard(
          title: title,
          entries: entries,
          onSliceTap: isHierarchical
              ? (sliceName) => _handleSliceTap(sliceName)
              : null,
          sliceIsActionable: isHierarchical
              ? (sliceName) =>
                    sliceName == _uncategorizedTagNode ||
                    _findNode(sliceName) != null
              : null,
          headerTrailing: isHierarchical && _breadcrumbs.isNotEmpty
              ? GestureDetector(
                  onTap: () => setState(() => _breadcrumbs.removeLast()),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: AppColors.slate100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.arrow_back,
                        size: 16,
                        color: AppColors.slate500,
                      ),
                    ),
                  ),
                )
              : null,
        );
      },
      loading: () => const SizedBox(
        height: 180,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

/// Pie chart with circle on left + legend rows on right, matching the HTML reference.
class _PieChartCard extends StatefulWidget {
  const _PieChartCard({
    required this.title,
    required this.entries,
    this.headerTrailing,
    this.onSliceTap,
    this.sliceIsActionable,
  });

  final String title;
  final List<MapEntry<String, double>> entries;
  final Widget? headerTrailing;

  /// Called when a legend row / pie slice is tapped (for drill-down).
  final void Function(String sliceName)? onSliceTap;

  /// Allows callers to suppress tap affordances for synthetic slices like "Other".
  final bool Function(String sliceName)? sliceIsActionable;

  @override
  State<_PieChartCard> createState() => _PieChartCardState();
}

class _PieChartCardState extends State<_PieChartCard> {
  static const _palette = [
    AppColors.teal700,
    AppColors.teal500,
    Color(0xFF5EEAD4),
    AppColors.teal100,
    AppColors.slate400,
  ];

  /// When true, legend shows dollar amounts; when false, percentages.
  bool _showDollars = true;

  @override
  Widget build(BuildContext context) {
    final entries = [...widget.entries]
      ..sort((a, b) => b.value.abs().compareTo(a.value.abs()));
    // Pie sections must be positive; amounts are signed (expenses negative, refunds positive).
    final totalAbs = entries.fold<double>(0, (a, b) => a + b.value.abs());
    if (totalAbs <= 0) return const SizedBox.shrink();
    final showPie = entries.length <= 7;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(RefLayout.rounded3xl),
        border: Border.all(color: AppColors.slate100),
        boxShadow: refCardShadow,
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.title,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.slate900,
                  ),
                ),
              ),
              if (widget.headerTrailing != null) ...[
                widget.headerTrailing!,
                const SizedBox(width: 6),
              ],
              GestureDetector(
                onTap: () => setState(() => _showDollars = !_showDollars),
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: AppColors.slate100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      _showDollars ? '%' : '\$',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.slate500,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showPie) ...[
                SizedBox(
                  width: 96,
                  height: 96,
                  child: PieChart(
                    PieChartData(
                      sections: [
                        for (var i = 0; i < entries.length; i++)
                          PieChartSectionData(
                            value: entries[i].value.abs(),
                            title: '',
                            radius: 48,
                            color: _palette[i % _palette.length],
                          ),
                      ],
                      sectionsSpace: 1,
                      centerSpaceRadius: 0,
                    ),
                  ),
                ),
                const SizedBox(width: 24),
              ],
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < entries.length; i++)
                      Builder(
                        builder: (context) {
                          final isActionable =
                              widget.onSliceTap != null &&
                              (widget.sliceIsActionable?.call(entries[i].key) ??
                                  true);
                          return GestureDetector(
                            onTap: isActionable
                                ? () => widget.onSliceTap!(entries[i].key)
                                : null,
                            behavior: HitTestBehavior.opaque,
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                children: [
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      color: _palette[i % _palette.length],
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      entries[i].key,
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: AppColors.slate700,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Text(
                                    _showDollars
                                        ? formatMoney(entries[i].value)
                                        : '${(entries[i].value.abs() / totalAbs * 100).round()}%',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.slate900,
                                    ),
                                  ),
                                  if (isActionable) ...[
                                    const SizedBox(width: 4),
                                    Icon(
                                      Icons.chevron_right,
                                      size: 14,
                                      color: AppColors.slate300,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DayBarChart extends StatelessWidget {
  const _DayBarChart({required this.entries});

  final List<MapEntry<String, double>> entries;

  /// Format an ISO date key like "2026-04-01T00:00:00" → "Apr 1".
  static String _shortDate(String iso) {
    try {
      final d = DateTime.parse(iso);
      return DateFormat('MMM d').format(d);
    } catch (_) {
      return iso.length > 6 ? iso.substring(0, 6) : iso;
    }
  }

  /// Format for tooltip: "Apr 1, 2026".
  static String _longDate(String iso) {
    try {
      return DateFormat.yMMMd().format(DateTime.parse(iso));
    } catch (_) {
      return iso;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();

    final n = entries.length;
    // Bar geometry uses magnitude; amounts may be signed (negative spend, positive refunds).
    final maxY = entries
        .map((e) => e.value.abs())
        .reduce((a, b) => a > b ? a : b);
    // Show only first, middle, last labels to avoid crowding.
    final labelIndices = <int>{0, n ~/ 2, n - 1};
    // Dynamic bar width based on entry count.
    final barWidth = (n <= 7) ? 10.0 : (n <= 15 ? 6.0 : 4.0);
    // Grid lines at 25% and 75% of max.
    final interval = maxY > 0 ? maxY / 4 : 1.0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(RefLayout.rounded3xl),
        border: Border.all(color: AppColors.slate100),
        boxShadow: refCardShadow,
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Spend by Day',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.slate900,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Stack(
              children: [
                BarChart(
                  BarChartData(
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
                          if (i < 0 || i >= entries.length) return null;
                          return BarTooltipItem(
                            '${_longDate(entries[i].key)}\n',
                            GoogleFonts.inter(
                              fontSize: 11,
                              color: AppColors.slate300,
                              fontWeight: FontWeight.w500,
                            ),
                            children: [
                              TextSpan(
                                text: formatMoney(entries[i].value),
                                style: GoogleFonts.inter(
                                  fontSize: 14,
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
                      for (var i = 0; i < n; i++)
                        BarChartGroupData(
                          x: i,
                          barRods: [
                            BarChartRodData(
                              toY: entries[i].value.abs(),
                              color: AppColors.teal500,
                              width: barWidth,
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
                            if (!labelIndices.contains(i) || i < 0 || i >= n) {
                              return const SizedBox.shrink();
                            }
                            return Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                _shortDate(entries[i].key),
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  color: AppColors.slate400,
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
                      horizontalInterval: interval,
                      checkToShowHorizontalLine: (v) {
                        // Only show lines at 25% and 75% of max
                        final q1 = maxY * 0.25;
                        final q3 = maxY * 0.75;
                        return (v - q1).abs() < interval * 0.1 ||
                            (v - q3).abs() < interval * 0.1;
                      },
                      getDrawingHorizontalLine: (_) =>
                          FlLine(color: AppColors.slate100, strokeWidth: 1),
                    ),
                    borderData: FlBorderData(show: false),
                  ),
                ),
                // Overlaid y-axis labels at 75% and 25% grid lines
                // The chart area excludes 24px bottom titles, so chartHeight = totalHeight - 24.
                // A value at Y% from bottom = chartHeight * (1 - Y) from top.
                LayoutBuilder(
                  builder: (context, constraints) {
                    final chartH = constraints.maxHeight - 24; // bottom titles
                    final labelStyle = GoogleFonts.inter(
                      fontSize: 9,
                      fontWeight: FontWeight.w500,
                      color: AppColors.slate400,
                    );
                    return Stack(
                      children: [
                        // 75% line label (25% from top of chart)
                        Positioned(
                          left: 2,
                          top: chartH * 0.25 - 12,
                          child: Text(
                            '\$${(maxY * 0.75).round()}',
                            style: labelStyle,
                          ),
                        ),
                        // 25% line label (75% from top of chart)
                        Positioned(
                          left: 2,
                          top: chartH * 0.75 - 12,
                          child: Text(
                            '\$${(maxY * 0.25).round()}',
                            style: labelStyle,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
