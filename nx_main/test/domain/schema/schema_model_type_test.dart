import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_voice_assistant/domain/schema/schema_model_type.dart';

void main() {
  test('SchemaModelType copyWith updates name', () {
    const t = SchemaModelType(id: 1, name: 'A');
    final u = t.copyWith(name: 'B');
    expect(u.name, 'B');
    expect(u.id, 1);
  });
}
