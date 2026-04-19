import 'package:flutter_test/flutter_test.dart';
import 'package:nx_time/data/projects/project_attr_keys.dart';

void main() {
  test('project keys are stable', () {
    expect(kProjectModelTypeName, 'Project');
    expect(kProjectRelationKey, 'Project');
    expect(kProjectRelationName, 'has_subproject');
  });
}
