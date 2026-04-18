import 'package:flutter_test/flutter_test.dart';
import 'package:nx_time/domain/action/action_category.dart';

void main() {
  test('equality', () {
    const a = ActionCategory(modelTypeId: 1, name: 'Meet');
    const b = ActionCategory(modelTypeId: 1, name: 'Meet');
    const c = ActionCategory(modelTypeId: 2, name: 'Meet');
    expect(a, b);
    expect(a, isNot(c));
  });
}
