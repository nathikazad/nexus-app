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
      closeTo(1, 1e-9),
    );
    expect(
      similarWordRetention(chinese, SimilarGroupKind.written),
      closeTo(.6, 1e-9),
    );
    expect(similarGroupRetention(group), closeTo(.8, 1e-9));
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
}
