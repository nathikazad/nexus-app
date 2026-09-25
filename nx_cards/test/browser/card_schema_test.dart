import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_cards/browser/data/kgql/kgql_card_schema.dart';

void main() {
  for (final invalid in [false, true]) {
    test(
      'schema accepts empty metadata but rejects incompatible constraints: $invalid',
      () async {
        final client = GraphQLClient(
          cache: GraphQLCache(),
          link: Link.function((request, [forward]) async* {
            final name =
                ((request.variables['input'] as Map)['model_types'] as List)
                    .single;
            final schema =
                (name == cardModelType
                        ? buildCardSchemaRequest()
                        : buildLanguageCardSchemaRequest())
                    .toJson();
            yield Response(
              data: {
                '__typename': 'Query',
                'getKgqlModelType': [
                  {
                    'id': name == cardModelType ? 66 : 67,
                    'name': name,
                    if (name == languageCardModelType)
                      'parent': {'id': 66, 'name': cardModelType},
                    'attributes': [
                      for (final attr
                          in schema['attribute_definitions'] as List)
                        {
                          'key': attr['key'],
                          'value_type': attr['value_type'],
                          'required': attr['required'],
                          'metadata': invalid && attr['key'] == attrCardDetails
                              ? {'wrong': true}
                              : attr['constraints'] ?? {},
                        },
                    ],
                    'tag_systems': [],
                  },
                ],
              },
              response: const {},
            );
          }),
        );
        expect((await inspectCardsSchema(client)).ready, !invalid);
      },
    );
  }

  test('card schema keeps only query fields outside versioned JSON', () {
    final json = buildCardSchemaRequest().toJson();
    final attributes = (json['attribute_definitions'] as List<dynamic>)
        .map((row) => row['key'])
        .toSet();
    final relations = json['relationship_types'] as List<dynamic>;

    expect(attributes, {
      attrCardDetails,
      attrDueAt,
      attrLearningState,
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
      (row) => row['key'] == attrLearningState,
    );
    expect(learningStatus['required'], isTrue);
    expect(learningStatus['constraints'], {
      'default': 'future',
      'enum': ['future', 'practice', 'recall'],
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
