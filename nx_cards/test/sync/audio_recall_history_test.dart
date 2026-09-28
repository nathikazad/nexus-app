import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_cards/browser/browser.dart';
import 'package:nx_cards/browser/data/kgql/kgql_card_mapper.dart';
import 'package:nx_cards/browser/data/kgql/kgql_card_schema.dart';
import 'package:nx_cards/scheduling/card_scheduler.dart';
import 'package:nx_cards/scheduling/learning_stage.dart';
import 'package:nx_cards/sync/native/cards_database.dart';
import 'package:nx_cards/sync/native/drift_local_cards_store.dart';
import 'package:nx_db/kgql.dart';
import 'package:nx_offline/nx_offline.dart';

void main() {
  test(
    'legacy JSON gains fresh audio recall and all histories survive storage',
    () async {
      final model = Model(
        id: 1,
        name: 'student',
        modelTypeId: 2,
        modelType: ModelType(id: 2, name: languageCardModelType),
        attributes: {
          attrCardDetails: {'front': 'student', 'back': '学生'},
          attrLanguageDetails: {
            'transliteration': 'xuésheng',
            'audio_url': '/student.mp3',
            'examples': [],
          },
          attrLearningState: 'recall',
          attrSchedule: {
            'version': 3,
            'algorithm': 'fsrs',
            'cues': {
              'from_language': {'enabled': true},
              'to_language': {'enabled': true},
              'transliteration': {'enabled': false},
            },
          },
          attrReviewHistory: {
            'version': 3,
            'items': [
              for (var i = 0; i < 8; i++)
                {
                  'id': 'text-$i',
                  'cue': 'from_language',
                  'rating': 3,
                  'reviewed_at': DateTime.utc(2026, 9, 1 + i).toIso8601String(),
                  'elapsed_seconds': 0,
                  'scheduled_seconds': 60,
                },
            ],
          },
        },
      );
      final old = studyCardFromModel(model)!;
      expect(old.scheduleFor(StudyCue.fromAudio).enabled, isTrue);
      expect(old.reviewHistoryFor(StudyCue.fromAudio), isEmpty);
      expect(learningStage(old, StudyCue.fromLanguage), LearningStage.past);
      expect(learningStage(old, StudyCue.fromAudio), LearningStage.current);
      final graded = FsrsCardScheduler(reviewId: () => 'audio-1')
          .preview(
            StudyPrompt(card: old, cue: StudyCue.fromAudio),
            DateTime.utc(2026, 9, 28),
          )[CardRating.good]!
          .card;
      final db = CardsDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final store = DriftLocalCardsStore(
        database: db,
        account: const AccountIdentity(
          domainId: 1,
          serverId: 'test',
          userId: '1',
          application: 'cards',
        ),
      );
      await store.applyCardSnapshot([graded]);
      final stored = (await store.getCard(1))!;
      expect(stored.reviewHistoryFor(StudyCue.fromLanguage).length, 8);
      expect(stored.reviewHistoryFor(StudyCue.fromAudio).single.id, 'audio-1');
      expect(stored.reviewHistoryFor(StudyCue.toLanguage), isEmpty);
      expect(stored.scheduleFor(StudyCue.fromAudio).reviewCount, 1);
      expect(scheduleJson(stored), scheduleJson(graded));
      expect(reviewHistoryJson(stored), reviewHistoryJson(graded));
      expect(scheduleJson(stored)['cues']['from_audio']['enabled'], isTrue);
    },
  );
}
