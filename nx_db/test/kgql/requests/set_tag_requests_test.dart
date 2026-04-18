@Tags(['unit'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:nx_db/nx_db.dart';
import 'package:test/test.dart' show Tags;

void main() {
  group('SetModelTag', () {
    test('R4.1 minimal', () {
      final j = SetModelTag(system: 'Category', nodes: ['Coffee']).toJson();
      expect(j, {'system': 'Category', 'nodes': ['Coffee']});
    });

    test('R4.2 clear', () {
      final j = SetModelTag(system: 'Category', nodes: [], clear: true).toJson();
      expect(j['clear'], true);
    });
  });

  group('SetTagSystemRequest', () {
    test('R4.3 create shape', () {
      final j = SetTagSystemRequest(
        name: 'Judgment',
        isHierarchical: false,
        selectionMode: 'multiple',
        nodes: [
          SetTagNodeRequest(name: 'Unnecessary'),
        ],
      ).toJson();
      expect(j.containsKey('id'), false);
      expect(j['name'], 'Judgment');
    });

    test('R4.4 delete', () {
      final j = SetTagSystemRequest(id: 5, delete: true).toJson();
      expect(j, {'id': 5, 'delete': true});
    });
  });

  group('SetTagNodeRequest', () {
    test('R4.5 nested', () {
      final j = SetTagNodeRequest(
        name: 'Food',
        children: [
          SetTagNodeRequest(
            name: 'Coffee',
            children: [SetTagNodeRequest(name: 'Latte')],
          ),
        ],
      ).toJson();
      expect(j['name'], 'Food');
      expect((j['children'] as List).length, 1);
    });
  });
}
