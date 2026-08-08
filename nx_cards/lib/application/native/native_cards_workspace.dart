import 'package:nx_cards/application/cards_workspace.dart';
import 'package:nx_cards/application/native/cards_uploader.dart';
import 'package:nx_cards/application/ports/cards_sync_transport.dart';
import 'package:nx_cards/application/ports/clock.dart';
import 'package:nx_cards/application/ports/local_cards_store.dart';
import 'package:nx_cards/application/sync/card_deck_synchronizer.dart';
import 'package:nx_cards/domain/card/cards_repository.dart';
import 'package:nx_cards/domain/cards_models.dart';
import 'package:nx_offline/nx_offline.dart' as offline;

final class NativeCardsWorkspace implements CardsWorkspace {
  const NativeCardsWorkspace({
    required LocalCardsStore localStore,
    required CardsRepository? remoteRepository,
    required CardsSyncTransport? transport,
    required CardsUploader? uploader,
    required CardDeckSynchronizer synchronizer,
    required Clock clock,
    required String Function() newOperationId,
  }) : _localStore = localStore,
       _remoteRepository = remoteRepository,
       _transport = transport,
       _uploader = uploader,
       _synchronizer = synchronizer,
       _clock = clock,
       _newOperationId = newOperationId;

  final LocalCardsStore _localStore;
  final CardsRepository? _remoteRepository;
  final CardsSyncTransport? _transport;
  final CardsUploader? _uploader;
  final CardDeckSynchronizer _synchronizer;
  final Clock _clock;
  final String Function() _newOperationId;

  @override
  Stream<CardsDashboard> watchDashboard() => _localStore.watchDashboard();

  @override
  Future<List<CardDeck>> listDecks() async =>
      (await _localStore.readDashboard()).decks;

  @override
  Future<List<StudyCard>> listCards() async =>
      (await _localStore.readDashboard()).cards;

  @override
  Future<List<String>> listLanguages() => _requireRepository().listLanguages();

  @override
  Future<List<RelatedBook>> listBooks() => _requireRepository().listBooks();

  @override
  Future<void> addLanguage(String name) =>
      _requireRepository().addLanguage(name);

  @override
  Future<int> createDeck({
    required String name,
    required String description,
    String? fromLanguage,
    String? toLanguage,
  }) async {
    final result = await _requireTransport().createDeck(
      name: name,
      description: description,
      fromLanguage: fromLanguage,
      toLanguage: toLanguage,
      clientUpdatedAt: _clock.now(),
    );
    await _synchronizer.syncDeck(result.entityId);
    return result.entityId;
  }

  @override
  Future<int> createCard({
    required CardContent content,
    required int deckId,
    int? sourceBookId,
  }) async {
    final result = await _requireTransport().createCard(
      content: content,
      deckId: deckId,
      sourceBookId: sourceBookId,
      clientUpdatedAt: _clock.now(),
    );
    await _synchronizer.syncDeck(deckId);
    return result.entityId;
  }

  @override
  Future<void> updateCardContent({
    required int id,
    required CardContent content,
  }) async {
    final existing = await _requireCard(id);
    final mergedContent = switch ((existing.content, content)) {
      (
        final LanguageCardContent oldContent,
        final LanguageCardContent newContent,
      ) =>
        LanguageCardContent(
          english: newContent.english,
          originalScript: newContent.originalScript,
          transliteration: newContent.transliteration,
          audioUrl: newContent.audioUrl ?? oldContent.audioUrl,
          examples: newContent.examples,
        ),
      _ => content,
    };
    await _enqueue(
      existing.copyWith(content: mergedContent),
      offline.MutationType.update,
    );
  }

  @override
  Future<void> saveSchedule(StudyCard card) async {
    final existing = await _requireCard(card.id);
    await _enqueue(
      existing.copyWith(
        schedules: card.schedules,
        reviewHistory: card.reviewHistory,
      ),
      offline.MutationType.update,
    );
  }

  @override
  Future<void> setSuspended(StudyCard card, bool suspended) async {
    final existing = await _requireCard(card.id);
    await _enqueue(
      existing.copyWith(suspended: suspended),
      offline.MutationType.update,
    );
  }

  @override
  Future<void> deleteCard(int id) async {
    await _enqueue(await _requireCard(id), offline.MutationType.delete);
  }

  Future<void> _enqueue(StudyCard card, offline.MutationType type) async {
    final now = _clock.now().toUtc();
    final updatedAt = card.updatedAt;
    final editTime = updatedAt != null && !now.isAfter(updatedAt)
        ? updatedAt.add(const Duration(microseconds: 1))
        : now;
    await _localStore.saveCardAndEnqueue(
      card.copyWith(updatedAt: editTime),
      operationId: _newOperationId(),
      mutationType: type,
      createdAt: editTime,
    );
    _uploader?.schedule();
  }

  Future<StudyCard> _requireCard(int cardId) async {
    final card = await _localStore.getCard(cardId);
    if (card == null) throw StateError('Card $cardId is not downloaded.');
    return card;
  }

  CardsRepository _requireRepository() {
    final repository = _remoteRepository;
    if (repository == null) {
      throw StateError(
        'The remote Cards service is unavailable while offline.',
      );
    }
    return repository;
  }

  CardsSyncTransport _requireTransport() {
    final transport = _transport;
    if (transport == null) {
      throw StateError(
        'The remote Cards service is unavailable while offline.',
      );
    }
    return transport;
  }

  @override
  Future<void> syncLibrary() => _synchronizer.syncLibrary();

  @override
  Future<void> syncDeck(int deckId) async {
    await _synchronizer.syncDeck(deckId);
  }

  @override
  Future<void> close() async {}
}

// ignore_for_file: prefer_initializing_formals
