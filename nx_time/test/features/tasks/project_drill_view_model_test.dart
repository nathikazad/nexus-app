import 'package:flutter_test/flutter_test.dart';
import 'package:nx_time/domain/projects/project.dart';
import 'package:nx_time/features/tasks/project_drill_view_model.dart';

void main() {
  test('breadcrumbForProject walks to root', () {
    final all = [
      const Project(id: 1, name: 'Root', modelTypeId: 8, childProjectIds: [2]),
      const Project(id: 2, name: 'Leaf', modelTypeId: 8),
    ];
    final chain = breadcrumbForProject(2, all);
    expect(chain.map((p) => p.name).toList(), ['Root', 'Leaf']);
  });
}
