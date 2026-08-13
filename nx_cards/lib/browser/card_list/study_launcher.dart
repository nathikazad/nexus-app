import 'package:flutter/material.dart';
import 'package:nx_cards/browser/browser.dart';
import 'package:nx_cards/study/session/study_session_page.dart';
import 'package:nx_cards/study/study_setup_page.dart';

Future<void> openStudy(
  BuildContext context,
  String title,
  List<StudyPrompt> prompts,
) {
  return Navigator.push<void>(
    context,
    MaterialPageRoute(
      builder: (_) => StudySessionPage(title: title, prompts: prompts),
    ),
  );
}

typedef StudyButtonBuilder = Widget Function(VoidCallback? onPressed);

class StudyLauncher extends StatelessWidget {
  const StudyLauncher({
    super.key,
    required this.title,
    required this.prompts,
    required this.studyCards,
    required this.preferenceKey,
    required this.builder,
    this.languagePair,
    this.sourceKind = StudySourceKind.language,
  });

  final String title;
  final List<StudyPrompt> prompts;
  final List<StudyCard> studyCards;
  final String preferenceKey;
  final StudyButtonBuilder builder;
  final LanguagePair? languagePair;
  final StudySourceKind sourceKind;

  @override
  Widget build(BuildContext context) {
    final hasLanguageCards = studyCards.any((card) => card.isLanguageCard);
    if (prompts.isEmpty && studyCards.isEmpty) return builder(null);
    if (sourceKind == StudySourceKind.language &&
        (languagePair == null || !hasLanguageCards)) {
      if (prompts.isEmpty) return builder(null);
      return builder(() => openStudy(context, title, prompts));
    }
    return builder(
      () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => StudySetupPage(
            title: title,
            prompts: prompts,
            studyCards: studyCards,
            fromLanguage: languagePair?.from ?? 'Question',
            toLanguage: languagePair?.to ?? 'Answer',
            sourceKind: sourceKind,
            preferenceKey: sourceKind == StudySourceKind.book
                ? preferenceKey
                : '$preferenceKey:${languagePair!.from}:${languagePair!.to}',
          ),
        ),
      ),
    );
  }
}

LanguagePair? languagesForCards(
  CardsDashboard dashboard,
  Iterable<StudyCard> cards,
) {
  final pairs = cards
      .where((card) => card.isLanguageCard)
      .map(dashboard.languageFor)
      .whereType<String>()
      .map((language) => LanguagePair('Front', language))
      .toSet();
  return pairs.length == 1 ? pairs.single : null;
}

class LanguagePair {
  const LanguagePair(this.from, this.to);
  final String from;
  final String to;

  @override
  bool operator ==(Object other) =>
      other is LanguagePair && other.from == from && other.to == to;

  @override
  int get hashCode => Object.hash(from, to);
}
