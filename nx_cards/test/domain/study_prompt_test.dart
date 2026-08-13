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
    schedules: const <StudyCue, CardSchedule>{
      StudyCue.fromLanguage: CardSchedule.initial(enabled: true),
      StudyCue.toLanguage: CardSchedule.initial(enabled: true),
      StudyCue.transliteration: CardSchedule.initial(enabled: true),
    },
    reviewHistory: const <StudyCue, List<CardReview>>{
      StudyCue.fromLanguage: <CardReview>[],
      StudyCue.toLanguage: <CardReview>[],
      StudyCue.transliteration: <CardReview>[],
    },
    suspended: false,
  );

  test('language prompts expose each supported cue', () {
    expect(
      StudyPrompt(card: card, cue: StudyCue.fromLanguage).prompt,
      'talent',
    );
    expect(StudyPrompt(card: card, cue: StudyCue.toLanguage).prompt, 'കഴിവ്');
    expect(
      StudyPrompt(card: card, cue: StudyCue.transliteration).prompt,
      'kazhivu',
    );
  });
}
