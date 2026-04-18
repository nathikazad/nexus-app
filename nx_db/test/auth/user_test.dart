@Tags(['unit'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:nx_db/auth.dart';
import 'package:test/test.dart' show Tags;

void main() {
  test('User equality', () {
    final a = User(userId: '1', preset: BackendPreset.laptop);
    final b = User(userId: '1', preset: BackendPreset.laptop);
    final c = User(userId: '2', preset: BackendPreset.laptop);
    expect(a, b);
    expect(a, isNot(c));
  });
}
