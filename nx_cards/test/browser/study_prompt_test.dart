import 'package:flutter_test/flutter_test.dart';
import 'package:nx_cards/browser/browser.dart';

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

  test(
    'legacy language cards start audio fresh and omit cards without audio',
    () {
      expect(card.scheduleFor(StudyCue.fromAudio).enabled, isTrue);
      expect(card.scheduleFor(StudyCue.fromAudio).reviewCount, 0);
      expect(card.reviewHistoryFor(StudyCue.fromAudio), isEmpty);
      expect(StudyPrompt(card: card, cue: StudyCue.fromAudio).prompt, 'Listen');
      expect(card.prompts.map((p) => p.cue), StudyCue.activeDirections);
      final disabled = card.copyWith(
        schedules: {
          ...card.schedules,
          StudyCue.fromAudio: const CardSchedule.initial(enabled: false),
        },
      );
      expect(disabled.prompts.any((p) => p.isListening), isFalse);
      final silent = card.copyWith(
        content: const LanguageCardContent(
          english: 'talent',
          originalScript: 'കഴിവ്',
          transliteration: 'kazhivu',
        ),
      );
      expect(silent.prompts.any((p) => p.isListening), isFalse);
    },
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
