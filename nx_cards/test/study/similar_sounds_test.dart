import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_cards/browser/browser.dart';
import 'package:nx_cards/study/language/similar_sounds.dart';

StudyCard soundCard(
  int id,
  String pinyin, {
  List<String> groups = const [],
  int englishScore = 0,
  int audioScore = 0,
  String language = 'Chinese',
  LearningStatus status = LearningStatus.recall,
}) => StudyCard(
  id: id,
  content: LanguageCardContent(
    similarWordGroups: groups,
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
    for (final direction in StudyCue.values)
      direction: CardSchedule.initial(
        enabled: direction != StudyCue.backToFront,
      ),
    for (final cue in StudyCue.languageDirections)
      cue: const CardSchedule.initial(enabled: true),
  },
  reviewHistory: {
    for (final (cue, score) in [
      (StudyCue.meaningToScript, englishScore),
      (StudyCue.soundToMeaning, audioScore),
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
    'tied group rounds are sampled before the limit with independent front scores',
    () {
      final cards = [
        for (var i = 1; i <= 20; i++)
          soundCard(i, 'word', groups: ['group-$i-write']),
      ];
      final selections = <String>{};
      for (var seed = 0; seed < 8; seed++) {
        final rounds = manualRecallSession(
          cards,
          sound: false,
          directions: {RecallComponent.meaning, RecallComponent.script},
          groupLimit: 3,
          random: Random(seed),
        );
        expect(rounds, hasLength(3));
        selections.add(
          rounds
              .map((g) => '${g.label}:${g.prompts.single.cue.name}')
              .join(','),
        );
      }
      expect(selections, hasLength(8));
      final one = soundCard(100, 'a', englishScore: 5, groups: ['one-write']);
      final weakest = manualRecallSession(
        [one],
        sound: false,
        directions: {RecallComponent.meaning, RecallComponent.script},
        groupLimit: 1,
        random: Random(1),
      );
      expect(weakest.single.prompts.single.cue, StudyCue.scriptToMeaning);
    },
  );

  test('Written averages both text fronts for words, groups and sorting', () {
    final english = soundCard(1, 'a', englishScore: 5);
    final chinese = soundCard(2, 'b', englishScore: 3);
    final both = english.copyWith(
      reviewHistory: {
        ...english.reviewHistory,
        StudyCue.scriptToMeaning: chinese.reviewHistoryFor(
          StudyCue.meaningToScript,
        ),
      },
    );
    final group = SimilarSoundGroup([both, chinese], label: 'pair-write');
    expect(
      similarWordRetention(both, SimilarGroupKind.written),
      closeTo(.2, 1e-9),
    );
    expect(
      similarWordRetention(chinese, SimilarGroupKind.written),
      closeTo(.075, 1e-9),
    );
    expect(similarGroupRetention(group), closeTo(.1375, 1e-9));
    final reverseOnly = english.copyWith(
      reviewHistory: {
        StudyCue.scriptToMeaning: english.reviewHistoryFor(
          StudyCue.meaningToScript,
        ),
      },
    );
    expect(
      sortedSimilarGroups([
        SimilarSoundGroup([reverseOnly], label: 'reverse-write'),
        SimilarSoundGroup([chinese], label: 'english-write'),
      ]).map((g) => g.label),
      ['english-write', 'reverse-write'],
    );
  });

  test(
    'browsing uses direction-specific averages and strips only category suffixes',
    () {
      final cards = [
        soundCard(1, 'a', groups: ['a-write', 'a-sound'], englishScore: 5),
        soundCard(2, 'b', groups: ['b-write', 'b-sound'], audioScore: 5),
        soundCard(3, 'c', groups: ['a-write', 'a-sound'], englishScore: 5),
      ];
      final groups = manualSimilarSoundGroups(cards);
      expect(
        sortedSimilarGroups(
          groups.where((g) => g.kind == SimilarGroupKind.written),
        ).map((g) => g.label),
        ['b-write', 'a-write'],
      );
      expect(
        sortedSimilarGroups(
          groups.where((g) => g.kind == SimilarGroupKind.sound),
        ).map((g) => g.label),
        ['a-sound', 'b-sound'],
      );
      expect(similarGroupTitle('particle-other'), 'particle');
      expect(similarGroupTitle('unknown-suffix'), 'unknown-suffix');
      expect(similarGroupKind('particle-other'), SimilarGroupKind.other);
    },
  );
  test('word details excludes peers outside Current', () {
    final word = soundCard(1, 'a', groups: ['one-write', 'two-other']);
    final peer = soundCard(
      2,
      'b',
      groups: ['one-write'],
      status: LearningStatus.future,
    );
    final groups = similarGroupsForCard(word, [word, peer]);
    expect(groups.map((g) => g.label), ['one-write', 'two-other']);
    expect(groups.first.cards.map((c) => c.id), equals([1]));
  });

  test(
    'whole groups support both written cues and automatic audio without retention cutoff',
    () {
      final cards = [
        soundCard(
          1,
          'shī',
          groups: ['a-write', 'sound-sound'],
          englishScore: 10,
        ),
        soundCard(
          2,
          'shì',
          groups: ['a-write', 'sound-sound'],
          englishScore: 10,
        ),
        soundCard(3, 'shí', groups: ['b-write']),
        soundCard(4, 'shí'),
      ];
      final groups = manualRecallSession(
        cards,
        sound: false,
        directions: {RecallComponent.meaning, RecallComponent.script},
        groupLimit: 12,
        random: Random(1),
      );
      expect(groups, hasLength(12));
      for (final group in groups) {
        expect(group.prompts.map((p) => p.cue).toSet(), hasLength(1));
      }
      final full = groups.where((g) => g.label == 'a-write');
      expect(full, hasLength(6));
      expect(
        full
            .expand((g) => g.prompts)
            .map((p) => '${p.cardId}:${p.cue.name}')
            .toSet(),
        {
          for (final id in [1, 2])
            for (final cue in StudyCue.languageDirections) '$id:${cue.name}',
        },
      );
      final weakest = manualRecallSession(
        cards,
        sound: false,
        directions: {RecallComponent.meaning},
        groupLimit: 1,
        random: Random(4),
      );
      expect(
        weakest.single.prompts.every((p) => p.reviewHistory.isEmpty),
        isTrue,
      );
      final sound = manualRecallSession(
        cards,
        sound: true,
        directions: {},
        groupLimit: 1,
      );
      expect(sound.single.label, 'sound-sound');
      expect(sound.single.prompts, hasLength(2));
      expect(sound.single.prompts.every((p) => p.cue.isListening), isTrue);
    },
  );
  test(
    'manual groups work across languages and no membership means no session',
    () {
      final cards = [
        soundCard(1, 'anything', language: 'Tamil', groups: ['pair-write']),
        soundCard(2, 'anything', language: 'Tamil', groups: ['pair-write']),
        soundCard(
          3,
          'anything',
          language: 'Tamil',
          groups: ['pair-write'],
          status: LearningStatus.future,
        ),
      ];
      final groups = manualRecallSession(
        cards,
        sound: false,
        directions: {RecallComponent.meaning},
        groupLimit: 1,
      );
      expect(
        groups.single.prompts.map((p) => p.cardId),
        unorderedEquals([1, 2]),
      );
      expect(
        manualRecallSession(
          [soundCard(4, 'anything')],
          sound: false,
          directions: {RecallComponent.meaning},
          groupLimit: 5,
        ),
        isEmpty,
      );
    },
  );
}
