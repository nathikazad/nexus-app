@Tags(['unit'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:nx_db/kgql.dart';

void main() {
  group('Relation', () {
    test('parses named relation metadata and attributes', () {
      final relation = Relation.fromJson({
        'relation_id': 42,
        'model_id': 7,
        'model_type': 'Company',
        'name': 'BootLoop',
        'description': 'Company row',
        'relation_name': 'work_for',
        'relation_description': 'Person worked or works for a company',
        'relation_attributes': [
          {'key': 'title', 'value': 'Head of Sales', 'value_type': 'string'},
          {'key': 'start_date', 'value': '2026-01-01T00:00:00Z'},
        ],
      });

      expect(relation.relationId, 42);
      expect(relation.modelId, 7);
      expect(relation.relationName, 'work_for');
      expect(
        relation.relationDescription,
        'Person worked or works for a company',
      );
      expect(relation.relationAttributes?['title'], 'Head of Sales');
      expect(
          relation.relationAttributes?['start_date'], '2026-01-01T00:00:00Z');
    });
  });
}
