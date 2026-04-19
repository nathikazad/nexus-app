import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nexus_voice_assistant/data/battery/battery_chart_service.dart';

void main() {
  group('fetchBatteryDates', () {
    test('parses dates', () async {
      final mock = MockClient(
        (request) async => http.Response(
          '{"dates":["2024-01-15"]}',
          200,
        ),
      );
      final dates = await fetchBatteryDates(
        'https://host/',
        'u1',
        httpClient: mock,
      );
      expect(dates.single, DateTime(2024, 1, 15));
    });

    test('throws on HTTP error', () async {
      final mock = MockClient((_) async => http.Response('x', 503));
      expect(
        () => fetchBatteryDates('https://h', 'u', httpClient: mock),
        throwsA(isA<BatteryChartException>()),
      );
    });
  });

  group('fetchBatteryDay', () {
    test('parses points', () async {
      final mock = MockClient(
        (request) async => http.Response(
          '''
{"points":[{"time":"12:00:00","battery_pct":80,"voltage_mv":3900,"charging":true}]}
''',
          200,
        ),
      );
      final pts = await fetchBatteryDay(
        'https://h',
        'u',
        DateTime(2024, 6, 1),
        httpClient: mock,
      );
      expect(pts.length, 1);
      expect(pts.single.percent, 80);
      expect(pts.single.charging, true);
      expect(pts.single.voltageMv, 3900);
    });
  });
}
