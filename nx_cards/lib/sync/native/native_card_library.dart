import 'package:nx_cards/sync/native/cards_uploader.dart';
import 'package:nx_cards/sync/remote/cards_sync_transport.dart';
import 'package:nx_cards/scheduling/clock.dart';
import 'package:nx_cards/sync/native/local_cards_store.dart';
import 'package:nx_cards/sync/card_synchronizer.dart';
import 'package:nx_cards/browser/browser.dart';
import 'package:nx_offline/nx_offline.dart' as offline;

final class NativeCardLibrary implements CardWorkspace {
  const NativeCardLibrary({
    required LocalCardsStore localStore,
    required CardLibrary? serverLibrary,
    required CardsSyncTransport? transport,
    required CardsUploader? uploader,
    required CardLibrarySynchronizer synchronizer,
    required Clock clock,
    required String Function() newOperationId,
  }) : _localStore = localStore,
       _serverLibrary = serverLibrary,
       _transport = transport,
       _uploader = uploader,
       _synchronizer = synchronizer,
       _clock = clock,
       _newOperationId = newOperationId;

  final LocalCardsStore _localStore;
  final CardLibrary? _serverLibrary;
  final CardsSyncTransport? _transport;
  final CardsUploader? _uploader;
  final CardLibrarySynchronizer _synchronizer;
  final Clock _clock;
  final String Function() _newOperationId;

  @override
  Stream<CardsDashboard> watchDashboard() => _localStore.watchDashboard();

  @override
  Future<List<StudyCard>> listCards() async =>
      (await _localStore.readDashboard()).cards;

  @override
  Future<List<String>> listLanguages() =>
      _requireServerLibrary().listLanguages();

  @override
  Future<List<RelatedBook>> listBooks() => _requireServerLibrary().listBooks();

  @override
  Future<void> addLanguage(String name) =>
      _requireServerLibrary().addLanguage(name);

  @override
  Future<int> createCard({
    required CardContent content,
    int? sourceBookId,
  }) async {
    final result = await _requireTransport().createCard(
      content: content,
      sourceBookId: sourceBookId,
      clientUpdatedAt: _clock.now(),
    );
    await _synchronizer.syncLibrary();
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
  Future<void> setLearningStatus(StudyCard card, LearningStatus status) async {
    final existing = await _requireCard(card.id);
    await _enqueue(
      existing.copyWith(learningStatus: status),
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

  CardLibrary _requireServerLibrary() {
    final library = _serverLibrary;
    if (library == null) {
      throw StateError(
        'The remote Cards service is unavailable while offline.',
      );
    }
    return library;
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
  Future<void> close() => _synchronizer.close();
}

// ignore_for_file: prefer_initializing_formals
