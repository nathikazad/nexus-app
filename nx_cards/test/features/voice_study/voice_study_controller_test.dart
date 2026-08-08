import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nx_cards/domain/card/cards_repository.dart';
import 'package:nx_cards/domain/cards_models.dart';
import 'package:nx_cards/domain/scheduling/card_scheduler.dart';
import 'package:nx_cards/features/voice_study/voice_study_controller.dart';
import 'package:nx_live_agent/nx_live_agent.dart';

class _MockCardsRepository extends Mock implements CardsRepository {}

class _FakeLiveAgentTransport implements LiveAgentTransport {
  final eventsController = StreamController<LiveAgentEvent>.broadcast();
  final toolResults = <String, Object?>{};
  final instructions = <String>[];
  List<LiveAgentToolDefinition> connectedTools = const [];
  LiveAgentSpec? connectedSpec;
  int responseRequests = 0;
  int closeRequests = 0;

  @override
  Stream<LiveAgentEvent> get events => eventsController.stream;

  @override
  Future<void> connect({
    required String credential,
    required LiveAgentSpec spec,
    required List<LiveAgentToolDefinition> tools,
  }) async {
    connectedSpec = spec;
    connectedTools = tools;
    eventsController.add(const LiveAgentEvent(LiveAgentEventType.connected));
  }

  void call(String id, String name, Map<String, Object?> arguments) {
    eventsController.add(
      LiveAgentEvent(
        LiveAgentEventType.toolCall,
        toolCall: LiveAgentToolCall(
          callId: id,
          name: name,
          arguments: arguments,
        ),
      ),
    );
  }

  @override
  Future<void> sendInstruction(
    String text, {
    bool requestResponse = true,
  }) async {
    instructions.add(text);
  }

  @override
  Future<void> sendToolResult(String callId, Object? output) async {
    toolResults[callId] = output;
  }

  @override
  Future<void> requestResponse() async => responseRequests += 1;

  @override
  Future<void> cancelResponse() async {}

  @override
  Future<void> setMuted(bool muted) async {}

  @override
  Future<void> close() async => closeRequests += 1;

  @override
  Future<void> dispose() async {
    await eventsController.close();
  }
}

