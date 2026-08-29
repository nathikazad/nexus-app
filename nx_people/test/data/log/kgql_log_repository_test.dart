import 'package:flutter_test/flutter_test.dart';
import 'package:nx_people/data/log/kgql_log_repository.dart';
import 'package:nx_people/domain/log/daily_log.dart';

void main() {
  test('builds a local-calendar-day KGQL range', () {
    expect(dailyLogDayFilter(DateTime(2026, 8, 29, 16, 45)), <String, Object?>{
      'model_type': 'Daily Log',
      'filters': <Map<String, Object?>>[
        <String, Object?>{
          'key': 'logged_at',
          'op': '>=',
          'value': '2026-08-29T00:00:00.000',
        },
        <String, Object?>{
          'key': 'logged_at',
          'op': '<',
          'value': '2026-08-30T00:00:00.000',
        },
      ],
    });
  });

  test('creates the canonical KGQL shape for a text and image log', () {
    final request = dailyLogCreateRequest(
      DailyLogDraft(
        loggedAt: DateTime(2026, 8, 27, 12, 34),
        entry: '  Met at the studio.  ',
        imageUrl: '/images/file?name=260827123400.jpg',
      ),
    ).toJson();

    expect(request['model_type'], 'Daily Log');
    expect(request['name'], 'Log 2026-08-27 12:34');
    expect(request['attributes'], <Map<String, Object?>>[
      <String, Object?>{'key': 'logged_at', 'value': '2026-08-27T12:34:00.000'},
      <String, Object?>{'key': 'entry', 'value': 'Met at the studio.'},
      <String, Object?>{
        'key': 'image_url',
        'value': '/images/file?name=260827123400.jpg',
      },
    ]);
  });

  test('allows image-only logs and rejects empty logs', () {
    final imageOnly = dailyLogCreateRequest(
      DailyLogDraft(
        loggedAt: DateTime(2026, 8, 27),
        imageUrl: '/images/file?name=image.jpg',
      ),
    ).toJson();

    final attributes = imageOnly['attributes']! as List<dynamic>;
    expect(
      attributes.where((item) => (item as Map)['key'] == 'entry'),
      isEmpty,
    );
    expect(
      () =>
          dailyLogCreateRequest(DailyLogDraft(loggedAt: DateTime(2026, 8, 27))),
      throwsArgumentError,
    );
  });
}
