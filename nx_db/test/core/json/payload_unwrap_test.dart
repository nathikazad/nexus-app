@Tags(['unit'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:nx_db/nx_db.dart';
import 'package:test/test.dart' show Tags;

void main() {
  group('unwrapJsonList', () {
    test('null → empty', () {
      expect(unwrapJsonList(null), isEmpty);
    });

    test('native list', () {
      expect(unwrapJsonList([1, 2]), [1, 2]);
    });

    test('JSON string list', () {
      final out = unwrapJsonList('[{"a":1}]');
      expect(out.length, 1);
      expect(out.first, {'a': 1});
    });
  });

  group('unwrapJsonMap', () {
    test('null → null', () {
      expect(unwrapJsonMap(null), isNull);
    });

    test('Map<String, dynamic>', () {
      expect(unwrapJsonMap({'x': 1}), {'x': 1});
    });

    test('Map (untyped)', () {
      expect(unwrapJsonMap(<dynamic, dynamic>{'x': 1}), {'x': 1});
    });

    test('JSON string object', () {
      expect(unwrapJsonMap('{"id":7}'), {'id': 7});
    });

    test('non-map string → null', () {
      expect(unwrapJsonMap('"hello"'), isNull);
    });

    test('invalid JSON throws', () {
      expect(() => unwrapJsonMap('{'), throwsFormatException);
    });
  });
}
