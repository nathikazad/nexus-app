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
  test('only explicit matching suffixes qualify; no phonetic fallback', () {
    final cards = [
      soundCard(1, 'shī', groups: ['shi-sound']),
      soundCard(2, 'shì', groups: ['shi-sound', 'contrast-write']),
      soundCard(3, 'shí'),
      soundCard(4, 'zǐ', groups: ['contrast-write']),
      soundCard(5, 'le', groups: ['unsuffixed']),
    ];
    for (final cue in StudyCue.activeDirections) {
      final groups = similarSoundRecallGroups([
        for (final c in cards) StudyPrompt(card: c, cue: cue),
      ], limit: 100);
      expect(
        groups.single.label,
        cue == StudyCue.fromAudio ? 'shi-sound' : 'contrast-write',
      );
      expect(
        groups.single.prompts.map((p) => p.cardId),
        unorderedEquals(cue == StudyCue.fromAudio ? [1, 2] : [2, 4]),
      );
    }
  });
  test(
    'manual groups retain overlap and partial comparisons, ordered weakest first',
    () {
      final cards = [
        soundCard(1, 'guó', groups: ['strong-sound'], audioScore: 5),
        soundCard(2, 'guǒ', groups: ['strong-sound'], audioScore: 5),
        soundCard(3, 'shī', groups: ['weak-sound', 'overlap-sound']),
        soundCard(4, 'shì', groups: ['weak-sound']),
        soundCard(5, 'shí', groups: ['weak-sound']),
      ];
      final candidates = [
        for (final c in cards) StudyPrompt(card: c, cue: StudyCue.fromAudio),
      ];
      final groups = similarSoundRecallGroups(
        candidates,
        limit: 2,
        random: Random(1),
      );
      expect(groups.first.label, 'weak-sound');
      expect(groups.single.prompts, hasLength(2));
      expect(groups.single.comparisonCards, hasLength(3));
      expect(
        groups.last.comparisonCards.length,
        greaterThanOrEqualTo(groups.last.prompts.length),
      );
      final all = similarSoundRecallGroups(candidates, limit: 100);
      expect(all.last.label, 'strong-sound');
      expect(
        all.expand((g) => g.prompts).where((p) => p.cardId == 3),
        hasLength(2),
      );
      expect(
        similarSoundRecallGroups([
          candidates.first,
          StudyPrompt(card: cards.last, cue: StudyCue.fromLanguage),
        ], limit: 10),
        isEmpty,
      );
    },
  );
}
