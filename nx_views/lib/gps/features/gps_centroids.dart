import 'package:latlong2/latlong.dart';

import 'package:nx_views/gps/domain/gps_point.dart';

class GpsCentroid {
  const GpsCentroid({
    required this.latitude,
    required this.longitude,
    required this.count,
    required this.firstTimeHms,
    required this.lastTimeHms,
    required this.duration,
    this.averageAccuracyM,
  });

  final double latitude;
  final double longitude;
  final int count;
  final String firstTimeHms;
  final String lastTimeHms;
  final Duration duration;
  final double? averageAccuracyM;
}

List<GpsCentroid> computeGpsCentroids(
  List<GpsPoint> points, {
  double radiusMeters = 75,
  int minPoints = 3,
  Duration minDuration = const Duration(minutes: 5),
  double maxAccuracyMeters = 75,
}) {
  final distance = const Distance();
  final clusters = <_WorkingGpsCentroid>[];

  for (final point in points) {
    final accuracy = point.accuracyM;
    if (accuracy != null && accuracy > maxAccuracyMeters) {
      continue;
    }

    final pointLatLng = LatLng(point.latitude, point.longitude);
    _WorkingGpsCentroid? nearest;
    var nearestMeters = double.infinity;
    for (final cluster in clusters) {
      final meters = distance.as(
        LengthUnit.Meter,
        LatLng(cluster.latitude, cluster.longitude),
        pointLatLng,
      );
      if (meters <= radiusMeters && meters < nearestMeters) {
        nearest = cluster;
        nearestMeters = meters;
      }
    }

    if (nearest == null) {
      clusters.add(_WorkingGpsCentroid(point));
    } else {
      nearest.add(point);
    }
  }

  final centroids = [
    for (final cluster in clusters)
      if (cluster.count >= minPoints && cluster.duration >= minDuration)
        cluster.toCentroid(),
  ]..sort((a, b) => a.firstTimeHms.compareTo(b.firstTimeHms));
  return centroids;
}

class _WorkingGpsCentroid {
  _WorkingGpsCentroid(GpsPoint point)
    : latitude = point.latitude,
      longitude = point.longitude,
      count = 1,
      firstTimeHms = point.timeHms,
      lastTimeHms = point.timeHms,
      _accuracySum = point.accuracyM ?? 0,
      _accuracyCount = point.accuracyM == null ? 0 : 1;

  double latitude;
  double longitude;
  int count;
  final String firstTimeHms;
  String lastTimeHms;
  double _accuracySum;
  int _accuracyCount;

  Duration get duration {
    final start = _durationSinceMidnight(firstTimeHms);
    final end = _durationSinceMidnight(lastTimeHms);
    if (start == null || end == null) return Duration.zero;
    return end >= start ? end - start : (end + const Duration(days: 1)) - start;
  }

  void add(GpsPoint point) {
    final nextCount = count + 1;
    latitude = ((latitude * count) + point.latitude) / nextCount;
    longitude = ((longitude * count) + point.longitude) / nextCount;
    count = nextCount;
    lastTimeHms = point.timeHms;
    final accuracy = point.accuracyM;
    if (accuracy != null) {
      _accuracySum += accuracy;
      _accuracyCount += 1;
    }
  }

  GpsCentroid toCentroid() {
    return GpsCentroid(
      latitude: latitude,
      longitude: longitude,
      count: count,
      firstTimeHms: firstTimeHms,
      lastTimeHms: lastTimeHms,
      duration: duration,
      averageAccuracyM: _accuracyCount == 0
          ? null
          : _accuracySum / _accuracyCount,
    );
  }
}

Duration? _durationSinceMidnight(String hms) {
  final parts = hms.split(':');
  if (parts.length < 2) return null;
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  final second = parts.length > 2 ? int.tryParse(parts[2]) ?? 0 : 0;
  if (hour == null || minute == null) return null;
  return Duration(hours: hour, minutes: minute, seconds: second);
}
