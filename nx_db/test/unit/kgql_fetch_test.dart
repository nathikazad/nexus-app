import 'package:flutter_test/flutter_test.dart';
import 'package:nx_db/nx_db.dart';

void main() {
  group('parseKgqlModelsResult', () {
    test('null → empty list', () {
      expect(parseKgqlModelsResult(null), isEmpty);
    });

    test('native list of maps', () {
      final list = parseKgqlModelsResult([
        {'id': 1, 'name': 'A', 'model_type_id': 9},
      ]);
      expect(list.length, 1);
      expect(list.first.id, 1);
      expect(list.first.name, 'A');
    });

    test('JSON string list', () {
      final list = parseKgqlModelsResult(
        '[{"id":2,"name":"B","model_type_id":9}]',
      );
      expect(list.length, 1);
      expect(list.first.name, 'B');
    });

    test('skips non-map entries', () {
      final list = parseKgqlModelsResult([
        {'id': 1, 'name': 'Ok', 'model_type_id': 9},
        'bad',
        3,
      ]);
      expect(list.length, 1);
      expect(list.first.name, 'Ok');
    });
  });
}
