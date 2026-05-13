import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:nexus_voice_assistant/domain/battery/battery_point.dart';
import 'package:nexus_voice_assistant/features/data_browser/battery_view_model.dart';

/// Browse necklace battery history by day; dual-axis line chart (%, voltage).
class BatteryPage extends ConsumerStatefulWidget {
  const BatteryPage({super.key});

  @override
  ConsumerState<BatteryPage> createState() => _BatteryPageState();
}

class _BatteryPageState extends ConsumerState<BatteryPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(batteryViewModelProvider.notifier).loadDates();
    });
  }

  Future<void> _pickDate(BatteryViewState vm) async {
    if (vm.available.isEmpty) return;
    final first = vm.available.reduce((a, b) => a.isBefore(b) ? a : b);
    final last = vm.available.reduce((a, b) => a.isAfter(b) ? a : b);
    final picked = await showDatePicker(
      context: context,
      initialDate: vm.selected.isBefore(first)
          ? first
          : (vm.selected.isAfter(last) ? last : vm.selected),
      firstDate: first,
      lastDate: last,
      selectableDayPredicate: (d) {
        final day = DateTime(d.year, d.month, d.day);
        return vm.available.contains(day);
      },
    );
    if (picked != null && mounted) {
      await ref.read(batteryViewModelProvider.notifier).applyPickedDate(picked);
    }
  }

  /// Minutes since local midnight for sorting / X axis.
  double _minutesFromHms(String hms) {
    final parts = hms.split(':');
    if (parts.length < 3) return 0;
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    final s = int.tryParse(parts[2]) ?? 0;
    return h * 60.0 + m + s / 60.0;
  }

  @override
  Widget build(BuildContext context) {
    final vm = ref.watch(batteryViewModelProvider);
    final notifier = ref.read(batteryViewModelProvider.notifier);

    ref.listen(batteryViewModelProvider, (prev, next) {
      final msg = next.transientNotice;
      if (msg != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
        notifier.clearTransientNotice();
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Necklace battery'),
      ),
      body: vm.loading
          ? const Center(child: CircularProgressIndicator())
          : vm.error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(vm.error!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: notifier.loadDates,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (vm.available.isEmpty)
                        const Text(
                          'No battery data yet.',
                          style: TextStyle(color: Colors.grey),
                        )
                      else ...[
                        OutlinedButton.icon(
                          onPressed: () => _pickDate(vm),
                          icon: const Icon(Icons.calendar_today),
                          label: Text(DateFormat.yMMMd().format(vm.selected)),
                        ),
                        const SizedBox(height: 12),
                        if (vm.loadingDay)
                          const Expanded(
                            child: Center(child: CircularProgressIndicator()),
                          )
                        else if (vm.points.isEmpty)
                          Expanded(
                            child: Center(
                              child: Text(
                                'No samples on ${DateFormat.yMMMd().format(vm.selected)}.',
                                style: TextStyle(color: Colors.grey.shade600),
                              ),
                            ),
                          )
                        else
                          Expanded(child: _buildChart(context, vm.points)),
                      ],
                    ],
                  ),
                ),
    );
  }

  Widget _buildChart(BuildContext context, List<BatteryPoint> pts) {
    final xs = pts.map((p) => _minutesFromHms(p.timeHms)).toList();
    final minX = xs.reduce((a, b) => a < b ? a : b);
    final maxX = xs.reduce((a, b) => a > b ? a : b);
    final pad = (maxX - minX) * 0.02;
    final minX0 = (minX - pad).clamp(0.0, 1440.0);
    final maxX0 = (maxX + pad).clamp(0.0, 1440.0);

    final vmins = pts.map((p) => p.voltageMv).toList();
    final vMin = vmins.reduce((a, b) => a < b ? a : b);
    final vMax = vmins.reduce((a, b) => a > b ? a : b);
    final vSpan = (vMax - vMin).clamp(1, 100000);

    double normV(int mv) {
      if (vMax == vMin) return 50;
      return (mv - vMin) / vSpan * 100;
    }

    final pctSpots = <FlSpot>[
      for (var i = 0; i < pts.length; i++)
        FlSpot(xs[i], pts[i].percent.toDouble()),
    ];
    final voltSpots = <FlSpot>[
      for (var i = 0; i < pts.length; i++)
        FlSpot(xs[i], normV(pts[i].voltageMv)),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(width: 12, height: 12, color: Colors.teal),
            const SizedBox(width: 8),
            const Text('Battery %'),
            const SizedBox(width: 16),
            Container(width: 12, height: 12, color: Colors.deepPurple),
            const SizedBox(width: 8),
            const Text('Voltage (V)'),
            const SizedBox(width: 16),
            Container(width: 12, height: 12, color: Colors.orange),
            const SizedBox(width: 8),
            const Text('Charging'),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: LineChart(
            LineChartData(
              minX: minX0,
              maxX: maxX0,
              minY: 0,
              maxY: 100,
              clipData: const FlClipData.all(),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: true,
                getDrawingHorizontalLine: (v) => FlLine(
                  color: Colors.grey.withValues(alpha: 0.2),
                  strokeWidth: 1,
                ),
                getDrawingVerticalLine: (v) => FlLine(
                  color: Colors.grey.withValues(alpha: 0.2),
                  strokeWidth: 1,
                ),
              ),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 36,
                    interval: 25,
                    getTitlesWidget: (v, m) => Text('${v.toInt()}%',
                        style: const TextStyle(fontSize: 10)),
                  ),
                ),
                rightTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    interval: 25,
                    getTitlesWidget: (v, m) {
                      final mv = vMin + (v / 100) * vSpan;
                      return Text(
                        '${(mv / 1000).toStringAsFixed(1)}V',
                        style: const TextStyle(fontSize: 10),
                      );
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    interval: (maxX0 - minX0) > 600 ? 180 : 120,
                    getTitlesWidget: (v, m) {
                      final totalMin = v.toInt().clamp(0, 1440);
                      final h = totalMin ~/ 60;
                      final min = totalMin % 60;
                      return Text(
                        '${h.toString().padLeft(2, '0')}:${min.toString().padLeft(2, '0')}',
                        style: const TextStyle(fontSize: 10),
                      );
                    },
                  ),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
              ),
              borderData: FlBorderData(show: true),
              lineBarsData: [
                LineChartBarData(
                  spots: pctSpots,
                  isCurved: true,
                  color: Colors.teal,
                  barWidth: 2,
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (spot, percent, bar, i) {
                      if (i < pts.length && pts[i].charging) {
                        return FlDotCirclePainter(
                          radius: 4,
                          color: Colors.orange,
                          strokeWidth: 0,
                        );
                      }
                      return FlDotCirclePainter(
                        radius: 2,
                        color: Colors.teal,
                        strokeWidth: 0,
                      );
                    },
                  ),
                ),
                LineChartBarData(
                  spots: voltSpots,
                  isCurved: true,
                  color: Colors.deepPurple,
                  barWidth: 2,
                  dotData: const FlDotData(show: false),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
