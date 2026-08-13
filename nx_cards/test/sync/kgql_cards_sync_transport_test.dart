import 'package:flutter_test/flutter_test.dart';
import 'package:gql/language.dart' show printNode;
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:nx_cards/sync/remote/kgql_sync_transport.dart';
import 'package:nx_cards/browser/browser.dart';

void main() {
  test('mutateCard sends the complete JSON scheduling aggregate', () async {
    Request? captured;
    final transport = KgqlCardsSyncTransport(
      _client((request) {
        captured = request;
        return const <String, Object?>{
          '__typename': 'Mutation',
          'mutateCardLibrary': <String, Object?>{
            'status': 'APPLIED',
            'id': 11,
            'updated_at': '2026-08-04T12:00:00Z',
          },
        };
      }),
    );

    final result = await transport.mutateCard(
      _card(),
      clientUpdatedAt: DateTime.utc(2026, 8, 4, 12),
    );

    expect(
      printNode(captured!.operation.document),
      contains('mutateCardLibrary'),
    );
    final data = captured!.variables['data'] as Map<String, dynamic>;
    final attributes = data['attributes'] as List<dynamic>;
    final schedule = attributes.cast<Map<String, dynamic>>().singleWhere(
      (value) => value['key'] == 'schedule',
    );
    final scheduleValue = schedule['value'] as Map<String, dynamic>;
    expect(
      ((scheduleValue['cues'] as Map<String, dynamic>)['from_language']
          as Map<String, dynamic>)['review_count'],
      1,
    );
    expect(
      ((scheduleValue['cues'] as Map<String, dynamic>)['to_language']
          as Map<String, dynamic>)['review_count'],
      0,
    );
    final languageDetails = attributes.cast<Map<String, dynamic>>().singleWhere(
      (value) => value['key'] == 'language_details',
    );
    expect(
      (languageDetails['value'] as Map<String, dynamic>)['examples'],
      isEmpty,
    );
    expect(
      attributes.cast<Map<String, dynamic>>().singleWhere(
        (value) => value['key'] == 'learning_status',
      )['value'],
      LearningStatus.notStarted.storageValue,
    );
    expect(result.status, CardMutationStatus.applied);
    expect(result.status, CardMutationStatus.applied);
  });
}

GraphQLClient _client(Map<String, Object?> Function(Request) respond) {
  final link = Link.function((request, [forward]) {
    return Stream<Response>.value(
      Response(
        response: const <String, Object?>{},
        data: respond(request),
        context: request.context,
      ),
    );
  });
  return GraphQLClient(cache: GraphQLCache(), link: link);
}

StudyCard _card() => StudyCard(
  id: 11,
  content: const LanguageCardContent(
    english: 'talent',
    originalScript: 'കഴിവ്',
    transliteration: 'kazhivu',
    audioUrl: '/cards/audio/1/11.mp3',
    examples: <LanguageExample>[
      LanguageExample(
        text: 'അവന് നല്ല കഴിവുണ്ട്.',
        transliteration: 'avan nalla kazhivundu',
        translation: 'He has good talent.',
      ),
    ],
  ),
  schedules: <StudyCue, CardSchedule>{
    StudyCue.fromLanguage: CardSchedule(
      enabled: true,
      dueAt: DateTime.utc(2026, 8, 5),
      lastReviewedAt: DateTime.utc(2026, 8, 4),
      stability: 3.5,
      difficulty: 5,
      schedulingState: 'review',
      learningStep: null,
      reviewCount: 1,
      lapseCount: 0,
    ),
    StudyCue.toLanguage: const CardSchedule.initial(enabled: true),
    StudyCue.transliteration: const CardSchedule.initial(enabled: true),
  },
  reviewHistory: const <StudyCue, List<CardReview>>{
    StudyCue.fromLanguage: <CardReview>[],
    StudyCue.toLanguage: <CardReview>[],
    StudyCue.transliteration: <CardReview>[],
  },
  suspended: false,
  updatedAt: DateTime.utc(2026, 8, 4),
);
