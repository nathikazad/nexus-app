@Tags(['unit'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:nx_db/nx_db.dart';
import 'package:test/test.dart' show Tags;

void main() {
  group('TG TagSystem toJson', () {
    test('TG3.1 TagSystem.toJson shape', () {
      final ts = TagSystem(
        id: 1,
        name: 'Category',
        isHierarchical: true,
        selectionMode: 'exclusive',
        nodes: [
          TagNode(id: 10, name: 'Food'),
        ],
      );
      final j = ts.toJson();
      expect(j['id'], 1);
      expect(j['name'], 'Category');
      expect(j['is_hierarchical'], true);
      expect(j['selection_mode'], 'exclusive');
      expect(j['nodes'], isA<List>());
    });

    test('TG3.2 TagNode nested toJson', () {
      final n = TagNode(
        id: 1,
        name: 'Root',
        children: [
          TagNode(id: 2, name: 'Leaf'),
        ],
      );
      final j = n.toJson();
      expect(j['children'], isA<List>());
      expect((j['children'] as List).first['name'], 'Leaf');
    });
  });
}