void main() {
  setUpAll(() => registerFallbackValue(_card(99)));

  test('tutor results map to conservative FSRS ratings', () {
    expect(cardRatingForTutorResult('incorrect'), CardRating.again);
    expect(cardRatingForTutorResult('partial'), CardRating.hard);
    expect(cardRatingForTutorResult('correct'), CardRating.good);
    expect(cardRatingForTutorResult('unexpected'), CardRating.again);
  });

  test('assessment saves but examples and advancing remain separate', () async {
    final repository = _MockCardsRepository();
    when(() => repository.saveSchedule(any())).thenAnswer((_) async {});
    final transport = _FakeLiveAgentTransport();
    final controller = VoiceStudyController(
      session: LiveAgentSession(transport: transport),
      repository: repository,
      scheduler: FsrsCardScheduler(reviewId: () => 'review-id'),
      prompts: [
        StudyPrompt(card: _card(1), cue: StudyCue.fromLanguage),
        StudyPrompt(card: _card(2), cue: StudyCue.fromLanguage),
      ],
      deckLanguages: const {7: (from: 'English', to: 'Malayalam')},
      onScheduleSaved: () {},
      now: () => DateTime.utc(2026, 8, 7, 12),
    );

    await controller.start(const StaticLiveAgentCredentialProvider('test-key'));
    expect(transport.connectedSpec?.model, 'gpt-realtime-2.1-mini');
    expect(
      transport.connectedTools.map((tool) => tool.name),
      containsAll([
        'assess_current_card',
        'get_current_examples',
        'advance_card',
      ]),
    );

    transport.call('assess-1', 'assess_current_card', {
      'rating': 'again',
      'heard': 'I do not know',
      'feedback': 'The answer was not recalled.',
    });
    await pumpEventQueue();

    expect(controller.index, 0);
    expect(controller.reviewedCount, 1);
    expect(controller.currentCardAssessed, isTrue);
    expect(controller.assessmentRating, CardRating.again);
    verify(() => repository.saveSchedule(any())).called(1);
    final assessment = transport.toolResults['assess-1'] as Map;
    expect(assessment['answer'], 'കഴിവ്');
    expect(assessment['pronunciation_hint'], 'kazhivu');
    expect(assessment, isNot(contains('answer_transliteration')));

    transport.call('examples-1', 'get_current_examples', const {});
    await pumpEventQueue();
    final examples =
        (transport.toolResults['examples-1'] as Map)['examples'] as List;
    expect(examples, hasLength(1));
    expect((examples.single as Map)['translation'], 'She has talent.');
    expect(controller.index, 0);

    transport.call('advance-1', 'advance_card', const {});
    await pumpEventQueue();
    expect(controller.index, 1);
    expect(controller.currentCardAssessed, isFalse);
    expect(controller.assessmentRating, isNull);

    controller.dispose();
  });

  test('advance is rejected until the current card is assessed', () async {
    final repository = _MockCardsRepository();
    final transport = _FakeLiveAgentTransport();
    final controller = VoiceStudyController(
      session: LiveAgentSession(transport: transport),
      repository: repository,
      scheduler: FsrsCardScheduler(reviewId: () => 'review-id'),
      prompts: [StudyPrompt(card: _card(1), cue: StudyCue.fromLanguage)],
      deckLanguages: const {7: (from: 'English', to: 'Malayalam')},
      onScheduleSaved: () {},
    );
    await controller.start(const StaticLiveAgentCredentialProvider('test-key'));

    transport.call('advance-early', 'advance_card', const {});
    await pumpEventQueue();

    expect(controller.index, 0);
    expect(
      (transport.toolResults['advance-early'] as Map)['reason'],
      'current_card_not_assessed',
    );
    controller.dispose();
  });

  test('recap aggregates performance, usage, and gpt-realtime cost', () async {
    final repository = _MockCardsRepository();
    when(() => repository.saveSchedule(any())).thenAnswer((_) async {});
    final transport = _FakeLiveAgentTransport();
    final controller = VoiceStudyController(
      session: LiveAgentSession(transport: transport),
      repository: repository,
      scheduler: FsrsCardScheduler(reviewId: () => 'review-id'),
      prompts: [StudyPrompt(card: _card(1), cue: StudyCue.fromLanguage)],
      deckLanguages: const {7: (from: 'English', to: 'Malayalam')},
      onScheduleSaved: () {},
    );
    await controller.start(const StaticLiveAgentCredentialProvider('test-key'));

    transport.call('assess-1', 'assess_current_card', {
      'rating': 'hard',
      'heard': 'kazhiv',
      'feedback': 'Nearly correct.',
    });
    transport.eventsController.add(
      const LiveAgentEvent(
        LiveAgentEventType.usage,
        usage: LiveAgentUsage(
          inputTokens: 1100,
          outputTokens: 550,
          inputTextTokens: 1000,
          inputAudioTokens: 100,
          cachedInputTokens: 220,
          cachedInputTextTokens: 200,
          cachedInputAudioTokens: 20,
          outputTextTokens: 500,
          outputAudioTokens: 50,
        ),
      ),
    );
    await pumpEventQueue();

    expect(controller.correctCount, 0);
    expect(controller.partialCount, 1);
    expect(controller.incorrectCount, 0);
    expect(controller.usage.totalTokens, 1650);
    expect(controller.inputCost, closeTo(0.001298, 0.0000001));
    expect(controller.outputCost, closeTo(0.0022, 0.0000001));
    expect(controller.totalCost, closeTo(0.003498, 0.0000001));

    await controller.end();
    expect(controller.phase, VoiceStudyPhase.completed);
    expect(transport.closeRequests, 1);
    controller.dispose();
  });
}

StudyCard _card(int id) => StudyCard(
  id: id,
  content: const LanguageCardContent(
    english: 'talent',
    originalScript: 'കഴിവ്',
    transliteration: 'kazhivu',
    examples: [
      LanguageExample(
        text: 'അവൾക്ക് കഴിവുണ്ട്.',
        transliteration: 'avalkku kazhivundu',
        translation: 'She has talent.',
      ),
    ],
  ),
  deckId: 7,
  deckName: 'Malayalam basics',
  schedules: const {
    StudyCue.fromLanguage: CardSchedule.initial(enabled: true),
    StudyCue.toLanguage: CardSchedule.initial(enabled: false),
    StudyCue.transliteration: CardSchedule.initial(enabled: false),
  },
  reviewHistory: const {
    StudyCue.fromLanguage: <CardReview>[],
    StudyCue.toLanguage: <CardReview>[],
    StudyCue.transliteration: <CardReview>[],
  },
  suspended: false,
);
