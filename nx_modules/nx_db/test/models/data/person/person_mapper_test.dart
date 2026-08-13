@Tags(['unit'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:nx_db/kgql.dart' show Model;
import 'package:nx_db/person.dart';
import 'package:test/test.dart' show Tags;

void main() {
  test('personFromModel reads id, name, description, and user preference', () {
    const kModelTypeColors = 'model_type_colors';
    final m = Model(
      id: 3,
      name: 'Nathik',
      modelTypeId: 1,
      description: 'desc',
    );
    final p = personFromModel(
      m,
      preference: {
        kModelTypeColors: {'X': '#ABCDEF'},
        'k': 1,
      },
    );
    expect(p.id, 3);
    expect(p.name, 'Nathik');
    expect(p.description, 'desc');
    final colors = p.preference[kModelTypeColors] as Map<String, dynamic>?;
    expect(colors?['X'], '#ABCDEF');
  });
}
