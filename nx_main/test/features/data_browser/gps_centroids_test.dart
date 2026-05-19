import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_voice_assistant/domain/gps/gps_point.dart';
import 'package:nexus_voice_assistant/features/data_browser/gps_centroids.dart';

void main() {
  test('computeGpsCentroids groups sustained stops and filters noisy samples',
      () {
    final points = [
      _point('09:00:00', 37.790280, -122.413520),
      _point('09:01:00', 37.790285, -122.413525),
      _point('09:02:00', 37.790275, -122.413530),
      _point('09:03:00', 37.790285, -122.413520),
      _point('09:04:00', 37.790275, -122.413525),
      _point('09:05:00', 37.790280, -122.413530),
      _point('11:00:00', 37.781200, -122.404200),
      _point('11:01:00', 37.781210, -122.404210),
      _point('11:02:00', 37.781220, -122.404220),
      _point('11:03:00', 37.781205, -122.404205),
      _point('11:04:00', 37.781215, -122.404215),
      _point('11:05:00', 37.781200, -122.404200),
      _point('12:00:00', 37.770000, -122.430000),
      _point('13:00:00', 37.790280, -122.413520, accuracyM: 200),
    ];

    final centroids = computeGpsCentroids(points);

    expect(centroids, hasLength(2));
    expect(centroids[0].count, 6);
    expect(centroids[0].firstTimeHms, '09:00:00');
    expect(centroids[0].lastTimeHms, '09:05:00');
    expect(centroids[0].duration, const Duration(minutes: 5));
    expect(centroids[0].latitude, closeTo(37.790280, 0.00002));
    expect(centroids[0].longitude, closeTo(-122.413525, 0.00002));

    expect(centroids[1].count, 6);
    expect(centroids[1].firstTimeHms, '11:00:00');
    expect(centroids[1].lastTimeHms, '11:05:00');
  });

  test('computeGpsCentroids ignores short stoplight-length pauses', () {
    final points = [
      _point('09:00:00', 37.790280, -122.413520),
      _point('09:01:00', 37.790285, -122.413525),
      _point('09:02:00', 37.790275, -122.413530),
      _point('09:03:00', 37.790285, -122.413520),
    ];

    final centroids = computeGpsCentroids(points);

    expect(centroids, isEmpty);
  });
}

GpsPoint _point(
  String timeHms,
  double latitude,
  double longitude, {
  double accuracyM = 10,
}) {
  return GpsPoint(
    timeHms: timeHms,
    timeIso: '2026-05-18T$timeHms',
    latitude: latitude,
    longitude: longitude,
    accuracyM: accuracyM,
  );
}
