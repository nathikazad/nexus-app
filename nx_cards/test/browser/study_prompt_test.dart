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
    schedules: {
      for (final direction in StudyCue.values)
        direction: CardSchedule.initial(
          enabled: direction != StudyCue.backToFront,
        ),
      for (final cue in StudyCue.languageDirections)
        cue: const CardSchedule.initial(enabled: true),
    },
    reviewHistory: const <StudyCue, List<CardReview>>{
      StudyCue.meaningToScript: <CardReview>[],
      StudyCue.scriptToMeaning: <CardReview>[],
      StudyCue.scriptToSound: <CardReview>[],
    },
    suspended: false,
  );

  test('v4 directions start independently and audio requires an asset', () {
    expect(card.scheduleFor(StudyCue.soundToMeaning).enabled, isTrue);
    expect(card.scheduleFor(StudyCue.soundToMeaning).reviewCount, 0);
    expect(card.reviewHistoryFor(StudyCue.soundToMeaning), isEmpty);
    expect(
      StudyPrompt(card: card, cue: StudyCue.soundToMeaning).prompt,
      'Listen',
    );
    expect(card.prompts.map((p) => p.cue), StudyCue.languageDirections);
    final disabled = card.copyWith(
      schedules: {
        for (final direction in StudyCue.values)
          direction: CardSchedule.initial(
            enabled: direction != StudyCue.backToFront,
          ),
        ...card.schedules,
        StudyCue.soundToMeaning: const CardSchedule.initial(enabled: false),
        StudyCue.soundToScript: const CardSchedule.initial(enabled: false),
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
  });

  test('language prompts expose each supported cue', () {
    expect(
      StudyPrompt(card: card, cue: StudyCue.meaningToScript).prompt,
      'talent',
    );
    expect(
      StudyPrompt(card: card, cue: StudyCue.scriptToMeaning).prompt,
      'കഴിവ്',
    );
    expect(
      StudyPrompt(card: card, cue: StudyCue.scriptToSound).answer,
      'kazhivu',
    );
  });
}
