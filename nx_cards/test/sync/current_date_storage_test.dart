import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_cards/browser/browser.dart';
import 'package:nx_cards/sync/native/cards_database.dart';
import 'package:nx_cards/sync/native/drift_local_cards_store.dart';
import 'package:nx_cards/sync/remote/cards_sync_transport.dart';
import 'package:nx_offline/nx_offline.dart';
import 'package:nx_offline/src/storage/content_files_native.dart';

void main() {
  test(
    'v17 upgrade preserves existing cards, dates stay null, queued edits survive',
    () async {
      final dir = await Directory.systemTemp.createTemp('cards-current-date-');
      final file = File('${dir.path}/cards.sqlite');
      var db = CardsDatabase(NativeDatabase(file));
      addTearDown(() async {
        await db.close();
        await dir.delete(recursive: true);
      });
      const account = AccountIdentity(
        domainId: 1,
        serverId: 'test',
        userId: '1',
        application: 'cards',
      );
      DriftLocalCardsStore store() =>
          DriftLocalCardsStore(database: db, account: account);
      final card = StudyCard(
        id: 1,
        content: const BasicCardContent(front: 'A', back: 'B'),
        schedules: {
          StudyCue.frontToBack: const CardSchedule.initial(enabled: true),
        },
        reviewHistory: {},
        suspended: false,
        learningStatus: LearningStatus.recall,
      );
      await store().applyCardBatch([HashedCard(card, 'before')]);
      await store().saveCardAndEnqueue(
        card,
        operationId: 'pending',
        mutationType: MutationType.update,
        createdAt: DateTime.utc(2026),
      );
      await db.customStatement(
        'ALTER TABLE local_study_cards DROP COLUMN added_to_current_at',
      );
      await db.customStatement('PRAGMA user_version=17');
      await db.close();
      db = CardsDatabase(NativeDatabase(file));
      expect((await store().getCard(1))!.addedToCurrentAt, isNull);
      expect((await store().pendingMutations()).single.operationId, 'pending');
      expect((await store().readDashboard()).cards.single.front, 'A');
      await db.close();
      db = CardsDatabase(NativeDatabase(file));
      expect((await store().pendingMutations()).single.operationId, 'pending');
    },
  );

  test(
    'date survives file bodies, dashboard and immutable queued snapshots',
    () async {
      final dir = await Directory.systemTemp.createTemp('cards-date-bodies-');
      final db = CardsDatabase(NativeDatabase.memory());
      addTearDown(() async {
        await db.close();
        await dir.delete(recursive: true);
      });
      final store = DriftLocalCardsStore(
        database: db,
        account: const AccountIdentity(
          domainId: 1,
          serverId: 'test',
          userId: '1',
          application: 'cards',
        ),
        files: DirectoryContentFiles(dir),
      );
      final card = StudyCard(
        id: 1,
        content: const BasicCardContent(front: 'A', back: 'B'),
        schedules: {
          StudyCue.frontToBack: const CardSchedule.initial(enabled: true),
        },
        reviewHistory: {},
        suspended: false,
        learningStatus: LearningStatus.recall,
        addedToCurrentAt: '2026-10-26',
      );
      await store.saveCardAndEnqueue(
        card,
        operationId: 'date',
        mutationType: MutationType.update,
        createdAt: DateTime.utc(2026),
      );
      final reference =
          (await store.pendingMutations()).single.payload['body_ref'] as String;
      await store.applyCardBatch([
        HashedCard(card.copyWith(addedToCurrentAt: '2026-10-27'), 'next'),
      ]);
      expect(
        (await store.readQueuedCard(1, reference))!.addedToCurrentAt,
        '2026-10-26',
      );
      expect((await store.getCard(1))!.addedToCurrentAt, isNotNull);
      expect(
        (await store.readDashboard()).cards.single.addedToCurrentAt,
        isNotNull,
      );
    },
  );
}
