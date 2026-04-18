@Tags(['unit'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:nx_db/internal.dart';
import 'package:test/test.dart' show Tags;

void main() {
  group('modelJsonInt', () {
    test('null uses fallback', () {
      expect(modelJsonInt(null, 3), 3);
    });

    test('int', () {
      expect(modelJsonInt(5), 5);
    });

    test('double rounds', () {
      expect(modelJsonInt(3.7), 4);
    });

    test('string parses', () {
      expect(modelJsonInt('12'), 12);
    });

    test('bad string uses fallback', () {
      expect(modelJsonInt('x', 0), 0);
    });
  });

  group('jsonIntNullable', () {
    test('null', () {
      expect(jsonIntNullable(null), isNull);
    });

    test('string', () {
      expect(jsonIntNullable('9'), 9);
    });
  });

  group('parseOptionalStringField', () {
    test('null', () {
      expect(parseOptionalStringField(null), isNull);
    });

    test('string', () {
      expect(parseOptionalStringField(' hi '), ' hi ');
    });

    test('list joins lines', () {
      expect(parseOptionalStringField(['a', '', 'b']), 'a\nb');
    });

    test('empty list parts → null', () {
      expect(parseOptionalStringField(['', '  ']), isNull);
    });

    test('other → toString', () {
      expect(parseOptionalStringField(42), '42');
    });
  });
}
