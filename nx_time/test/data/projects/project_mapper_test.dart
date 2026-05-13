import 'package:flutter_test/flutter_test.dart';
import 'package:nx_db/kgql.dart';
import 'package:nx_time/data/projects/project_attr_keys.dart';
import 'package:nx_time/data/projects/project_mapper.dart';
import 'package:nx_time/domain/projects/project.dart';

void main() {
  group('projectFromModel', () {
    test('reads nested Project children', () {
      final m = Model.fromJson({
        'id': 1,
        'name': 'Root',
        'model_type_id': 3,
        'model_type': {'id': 3, 'name': 'Project', 'type_kind': 'base'},
        'Project': [
          {
            'id': 2,
            'name': 'Sub',
            'model_type_id': 3,
            'model_type': {'id': 3, 'name': 'Project', 'type_kind': 'base'},
          },
        ],
      });
      final p = projectFromModel(m);
      expect(p.childProjectIds, [2]);
    });

    test('relation ids from relations list', () {
      final m = Model.fromJson({
        'id': 1,
        'name': 'Root',
        'model_type_id': 3,
        'model_type': {'id': 3, 'name': 'Project', 'type_kind': 'base'},
        'relations': [
          {
            'relation_id': 800,
            'model_id': 2,
            'model_type': 'Project',
            'relation': 'child',
          },
        ],
      });
      final p = projectFromModel(m);
      expect(p.childProjectIds, [2]);
      expect(p.relationIdByChildId[2], 800);
    });

    test('parent and children from relations list using relation field', () {
      final m = Model.fromJson({
        'id': 10,
        'name': 'Mid',
        'model_type_id': 3,
        'model_type': {'id': 3, 'name': 'Project', 'type_kind': 'base'},
        'relations': [
          {
            'relation_id': 100,
            'model_id': 5,
            'model_type': 'Project',
            'relation': 'parent',
          },
          {
            'relation_id': 200,
            'model_id': 20,
            'model_type': 'Project',
            'relation': 'child',
          },
          {
            'relation_id': 201,
            'model_id': 21,
            'model_type': 'Project',
            'relation': 'child',
          },
        ],
      });
      final p = projectFromModel(m);
      expect(p.parentProjectId, 5);
      expect(p.childProjectIds, [20, 21]);
      expect(p.relationIdByChildId[20], 200);
      expect(p.relationIdByChildId[21], 201);
    });

    test('nested Project uses attributes.relation for parent/child', () {
      final m = Model.fromJson({
        'id': 10,
        'name': 'Mid',
        'model_type_id': 3,
        'model_type': {'id': 3, 'name': 'Project', 'type_kind': 'base'},
        'Project': [
          {'id': 5, 'name': 'Root', 'model_type_id': 3, 'relation': 'parent'},
          {'id': 20, 'name': 'Leaf', 'model_type_id': 3, 'relation': 'child'},
        ],
      });
      final p = projectFromModel(m);
      expect(p.parentProjectId, 5);
      expect(p.childProjectIds, [20]);
    });
  });

  group('setModelRequestForCreateProject', () {
    test('links parent project', () {
      final req = setModelRequestForCreateProject(
        const Project(id: 0, name: 'Sub', modelTypeId: 3),
        parentProjectId: 99,
      );
      expect(req.modelType, kProjectModelTypeName);
      expect(req.relations!.single.modelType, kProjectRelationKey);
      expect(req.relations!.single.link, [99]);
    });
  });

  test('setModelRequestForDeleteProject', () {
    final req = setModelRequestForDeleteProject(5);
    expect(req.id, 5);
    expect(req.delete, isTrue);
  });
}
