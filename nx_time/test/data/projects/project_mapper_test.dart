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
          },
        ],
      });
      final p = projectFromModel(m);
      expect(p.childProjectIds, [2]);
      expect(p.relationIdByChildId[2], 800);
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
