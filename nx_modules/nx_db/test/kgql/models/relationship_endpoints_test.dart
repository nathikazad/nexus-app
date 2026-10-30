import 'package:flutter_test/flutter_test.dart';
import 'package:nx_db/kgql.dart';

void main() {
  Map<String, dynamic> schema(String name, String target) => {
    'id': 1,
    'name': name,
    'relations': [
      {
        'id': 7,
        'target_model_type': target,
        'name': 'book_chapters',
        'defining_model_type_id': 10,
        'endpoints': {
          'book': {'type': 'Book', 'count': 'one'},
          'chapters': {'type': 'Book Chapter', 'count': 'many'},
        },
      },
    ],
  };
  test('reads each target role count, independent of endpoint ordering', () {
    final book = ModelType.fromJson(schema('Book', 'Book Chapter'));
    final chapter = ModelType.fromJson(schema('Book Chapter', 'Book'));
    expect(book.relations!.single.targetEndpoint!.value.count, 'many');
    expect(chapter.relations!.single.targetEndpoint!.value.count, 'one');
    expect(chapter.relations!.single.definingModelTypeId, 10);
  });
  test('schema serialization preserves names, roles and ownership', () {
    final first = ModelType.fromJson(schema('Book', 'Book Chapter'));
    final second = ModelType.fromJson(first.toJson());
    expect(second.relations!.single.toJson(), first.relations!.single.toJson());
    expect(second.relations!.single.definingModelTypeId, 10);
    expect(
      second.relations!.single.toJson().containsKey('multiplicity'),
      isFalse,
    );
    expect(second.relations!.single.toJson()['name'], 'book_chapters');
  });
  test('self relations require the caller to choose a role', () {
    final relation = RelationshipType(
      link: 'Task',
      endpoints: const {
        'parent': RelationshipEndpoint(type: 'Task', count: 'one'),
        'children': RelationshipEndpoint(type: 'Task', count: 'many'),
      },
    );
    expect(relation.targetEndpoint, isNull);
    expect((relation.toJson()['endpoints'] as Map).keys, [
      'parent',
      'children',
    ]);
  });
  test('rejects malformed counts and incomplete endpoint definitions', () {
    expect(
      () => const RelationshipEndpoint(type: 'Task', count: 'some').toJson(),
      throwsArgumentError,
    );
    expect(
      () => RelationshipType(
        endpoints: const {
          'parent': RelationshipEndpoint(type: 'Task', count: 'one'),
        },
      ).toJson(),
      throwsArgumentError,
    );
  });
}
