import 'package:flutter_test/flutter_test.dart';
import 'package:nx_people/data/meeting/meeting_time.dart';

void main() {
  test(
    'creation timestamps with and without a zone represent the same UTC instant',
    () {
      final expected = DateTime.utc(2026, 10, 9, 2, 7);
      expect(parseMeetingCreatedAt('2026-10-09 02:07:00'), expected);
      expect(parseMeetingCreatedAt('2026-10-09T02:07:00Z'), expected);
      expect(parseMeetingCreatedAt('2026-10-08T19:07:00-07:00'), expected);
      expect(parseMeetingCreatedAt(null), isNull);
      expect(parseMeetingCreatedAt('invalid'), isNull);
    },
  );
}
