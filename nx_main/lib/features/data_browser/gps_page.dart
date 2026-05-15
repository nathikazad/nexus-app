import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import 'package:nexus_voice_assistant/domain/gps/gps_point.dart';
import 'package:nexus_voice_assistant/features/data_browser/gps_view_model.dart';

class GpsPage extends ConsumerStatefulWidget {
  const GpsPage({super.key});

  @override
  ConsumerState<GpsPage> createState() => _GpsPageState();
}

class _GpsPageState extends ConsumerState<GpsPage> {
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(gpsViewModelProvider.notifier).loadDates();
    });
  }

  Future<void> _pickDate(GpsViewState vm) async {
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
      await ref.read(gpsViewModelProvider.notifier).applyPickedDate(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = ref.watch(gpsViewModelProvider);
    final notifier = ref.read(gpsViewModelProvider.notifier);

    ref.listen(gpsViewModelProvider, (prev, next) {
      final msg = next.transientNotice;
      if (msg != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
        notifier.clearTransientNotice();
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('GPS')),
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
                          'No GPS data yet.',
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
                                'No GPS samples on ${DateFormat.yMMMd().format(vm.selected)}.',
                                style: TextStyle(color: Colors.grey.shade600),
                              ),
                            ),
                          )
                        else
                          Expanded(
                            child: _GpsMapView(
                              points: vm.points,
                              selectedIndex: vm.selectedIndex,
                              mapController: _mapController,
                              onIndexChanged: notifier.setSelectedIndex,
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
    );
  }
}

class _GpsMapView extends StatelessWidget {
  const _GpsMapView({
    required this.points,
    required this.selectedIndex,
    required this.mapController,
    required this.onIndexChanged,
  });

  final List<GpsPoint> points;
  final int selectedIndex;
  final MapController mapController;
  final ValueChanged<int> onIndexChanged;

  @override
  Widget build(BuildContext context) {
    final latLngs = [
      for (final point in points) LatLng(point.latitude, point.longitude),
    ];
    final selected = points[selectedIndex.clamp(0, points.length - 1)];
    final selectedLatLng = LatLng(selected.latitude, selected.longitude);
    final bounds = LatLngBounds.fromPoints(latLngs);
    final hasArea = (bounds.north - bounds.south).abs() > 0.00001 ||
        (bounds.east - bounds.west).abs() > 0.00001;
    final fitBounds = latLngs.length > 1 && hasArea;
    final initialZoom = fitBounds ? 14.0 : 16.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Flexible(
          flex: 9,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: FlutterMap(
              mapController: mapController,
              options: MapOptions(
                initialCenter: selectedLatLng,
                initialZoom: initialZoom,
                initialCameraFit: fitBounds
                    ? CameraFit.bounds(
                        bounds: bounds,
                        padding: const EdgeInsets.all(42),
                      )
                    : null,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.nexus.nx_main',
                  errorTileCallback: (tile, error, stackTrace) {
                    debugPrint('[GPS Map] tile load failed: $error');
                  },
                ),
                CircleLayer(
                  circles: _heatCircles(points),
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: selectedLatLng,
                      width: 34,
                      height: 34,
                      child: const Icon(
                        Icons.location_on,
                        color: Colors.red,
                        size: 34,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        _SelectedPointSummary(point: selected, count: points.length),
        SafeArea(
          top: false,
          minimum: const EdgeInsets.only(bottom: 18),
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Slider(
              value: selectedIndex.toDouble(),
              min: 0,
              max: (points.length - 1).toDouble(),
              divisions: points.length > 1 ? points.length - 1 : null,
              label: _formatTime(selected.timeHms),
              onChanged: (value) {
                final next = value.round();
                onIndexChanged(next);
                final point = points[next];
                mapController.move(
                  LatLng(point.latitude, point.longitude),
                  mapController.camera.zoom,
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  List<CircleMarker> _heatCircles(List<GpsPoint> points) {
    final buckets = <String, ({GpsPoint point, int count})>{};
    for (final point in points) {
      final key =
          '${point.latitude.toStringAsFixed(4)},${point.longitude.toStringAsFixed(4)}';
      final current = buckets[key];
      buckets[key] = (
        point: current?.point ?? point,
        count: (current?.count ?? 0) + 1,
      );
    }
    final maxCount = buckets.values.fold<int>(
      1,
      (max, bucket) => bucket.count > max ? bucket.count : max,
    );
    return [
      for (final bucket in buckets.values)
        CircleMarker(
          point: LatLng(bucket.point.latitude, bucket.point.longitude),
          radius: 18 + (bucket.count / maxCount) * 26,
          color: Colors.deepOrange.withValues(
            alpha: 0.16 + (bucket.count / maxCount) * 0.24,
          ),
          borderColor: Colors.deepOrange.withValues(alpha: 0.35),
          borderStrokeWidth: 1,
        ),
    ];
  }
}

class _SelectedPointSummary extends StatelessWidget {
  const _SelectedPointSummary({
    required this.point,
    required this.count,
  });

  final GpsPoint point;
  final int count;

  @override
  Widget build(BuildContext context) {
    final accuracy = point.accuracyM == null
        ? null
        : '${point.accuracyM!.toStringAsFixed(0)} m';
    final speed = point.speedMps == null
        ? null
        : '${point.speedMps!.toStringAsFixed(1)} m/s';
    return Row(
      children: [
        Expanded(
          child: Text(
            [
              _formatTime(point.timeHms),
              '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}',
              if (accuracy != null) 'accuracy $accuracy',
              if (speed != null) 'speed $speed',
            ].join('  ·  '),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Text(
          '$count pts',
          style: TextStyle(color: Colors.grey.shade700),
        ),
      ],
    );
  }
}

String _formatTime(String hms) {
  final parts = hms.split(':');
  if (parts.length < 2) return hms;
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null) return hms;
  final date = DateTime(2000, 1, 1, hour, minute);
  return DateFormat.jm().format(date);
}
