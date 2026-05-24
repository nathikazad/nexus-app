import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_voice_assistant/domain/schema/model_type_form_state.dart';
import 'package:nexus_voice_assistant/domain/schema/schema_model_type.dart';

void main() {
  test('fromSchemaModelType copies name and parentName from parent node', () {
    final mt = SchemaModelType(
      id: 2,
      name: 'Child',
      typeKind: 'base',
      description: 'desc',
      agentInstructions: const {'Child': 'Use exact interval fields.'},
      parentId: 1,
      parent: const SchemaModelType(id: 1, name: 'Parent'),
    );
    final f = ModelTypeFormFields.fromSchemaModelType(mt);
    expect(f.name, 'Child');
    expect(f.description, 'desc');
    expect(f.agentInstructions, 'Use exact interval fields.');
    expect(f.typeKind, 'base');
    expect(f.parentId, 1);
    expect(f.parentName, 'Parent');
  });

  test('parentName null when parent node missing', () {
    final mt = SchemaModelType(
      id: 2,
      name: 'Orphan',
      parentId: 99,
    );
    final f = ModelTypeFormFields.fromSchemaModelType(mt);
    expect(f.parentName, isNull);
  });
}
