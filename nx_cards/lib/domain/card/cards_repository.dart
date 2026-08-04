import 'package:nx_cards/domain/book/related_book.dart';
import 'package:nx_cards/domain/card/card_content.dart';
import 'package:nx_cards/domain/card/study_card.dart';
import 'package:nx_cards/domain/deck/card_deck.dart';

/// Domain boundary used by the application and presentation layers.
///
/// The current implementation is KGQL-backed. A future local-first
/// implementation can satisfy this same contract with Drift plus an outbox.
abstract class CardsRepository {
  Future<List<CardDeck>> listDecks();
  Future<List<StudyCard>> listCards();
  Future<List<String>> listLanguages();
  Future<List<String>> listCardTags();
  Future<List<RelatedBook>> listBooks();
  Future<void> addLanguage(String name);
  Future<void> addCardTag(String name);

  Future<int> createDeck({
    required String name,
    required String description,
    String? language,
  });

  Future<int> createCard({
    required CardContent content,
    required int deckId,
    required List<String> tags,
    int? sourceBookId,
  });

  Future<void> updateCardContent({
    required int id,
    required CardContent content,
    required List<String> tags,
  });

  Future<void> saveSchedule(StudyCard card);
  Future<void> setSuspended(StudyCard card, bool suspended);
  Future<void> deleteCard(int id);
}
