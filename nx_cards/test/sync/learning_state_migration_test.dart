import 'dart:io';
import 'dart:convert';
import 'package:nx_offline/src/storage/content_files_native.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_cards/browser/browser.dart';
import 'package:nx_cards/sync/native/cards_database.dart';
import 'package:nx_cards/sync/native/drift_local_cards_store.dart';
import 'package:nx_offline/nx_offline.dart';

void main() {
  test('v13 rewrites body and queued snapshot references once', () async {
    final dir = await Directory.systemTemp.createTemp('nx-status-bodies-');
    final file = File('${dir.path}/index.sqlite');
    var db = CardsDatabase(NativeDatabase(file));
    final files = DirectoryContentFiles(Directory('${dir.path}/content'));
    const account = AccountIdentity(
      domainId: 1,
      serverId: 'test',
      userId: '1',
      application: 'cards',
    );
    DriftLocalCardsStore store() =>
        DriftLocalCardsStore(database: db, account: account, files: files);
    final card = StudyCard(
      id: 1,
      content: const BasicCardContent(front: 'A', back: 'B'),
      suspended: false,
      learningStatus: LearningStatus.practice,
      schedules: const {},
      reviewHistory: const {},
    );
    await store().saveCardAndEnqueue(
      card,
      operationId: 'pending',
      mutationType: MutationType.update,
      createdAt: DateTime.utc(2026),
    );
    final row = await db.select(db.localStudyCards).getSingle();
    final body =
        jsonDecode(await files.read(row.contentRef!)) as Map<String, dynamic>;
    body['learning_status'] = 'prep';
    final oldRef = await files.write('cards', '1', jsonEncode(body));
    await db.customStatement(
      "UPDATE local_study_cards SET learning_status='prep',content_ref=?",
      [oldRef],
    );
    await db.customStatement(
      r"UPDATE offline_outbox SET payload_json=json_set(payload_json,'$.body_ref',?)",
      [oldRef],
    );
    await db.customStatement('PRAGMA user_version=13');
    await db.close();
    db = CardsDatabase(NativeDatabase(file));
    addTearDown(() async {
      await db.close();
      await dir.delete(recursive: true);
    });
    final migrated = store();
    expect(
      (await migrated.getCard(1))!.learningStatus,
      LearningStatus.practice,
    );
    final queued = (await migrated.pendingMutations()).single;
    expect(queued.operationId, 'pending');
    final newRef = queued.payload['body_ref'] as String;
    expect(newRef, isNot(oldRef));
    expect(jsonDecode(await files.read(newRef))['learning_status'], 'practice');
    expect(
      (await migrated.readQueuedCard(1, newRef))!.learningStatus,
      LearningStatus.practice,
    );
    expect(
      await db.customSelect('SELECT * FROM card_status_body_migrations').get(),
      isEmpty,
    );
  });

  test(
    'v12 status migration preserves directions, schedules and pending writes',
    () async {
      final dir = await Directory.systemTemp.createTemp('nx-prep-migration-');
      final file = File('${dir.path}/cards.sqlite');
      var db = CardsDatabase(NativeDatabase(file));
      const account = AccountIdentity(
        domainId: 1,
        serverId: 'test',
        userId: '1',
        application: 'cards',
      );
      DriftLocalCardsStore store() =>
          DriftLocalCardsStore(database: db, account: account);
      final cards = [
        for (var id = 1; id <= 4; id++)
          StudyCard(
            id: id,
            content: const BasicCardContent(front: 'A', back: 'B'),
            suspended: false,
            learningStatus: LearningStatus.recall,
            schedules: const {
              StudyCue.toLanguage: CardSchedule.initial(enabled: true),
            },
            reviewHistory: {
              if (id == 2 || id == 3)
                (id == 2 ? StudyCue.toLanguage : StudyCue.transliteration): [
                  CardReview(
                    id: 'old-$id',
                    reviewedAt: DateTime.utc(2026),
                    rating: 3,
                    elapsedSeconds: 2,
                    scheduledSeconds: 8,
                  ),
                ],
            },
          ),
      ];
      await store().applyCardSnapshot(cards);
      await store().saveCardAndEnqueue(
        cards[1],
        operationId: 'pending',
        mutationType: MutationType.update,
        createdAt: DateTime.utc(2026),
      );
      await db.customStatement(
        "UPDATE local_study_cards SET learning_status=CASE WHEN remote_id=4 THEN 'not_started' ELSE 'learning' END",
      );
      final before = await db
          .customSelect(
            'SELECT remote_id,schedule_json,review_history_json FROM local_study_cards ORDER BY remote_id',
          )
          .get();
      await db.customStatement('PRAGMA user_version=12');
      await db.close();
      db = CardsDatabase(NativeDatabase(file));
      addTearDown(() async {
        await db.close();
        await dir.delete(recursive: true);
      });
      final restored = await store().readDashboard();
      expect(
        {for (final card in restored.cards) card.id: card.learningStatus},
        {
          1: LearningStatus.practice,
          2: LearningStatus.recall,
          3: LearningStatus.practice,
          4: LearningStatus.future,
        },
      );
      final after = await db
          .customSelect(
            'SELECT remote_id,schedule_json,review_history_json FROM local_study_cards ORDER BY remote_id',
          )
          .get();
      expect(
        after.map((r) => r.data).toList(),
        before.map((r) => r.data).toList(),
      );
      expect((await store().pendingMutations()).single.operationId, 'pending');
    },
  );
}
