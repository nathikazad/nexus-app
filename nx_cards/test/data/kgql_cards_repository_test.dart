import 'package:flutter_test/flutter_test.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:nx_cards/data/remote/kgql/card_schema.dart';
import 'package:nx_cards/data/remote/kgql/kgql_cards_repository.dart';
import 'package:nx_cards/domain/cards_models.dart';

void main() {
  test('creates language content as a LanguageFlashcard', () async {
    Request? captured;
    final repository = KgqlCardsRepository(
      _client((request) {
        captured = request;
        return const {
          '__typename': 'Mutation',
          'setKgqlModels': {
            '__typename': 'SetKgqlModelsPayload',
            'json': {'id': 42},
          },
        };
      }),
    );

    final id = await repository.createCard(
      content: const LanguageCardContent(
        english: 'talent',
        originalScript: 'കഴിവ്',
        transliteration: 'kazhivu',
      ),
      deckId: 7,
      tags: const ['Vocabulary'],
    );

    expect(id, 42);
    final input = captured!.variables['input'] as Map<String, dynamic>;
    final data = input['data'] as Map<String, dynamic>;
    expect(data['model_type'], languageCardModelType);
    expect(data['name'], 'talent');
    expect(data['description'], 'കഴിവ്');
    final attributes = data['attributes'] as List<dynamic>;
    final transliteration =
        attributes.singleWhere(
              (row) =>
                  (row as Map<String, dynamic>)['key'] == attrTransliteration,
            )
            as Map<String, dynamic>;
    expect(transliteration['value'], 'kazhivu');
    final schedule =
        attributes.singleWhere(
              (row) => (row as Map<String, dynamic>)['key'] == attrSchedule,
            )
            as Map<String, dynamic>;
    final scheduleValue = schedule['value'] as Map<String, dynamic>;
    expect(
      (scheduleValue['front_to_back'] as Map<String, dynamic>)['enabled'],
      isTrue,
    );
    expect(
      (scheduleValue['back_to_front'] as Map<String, dynamic>)['enabled'],
      isTrue,
    );
  });

  test('maps a LanguageFlashcard response to typed language content', () async {
    final requestedTypes = <String>[];
    final repository = KgqlCardsRepository(
      _client((request) {
        final filter = request.variables['filter'] as Map<String, dynamic>;
        final requestedType = filter['model_type']! as String;
        requestedTypes.add(requestedType);
        return {
          '__typename': 'Query',
          'getKgqlModels': [
            {
              'id': 42,
              'name': 'talent',
              'description': 'കഴിവ്',
              'model_type_id': 67,
              if (requestedType == languageCardModelType)
                'transliteration': 'kazhivu',
              'suspended': false,
              'schedule': {
                'version': 2,
                'algorithm': 'fsrs',
                'front_to_back': _emptySchedule(enabled: true),
                'back_to_front': _emptySchedule(enabled: true),
              },
              'review_history': {
                'version': 2,
                'front_to_back': {'items': <Object?>[]},
                'back_to_front': {'items': <Object?>[]},
              },
              'model_type': {'id': 67, 'name': languageCardModelType},
              'FlashcardDeck': [
                {'id': 7, 'name': 'Malayalam', 'model_type_id': 65},
              ],
              'tags': <String, dynamic>{},
            },
          ],
        };
      }),
    );

    final cards = await repository.listCards();

    expect(cards, hasLength(1));
    expect(cards.single.content, isA<LanguageCardContent>());
    final content = cards.single.content as LanguageCardContent;
    expect(content.english, 'talent');
    expect(content.originalScript, 'കഴിവ്');
    expect(content.transliteration, 'kazhivu');
    expect(
      cards.single.scheduleFor(StudyDirection.frontToBack).enabled,
      isTrue,
    );
    expect(
      cards.single.scheduleFor(StudyDirection.backToFront).enabled,
      isTrue,
    );
    expect(requestedTypes.toSet(), {cardModelType, languageCardModelType});
  });
}

Map<String, Object?> _emptySchedule({required bool enabled}) =>
    <String, Object?>{
      'enabled': enabled,
      'state': 'learning',
      'step': 0,
      'due_at': null,
      'last_reviewed_at': null,
      'stability': null,
      'difficulty': null,
      'review_count': 0,
      'lapse_count': 0,
    };

GraphQLClient _client(Map<String, dynamic> Function(Request) respond) {
  final link = Link.function((request, [forward]) {
    return Stream.value(
      Response(
        response: const {},
        data: respond(request),
        context: request.context,
      ),
    );
  });
  return GraphQLClient(cache: GraphQLCache(), link: link);
}
