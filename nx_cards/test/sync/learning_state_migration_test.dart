import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_cards/browser/browser.dart';
import 'package:nx_cards/sync/native/cards_database.dart';
import 'package:nx_cards/sync/native/drift_local_cards_store.dart';
import 'package:nx_cards/sync/remote/cards_sync_transport.dart';
import 'package:nx_offline/nx_offline.dart';

void main() {
  for (final version in [12, 13, 16]) {
    test(
      'v$version cutover rejects old queues and reloads each account independently',
      () async {
        final dir = await Directory.systemTemp.createTemp('nx-cards-v4-');
        final file = File('${dir.path}/cards.sqlite');
        var db = CardsDatabase(NativeDatabase(file));
        addTearDown(() async {
          await db.close();
          await dir.delete(recursive: true);
        });
        final accounts = [
          for (final id in ['1', '2'])
            AccountIdentity(
              domainId: 1,
              serverId: 'test',
              userId: id,
              application: 'cards',
            ),
        ];
        DriftLocalCardsStore store(AccountIdentity account) =>
            DriftLocalCardsStore(database: db, account: account);
        final card = StudyCard(
          id: 1,
          content: const BasicCardContent(front: 'A', back: 'B'),
          schedules: {
            StudyCue.frontToBack: const CardSchedule.initial(enabled: true),
          },
          reviewHistory: {},
          suspended: false,
        );
        for (final account in accounts) {
          await store(account).applyCardBatch([HashedCard(card, 'old')]);
          await store(account).saveCardAndEnqueue(
            card,
            operationId: 'pending-${account.userId}',
            mutationType: MutationType.update,
            createdAt: DateTime.utc(2026),
          );
        }
        await db.customStatement(
          "UPDATE local_study_cards SET schedule_json='{\"version\":3,\"cues\":{}}'",
        );
        await db.customStatement('PRAGMA user_version=$version');
        await db.close();
        db = CardsDatabase(NativeDatabase(file));
        expect(
          await db.customSelect('SELECT * FROM rejected_card_outbox_v3').get(),
          hasLength(2),
        );
        expect(
          await db.customSelect('SELECT * FROM card_sync_hashes').get(),
          isEmpty,
        );
        for (final account in accounts) {
          expect((await store(account).readDashboard()).cards, isEmpty);
          expect(await store(account).pendingMutations(), isEmpty);
        }
        await store(accounts.first).applyCardBatch([HashedCard(card, 'v4')]);
        expect(
          (await store(accounts.first).readDashboard()).cards,
          hasLength(1),
        );
        expect((await store(accounts.last).readDashboard()).cards, isEmpty);
        await store(accounts.first).saveCardAndEnqueue(
          card,
          operationId: 'new-v4',
          mutationType: MutationType.update,
          createdAt: DateTime.utc(2026),
        );
        await db.close();
        db = CardsDatabase(NativeDatabase(file));
        expect(
          (await store(accounts.first).pendingMutations()).single.operationId,
          'new-v4',
        );
      },
    );
  }
}
