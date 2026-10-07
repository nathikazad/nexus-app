import 'package:nx_cards/progress/progress_analysis.dart';
import 'package:nx_cards/scheduling/learning_stage.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_cards/browser/browser.dart';
import 'package:nx_cards/goals/daily_goal.dart';
import 'package:nx_cards/scheduling/clock.dart';
import 'package:nx_cards/scheduling/phrase_credit.dart';
import 'package:nx_cards/sync/card_synchronizer.dart';
import 'package:nx_cards/sync/native/cards_database.dart';
import 'package:nx_cards/sync/native/drift_local_cards_store.dart';
import 'package:nx_cards/sync/native/native_card_library.dart';
import 'package:nx_offline/nx_offline.dart' hide SystemClock;

final time = DateTime.utc(2026, 10, 6, 12);
StudyCard card(
  int id, {
  String category = 'Word',
  Set<int> links = const {},
  bool spoken = false,
}) => StudyCard(
  id: id,
  content: LanguageCardContent(
    english: 'test',
    originalScript: '测试',
    transliteration: 'test',
    spokenOnly: spoken,
  ),
  schedules: {
    for (final cue in StudyCue.languageDirections)
      cue: const CardSchedule.initial(enabled: true),
  },
  reviewHistory: {},
  suspended: false,
  tags: {
    'Category': [category],
    'Language': ['Chinese'],
  },
  linkedWordIds: links,
);
StudyCard answer(
  StudyCard card, {
  int rating = 3,
  String id = 'answer',
  List<StudyCue> cues = const [StudyCue.meaningToSound],
}) {
  for (final cue in cues) {
    card = card.updateCue(
      cue: cue,
      schedule: card
          .scheduleFor(cue)
          .copyWith(reviewCount: 1, lastReviewedAt: time),
      history: [
        ...card.reviewHistoryFor(cue),
        CardReview(
          id: '$id-${cue.name}',
          reviewedAt: time,
          rating: rating,
          elapsedSeconds: 0,
          scheduledSeconds: 60,
        ),
      ],
    );
  }
  return card;
}

void main() {
  test(
    'success credits exact directions once through shared links and cycles, preserving schedules',
    () async {
      final cards = {
        1: card(1, category: 'Phrase', links: {2, 3}),
        2: card(2, links: {4}),
        3: card(3, links: {4}),
        4: card(4, category: 'Script', links: {1}),
      };
      final updated = await planRecallSave(
        answer(
          cards[1]!,
          cues: [StudyCue.meaningToSound, StudyCue.meaningToScript],
        ),
        (id) async => cards[id]!,
      );
      expect(updated.map((c) => c.id).toSet(), {1, 2, 3, 4});
      expect(updated.length, 4);
      for (final c in updated.where((c) => c.id != 1)) {
        expect(c.reviewHistory.length, 2);
        for (final cue in [StudyCue.meaningToSound, StudyCue.meaningToScript]) {
          expect(c.reviewHistoryFor(cue), hasLength(1));
          final review = c.reviewHistoryFor(cue).single;
          expect(review.sourcePhraseId, 1);
          expect(CardReview.fromJson(review.toJson())!.sourcePhraseId, 1);
          expect(c.scheduleFor(cue), same(cards[c.id]!.scheduleFor(cue)));
        }
        expect(c.learningStatus, LearningStatus.future);
      }
      expect(dailyRecallCounts(updated, time).values.single, 2);
      final progress = analyzeProgress(
        cards: updated,
        directions: RecallComponent.values.toSet(),
        targetPercent: 10,
        now: time,
      );
      expect(progress.recalls, 2);
      expect(
        combinedRecallScore(updated.first, RecallComponent.values).percentage,
        greaterThan(0),
      );
      for (final c in updated) {
        cards[c.id] = c;
      }
      expect(
        await planRecallSave(
          answer(card(1, category: 'Phrase')),
          (id) async => cards[id]!,
        ),
        isEmpty,
      );
    },
  );
  test(
    'partial remote retry deduplicates saved children and completes parent',
    () async {
      final source = card(1, category: 'Phrase', links: {2, 3});
      final cards = {1: source, 2: card(2), 3: card(3)};
      final incoming = answer(source);
      final first = await planRecallSave(incoming, (id) async => cards[id]!);
      cards[first.first.id] = first.first;
      final retry = await planRecallSave(incoming, (id) async => cards[id]!);
      expect(retry.map((c) => c.id), [3, 1]);
    },
  );

  test('failure and ordinary word success never credit descendants', () async {
    for (final category in ['Phrase', 'Word']) {
      for (final rating in [1, 2, 3]) {
        if (category == 'Phrase' && rating == 3) continue;
        final source = card(1, category: category, links: {2});
        final updates = await planRecallSave(answer(source, rating: rating), (
          id,
        ) async {
          expect(id, 1);
          return source;
        });
        expect(updates, hasLength(1));
      }
    }
  });
  test(
    'spoken-only descendants receive no script credit; stale direct saves preserve contextual history',
    () async {
      final source = card(1, category: 'Phrase', links: {2});
      final child = card(2, spoken: true);
      final updates = await planRecallSave(
        answer(
          source,
          cues: [StudyCue.meaningToSound, StudyCue.meaningToScript],
        ),
        (id) async => id == 1 ? source : child,
      );
      final credited = updates.first;
      expect(credited.reviewHistoryFor(StudyCue.meaningToScript), isEmpty);
      final merged = await planRecallSave(
        answer(child, id: 'direct'),
        (_) async => credited,
      );
      expect(
        merged.single.reviewHistoryFor(StudyCue.meaningToSound),
        hasLength(2),
      );
      expect(merged.single.scheduleFor(StudyCue.meaningToSound).reviewCount, 1);
    },
  );
  test(
    'offline saves persist parent and children, retry safely, and reject missing links without saving',
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
      final source = card(1, category: 'Phrase', links: {2, 3});
      await store.applyCardSnapshot([source, card(2)]);
      var operation = 0;
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
        newOperationId: () => '${operation++}',
      );
      final outcome = answer(source);
      await expectLater(library.saveSchedule(outcome), throwsStateError);
      expect(
        (await store.getCard(1))!.reviewHistoryFor(StudyCue.meaningToSound),
        isEmpty,
      );
      expect(
        (await store.getCard(2))!.reviewHistoryFor(StudyCue.meaningToSound),
        isEmpty,
      );
      await store.applyCardSnapshot([source, card(2), card(3)]);
      await library.saveSchedule(outcome);
      await library.saveSchedule(outcome);
      for (final id in [1, 2, 3]) {
        expect(
          (await store.getCard(id))!.reviewHistoryFor(StudyCue.meaningToSound),
          hasLength(1),
        );
      }
    },
  );
}
