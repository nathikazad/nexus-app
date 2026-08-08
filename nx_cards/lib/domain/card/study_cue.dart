enum StudyCue {
  fromLanguage('from_language'),
  toLanguage('to_language'),
  transliteration('transliteration');

  const StudyCue(this.storageKey);

  final String storageKey;
}
