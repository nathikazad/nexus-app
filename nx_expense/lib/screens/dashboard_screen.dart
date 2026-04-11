import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nx_db/nx_db.dart';

import '../aggregate_ui.dart';
import '../expense_schema.dart';
import '../format.dart';
import '../providers/expense_providers.dart';
import '../widgets/stat_card.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schemaAsync = ref.watch(expenseSchemaProvider);
    final summaryAsync = ref.watch(dashboardExpenseSummaryProvider);
    final numsAsync = ref.watch(dashboardNumberSumsProvider);
    final dayAsync = ref.watch(spendByDayProvider);
    final range = ref.watch(dashboardDateRangeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range),
            onPressed: () async {
              final now = DateTime.now();
              final picked = await showDateRangePicker(
                context: context,
                firstDate: DateTime(now.year - 2),
                lastDate: DateTime(now.year + 1),
                initialDateRange: range ??
                    DateTimeRange(
                      start: now.subtract(const Duration(days: 30)),
                      end: now,
                    ),
              );
              if (picked != null) {
                ref.read(dashboardDateRangeProvider.notifier).setRange(picked);
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) context.go('/login');
            },
          ),
        ],
      ),
      body: schemaAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (schema) {
          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              if (range != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    '${range.start.toLocal().toString().split(' ').first} — ${range.end.toLocal().toString().split(' ').first}',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
              summaryAsync.when(
                data: (s) => Row(
                  children: [
                    Expanded(
                      child: StatCard(
                        title: 'Count',
                        value: '${s.count}',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: StatCard(
                        title: 'Total',
                        value: s.sumTotal != null ? formatMoney(s.sumTotal) : '—',
                      ),
                    ),
                  ],
                ),
                loading: () => const LinearProgressIndicator(),
                error: (_, __) => const SizedBox.shrink(),
              ),
              const SizedBox(height: 12),
              numsAsync.when(
                data: (rows) => Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final r in rows)
                      SizedBox(
                        width: 160,
                        child: StatCard(
                          title: r.key,
                          value: formatMoney(r.value),
                        ),
                      ),
                  ],
                ),
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
              const SizedBox(height: 16),
              Text('Spend by day', style: Theme.of(context).textTheme.titleMedium),
              SizedBox(
                height: 220,
                child: dayAsync.when(
                  data: (raw) => _DayBarChart(entries: parseDaySpendEntries(raw)),
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Text('$e'),
                ),
              ),
              const SizedBox(height: 16),
              for (final ts in schema.tagSystems ?? const <TagSystem>[]) ...[
                Text('Spend by ${ts.name}', style: Theme.of(context).textTheme.titleMedium),
                SizedBox(
                  height: 200,
                  child: Consumer(
                    builder: (context, ref, _) {
                      final agg = ref.watch(spendByTagSystemProvider(ts.name));
                      return agg.when(
                        data: (raw) => _PieChartCard(entries: parseGroupedChartEntries(raw)),
                        loading: () => const Center(child: CircularProgressIndicator()),
                        error: (e, _) => Text('$e'),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
              ],
              for (final relName in allRelationTargetTypeNames(schema)) ...[
                Text('Spend by $relName', style: Theme.of(context).textTheme.titleMedium),
                SizedBox(
                  height: 200,
                  child: Consumer(
                    builder: (context, ref, _) {
                      final agg = ref.watch(spendByRelationProvider(relName));
                      return agg.when(
                        data: (raw) => _PieChartCard(entries: parseGroupedChartEntries(raw)),
                        loading: () => const Center(child: CircularProgressIndicator()),
                        error: (e, _) => Text('$e'),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _DayBarChart extends StatelessWidget {
  const _DayBarChart({required this.entries});

  final List<MapEntry<String, double>> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const Center(child: Text('No data'));
    }
    final maxY = entries.map((e) => e.value).reduce((a, b) => a > b ? a : b) * 1.2;
    return BarChart(
      BarChartData(
        barGroups: [
          for (var i = 0; i < entries.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: entries[i].value,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ],
            ),
        ],
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (v, _) {
                final i = v.toInt();
                if (i < 0 || i >= entries.length) return const SizedBox.shrink();
                final t = entries[i].key;
                final short = t.length > 6 ? t.substring(0, 6) : t;
                return Text(short, style: const TextStyle(fontSize: 10));
              },
            ),
          ),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 36)),
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
        ),
        gridData: const FlGridData(show: true),
        borderData: FlBorderData(show: false),
        maxY: maxY > 0 ? maxY : 1,
      ),
    );
  }
}

class _PieChartCard extends StatelessWidget {
  const _PieChartCard({required this.entries});

  final List<MapEntry<String, double>> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const Center(child: Text('No data'));
    }
    return PieChart(
      PieChartData(
        sections: [
          for (var i = 0; i < entries.length; i++)
            PieChartSectionData(
              value: entries[i].value,
              title: entries[i].key,
              radius: 60,
              titleStyle: const TextStyle(fontSize: 10, color: Colors.white),
              color: Colors.primaries[i % Colors.primaries.length],
            ),
        ],
        sectionsSpace: 2,
        centerSpaceRadius: 0,
      ),
    );
  }
}
