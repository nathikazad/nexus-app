import 'package:flutter_test/flutter_test.dart';
import 'package:nx_cards/domain/cards_models.dart';

void main() {
  final card = StudyCard(
    id: 42,
    content: const LanguageCardContent(
      english: 'talent',
      originalScript: 'കഴിവ്',
      transliteration: 'kazhivu',
      audioUrl: '/cards/audio/talent.mp3',
    ),
    deckId: 7,
    deckName: 'Malayalam',
    tags: const <String>['Vocabulary'],
    schedules: const <StudyDirection, CardSchedule>{
      StudyDirection.frontToBack: CardSchedule.initial(enabled: true),
      StudyDirection.backToFront: CardSchedule.initial(enabled: true),
    },
    reviewHistory: const <StudyDirection, List<CardReview>>{
      StudyDirection.frontToBack: <CardReview>[],
      StudyDirection.backToFront: <CardReview>[],
    },
    suspended: false,
  );

  test('forward language prompt reveals script and language supplements', () {
    final prompt = StudyPrompt(
      card: card,
      direction: StudyDirection.frontToBack,
    );

    expect(prompt.prompt, 'talent');
    expect(prompt.answer, 'കഴിവ്');
    expect(prompt.showLanguageSupplements, isTrue);
  });

  test('reverse language prompt exposes only script before English answer', () {
    final prompt = StudyPrompt(
      card: card,
      direction: StudyDirection.backToFront,
    );

    expect(prompt.prompt, 'കഴിവ്');
    expect(prompt.answer, 'talent');
    expect(prompt.showLanguageSupplements, isFalse);
  });
}
