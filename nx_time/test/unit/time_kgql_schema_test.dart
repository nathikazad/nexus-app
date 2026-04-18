import 'package:flutter_test/flutter_test.dart';
import 'package:nx_db/nx_db.dart';
import 'package:nx_time/data/time_kgql_schema.dart';

void main() {
  group('buildActionActivityStruct', () {
    test('includes core fields and attributes', () {
      final mt = ModelType.fromJson({
        'id': 1,
        'name': 'Action',
        'attributes': [
          {'key': 'start_time', 'value_type': 'datetime'},
          {'key': 'end_time', 'value_type': 'datetime'},
        ],
      });
      final s = buildActionActivityStruct(mt);
      expect(s['id'], true);
      expect(s['model_type_id'], true);
      expect(s['start_time'], true);
      expect(s['end_time'], true);
      expect(s['relations'], isA<Map<String, dynamic>>());
    });

    test('nested relation keys', () {
      final mt = ModelType.fromJson({
        'id': 1,
        'name': 'Action',
        'relations': [
          {'target_model_type': 'Place'},
        ],
      });
      final s = buildActionActivityStruct(mt);
      expect(s['Place'], {'id': true, 'name': true});
    });
  });
}
