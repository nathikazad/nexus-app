@Tags(['unit'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:nx_db/account.dart' show AccountProfile;
import 'package:test/test.dart' show Tags;

void main() {
  test('AccountProfile copyWith updates preference', () {
    const p = AccountProfile(
      id: 1,
      name: 'U',
      preferences: <String, dynamic>{'a': 1},
    );
    final q = p.copyWith(preferences: <String, dynamic>{'b': 2});
    expect(q.id, 1);
    expect(q.name, 'U');
    expect(q.preferences['b'], 2);
  });
}
