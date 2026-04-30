import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nx_db/nx_db.dart';

void main() {
  group('minutesFromImageFilename', () {
    test('parses YYMMDDHHmmss stem from name query', () {
      final url = 'https://x/img?name=250418143052.jpg&foo=1';
      final m = minutesFromImageFilename(url);
      // stem → HH=14, mm=30, ss=52
      expect(m, closeTo(14 * 60 + 30 + 52 / 60.0, 0.001));
    });

    test('returns null for invalid name', () {
      expect(minutesFromImageFilename('https://x/img'), isNull);
    });
  });

  group('fetchAvailableDates', () {
    test('parses dates and strips trailing slash on base', () async {
      final mock = MockClient((request) async {
        expect(request.url.path, '/images/dates');
        expect(request.url.queryParameters['source'], 'necklace');
        return http.Response('{"dates":["2024-03-01","2024-03-02"]}', 200);
      });
      final dates = await fetchAvailableDates(
        'https://host///',
        'u1',
        'necklace',
        httpClient: mock,
      );
      expect(dates.length, 2);
      expect(dates.first, DateTime(2024, 3, 1));
    });

    test('throws ImageServiceException on bad status', () async {
      final mock = MockClient((request) async => http.Response('err', 500));
      expect(
        () =>
            fetchAvailableDates('https://h', 'u', 'necklace', httpClient: mock),
        throwsA(isA<ImageServiceException>()),
      );
    });
  });

  group('fetchImagesForDay', () {
    test('parses image entries with time from filename', () async {
      final mock = MockClient((request) async {
        return http.Response(
          '''
{"images":[{"url":"https://x/i?name=250418120000.jpg","current_app":"cam"}]}
''',
          200,
        );
      });
      final day = DateTime(2025, 4, 18);
      final images = await fetchImagesForDay(
        'https://h',
        'u',
        'necklace',
        day,
        httpClient: mock,
      );
      expect(images.length, 1);
      expect(images.first.currentApp, 'cam');
      expect(images.first.minutesSinceMidnight, closeTo(12 * 60, 0.001));
    });
  });
}
