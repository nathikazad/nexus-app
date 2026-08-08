import 'package:flutter_test/flutter_test.dart';
import 'package:nx_cards/data/remote/kgql/card_schema.dart';

void main() {
  test('deck schema stores both study languages as attributes', () {
    final json = buildDeckSchemaRequest().toJson();
    final definitions = json['attribute_definitions'] as List<dynamic>;

    expect(json['name'], deckModelType);
    expect(json['tag_systems'], isNull);
    for (final key in [attrFromLanguage, attrToLanguage]) {
      expect(definitions.singleWhere((row) => row['key'] == key), {
        'key': key,
        'value_type': 'string',
        'required': false,
      });
    }
  });

  test('card schema keeps only query fields outside versioned JSON', () {
    final json = buildCardSchemaRequest().toJson();
    final attributes = (json['attribute_definitions'] as List<dynamic>)
        .map((row) => row['key'])
        .toSet();
    final relations = json['relationship_types'] as List<dynamic>;
    final systems = json['tag_systems'] as List<dynamic>;

    expect(attributes, {
      attrCardDetails,
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
    expect(scheduleJsonSchema['required'], ['version', 'algorithm', 'cues']);
    expect(reviewHistoryJsonSchema['required'], ['version', 'items']);
    final scheduleProperties =
        scheduleJsonSchema['properties'] as Map<String, dynamic>;
    final historyProperties =
        reviewHistoryJsonSchema['properties'] as Map<String, dynamic>;
    expect(scheduleProperties['version'], {'type': 'integer', 'const': 3});
    expect(historyProperties['version'], {'type': 'integer', 'const': 3});
    final cues = scheduleProperties['cues'] as Map<String, dynamic>;
    expect(cues['required'], [
      'from_language',
      'to_language',
      'transliteration',
    ]);
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
    expect(definitions, hasLength(1));
    expect(
      definitions.singleWhere((row) => row['key'] == attrLanguageDetails),
      {
        'key': attrLanguageDetails,
        'value_type': 'json',
        'required': true,
        'constraints': {'json_schema': languageDetailsJsonSchema},
      },
    );
  });
}
