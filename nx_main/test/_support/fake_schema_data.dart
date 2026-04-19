import 'package:nexus_voice_assistant/domain/schema/schema_model_type.dart';

/// Minimal [SchemaModelType] for widget / provider overrides in tests.
SchemaModelType fakeSchemaModelType({
  int id = 1,
  String name = 'TestType',
  String? description = 'Desc',
}) {
  return SchemaModelType(
    id: id,
    name: name,
    description: description,
  );
}
