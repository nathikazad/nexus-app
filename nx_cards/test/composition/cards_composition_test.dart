import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_cards/application/web/web_cards_workspace.dart';
import 'package:nx_cards/composition/cards_composition.dart';
import 'package:nx_cards/domain/card/cards_repository.dart';
import 'package:nx_cards/domain/cards_models.dart';

void main() {
  test('web policy constructs a network workspace without opening SQLite', () {
    var databaseOpened = false;
    final remote = _DashboardRepository();
    final container = ProviderContainer(
      overrides: [
        cardsOfflineEnabledProvider.overrideWithValue(false),
        remoteCardsRepositoryProvider.overrideWithValue(remote),
        cardsDatabaseProvider.overrideWith((ref, accountKey) {
          databaseOpened = true;
          throw StateError('Web must not open the offline database');
        }),
      ],
    );
    addTearDown(container.dispose);

    final workspace = container.read(cardsWorkspaceProvider);

    expect(workspace, isA<WebCardsWorkspace>());
    expect(databaseOpened, isFalse);
    expect(container.read(localCardsStoreProvider), isNull);
    expect(container.read(cardsUploaderProvider), isNull);
    expect(container.read(cardDeckSynchronizerProvider), isNull);
  });
}

final class _DashboardRepository implements CardsRepository {
  @override
  Future<List<CardDeck>> listDecks() async => const <CardDeck>[];

  @override
  Future<List<StudyCard>> listCards() async => const <StudyCard>[];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
