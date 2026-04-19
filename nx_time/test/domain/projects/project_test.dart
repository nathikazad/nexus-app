import 'package:flutter_test/flutter_test.dart';
import 'package:nx_time/domain/projects/project.dart';

void main() {
  test('Project equality', () {
    const a = Project(
      id: 1,
      name: 'P',
      modelTypeId: 3,
      childProjectIds: [2],
    );
    const b = Project(
      id: 1,
      name: 'P',
      modelTypeId: 3,
      childProjectIds: [2],
    );
    const c = Project(
      id: 1,
      name: 'P',
      modelTypeId: 3,
      childProjectIds: [3],
    );
    expect(a, b);
    expect(a, isNot(c));
  });
}
