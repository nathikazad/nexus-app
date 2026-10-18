import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nx_db/app_reads.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_cards/sync/remote/remote_card_library.dart';
import 'package:nx_cards/account/account_session.dart';
import 'package:nx_cards/browser/browser_providers.dart';
import 'package:nx_cards/sync/sync_providers.dart';
import 'package:nx_cards/browser/browser.dart';

void main() {
  test(
    'native source list publishes an empty offline library without a server',
    () async {
      final local = _OfflineWorkspace();
      var requests = 0;
      final pending = Completer<http.Response>();
      final reads = AppReads(
        MockClient((_) {
          requests++;
          return pending.future;
        }),
        Uri.parse('https://example.invalid'),
        'cards',
      );
      addTearDown(reads.close);
      final c = ProviderContainer(
        overrides: [
          cardsOfflineEnabledProvider.overrideWithValue(true),
          cardWorkspaceProvider.overrideWithValue(local),
          appReadsProvider('cards').overrideWithValue(reads),
        ],
      );
      addTearDown(c.dispose);
      final sub = c.listen(cardsSourcesProvider, (_, _) {});
      addTearDown(sub.close);
      expect(
        await c
            .read(cardsSourcesProvider.future)
            .timeout(const Duration(milliseconds: 500)),
        isEmpty,
      );
      expect(requests, 0);
    },
  );

  test('web policy constructs a network workspace without opening SQLite', () {
    var databaseOpened = false;
    final remote = _DashboardRepository();
    final container = ProviderContainer(
      overrides: [
        cardsOfflineEnabledProvider.overrideWithValue(false),
        kgqlCardApiProvider.overrideWithValue(remote),
        cardsDatabaseProvider.overrideWith((ref, accountKey) {
          databaseOpened = true;
          throw StateError('Web must not open the offline database');
        }),
      ],
    );
    addTearDown(container.dispose);

    final workspace = container.read(cardWorkspaceProvider);

    expect(workspace, isA<RemoteCardLibrary>());
    expect(databaseOpened, isFalse);
    expect(container.read(localCardsStoreProvider), isNull);
    expect(container.read(cardsUploaderProvider), isNull);
    expect(container.read(cardLibrarySynchronizerProvider), isNull);
  });
}

final class _DashboardRepository implements CardLibrary {
  @override
  Future<List<StudyCard>> listCards() async => const <StudyCard>[];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _OfflineWorkspace implements CardWorkspace {
  @override
  Stream<CardsDashboard> watchDashboard() =>
      Stream.value(const CardsDashboard(cards: []));
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
