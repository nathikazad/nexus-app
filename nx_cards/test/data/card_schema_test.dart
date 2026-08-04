import 'package:flutter_test/flutter_test.dart';
import 'package:nx_cards/data/remote/kgql/card_schema.dart';

void main() {
  test('deck schema includes exclusive language tags', () {
    final json = buildDeckSchemaRequest().toJson();
    final systems = json['tag_systems'] as List<dynamic>;

    expect(json['name'], deckModelType);
    expect(systems.single['name'], deckLanguageTagSystem);
    expect(systems.single['selection_mode'], 'exclusive');
  });

  test('card schema keeps only query fields outside versioned JSON', () {
    final json = buildCardSchemaRequest().toJson();
    final attributes = (json['attribute_definitions'] as List<dynamic>)
        .map((row) => row['key'])
        .toSet();
    final relations = json['relationship_types'] as List<dynamic>;
    final systems = json['tag_systems'] as List<dynamic>;

    expect(attributes, {
      attrDueAt,
      attrSuspended,
      attrSchedule,
      attrReviewHistory,
    });
    final definitions = json['attribute_definitions'] as List<dynamic>;
    for (final key in [attrSchedule, attrReviewHistory]) {
      final definition = definitions.singleWhere((row) => row['key'] == key);
      expect(definition['constraints']['json_schema'], isA<Map>());
    }
    expect(
      relations.map((row) => row['link']),
      containsAll([deckModelType, bookModelType]),
    );
    expect(systems.single['selection_mode'], 'multiple');
  });
}
