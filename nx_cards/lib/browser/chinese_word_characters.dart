import 'package:nx_cards/browser/browser.dart';

/// Only compound Word/Verb cards expose characters. Phrase cards keep their
/// explicit whole-word links and are never recursively flattened.
List<StudyCard> chineseWordCharacters(StudyCard card, List<StudyCard> library) {
  if (!card.isWordCard ||
      card.language != 'Chinese' ||
      !RegExp(r'^[\u4e00-\u9fff]{2,}$').hasMatch(card.back)) {
    return const [];
  }
  final characters = {
    for (final word in library)
      if (word.isWordCard &&
          word.language == card.language &&
          word.back.runes.length == 1)
        word.back: word,
  };
  return [
    for (final rune in card.back.runes) ?characters[String.fromCharCode(rune)],
  ];
}
