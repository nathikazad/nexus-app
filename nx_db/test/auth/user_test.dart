@Tags(['unit'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:nx_db/auth.dart';
import 'package:test/test.dart' show Tags;

void main() {
  test('User equality', () {
    final a = User(
      userId: '1',
      personalDomainId: 1,
      homeDomainId: 2,
      preset: BackendPreset.laptop,
    );
    final b = User(
      userId: '1',
      personalDomainId: 1,
      homeDomainId: 2,
      preset: BackendPreset.laptop,
    );
    final c = User(
      userId: '2',
      personalDomainId: 1,
      homeDomainId: 2,
      preset: BackendPreset.laptop,
    );
    final d = User(
      userId: '1',
      personalDomainId: 9,
      homeDomainId: 2,
      preset: BackendPreset.laptop,
    );
    expect(a, b);
    expect(a, isNot(c));
    expect(a, isNot(d));
  });
}
