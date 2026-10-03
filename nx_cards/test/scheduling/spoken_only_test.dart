import 'package:nx_cards/sync/native/native_card_library.dart';
import 'package:nx_cards/sync/card_synchronizer.dart';
import 'package:nx_cards/scheduling/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_cards/browser/browser.dart';
import 'package:nx_cards/browser/data/kgql/kgql_card_mapper.dart';
import 'package:nx_cards/progress/progress_analysis.dart';
import 'package:nx_cards/scheduling/learning_stage.dart';
import 'package:nx_cards/scheduling/retention.dart';
import 'package:nx_cards/scheduling/card_scheduler.dart';
import 'package:nx_cards/sync/native/cards_database.dart';
import 'package:nx_cards/sync/native/drift_local_cards_store.dart';
import 'package:nx_cards/sync/remote/cards_sync_transport.dart';
import 'package:drift/native.dart';
import 'package:nx_offline/nx_offline.dart' hide SystemClock;
import 'package:nx_db/kgql.dart';

StudyCard spokenCard({bool? spokenOnly}) => studyCardFromModel(
  Model(
    id: 1,
    name: 'house',
    modelTypeId: 2,
    modelType: ModelType(id: 2, name: 'LanguageFlashcard'),
    attributes: {
      'card_details': {'front': 'house', 'back': '家'},
      'language_details': {'transliteration': 'jiā', 'audio_url': '/house.mp3'},
      'spoken_only': ?spokenOnly,
      'learning_state': 'recall',
      'schedule': {
        'version': 4,
        'cues': {
          for (final cue in StudyCue.languageDirections)
            cue.storageKey: {
              'enabled': true,
              'due_at': cue == StudyCue.scriptToMeaning
                  ? '2026-09-01T00:00:00Z'
                  : '2026-10-01T00:00:00Z',
            },
        },
      },
      'review_history': {
        'version': 4,
        'items': [
          for (final cue in StudyCue.languageDirections)
            for (var i = 1; i <= 5; i++)
              {
                'id': '${cue.name}-$i',
                'cue': cue.storageKey,
                'reviewed_at': '2026-09-0${i}T12:00:00Z',
                'rating': cue == StudyCue.scriptToMeaning ? 1 : 3,
                'elapsed_seconds': 0,
                'scheduled_seconds': 0,
              },
        ],
      },
    },
  ),
)!;

