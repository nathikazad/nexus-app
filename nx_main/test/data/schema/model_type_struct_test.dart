import 'package:flutter_test/flutter_test.dart';
import 'package:nx_db/nx_db.dart' as nx;
import 'package:nexus_voice_assistant/data/schema/model_type_struct.dart';

void main() {
  test('navigatorKgqlStructForSchema includes id and attribute keys', () {
    final schema = nx.ModelType(
      id: 1,
      name: 'T',
      attributes: [
        nx.AttributeDefinition(key: 'email', valueType: 'string'),
      ],
    );
    final struct = navigatorKgqlStructForSchema(schema);
    expect(struct['id'], isTrue);
    expect(struct['email'], isTrue);
  });
}
