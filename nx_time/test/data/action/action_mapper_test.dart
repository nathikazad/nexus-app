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

    test('reads child ids from nested Action map', () {
      final m = Model.fromJson({
        'id': 1,
        'name': 'Parent',
        'model_type_id': 1,
        'start_time': '2026-04-18T08:00:00.000',
        'end_time': '2026-04-18T12:00:00.000',
        'model_type': {'id': 1, 'name': 'Goto', 'type_kind': 'base'},
        'Action': [
          {
            'id': 7,
            'name': 'Child',
            'model_type_id': 2,
            'start_time': '2026-04-18T09:00:00.000',
            'end_time': '2026-04-18T10:00:00.000',
            'model_type': {'id': 2, 'name': 'Meet', 'type_kind': 'base'},
          },
        ],
      });
      final a = actionFromModel(m);
      expect(a.childActionIds, [7]);
    });

    test('reads child ids and relation ids from relations list', () {
      final m = Model.fromJson({
        'id': 1,
        'name': 'Parent',
        'model_type_id': 1,
        'start_time': '2026-04-18T08:00:00.000',
        'end_time': '2026-04-18T12:00:00.000',
        'model_type': {'id': 1, 'name': 'Goto', 'type_kind': 'base'},
        'relations': [
          {'relation_id': 9001, 'model_id': 7, 'model_type': 'Action'},
        ],
      });
      final a = actionFromModel(m);
      expect(a.childActionIds, [7]);
      expect(a.relationIdByChildId[7], 9001);
    });

    test(
      'nested Action map: keeps relation==child, drops relation==parent',
      () {
        final m = Model.fromJson({
          'id': 100,
          'name': 'Middle',
          'model_type_id': 1,
          'start_time': '2026-04-18T09:00:00.000',
          'end_time': '2026-04-18T10:00:00.000',
          'model_type': {'id': 1, 'name': 'Goto', 'type_kind': 'base'},
          'Action': [
            {
              'id': 7,
              'name': 'A child',
              'model_type_id': 2,
              'relation': 'child',
              'start_time': '2026-04-18T09:10:00.000',
              'end_time': '2026-04-18T09:30:00.000',
              'model_type': {'id': 2, 'name': 'Meet', 'type_kind': 'base'},
            },
            {
              'id': 50,
              'name': 'My parent',
              'model_type_id': 3,
              'relation': 'parent',
              'start_time': '2026-04-18T08:00:00.000',
              'end_time': '2026-04-18T12:00:00.000',
              'model_type': {'id': 3, 'name': 'Workout', 'type_kind': 'base'},
            },
          ],
        });
        final a = actionFromModel(m);
        expect(a.childActionIds, [7]);
      },
    );

    test(
      'relations list: keeps relation==child only and tracks relation ids',
      () {
        final m = Model.fromJson({
          'id': 100,
          'name': 'Middle',
          'model_type_id': 1,
          'start_time': '2026-04-18T09:00:00.000',
          'end_time': '2026-04-18T10:00:00.000',
          'model_type': {'id': 1, 'name': 'Goto', 'type_kind': 'base'},
          'relations': [
            {
              'relation_id': 9001,
              'model_id': 7,
              'model_type': 'Action',
              'relation': 'child',
            },
            {
              'relation_id': 9002,
              'model_id': 50,
              'model_type': 'Action',
              'relation': 'parent',
            },
          ],
        });
        final a = actionFromModel(m);
        expect(a.childActionIds, [7]);
        expect(a.relationIdByChildId.keys.toList(), [7]);
        expect(a.relationIdByChildId[7], 9001);
        expect(a.relationIdByChildId.containsKey(50), isFalse);
      },
    );

    test(
      'relations list: legacy null relation is treated as child (back-compat)',
      () {
        final m = Model.fromJson({
          'id': 100,
          'name': 'Middle',
          'model_type_id': 1,
          'start_time': '2026-04-18T09:00:00.000',
          'end_time': '2026-04-18T10:00:00.000',
          'model_type': {'id': 1, 'name': 'Goto', 'type_kind': 'base'},
          'relations': [
            {'relation_id': 9001, 'model_id': 7, 'model_type': 'Action'},
          ],
        });
        final a = actionFromModel(m);
        expect(a.childActionIds, [7]);
        expect(a.relationIdByChildId[7], 9001);
      },
    );
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

  group('setModelRequestForCreateWithParent', () {
    test('adds Action relation link to parent id', () {
      final start = DateTime(2026, 4, 18, 8, 0);
      final end = DateTime(2026, 4, 18, 9, 0);
      final req = setModelRequestForCreateWithParent(
        Action(
          id: 0,
          name: 'Child block',
          modelTypeId: 2,
          startTime: start,
          endTime: end,
        ),
        'Meet',
        parentActionId: 42,
      );
      expect(req.relations, isNotNull);
      expect(req.relations!.length, 1);
      expect(req.relations!.first.modelType, kActionRelationKey);
      expect(req.relations!.first.link, [42]);
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
