import 'package:flutter_test/flutter_test.dart';
import 'package:nx_cards/browser/browser.dart';
import 'package:nx_cards/scheduling/learning_stage.dart';
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
        for (var i = 0; i < 5; i++)
          CardReview(
            id: '$id-$d-$i',
            reviewedAt: DateTime.utc(
              2026,
              1,
              1,
            ).add(Duration(minutes: d * 10 + i)),
            rating: i < correct[d] ? 3 : 1,
            elapsedSeconds: 0,
            scheduledSeconds: 0,
          ),
      ],
  },
);
void main() {
  final all = RecallComponent.values.toSet();
  test(
    'Sound off excludes both sound directions; writing remains independent',
    () {
      final card = scored(1, [5, 4, 3, 2, 1, 0]);
      expect(
        retentionPrompts([card], all, sound: false).map((p) => p.cue).toSet(),
        {StudyCue.meaningToScript, StudyCue.scriptToMeaning},
      );
      expect(
        retentionPrompts(
          [card],
          all,
          sound: false,
          writing: false,
        ).map((p) => p.cue).toSet(),
        {StudyCue.scriptToMeaning},
      );
      final spoken = card.copyWith(
        content: (card.content as LanguageCardContent).copyWith(
          spokenOnly: true,
        ),
      );
      expect(retentionPrompts([spoken], all, sound: false), isEmpty);
    },
  );
  test(
    'Writing off excludes only script answers and leaves score unchanged',
    () {
      final card = scored(1, [5, 4, 3, 2, 1, 0]);
      final score = averageRetention(card, all);
      expect(
        retentionPrompts([card], all, writing: false).map((p) => p.cue).toSet(),
        {
          StudyCue.meaningToSound,
          StudyCue.soundToMeaning,
          StudyCue.scriptToMeaning,
          StudyCue.scriptToSound,
        },
      );
      expect(
        retentionPrompts(
          [card],
          {RecallComponent.script},
          writing: false,
        ).map((p) => p.cue).toSet(),
        {StudyCue.scriptToMeaning, StudyCue.scriptToSound},
      );
      expect(averageRetention(card, all), score);
    },
  );
  test(
    'overall score averages skills; each skill pools five recent incident reviews',
    () {
      final cues = [
        StudyCue.meaningToSound,
        StudyCue.soundToMeaning,
        StudyCue.meaningToScript,
        StudyCue.scriptToMeaning,
        StudyCue.soundToScript,
        StudyCue.scriptToSound,
        StudyCue.meaningToSound,
        StudyCue.soundToMeaning,
      ];
      final ratings = [3, 3, 1, 3, 1, 3, 3, 1];
      final history = <StudyCue, List<CardReview>>{};
      for (var i = 0; i < cues.length; i++) {
        history
            .putIfAbsent(cues[i], () => [])
            .add(
              CardReview(
                id: 'r$i',
                reviewedAt: DateTime.utc(2026, 1, i + 1),
                rating: ratings[i],
                elapsedSeconds: 0,
                scheduledSeconds: 0,
              ),
            );
      }
      final card = scored(1, [
        0,
        0,
        0,
        0,
        0,
        0,
      ]).copyWith(reviewHistory: history);
      expect(recallScore(card, RecallComponent.meaning).fraction, .6);
      expect(recallScore(card, RecallComponent.sound).fraction, .6);
      expect(recallScore(card, RecallComponent.script).fraction, .4);
      expect(averageRetention(card, all), closeTo(8 / 15, 1e-9));
      expect(
        averageRetention(card, [
          RecallComponent.meaning,
          RecallComponent.script,
        ]),
        .5,
      );
      expect(recallScore(card, null).fraction, averageRetention(card, all));
      expect(recallScore(card, StudyCue.meaningToSound).fraction, .4);
      final spoken = card.copyWith(
        content: (card.content as LanguageCardContent).copyWith(
          spokenOnly: true,
        ),
      );
      expect(averageRetention(spoken, all), .6);
      expect(retentionPrompts([spoken], {RecallComponent.script}), isEmpty);
    },
  );
  test('27 cards produce unique directed questions when skills overlap', () {
    final cards = [
      for (var i = 0; i < 27; i++) scored(i, [4, 2, 3, 4, 2, 3]),
    ];
    for (var size = 1; size <= 3; size++) {
      final prompts = retentionPrompts(
        cards,
        RecallComponent.values.take(size).toSet(),
      );
      expect(prompts.length, 27 * (size == 1 ? 4 : 6));
      expect(
        prompts.map((p) => (p.cardId, p.cue)).toSet().length,
        prompts.length,
      );
    }
  });
  test('Recall filters individual directions, not the overall card score', () {
    final card = scored(1, [0, 0, 0, 0, 5, 5]);
    expect(averageRetention(card, all), greaterThan(0));
    expect(retentionCards([card], all, maximum: 0), isEmpty);
    expect(
      retentionPrompts([card], all, maximum: 0).map((p) => p.cue).toSet(),
      {
        StudyCue.meaningToScript,
        StudyCue.soundToScript,
        StudyCue.meaningToSound,
        StudyCue.soundToMeaning,
      },
    );
    expect(
      retentionPrompts([card], all, minimum: .8).map((p) => p.cue).toSet(),
      {StudyCue.scriptToMeaning, StudyCue.scriptToSound},
    );
  });
  test(
    'range endpoints and 80 percent are exact; disabled directions cannot be queued',
    () {
      final card = scored(1, [4, 4, 4, 4, 4, 4]);
      expect(averageRetention(card, all), .8);
      expect(retentionCards([card], all, weakOnly: true), isEmpty);
      expect(retentionCards([card], all, minimum: .8), [card]);
      expect(
        retentionPrompts([card], all, minimum: .8, maximum: .8),
        hasLength(6),
      );
      final disabled = card.copyWith(
        schedules: {
          ...card.schedules,
          StudyCue.meaningToSound: const CardSchedule.initial(enabled: false),
        },
      );
      expect(retentionPrompts([disabled], all), hasLength(5));
    },
  );
  test(
    'audio source requires recording; inactive or suspended cards are omitted',
    () {
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
    },
  );
}
