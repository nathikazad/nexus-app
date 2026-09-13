import 'dart:io';
import 'package:nx_cards/sync/remote/cards_sync_transport.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_cards/browser/browser.dart';
import 'package:nx_cards/sync/native/cards_database.dart';
import 'package:nx_cards/sync/native/drift_local_cards_store.dart';
import 'package:nx_offline/nx_offline.dart';
import 'package:nx_offline/src/storage/content_files_native.dart';

void main() {
  test(
    'hash sync skips unchanged content, repairs missing files and preserves pending edits',
    () async {
      final dir = await Directory.systemTemp.createTemp('nx-card-hash-');
      final db = CardsDatabase(NativeDatabase.memory());
      addTearDown(() async {
        await db.close();
        await dir.delete(recursive: true);
      });
      final files = DirectoryContentFiles(Directory('${dir.path}/content'));
      final store = DriftLocalCardsStore(
        database: db,
        files: files,
        account: const AccountIdentity(
          serverId: 'test',
          userId: '1',
          application: 'cards',
        ),
      );
      final card = StudyCard(
        id: 1,
        content: const BasicCardContent(front: 'A', back: 'B'),
        schedules: const {},
        reviewHistory: const {},
        suspended: false,
      );
      const hash = CardHash(1, 'server-v1');
      expect(await store.verifiedCard(hash), false);
      await store.applyCardBatch([HashedCard(card, hash.hash)]);
      expect(await store.verifiedCard(hash), true);
      expect(await store.verifiedCard(const CardHash(1, 'changed')), false);
      await Directory('${dir.path}/content').delete(recursive: true);
      expect(await store.verifiedCard(hash), false);
      await store.applyCardBatch([HashedCard(card, hash.hash)]);
      expect(await store.verifiedCard(hash), true);
      await store.saveCardAndEnqueue(
        card.copyWith(suspended: true),
        operationId: 'edit',
        mutationType: MutationType.update,
        createdAt: DateTime.now(),
      );
      expect(await store.verifiedCard(hash), false);
      await store.applyCardBatch([HashedCard(card, hash.hash)]);
      await store.publishCardManifest([]);
      expect((await store.getCard(1))!.suspended, true);
      expect(await store.verifiedCard(hash), false);
    },
  );
  test(
    'cards migrate losslessly; dashboard reads projections, opening reads one body',
    () async {
      final dir = await Directory.systemTemp.createTemp('nx-cards-files-');
      final db = CardsDatabase(
        NativeDatabase(File('${dir.path}/index.sqlite')),
      );
      addTearDown(() async {
        await db.close();
        await dir.delete(recursive: true);
      });
      const account = AccountIdentity(
        serverId: 'test',
        userId: '1',
        application: 'cards',
      );
      final legacy = DriftLocalCardsStore(database: db, account: account);
      final history = [
        for (var i = 0; i < 30; i++)
          CardReview(
            id: '$i',
            reviewedAt: DateTime.utc(2026, 1, 1).add(Duration(days: i)),
            rating: 3,
            elapsedSeconds: 1,
            scheduledSeconds: 10,
          ),
      ];
      final card = StudyCard(
        id: 1,
        notes: 'Shared explanation survives offline storage.',
        content: BasicCardContent(front: 'front' * 1000, back: 'back' * 1000),
        schedules: const {},
        reviewHistory: {StudyCue.fromLanguage: history},
        suspended: false,
      );
      await legacy.applyCardSnapshot([card]);
      final files = DirectoryContentFiles(Directory('${dir.path}/content'));
      final store = DriftLocalCardsStore(
        database: db,
        account: account,
        files: files,
      );
      await store.migrateContent();
      final dashboard = await store.readDashboard();
      expect(files.reads, 0);
      expect(dashboard.cards.single.isSummary, isTrue);
      expect(dashboard.cards.single.front.length, 320);
      expect(
        dashboard.cards.single.reviewHistoryFor(StudyCue.fromLanguage),
        hasLength(10),
      );
      final full = (await store.getCard(1))!;
      expect(files.reads, 1);
      expect(full.isSummary, isFalse);
      expect(full.front, card.front);
      expect(full.back, card.back);
      expect(full.notes, card.notes);
      expect(full.reviewHistoryFor(StudyCue.fromLanguage), hasLength(30));
      await store.saveCardAndEnqueue(
        full.copyWith(suspended: true),
        operationId: 'edit',
        mutationType: MutationType.update,
        createdAt: DateTime.utc(2026, 2),
      );
      expect((await store.pendingMutations()).single.operationId, 'edit');
      expect(
        (await store.getCard(1))!.reviewHistoryFor(StudyCue.fromLanguage),
        hasLength(30),
      );
      final claimed = (await store.claimNext(
        workerId: 'test',
        now: DateTime.utc(2026, 3),
        lease: const Duration(minutes: 1),
      ))!;
      await store.saveCardAndEnqueue(
        full.copyWith(suspended: false),
        operationId: 'newer',
        mutationType: MutationType.update,
        createdAt: DateTime.utc(2026, 3),
      );
      final uploaded = await store.readQueuedCard(
        1,
        claimed.payload['body_ref'] as String,
      );
      expect(uploaded!.suspended, isTrue);
      await store.complete(
        MutationReceipt(
          operationId: claimed.operationId,
          entityKey: claimed.entityKey,
          revision: const Revision('old-ack'),
        ),
      );
      expect((await store.pendingMutations()).single.operationId, 'newer');
      expect((await store.getCard(1))!.suspended, isFalse);
      await expectLater(
        store.saveCardAndEnqueue(
          dashboard.cards.single,
          operationId: 'invalid',
          mutationType: MutationType.update,
          createdAt: DateTime.utc(2026, 3),
        ),
        throwsStateError,
      );
    },
  );
}
