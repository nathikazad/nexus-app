import 'package:flutter_test/flutter_test.dart';
import 'package:nx_time/domain/action/action.dart';

void main() {
  test('Action equality', () {
    const a = Action(id: 1, name: 'X', modelTypeId: 2);
    const b = Action(id: 1, name: 'X', modelTypeId: 2);
    const c = Action(id: 2, name: 'X', modelTypeId: 2);
    expect(a, b);
    expect(a, isNot(c));
  });
}
