import 'package:flutter_test/flutter_test.dart';
import 'package:nx_db/kgql.dart';
import 'package:nx_time/data/action/planning_schema.dart';

void main() {
  test(
    'discovers custom and inherited Plannable types without a name list',
    () {
      final root = ModelType(
        id: 1,
        name: 'Action',
        children: [
          ModelType(
            id: 2,
            name: 'Custom appointment',
            typeKind: 'base',
            mixins: [ModelType(id: 3, name: 'Plannable', typeKind: 'mixin')],
            children: [
              ModelType(id: 4, name: 'Special appointment', typeKind: 'base'),
            ],
          ),
          ModelType(id: 5, name: 'Work', typeKind: 'base'),
        ],
      );
      expect(plannableTypeNames(root), {
        'Custom appointment',
        'Special appointment',
      });
    },
  );
}
