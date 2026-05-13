import 'package:flutter_test/flutter_test.dart';
import 'package:nx_time/domain/projects/project.dart';

void main() {
  test('Project equality', () {
    const a = Project(id: 1, name: 'P', modelTypeId: 3, childProjectIds: [2]);
    const b = Project(id: 1, name: 'P', modelTypeId: 3, childProjectIds: [2]);
    const c = Project(id: 1, name: 'P', modelTypeId: 3, childProjectIds: [3]);
    expect(a, b);
    expect(a, isNot(c));
  });

  test('Project.copyWith', () {
    const p = Project(id: 1, name: 'A', modelTypeId: 3);
    final q = p.copyWith(name: 'B');
    expect(q.name, 'B');
    expect(q.id, 1);
  });
}
