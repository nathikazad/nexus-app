import 'package:flutter_test/flutter_test.dart';
import 'package:nx_time/data/action/action_attr_keys.dart';

void main() {
  test('action attribute keys are stable', () {
    expect(kActionAttrStartTime, 'start_time');
    expect(kActionAttrEndTime, 'end_time');
    expect(kActionAttrDescription, 'description');
  });
}
