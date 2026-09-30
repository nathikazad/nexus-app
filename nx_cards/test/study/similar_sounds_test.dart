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
        directions: {StudyCue.fromLanguage, StudyCue.toLanguage},
        groupLimit: 2,
        random: Random(1),
      );
      expect(groups.map((g) => g.label), ['b-write', 'a-write']);
      final full = groups.last;
      expect(full.prompts, hasLength(4));
      expect(full.prompts.map((p) => '${p.cardId}:${p.cue.name}').toSet(), {
        '1:fromLanguage',
        '1:toLanguage',
        '2:fromLanguage',
        '2:toLanguage',
      });
      final sound = manualRecallSession(
        cards,
        sound: true,
        directions: {},
        groupLimit: 1,
      );
      expect(sound.single.label, 'sound-sound');
      expect(sound.single.prompts, hasLength(2));
      expect(
        sound.single.prompts.every((p) => p.cue == StudyCue.fromAudio),
        isTrue,
      );
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
        directions: {StudyCue.fromLanguage},
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
          directions: {StudyCue.fromLanguage},
          groupLimit: 5,
        ),
        isEmpty,
      );
    },
  );
}
