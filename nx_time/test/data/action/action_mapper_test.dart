import 'package:flutter_test/flutter_test.dart';
import 'package:nx_db/kgql.dart';
import 'package:nx_time/data/action/action_attr_keys.dart';
import 'package:nx_time/data/action/action_mapper.dart';
import 'package:nx_time/domain/action/action.dart';

void main() {
  group('actionFromModel', () {
    test('reads flat datetime fields into Action', () {
      final m = Model.fromJson({
        'id': 42,
        'name': 'Run',
        'model_type_id': 9,
        'start_time': '2026-04-18T08:00:00.000',
        'end_time': '2026-04-18T09:15:00.000',
        'model_type': {'id': 9, 'name': 'Workout', 'type_kind': 'base'},
      });
      final a = actionFromModel(m);
      expect(a.id, 42);
      expect(a.name, 'Run');
      expect(a.modelTypeName, 'Workout');
      expect(a.startTime!.hour, 8);
      expect(a.endTime!.minute, 15);
    });

    test('maps description from top-level field', () {
      final m = Model.fromJson({
        'id': 1,
        'name': 'X',
        'model_type_id': 1,
        'description': '  hello  ',
        'start_time': '2026-04-18T08:00:00.000',
        'end_time': '2026-04-18T09:00:00.000',
        'model_type': {'id': 1, 'name': 'Meet', 'type_kind': 'base'},
      });
      final a = actionFromModel(m);
      expect(a.description, '  hello  ');
    });
  });

  group('setModelRequestForCreate', () {
    test('includes interval attributes', () {
      final start = DateTime(2026, 4, 18, 8, 0);
      final end = DateTime(2026, 4, 18, 9, 0);
      final req = setModelRequestForCreate(
        Action(
          id: 0,
          name: 'Block',
          modelTypeId: 1,
          startTime: start,
          endTime: end,
        ),
        'Meet',
      );
      expect(req.modelType, 'Meet');
      final keys = req.attributes!.map((a) => a.key).toSet();
      expect(keys, containsAll([kActionAttrStartTime, kActionAttrEndTime]));
    });
  });

  group('setModelRequestForUpdate', () {
    test('passes id and optional model type', () {
      final start = DateTime(2026, 4, 18, 8, 0);
      final end = DateTime(2026, 4, 18, 9, 0);
      final req = setModelRequestForUpdate(
        Action(
          id: 55,
          name: 'Block',
          modelTypeId: 1,
          startTime: start,
          endTime: end,
        ),
        modelTypeNameIfChanged: 'Sleep',
      );
      expect(req.id, 55);
      expect(req.modelType, 'Sleep');
    });
  });

  test('setModelRequestForDelete marks delete', () {
    final req = setModelRequestForDelete(99);
    expect(req.id, 99);
    expect(req.delete, isTrue);
  });
}
