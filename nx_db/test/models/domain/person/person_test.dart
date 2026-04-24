@Tags(['unit'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:nx_db/person.dart' show Person;
import 'package:test/test.dart' show Tags;

void main() {
  test('Person copyWith updates preference', () {
    const p = Person(
      id: 1,
      name: 'U',
      preference: <String, dynamic>{'a': 1},
    );
    final q = p.copyWith(preference: <String, dynamic>{'b': 2});
    expect(q.id, 1);
    expect(q.name, 'U');
    expect(q.preference['b'], 2);
  });
}
