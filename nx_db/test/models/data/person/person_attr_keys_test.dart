@Tags(['unit'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:nx_db/person.dart';
import 'package:test/test.dart' show Tags;

void main() {
  test('legacy Person preference attribute key is stable', () {
    expect(kPersonAttrPreference, 'preference');
  });
}