void main() {
  test(
    'bulk activation queues mode and status together without losing history',
    () async {
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
      final original = spokenCard().copyWith(
        learningStatus: LearningStatus.future,
      );
      await store.applyCardBatch([HashedCard(original, 'original')]);
      final library = NativeCardLibrary(
        localStore: store,
        serverLibrary: null,
        transport: null,
        uploader: null,
        synchronizer: CardLibrarySynchronizer(
          localStore: store,
          transport: null,
          uploader: null,
        ),
        clock: const SystemClock(),
        newOperationId: () => 'bulk-spoken',
      );
      await library.setLearningStatus(
        original,
        LearningStatus.recall,
        spokenOnly: true,
      );
      final updated = (await store.getCard(1))!;
      expect(updated.spokenOnly, isTrue);
      expect(updated.learningStatus, LearningStatus.recall);
      expect(reviewHistoryJson(updated), reviewHistoryJson(original));
      expect(scheduleJson(updated), scheduleJson(original));
      final queued = (await store.pendingMutations()).single;
      expect(queued.entityKey.remoteId, 1);
      expect(queued.operationId, 'bulk-spoken');
    },
  );

  test(
    'missing and false keep all directions; true skips characters and hints',
    () {
      for (final value in [null, false]) {
        final card = spokenCard(spokenOnly: value);
        expect(card.spokenOnly, isFalse);
        expect(card.prompts.length, 6);
        expect(
          averageRetention(card, RecallComponent.values),
          closeTo(13 / 15, .001),
        );
      }
      final card = spokenCard(spokenOnly: true);
      expect(card.prompts.map((p) => p.cue), [
        StudyCue.meaningToSound,
        StudyCue.soundToMeaning,
      ]);
      expect(card.nextDueAt, DateTime.utc(2026, 10));
      expect(
        availableForRecall(
          card,
          StudyCue.scriptToMeaning,
          DateTime.utc(2026, 10),
        ),
        isFalse,
      );
      expect(
        StudyPrompt(
          card: card,
          cue: StudyCue.meaningToSound,
          showEnglishAndTransliteration: true,
        ).prompt,
        'house',
      );
      expect(averageRetention(card, RecallComponent.values), 1);
      expect(retentionPrompts([card], {RecallComponent.script}), isEmpty);
    },
  );

  test('character history and schedules survive toggling and oral review', () {
    final original = spokenCard().copyWith(
      reviewHistory: {
        StudyCue.scriptToMeaning: [
          for (var i = 0; i < 5; i++)
            CardReview(
              id: '$i',
              reviewedAt: DateTime.utc(2026, 9, i + 1),
              rating: 3,
              elapsedSeconds: 0,
              scheduledSeconds: 0,
            ),
        ],
      },
    );
    final spoken = original.copyWith(
      content: (original.content as LanguageCardContent).copyWith(
        spokenOnly: true,
      ),
    );
    expect(recallScore(spoken, StudyCue.scriptToMeaning).percentage, 0);
    expect(reviewHistoryJson(spoken), reviewHistoryJson(original));
    expect(scheduleJson(spoken), scheduleJson(original));
    final scheduler = FsrsCardScheduler(reviewId: () => 'new');
    expect(
      () => scheduler.preview(
        StudyPrompt(card: spoken, cue: StudyCue.scriptToMeaning),
        DateTime.utc(2026, 10),
      ),
      throwsStateError,
    );
    final reviewed = scheduler
        .preview(
          StudyPrompt(card: spoken, cue: StudyCue.meaningToSound),
          DateTime.utc(2026, 10),
        )[CardRating.good]!
        .card;
    expect(
      reviewed.reviewHistoryFor(StudyCue.scriptToMeaning),
      original.reviewHistoryFor(StudyCue.scriptToMeaning),
    );
    final restored = reviewed.copyWith(
      content: (reviewed.content as LanguageCardContent).copyWith(
        spokenOnly: false,
      ),
    );
    expect(recallScore(restored, StudyCue.scriptToMeaning).percentage, 100);
  });

  test(
    'progress averages eligible directions and preserves historical recall counts',
    () {
      final report = analyzeProgress(
        cards: [spokenCard(spokenOnly: true)],
        directions: RecallComponent.values.toSet(),
        targetPercent: 50,
        now: DateTime.utc(2026, 9, 6),
      );
      expect(report.days.last.atTarget, 1);
      expect(report.recalls, 10);
      final written = analyzeProgress(
        cards: [spokenCard(spokenOnly: true)],
        directions: {RecallComponent.script},
        targetPercent: 0,
        now: DateTime.utc(2026, 9, 6),
      );
      expect(written.days.last.atTarget, 0);
      expect(written.recalls, 0);
    },
  );

  test(
    'flag survives offline summaries, queued edits and full card reads',
    () async {
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
      await store.applyCardBatch([
        HashedCard(spokenCard(spokenOnly: true), 'spoken'),
      ]);
      expect((await store.readDashboard()).cards.single.spokenOnly, isTrue);
      final card = (await store.getCard(1))!;
      expect(card.spokenOnly, isTrue);
      await store.saveCardAndEnqueue(
        card.copyWith(
          content: (card.content as LanguageCardContent).copyWith(
            spokenOnly: false,
          ),
        ),
        operationId: 'toggle',
        mutationType: MutationType.update,
        createdAt: DateTime.utc(2026, 10),
      );
      expect((await store.getCard(1))!.spokenOnly, isFalse);
      expect(
        (await store.getCard(1))!.reviewHistoryFor(StudyCue.scriptToMeaning),
        hasLength(5),
      );
    },
  );
}
