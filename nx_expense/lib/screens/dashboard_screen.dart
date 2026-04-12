import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nx_db/nx_db.dart';

import '../aggregate_ui.dart';
import '../app_theme.dart';
import '../expense_schema.dart';
import '../format.dart';
import '../providers/expense_providers.dart';
import '../reference_layout.dart';
import '../widgets/expense_app_end_drawer.dart';
import '../widgets/expense_date_range_bar.dart';
import '../widgets/stat_card.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schemaAsync = ref.watch(expenseSchemaProvider);
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
                  padding: const EdgeInsets.fromLTRB(RefLayout.px5, RefLayout.appBarTop, RefLayout.px5, RefLayout.pb4),
                  child: Row(
                    children: [
                      Expanded(child: Text('Stats', style: refAppBarTitleLarge())),
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
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('$e')),
                  data: (s) {
                    // No data — show empty state
                    if (s.count == 0) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.receipt_long_outlined, size: 48, color: AppColors.slate300),
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
                              style: GoogleFonts.inter(fontSize: 13, color: AppColors.slate400),
                            ),
                          ],
                        ),
                      );
                    }

                    // Has data — show stats + charts
                    return ListView(
                      padding: const EdgeInsets.fromLTRB(RefLayout.px5, 8, RefLayout.px5, RefLayout.pb24),
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: StatCard(title: 'Count', value: '${s.count}'),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: StatCard(
                                title: 'Total',
                                value: s.sumTotal != null ? formatMoney(s.sumTotal) : '—',
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
                            return SizedBox(height: 240, child: _DayBarChart(entries: entries));
                          },
                          loading: () => const SizedBox(height: 240, child: Center(child: CircularProgressIndicator())),
                          error: (_, __) => const SizedBox.shrink(),
                        ),
                        const SizedBox(height: 24),
                        for (final ts in schema.tagSystems ?? const <TagSystem>[]) ...[
                          _TagPieChart(tagSystem: ts),
                          const SizedBox(height: 24),
                        ],
                        for (final relName in allRelationTargetTypeNames(schema)) ...[
                          Consumer(
                            builder: (context, ref, _) {
                              final agg = ref.watch(spendByRelationProvider(relName));
                              return agg.when(
                                data: (raw) {
                                  final entries = parseGroupedChartEntries(raw);
                                  if (entries.isEmpty) return const SizedBox.shrink();
                                  return _PieChartCard(title: 'Spend by $relName', entries: entries);
                                },
                                loading: () => const SizedBox(height: 180, child: Center(child: CircularProgressIndicator())),
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

/// Drill-down pie chart for tag systems.
/// For hierarchical systems: starts at root level, tap a slice to drill into
/// its children. Breadcrumb trail shows path; tap to go back.
/// For flat systems: just shows the pie chart with no drill-down.
class _TagPieChart extends ConsumerStatefulWidget {
  const _TagPieChart({required this.tagSystem});
  final TagSystem tagSystem;

  @override
  ConsumerState<_TagPieChart> createState() => _TagPieChartState();
}

class _TagPieChartState extends ConsumerState<_TagPieChart> {
  /// Stack of drilled-into node names. Empty = root level.
  final List<String> _breadcrumbs = [];

  /// Check if a node name has children in the tag system tree.
  bool _hasChildren(String nodeName) {
    TagNode? find(List<TagNode> nodes) {
      for (final n in nodes) {
        if (n.name == nodeName) return n;
        if (n.children != null) {
          final r = find(n.children!);
          if (r != null) return r;
        }
      }
      return null;
    }
    final node = find(widget.tagSystem.nodes);
    return node?.children != null && node!.children!.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final ts = widget.tagSystem;
    final isHierarchical = ts.isHierarchical;
    final parentNode = _breadcrumbs.isNotEmpty ? _breadcrumbs.last : null;

    // At root: group by level 1 (root categories). When drilled in: group by
    // leaf within the filtered parent — the API returns direct children since
    // we filter to the parent with include_descendants.
    final int? level = isHierarchical && _breadcrumbs.isEmpty ? 1 : null;

    final agg = ref.watch(spendByTagSystemProvider((
      systemName: ts.name,
      parentNode: parentNode,
      level: level,
    )));

    return agg.when(
      data: (raw) {
        var entries = parseGroupedChartEntries(raw);
        if (entries.isEmpty) return const SizedBox.shrink();

        // Rename entries tagged directly to the parent node to "Other".
        if (parentNode != null) {
          entries = entries
              .map((e) => e.key == parentNode ? MapEntry('Other', e.value) : e)
              .toList();
        }

        // Build title with breadcrumbs
        final titleParts = [ts.name, ..._breadcrumbs];
        final title = titleParts.join(' › ');

        return _PieChartCard(
          title: 'Spend by $title',
          entries: entries,
          onSliceTap: isHierarchical
              ? (sliceName) {
                  if (_hasChildren(sliceName)) {
                    setState(() => _breadcrumbs.add(sliceName));
                  }
                }
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
                      child: Icon(Icons.arrow_back, size: 16, color: AppColors.slate500),
                    ),
                  ),
                )
              : null,
        );
      },
      loading: () => const SizedBox(height: 180, child: Center(child: CircularProgressIndicator())),
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
  });

  final String title;
  final List<MapEntry<String, double>> entries;
  final Widget? headerTrailing;
  /// Called when a legend row / pie slice is tapped (for drill-down).
  final void Function(String sliceName)? onSliceTap;

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

  bool _showDollars = false;

  @override
  Widget build(BuildContext context) {
    final entries = widget.entries;
    final total = entries.fold<double>(0, (a, b) => a + b.value);
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
            children: [
              // Pie circle
              SizedBox(
                width: 96,
                height: 96,
                child: PieChart(
                  PieChartData(
                    sections: [
                      for (var i = 0; i < entries.length; i++)
                        PieChartSectionData(
                          value: entries[i].value,
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
              // Legend
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < entries.length; i++)
                      GestureDetector(
                        onTap: widget.onSliceTap != null ? () => widget.onSliceTap!(entries[i].key) : null,
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
                                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.slate700),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                _showDollars
                                    ? formatMoney(entries[i].value)
                                    : (total > 0 ? '${(entries[i].value / total * 100).round()}%' : '—'),
                                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.slate900),
                              ),
                              if (widget.onSliceTap != null) ...[
                                const SizedBox(width: 4),
                                Icon(Icons.chevron_right, size: 14, color: AppColors.slate300),
                              ],
                            ],
                          ),
                        ),
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
    final maxY = entries.map((e) => e.value).reduce((a, b) => a > b ? a : b);
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
                        tooltipPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        getTooltipColor: (_) => AppColors.slate900,
                        getTooltipItem: (group, _, rod, __) {
                          final i = group.x;
                          if (i < 0 || i >= entries.length) return null;
                          return BarTooltipItem(
                            '${_longDate(entries[i].key)}\n',
                            GoogleFonts.inter(fontSize: 11, color: AppColors.slate300, fontWeight: FontWeight.w500),
                            children: [
                              TextSpan(
                                text: formatMoney(rod.toY),
                                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
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
                              toY: entries[i].value,
                              color: AppColors.teal500,
                              width: barWidth,
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
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
                                style: GoogleFonts.inter(fontSize: 10, color: AppColors.slate400, fontWeight: FontWeight.w500),
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
                        return (v - q1).abs() < interval * 0.1 || (v - q3).abs() < interval * 0.1;
                      },
                      getDrawingHorizontalLine: (_) => FlLine(color: AppColors.slate100, strokeWidth: 1),
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
                    final labelStyle = GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w500, color: AppColors.slate400);
                    return Stack(
                      children: [
                        // 75% line label (25% from top of chart)
                        Positioned(
                          left: 2,
                          top: chartH * 0.25 - 12,
                          child: Text('\$${(maxY * 0.75).round()}', style: labelStyle),
                        ),
                        // 25% line label (75% from top of chart)
                        Positioned(
                          left: 2,
                          top: chartH * 0.75 - 12,
                          child: Text('\$${(maxY * 0.25).round()}', style: labelStyle),
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
