import 'package:flutter_test/flutter_test.dart';
import 'package:nx_cards/browser/data/kgql/kgql_card_schema.dart';

void main() {
  test('card schema keeps only query fields outside versioned JSON', () {
    final json = buildCardSchemaRequest().toJson();
    final attributes = (json['attribute_definitions'] as List<dynamic>)
        .map((row) => row['key'])
        .toSet();
    final relations = json['relationship_types'] as List<dynamic>;

    expect(attributes, {
      attrCardDetails,
      attrDueAt,
      attrLearningStatus,
      attrSuspended,
      attrSchedule,
      attrReviewHistory,
    });
    final definitions = json['attribute_definitions'] as List<dynamic>;
    for (final key in [attrSchedule, attrReviewHistory]) {
      final definition = definitions.singleWhere((row) => row['key'] == key);
      expect(definition['constraints']['json_schema'], isA<Map>());
    }
    final learningStatus = definitions.singleWhere(
      (row) => row['key'] == attrLearningStatus,
    );
    expect(learningStatus['required'], isTrue);
    expect(learningStatus['constraints'], {
      'default': 'not_started',
      'enum': ['not_started', 'learning', 'learnt'],
    });
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
    expect(relations.map((row) => row['link']), contains(bookModelType));
    expect(relations, hasLength(1));
    expect(json['tag_systems'], isNull);
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
