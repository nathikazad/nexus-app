import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nexus_voice_assistant/data/gps/gps_upload_manager.dart';

void main() {
  test('GpsUploadManager batches samples and posts to gps upload endpoint',
      () async {
    final requests = <http.Request>[];
    final manager = GpsUploadManager(
      httpBaseUrl: 'https://example.test/',
      headers: {'X-User-Id': '7'},
      timezoneLabel: 'UTC-07:00',
      client: MockClient((request) async {
        requests.add(request);
        return http.Response(jsonEncode({'ok': true}), 200);
      }),
      sampleReader: () async => GpsSample(
        time: DateTime.parse('2026-05-14T18:00:00Z'),
        latitude: 37.7749,
        longitude: -122.4194,
        accuracyM: 4.2,
        altitudeM: 12,
        altitudeAccuracyM: 1.5,
        headingDeg: 180,
        headingAccuracyDeg: 3,
        speedMps: 1.2,
        speedAccuracyMps: 0.4,
        isMocked: false,
      ),
    );

    await manager.collectOnce();
    expect(manager.pendingCount, 1);

    final ok = await manager.flush();

    expect(ok, isTrue);
    expect(manager.pendingCount, 0);
    expect(requests, hasLength(1));
    expect(requests.single.url.toString(), 'https://example.test/gps/upload');
    expect(requests.single.headers['X-User-Id'], '7');
    final body = jsonDecode(requests.single.body) as Map<String, dynamic>;
    expect(body['source'], 'phone');
    expect(body['timezone'], 'UTC-07:00');
    final samples = body['samples'] as List<dynamic>;
    expect(samples, hasLength(1));
    final sample = samples.single as Map<String, dynamic>;
    expect(sample['time'],
        DateTime.parse('2026-05-14T18:00:00Z').toLocal().toIso8601String());
    expect(sample['latitude'], 37.7749);
    expect(sample['longitude'], -122.4194);
    expect(sample['accuracy_m'], 4.2);
  });

  test('GpsUploadManager keeps samples when upload fails', () async {
    final manager = GpsUploadManager(
      httpBaseUrl: 'https://example.test',
      headers: const {},
      client: MockClient((request) async => http.Response('nope', 500)),
      sampleReader: () async => GpsSample(
        time: DateTime.parse('2026-05-14T18:00:00Z'),
        latitude: 1,
        longitude: 2,
        accuracyM: 3,
        altitudeM: 0,
        altitudeAccuracyM: 0,
        headingDeg: 0,
        headingAccuracyDeg: 0,
        speedMps: 0,
        speedAccuracyMps: 0,
        isMocked: false,
      ),
    );

    await manager.collectOnce();
    final ok = await manager.flush();

    expect(ok, isFalse);
    expect(manager.pendingCount, 1);
  });

  test('localTimezoneOffsetLabel formats offsets', () {
    expect(
      localTimezoneOffsetLabel(DateTime.parse('2026-05-14T18:00:00Z')),
      startsWith('UTC'),
    );
  });
}
