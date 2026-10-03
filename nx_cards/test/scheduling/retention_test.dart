import 'package:flutter_test/flutter_test.dart';
import 'package:nx_cards/browser/browser.dart';
import 'package:nx_cards/scheduling/retention.dart';
import '../study/study_setup_page_test.dart' show sample;

StudyCard scored(int id, List<int> correct) => sample(id, 0).copyWith(
  content: LanguageCardContent(
    english: 'word $id',
    originalScript: '字',
    transliteration: 'zi',
    audioUrl: '/audio',
  ),
  reviewHistory: {
    for (var d = 0; d < 6; d++)
      StudyCue.languageDirections[d]: [
        for (var i = 0; i < 10; i++)
          CardReview(
            id: '$id-$d-$i',
            reviewedAt: DateTime.utc(2026, 1, i + 1),
            rating: i < correct[d] ? 3 : 1,
            elapsedSeconds: 0,
            scheduledSeconds: 0,
          ),
      ],
  },
);
void main() {
  final all = RecallComponent.values.toSet();
  test('Writing off excludes only target script, with no effect on retention', () {
    final card=scored(1,[10,8,6,4,2,0]);
    expect(retentionPrompts([card], all, writing:false).map((p)=>p.cue).toSet(), {
      StudyCue.meaningToSound,StudyCue.soundToMeaning,StudyCue.scriptToMeaning,StudyCue.scriptToSound});
    expect(retentionPrompts([card], {RecallComponent.script}, writing:false).map((p)=>p.cue).toSet(), {
      StudyCue.scriptToMeaning,StudyCue.scriptToSound});
    expect(averageRetention(card,all),.5);
    final spoken=card.copyWith(content:(card.content as LanguageCardContent).copyWith(spokenOnly:true));
    for(final writing in [true,false]) {
      expect(retentionPrompts([spoken],all,writing:writing).map((p)=>p.cue).toSet(), {
        StudyCue.meaningToSound,StudyCue.soundToMeaning});
    }
  });
  test('one component averages all four incident directions', () {
    final card = scored(1, [10, 8, 6, 4, 2, 0]);
    expect(averageRetention(card, all), .5);
    expect(averageRetention(card, [RecallComponent.meaning]), .65);
    expect(averageRetention(card, [RecallComponent.sound]), .5);
    expect(averageRetention(card, [RecallComponent.script]), .35);
  });
  test('two components select six directions once, including script pairs', () {
    final card = scored(1, [10, 8, 6, 4, 2, 0]);
    for (final a in RecallComponent.values) {
      for (final b in RecallComponent.values.where((c) => c != a)) {
        expect(selectedCues(card, [a, b]), StudyCue.languageDirections.toSet());
        expect(averageRetention(card, [a, b]), .5);
      }
    }
  });
  test('27 cards produce 108 or 162 unique directed questions', () {
    final cards = [
      for (var i = 0; i < 27; i++) scored(i, [4, 2, 3, 4, 2, 3]),
    ];
    for (var size = 1; size <= 3; size++) {
      final prompts = retentionPrompts(
        cards,
        RecallComponent.values.take(size).toSet(),
      );
      final count = 27 * (size == 1 ? 4 : 6);
      expect(prompts.length, count);
      expect(prompts.map((p) => (p.cardId, p.cue)).toSet().length, count);
    }
  });
  test('score filters apply before weakest direction ordering', () {
    final cards = [
      scored(1, [4, 2, 3, 4, 2, 3]),
      scored(2, [9, 9, 9, 9, 9, 9]),
    ];
    final prompts = retentionPrompts(cards, all, maximum: .65);
    expect(prompts.map((p) => p.cardId).toSet(), {1});
    expect(prompts.map((p) => p.cue), [
      StudyCue.meaningToScript,
      StudyCue.scriptToMeaning,
      StudyCue.soundToMeaning,
      StudyCue.scriptToSound,
      StudyCue.meaningToSound,
      StudyCue.soundToScript,
    ]);
  });
  test(
    'exactly 80 percent is Strong; disabled directions do not dilute score',
    () {
      final card = scored(1, [8, 8, 8, 8, 8, 8]);
      expect(averageRetention(card, all), .8);
      expect(retentionCards([card], all, weakOnly: true), isEmpty);
      expect(retentionCards([card], all, minimum: .8), [card]);
      final disabled = card.copyWith(
        schedules: {
          ...card.schedules,
          StudyCue.meaningToSound: const CardSchedule.initial(enabled: false),
        },
      );
      expect(averageRetention(disabled, all), .8);
      expect(retentionPrompts([disabled], all).length, 5);
    },
  );
  test('audio source needs a recording; sound target does not', () {
    expect(retentionPrompts([sample(1, 0)], all).map((p) => p.cue).toSet(), {
      StudyCue.meaningToSound,
      StudyCue.meaningToScript,
      StudyCue.scriptToMeaning,
      StudyCue.scriptToSound,
    });
    expect(
      retentionPrompts([
        sample(2, 0, prep: true),
        sample(3, 0, active: false),
        sample(4, 0).copyWith(suspended: true),
      ], all),
      isEmpty,
    );
  });
}
