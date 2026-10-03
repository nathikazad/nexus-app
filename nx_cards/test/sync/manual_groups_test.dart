import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_cards/browser/browser.dart';
import 'package:nx_cards/browser/data/kgql/kgql_card_mapper.dart';
import 'package:nx_cards/study/language/similar_sounds.dart';
import 'package:nx_cards/sync/native/cards_database.dart';
import 'package:nx_cards/sync/native/drift_local_cards_store.dart';
import 'package:nx_cards/sync/remote/cards_sync_transport.dart';
import 'package:nx_db/kgql.dart';
import 'package:nx_offline/nx_offline.dart';
import 'package:nx_offline/src/storage/content_files_native.dart';

StudyCard card(
  int id,
  List<String> groups, {
  String language = 'Chinese',
  String status = 'recall',
}) => studyCardFromModel(
  Model(
    id: id,
    name: 'word $id',
    modelTypeId: 2,
    modelType: ModelType(id: 2, name: 'LanguageFlashcard'),
    attributes: {
      'card_details': {'front': 'word $id', 'back': '字$id'},
      'language_details': {'transliteration': 'unparseable'},
      'similar_word_groups': groups,
      'learning_state': status,
    },
    tags: {
      'Language': [language],
    },
  ),
)!;

void main() {
  test(
    'manual membership is exact, overlapping, Current-only, language-independent and independent of pinyin',
    () {
      final groups = manualSimilarSoundGroups([
        card(1, ['shi', 'contrast', 'shi']),
        card(2, ['shi']),
        card(3, ['shi'], status: 'future'),
        card(4, ['shi'], language: 'Tamil'),
        card(5, ['Shi']),
        card(6, []),
      ]);
      expect(groups.first.label, 'shi');
      expect(groups.first.cards.map((c) => c.id), [1, 2, 4]);
      expect(groups.map((g) => g.label), ['shi', 'Shi', 'contrast']);
      expect(similarWordGroupsFromJson(['', ' shi ', 3, 'shi', 'shi']), [
        'shi',
      ]);
    },
  );

  test(
    'memberships survive file storage, summary, restart, queued edits and changed hashes',
    () async {
      final dir = await Directory.systemTemp.createTemp('manual-groups-');
      final file = File('${dir.path}/index.sqlite');
      var db = CardsDatabase(NativeDatabase(file));
      const account = AccountIdentity(
        domainId: 1,
        serverId: 'test',
        userId: '1',
        application: 'cards',
      );
      final files = DirectoryContentFiles(Directory('${dir.path}/content'));
      DriftLocalCardsStore store() =>
          DriftLocalCardsStore(database: db, account: account, files: files);
      addTearDown(() async {
        await db.close();
        await dir.delete(recursive: true);
      });
      await store().applyCardBatch([
        HashedCard(card(1, ['shi', 'contrast']), 'h1'),
      ]);
      expect(
        ((await store().readDashboard()).cards.single.content
                as LanguageCardContent)
            .similarWordGroups,
        ['shi', 'contrast'],
      );
      await db.close();
      db = CardsDatabase(NativeDatabase(file));
      expect(
        ((await store().getCard(1))!.content as LanguageCardContent)
            .similarWordGroups,
        ['shi', 'contrast'],
      );
      await store().applyCardBatch([
        HashedCard(card(1, ['shi']), 'h2'),
      ]);
      expect(
        ((await store().getCard(1))!.content as LanguageCardContent)
            .similarWordGroups,
        ['shi'],
      );
      await store().saveCardAndEnqueue(
        (await store().getCard(1))!.copyWith(suspended: true),
        operationId: 'pending',
        mutationType: MutationType.update,
        createdAt: DateTime.utc(2026),
      );
      // Emulate v15: no membership column and an already accepted hash.
      await db.customStatement(
        'ALTER TABLE local_study_cards DROP COLUMN similar_word_groups_json',
      );
      await db.customStatement('PRAGMA user_version=15');
      await db.close();
      db = CardsDatabase(NativeDatabase(file));
      expect(
        await db.customSelect('SELECT * FROM card_sync_hashes').get(),
        isEmpty,
      );
      expect(await store().pendingMutations(), isEmpty);
      expect(await store().getCard(1), isNull);
      await store().applyCardBatch([
        HashedCard(card(1, ['shi']), 'v4'),
      ]);
      expect(
        ((await store().getCard(1))!.content as LanguageCardContent)
            .similarWordGroups,
        ['shi'],
      );
      expect(await store().verifiedCard(const CardHash(1, 'h2')), false);
    },
  );
}
