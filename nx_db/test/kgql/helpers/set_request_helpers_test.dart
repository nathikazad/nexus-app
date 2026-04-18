@Tags(['unit'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:nx_db/kgql.dart';
import 'package:test/test.dart' show Tags;

void main() {
  group('setKgqlCreate', () {
    test('JSON shape for create', () {
      final r = setKgqlCreate(
        modelType: 'Expense',
        name: 'Coffee',
        description: 'Morning',
        attributes: [
          SetModelAttribute(key: 'amount', value: 12.5),
        ],
      );
      expect(r.toJson(), {
        'model_type': 'Expense',
        'name': 'Coffee',
        'description': 'Morning',
        'attributes': [
          {'key': 'amount', 'value': 12.5},
        ],
      });
    });
  });

  group('setKgqlUpdate', () {
    test('with modelType', () {
      final r = setKgqlUpdate(
        id: 7,
        modelType: 'Expense',
        name: 'Tea',
        description: null,
        attributes: [SetModelAttribute(key: 'amount', value: 3)],
      );
      expect(r.toJson(), {
        'id': 7,
        'model_type': 'Expense',
        'name': 'Tea',
        'attributes': [
          {'key': 'amount', 'value': 3},
        ],
      });
    });

    test('without modelType', () {
      final r = setKgqlUpdate(
        id: 7,
        name: 'Tea',
        description: null,
        attributes: const [],
      );
      expect(r.toJson(), {
        'id': 7,
        'name': 'Tea',
        'attributes': <Map<String, dynamic>>[],
      });
      expect(r.toJson().containsKey('model_type'), isFalse);
    });
  });

  group('setKgqlDelete', () {
    test('payload is id + delete: true', () {
      final r = setKgqlDelete(42);
      expect(r.toJson(), {'id': 42, 'delete': true});
    });
  });
}
