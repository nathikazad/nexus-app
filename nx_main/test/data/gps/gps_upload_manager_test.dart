import 'dart:convert';
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nexus_voice_assistant/data/gps/gps_upload_manager.dart';
import 'package:nx_db/auth.dart';

void main() {
  GpsSample makeSample({
    double latitude = 37.7749,
    double longitude = -122.4194,
  }) {
    return GpsSample(
      time: DateTime.parse('2026-05-14T18:00:00Z'),
      latitude: latitude,
      longitude: longitude,
      accuracyM: 4.2,
      altitudeM: 12,
      altitudeAccuracyM: 1.5,
      headingDeg: 180,
      headingAccuracyDeg: 3,
      speedMps: 1.2,
      speedAccuracyMps: 0.4,
      isMocked: false,
    );
  }

  test('GpsUploadManager records first streamed sample and flushes it',
      () async {
    final controller = StreamController<GpsSample>();
    final requests = <http.Request>[];
    final manager = GpsUploadManager(
      httpBaseUrl: 'https://example.test/',
      client: MockClient((request) async {
        requests.add(request);
        return http.Response(jsonEncode({'ok': true}), 200);
      }),
      sampleStreamFactory: () => controller.stream,
      sampleInterval: const Duration(hours: 1),
      flushInterval: const Duration(hours: 1),
    );

    manager.start();
    controller.add(makeSample(latitude: 1, longitude: 2));
    await Future<void>.delayed(Duration.zero);

    expect(manager.pendingCount, 1);
    expect(await manager.flush(), isTrue);
    expect(manager.pendingCount, 0);
    expect(requests, hasLength(1));
    await manager.stop(flushPending: false);
    await controller.close();
  });

  test('GpsUploadManager batches samples and posts to gps upload endpoint',
      () async {
    final requests = <http.Request>[];
    final manager = GpsUploadManager(
      httpBaseUrl: 'https://example.test/',
      timezoneLabel: 'UTC-07:00',
      client: MockClient((request) async {
        requests.add(request);
        return http.Response(jsonEncode({'ok': true}), 200);
      }),
      sampleReader: () async => makeSample(),
    );

    await manager.collectOnce();
    expect(manager.pendingCount, 1);

    final ok = await manager.flush();

    expect(ok, isTrue);
    expect(manager.pendingCount, 0);
    expect(requests, hasLength(1));
    expect(requests.single.url.toString(), 'https://example.test/gps/upload');
    expect(requests.single.headers['X-User-Id'], isNull);
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
      client: MockClient((request) async => http.Response('nope', 500)),
      sampleReader: () async => makeSample(latitude: 1, longitude: 2),
    );

    await manager.collectOnce();
    final ok = await manager.flush();

    expect(ok, isFalse);
    expect(manager.pendingCount, 1);
  });

  test('background GPS refreshes a bearer token once after 401', () async {
    var requests = 0;
    final refreshes = <bool>[];
    final authenticatedClient = NexusAuthenticatedClient(
      preset: BackendPreset.piWan,
      userId: '7',
      inner: MockClient((request) async {
        requests++;
        expect(request.headers['x-user-id'], isNull);
        expect(
          request.headers['authorization'],
          requests == 1 ? 'Bearer current' : 'Bearer refreshed',
        );
        return http.Response(
          requests == 1 ? 'expired' : jsonEncode({'ok': true}),
          requests == 1 ? 401 : 200,
        );
      }),
      authHeaders: (forceRefresh) async {
        refreshes.add(forceRefresh);
        return {
          'authorization': 'Bearer ${forceRefresh ? 'refreshed' : 'current'}',
        };
      },
    );
    final manager = GpsUploadManager(
      httpBaseUrl: 'https://example.test',
      client: authenticatedClient,
      sampleReader: () async => makeSample(),
    );

    await manager.collectOnce();
    expect(await manager.flush(), isTrue);
    expect(refreshes, [false, true]);
    expect(requests, 2);
    authenticatedClient.close();
  });

  test('localTimezoneOffsetLabel formats offsets', () {
    expect(
      localTimezoneOffsetLabel(DateTime.parse('2026-05-14T18:00:00Z')),
      startsWith('UTC'),
    );
  });
}
