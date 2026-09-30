import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_cards/browser/browser.dart';
import 'package:nx_cards/study/language/similar_sounds.dart';

StudyCard soundCard(
  int id,
  String pinyin, {
  int englishScore = 0,
  int audioScore = 0,
  String language = 'Chinese',
  LearningStatus status = LearningStatus.recall,
}) => StudyCard(
  id: id,
  content: LanguageCardContent(
    english: 'meaning $id',
    originalScript: '字$id',
    transliteration: pinyin,
    audioUrl: '/audio/$id',
  ),
  tags: {
    'Language': [language],
  },
  learningStatus: status,
  suspended: false,
  schedules: {
    for (final cue in StudyCue.activeDirections)
      cue: const CardSchedule.initial(enabled: true),
  },
  reviewHistory: {
    for (final (cue, score) in [
      (StudyCue.fromLanguage, englishScore),
      (StudyCue.fromAudio, audioScore),
    ])
      cue: [
        for (var i = 0; i < score; i++)
          CardReview(
            id: '$id-${cue.name}-$i',
            reviewedAt: DateTime.utc(2026, 9, 1, i),
            rating: 3,
            elapsedSeconds: 0,
            scheduledSeconds: 0,
          ),
      ],
  },
);
void main() {
  test(
    'parses tone marks, numeric tones, joined words and ü without conflating u',
    () {
      expect(parsePinyin('xuéshēng').map((s) => s.key), ['xue2', 'sheng1']);
      expect(parsePinyin("xi1'an1").map((s) => s.key), ['xi1', 'an1']);
      expect(parsePinyin('nu\u0308\u030c').single.key, 'nü3');
      expect(parsePinyin('nv3').single.key, 'nü3');
      expect(parsePinyin('nǔ').single.key, 'nu3');
      expect(parsePinyin('de').single.key, 'de5');
      expect(parsePinyin('not pinyin!'), isEmpty);
    },
  );
  test('matches requested sound contrasts and keeps syllable order', () {
    for (final pair in [
      ('shī', 'shì'),
      ('gǒu', 'hòu'),
      ('gǒu', 'guó'),
      ('yī', 'yě'),
      ('gǒu', 'yǒu'),
      ('yǒu', 'yo'),
    ]) {
      expect(
        pinyinDistance(parsePinyin(pair.$1), parsePinyin(pair.$2)),
        isNotNull,
        reason: '$pair',
      );
    }
    expect(
      pinyinDistance(parsePinyin('xuéshēng'), parsePinyin('shēngxué')),
      isNull,
    );
  });
  test(
    'Current Chinese only; homophones included; guo appears in different groups',
    () {
      final groups = similarSoundGroups([
        soundCard(1, 'guó'),
        soundCard(2, 'guǒ'),
        soundCard(3, 'guò'),
        soundCard(4, 'gǒu'),
        soundCard(5, 'hòu'),
        soundCard(6, 'yóu'),
        soundCard(7, 'yóu'),
        soundCard(8, 'guó', language: 'Tamil'),
        soundCard(9, 'guó', status: LearningStatus.practice),
        soundCard(10, 'guó', status: LearningStatus.future),
      ]);
      expect(
        groups
            .where((g) => g.kind == SimilarSoundKind.syllable)
            .map((g) => g.cards.map((c) => c.id).toSet()),
        containsAll([
          {1, 2, 3},
          {6, 7},
        ]),
      );
      expect(
        groups.where((g) => g.cards.any((c) => c.id == 1)).length,
        greaterThan(1),
      );
      expect(groups.expand((g) => g.cards).any((c) => c.id >= 8), isFalse);
    },
  );
  test('orders by the group average in the selected direction', () {
    final cards = [
      soundCard(1, 'guó', englishScore: 5),
      soundCard(2, 'guǒ', englishScore: 5),
      soundCard(3, 'shī', audioScore: 5),
      soundCard(4, 'shì', audioScore: 5),
    ];
    List<SimilarRecallGroup> select(StudyCue cue) => similarSoundRecallGroups(
      [for (final c in cards) StudyPrompt(card: c, cue: cue)],
      limit: 4,
      random: Random(1),
    );
    expect(
      select(StudyCue.fromLanguage).first.prompts.map((p) => p.cardId),
      unorderedEquals([3, 4]),
    );
    expect(
      select(StudyCue.fromAudio).first.prompts.map((p) => p.cardId),
      unorderedEquals([1, 2]),
    );
  });
  test(
    'count truncates questions but retains the entire final comparison group',
    () {
      final cards = [
        soundCard(1, 'guó'),
        soundCard(2, 'guǒ'),
        soundCard(3, 'shī'),
        soundCard(4, 'shì'),
        soundCard(5, 'shí'),
      ];
      final groups = similarSoundRecallGroups(
        [for (final c in cards) StudyPrompt(card: c, cue: StudyCue.fromAudio)],
        limit: 3,
        random: Random(2),
      );
      expect(groups.map((g) => g.prompts.length), [2, 1]);
      expect(groups.last.comparisonCards, hasLength(3));
      final one = similarSoundRecallGroups([
        for (final c in cards) StudyPrompt(card: c, cue: StudyCue.fromLanguage),
      ], limit: 1);
      expect(one.single.prompts, hasLength(1));
      expect(one.single.comparisonCards, hasLength(2));
    },
  );
  test('same card is asked again in a different contrast group', () {
    final cards = [
      soundCard(1, 'guó'),
      soundCard(2, 'guǒ'),
      soundCard(3, 'gǒu'),
      soundCard(4, 'hòu'),
    ];
    final groups = similarSoundRecallGroups([
      for (final c in cards) StudyPrompt(card: c, cue: StudyCue.fromAudio),
    ], limit: 100);
    expect(
      groups.expand((g) => g.prompts).where((p) => p.cardId == 1).length,
      greaterThan(1),
    );
    for (final g in groups) {
      expect(g.prompts.map((p) => p.cardId).toSet().length, g.prompts.length);
    }
  });
}
