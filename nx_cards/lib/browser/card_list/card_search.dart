import 'package:nx_cards/browser/browser.dart';

/// Search both sides and transliteration, ignoring pinyin tones and spacing.
bool cardMatchesSearch(StudyCard card, String query) {
  final needle = _normalize(query);
  if (needle.isEmpty) return true;
  final content = card.content;
  return [
    card.front,
    card.back,
    if (content is LanguageCardContent) content.transliteration,
  ].any((value) => _normalize(value).contains(needle));
}

String _normalize(String value) {
  const groups = {
    'a': 'āáǎà',
    'e': 'ēéěèê',
    'i': 'īíǐì',
    'o': 'ōóǒò',
    'u': 'ūúǔùüǖǘǚǜ',
    'n': 'ńňǹ',
    'm': 'ḿ',
  };
  var result = value.toLowerCase().trim();
  for (final group in groups.entries) {
    for (final character in group.value.split('')) {
      result = result.replaceAll(character, group.key);
    }
  }
  return result.replaceAll(RegExp(r'[\u0300-\u036f\s]'), '');
}
