import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_voice_assistant/data/schema/schema_entity_mappers.dart';
import 'package:nexus_voice_assistant/domain/schema/model_type_form_state.dart';
import 'package:nx_db/kgql.dart' as nx;

void main() {
  test(
      'preserves role names and keeps reverse definitions out of a schema save',
      () {
    final model = nx.ModelType(id: 20, name: 'Book Chapter', relations: [
      nx.RelationshipType(
          id: 7,
          link: 'Book',
          definingModelTypeId: 10,
          relationName: 'book_chapters',
          endpoints: const {
            'book': nx.RelationshipEndpoint(type: 'Book', count: 'one'),
            'chapters':
                nx.RelationshipEndpoint(type: 'Book Chapter', count: 'many'),
          }),
    ]);
    final view = schemaModelTypeFromNx(model);
    final relation = view.relations!.single;
    expect(
        relationDraftToNx(relation).toJson(), model.relations!.single.toJson());
    expect(relation.endpointSummary, contains('chapters: Book Chapter (many)'));
    expect(ModelTypeFormFields.fromSchemaModelType(view).relationshipTypes,
        isEmpty);
  });
}
