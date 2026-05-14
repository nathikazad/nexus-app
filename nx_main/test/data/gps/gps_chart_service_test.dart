import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nexus_voice_assistant/data/gps/gps_chart_service.dart';

void main() {
  test('fetchGpsDates parses date list', () async {
    final dates = await fetchGpsDates(
      'https://example.test/',
      '7',
      httpClient: MockClient((request) async {
        expect(request.url.toString(), 'https://example.test/gps/dates');
        expect(request.headers['X-User-Id'], '7');
        return http.Response(
          jsonEncode({
            'dates': ['2026-05-14', 'bad', '2026-05-15'],
          }),
          200,
        );
      }),
    );

    expect(dates, [
      DateTime(2026, 5, 14),
      DateTime(2026, 5, 15),
    ]);
  });

  test('fetchGpsDay parses point list', () async {
    final points = await fetchGpsDay(
      'https://example.test',
      '7',
      DateTime(2026, 5, 14),
      httpClient: MockClient((request) async {
        expect(
          request.url.toString(),
          'https://example.test/gps/day?date=2026-05-14',
        );
        return http.Response(
          jsonEncode({
            'points': [
              {
                'time': '18:00:00',
                'time_iso': '2026-05-14T18:00:00Z',
                'latitude': 37.7749,
                'longitude': -122.4194,
                'accuracy_m': 4.2,
                'speed_mps': 1.1,
                'is_mocked': false,
              },
              {'time': 'bad'},
            ],
          }),
          200,
        );
      }),
    );

    expect(points, hasLength(1));
    expect(points.single.timeHms, '18:00:00');
    expect(points.single.latitude, 37.7749);
    expect(points.single.longitude, -122.4194);
    expect(points.single.accuracyM, 4.2);
    expect(points.single.speedMps, 1.1);
    expect(points.single.isMocked, isFalse);
  });
}
