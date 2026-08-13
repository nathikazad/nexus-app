import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_cards/sync/remote/remote_card_library.dart';
import 'package:nx_cards/account/account_session.dart';
import 'package:nx_cards/browser/browser_providers.dart';
import 'package:nx_cards/sync/sync_providers.dart';
import 'package:nx_cards/browser/browser.dart';

void main() {
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
