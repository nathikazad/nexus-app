import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../auth.dart';
import '../services/battery_chart_service.dart';

/// Browse necklace battery history by day; dual-axis line chart (%, voltage).
class BatteryScreen extends ConsumerStatefulWidget {
  const BatteryScreen({super.key});

  @override
  ConsumerState<BatteryScreen> createState() => _BatteryScreenState();
}

class _BatteryScreenState extends ConsumerState<BatteryScreen> {
  bool _loading = true;
  String? _error;
  Set<DateTime> _available = {};
  late DateTime _selected;
  bool _loadingDay = false;
  List<BatteryPoint> _points = [];
  Timer? _pollTimer;

  bool get _isToday {
    final now = DateTime.now();
    return _selected.year == now.year &&
        _selected.month == now.month &&
        _selected.day == now.day;
  }

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selected = DateTime(now.year, now.month, now.day);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadDates());
  }

  @override
  void dispose() {
    _stopPolling();
    super.dispose();
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  void _startPolling() {
    _stopPolling();
    if (!_isToday) return;
    _pollTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      _pollForNewPoints();
    });
  }

  Future<void> _pollForNewPoints() async {
    if (!mounted || !_isToday) return;
    final base = ref.read(imageBaseUrlProvider);
    final uid = ref.read(userIdProvider);
    if (base == null || uid == null || uid.isEmpty) return;
    try {
      final fresh = await fetchBatteryDay(base, uid, _selected);
      if (!mounted) return;
      if (fresh.length > _points.length) {
        setState(() {
          _points = fresh;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadDates() async {
    final base = ref.read(imageBaseUrlProvider);
    final uid = ref.read(userIdProvider);
    if (base == null || uid == null || uid.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Not logged in or missing image server URL.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final dates = await fetchBatteryDates(base, uid);
      if (!mounted) return;
      final initial = _initialSelected(dates);
      setState(() {
        _available = dates.toSet();
        _selected = initial;
        _loading = false;
      });
      await _loadDay();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  DateTime _initialSelected(List<DateTime> dates) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (dates.contains(today)) return today;
    if (dates.isNotEmpty) return dates.first;
    return today;
  }

  Future<void> _loadDay() async {
    final base = ref.read(imageBaseUrlProvider);
    final uid = ref.read(userIdProvider);
    if (base == null || uid == null || uid.isEmpty) return;

    setState(() {
      _loadingDay = true;
      _points = [];
    });

    try {
      final pts = await fetchBatteryDay(base, uid, _selected);
      if (!mounted) return;
      setState(() {
        _points = pts;
        _loadingDay = false;
      });
      _startPolling();
    } catch (e) {
      if (!mounted) return;
      _stopPolling();
      setState(() {
        _points = [];
        _loadingDay = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load battery data: $e')),
      );
    }
  }

  Future<void> _pickDate() async {
    if (_available.isEmpty) return;
    final first = _available.reduce((a, b) => a.isBefore(b) ? a : b);
    final last = _available.reduce((a, b) => a.isAfter(b) ? a : b);
    final picked = await showDatePicker(
      context: context,
      initialDate: _selected.isBefore(first)
          ? first
          : (_selected.isAfter(last) ? last : _selected),
      firstDate: first,
      lastDate: last,
      selectableDayPredicate: (d) {
        final day = DateTime(d.year, d.month, d.day);
        return _available.contains(day);
      },
    );
    if (picked != null && mounted) {
      setState(() {
        _selected = DateTime(picked.year, picked.month, picked.day);
      });
      await _loadDay();
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Necklace battery'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: _loadDates,
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
                      if (_available.isEmpty)
                        const Text(
                          'No battery data yet.',
                          style: TextStyle(color: Colors.grey),
                        )
                      else ...[
                        OutlinedButton.icon(
                          onPressed: _pickDate,
                          icon: const Icon(Icons.calendar_today),
                          label: Text(DateFormat.yMMMd().format(_selected)),
                        ),
                        const SizedBox(height: 12),
                        if (_loadingDay)
                          const Expanded(
                            child: Center(child: CircularProgressIndicator()),
                          )
                        else if (_points.isEmpty)
                          Expanded(
                            child: Center(
                              child: Text(
                                'No samples on ${DateFormat.yMMMd().format(_selected)}.',
                                style: TextStyle(color: Colors.grey.shade600),
                              ),
                            ),
                          )
                        else
                          Expanded(child: _buildChart(context)),
                      ],
                    ],
                  ),
                ),
    );
  }

  Widget _buildChart(BuildContext context) {
    final pts = _points;
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
                    getTitlesWidget: (v, m) =>
                        Text('${v.toInt()}%', style: const TextStyle(fontSize: 10)),
                  ),
                ),
                rightTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    interval: 25,
                    getTitlesWidget: (v, m) {
                      final mv =
                          vMin + (v / 100) * vSpan;
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
