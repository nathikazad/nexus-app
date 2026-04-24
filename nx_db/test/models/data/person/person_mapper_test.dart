@Tags(['unit'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:nx_db/kgql.dart' show Model;
import 'package:nx_db/person.dart';
import 'package:test/test.dart' show Tags;

void main() {
  test('personFromModel reads id, name, description, and preference', () {
    const kModelTypeColors = 'model_type_colors';
    final m = Model(
      id: 3,
      name: 'Main User',
      modelTypeId: 1,
      description: 'desc',
      attributes: {
        kPersonAttrPreference: {
          kModelTypeColors: {'X': '#ABCDEF'},
          'k': 1,
        },
      },
    );
    final p = personFromModel(m);
    expect(p.id, 3);
    expect(p.name, 'Main User');
    expect(p.description, 'desc');
    final colors = p.preference[kModelTypeColors] as Map<String, dynamic>?;
    expect(colors?['X'], '#ABCDEF');
  });
}
