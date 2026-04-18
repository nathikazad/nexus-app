import 'package:flutter_test/flutter_test.dart';
import 'package:nx_time/domain/schema/action_schema.dart';

void main() {
  test('ActionSubtypeName is usable as String', () {
    ActionSubtypeName t = 'Meet';
    expect(t, 'Meet');
  });
}
