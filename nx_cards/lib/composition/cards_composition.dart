import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_cards/application/ports/clock.dart';
import 'package:nx_cards/application/study/study_queue_service.dart';
import 'package:nx_cards/data/audio/http_card_audio_repository.dart';
import 'package:nx_cards/data/remote/kgql/card_schema.dart';
import 'package:nx_cards/data/remote/kgql/kgql_cards_repository.dart';
import 'package:nx_cards/domain/card/cards_repository.dart';
import 'package:nx_cards/domain/card/card_audio_repository.dart';
import 'package:nx_cards/domain/scheduling/card_scheduler.dart';
import 'package:nx_cards/domain/cards_models.dart';
import 'package:nx_db/nx_db.dart';

final cardsRepositoryProvider = Provider<CardsRepository>((ref) {
  return KgqlCardsRepository(ref.watch(graphqlClientProvider));
});

final clockProvider = Provider<Clock>((ref) => const SystemClock());

final studyQueueServiceProvider = Provider<StudyQueueService>((ref) {
  return StudyQueueService(ref.watch(clockProvider));
});

final cardSchedulerProvider = Provider<CardScheduler>((ref) {
  return FsrsCardScheduler();
});

final cardAudioRepositoryProvider = Provider<CardAudioRepository?>((ref) {
  final baseUrl = ref.watch(imageBaseUrlProvider);
  final userId = ref.watch(userIdProvider);
  if (baseUrl == null || userId == null) return null;
  return HttpCardAudioRepository(baseUrl: baseUrl, userId: userId);
});

final cardsSchemaStatusProvider = FutureProvider<CardsSchemaStatus>((ref) {
  return inspectCardsSchema(ref.watch(graphqlClientProvider));
});

final cardsDashboardProvider = FutureProvider<CardsDashboard>((ref) async {
  final repository = ref.watch(cardsRepositoryProvider);
  final results = await Future.wait([
    repository.listDecks(),
    repository.listCards(),
  ]);
  return CardsDashboard(
    decks: results[0] as List<CardDeck>,
    cards: results[1] as List<StudyCard>,
  );
});

final languagesProvider = FutureProvider<List<String>>((ref) {
  return ref.watch(cardsRepositoryProvider).listLanguages();
});

final cardTagsProvider = FutureProvider<List<String>>((ref) {
  return ref.watch(cardsRepositoryProvider).listCardTags();
});

final relatedBooksProvider = FutureProvider<List<RelatedBook>>((ref) {
  return ref.watch(cardsRepositoryProvider).listBooks();
});

void invalidateCardsData(Ref ref) {
  ref.invalidate(cardsDashboardProvider);
  ref.invalidate(languagesProvider);
  ref.invalidate(cardTagsProvider);
  ref.invalidate(relatedBooksProvider);
}
