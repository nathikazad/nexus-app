@Tags(['unit'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:nx_db/kgql.dart';
import 'package:test/test.dart' show Tags;

Model _m(Map<String, dynamic>? attrs) => Model(
      id: 1,
      name: 'n',
      modelTypeId: 1,
      attributes: attrs,
    );

void main() {
  group('ModelAttrReads', () {
    test('attrString: string, trim empty to null, preserves non-empty spacing', () {
      expect(_m({'a': 'x'}).attrString('a'), 'x');
      expect(_m({'a': '  '}).attrString('a'), isNull);
      expect(_m({'a': '  hi  '}).attrString('a'), '  hi  ');
      expect(_m({'a': 42}).attrString('a'), '42');
    });

    test('attrString: missing key', () {
      expect(_m({}).attrString('nope'), isNull);
    });

    test('attrInt: int, double rounds, string parse', () {
      expect(_m({'i': 3}).attrInt('i'), 3);
      expect(_m({'i': 3.7}).attrInt('i'), 4);
      expect(_m({'i': '9'}).attrInt('i'), 9);
      expect(_m({'i': null}).attrInt('i'), isNull);
    });

    test('attrDouble: double, int promotes, string parse', () {
      expect(_m({'d': 2.5}).attrDouble('d'), 2.5);
      expect(_m({'d': 4}).attrDouble('d'), 4.0);
      expect(_m({'d': '1.25'}).attrDouble('d'), 1.25);
    });

    test('attrBool: bool and string true/false', () {
      expect(_m({'b': true}).attrBool('b'), isTrue);
      expect(_m({'b': false}).attrBool('b'), isFalse);
      expect(_m({'b': 'TRUE'}).attrBool('b'), isTrue);
      expect(_m({'b': 'false'}).attrBool('b'), isFalse);
      expect(_m({'b': 'maybe'}).attrBool('b'), isNull);
    });

    test('attrDateTime: DateTime passthrough, ISO string, invalid null', () {
      final dt = DateTime.utc(2024, 1, 2);
      expect(_m({'t': dt}).attrDateTime('t'), dt);
      expect(_m({'t': '2024-01-02T00:00:00.000Z'}).attrDateTime('t'), isNotNull);
      expect(_m({'t': 'not-a-date'}).attrDateTime('t'), isNull);
    });
  });
}
