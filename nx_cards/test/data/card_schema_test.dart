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
    expect(scheduleJsonSchema['required'], [
      'version',
      'algorithm',
      'front_to_back',
      'back_to_front',
    ]);
    expect(reviewHistoryJsonSchema['required'], [
      'version',
      'front_to_back',
      'back_to_front',
    ]);
    final scheduleProperties =
        scheduleJsonSchema['properties'] as Map<String, dynamic>;
    final historyProperties =
        reviewHistoryJsonSchema['properties'] as Map<String, dynamic>;
    expect(scheduleProperties['version'], {'type': 'integer', 'const': 2});
    expect(historyProperties['version'], {'type': 'integer', 'const': 2});
    expect(
      scheduleProperties['front_to_back'],
      scheduleProperties['back_to_front'],
    );
    expect(
      historyProperties['front_to_back'],
      historyProperties['back_to_front'],
    );
    expect(
      relations.map((row) => row['link']),
      containsAll([deckModelType, bookModelType]),
    );
    expect(systems.single['selection_mode'], 'multiple');
  });

  test('language card inherits Flashcard and adds language-only fields', () {
    final json = buildLanguageCardSchemaRequest().toJson();
    final definitions = json['attribute_definitions'] as List<dynamic>;

    expect(json['name'], languageCardModelType);
    expect(json['parent'], {'link': cardModelType});
    expect(definitions, hasLength(2));
    expect(
      definitions.singleWhere((row) => row['key'] == attrTransliteration),
      {
        'key': attrTransliteration,
        'value_type': 'string',
        'required': true,
        'constraints': {'minLength': 1},
      },
    );
    expect(definitions.singleWhere((row) => row['key'] == attrAudioUrl), {
      'key': attrAudioUrl,
      'value_type': 'string',
      'required': false,
    });
  });
}
