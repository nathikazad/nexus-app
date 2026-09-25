import 'package:nx_cards/scheduling/study_scope.dart';
import 'package:flutter/material.dart';
import 'package:nx_cards/browser/browser.dart';
import 'package:nx_cards/study/session/study_session_page.dart';
import 'package:nx_cards/study/study_setup_page.dart';

Future<void> openStudy(
  BuildContext context,
  String title,
  List<StudyPrompt> prompts, {
  StudyScope? studyScope,
}) {
  return Navigator.push<void>(
    context,
    MaterialPageRoute(
      builder: (_) => StudySessionPage(
        title: title,
        prompts: prompts,
        studyScope: studyScope,
      ),
    ),
  );
}

typedef StudyButtonBuilder = Widget Function(VoidCallback? onPressed);

class StudyLauncher extends StatelessWidget {
  const StudyLauncher({
    this.studyScope,
    this.followLearningTab = false,
    super.key,
    required this.title,
    required this.prompts,
    required this.studyCards,
    required this.preferenceKey,
    required this.builder,
    this.languagePair,
    this.sourceKind = StudySourceKind.language,
  });

  final bool followLearningTab;
  final StudyScope? studyScope;
  final String title;
  final List<StudyPrompt> prompts;
  final List<StudyCard> studyCards;
  final String preferenceKey;
  final StudyButtonBuilder builder;
  final LanguagePair? languagePair;
  final StudySourceKind sourceKind;

  @override
  Widget build(BuildContext context) {
    if (!followLearningTab) return _build(context, StudySetupFlow.recall);
    final tabs = DefaultTabController.of(context);
    return AnimatedBuilder(
      animation: tabs,
      builder: (context, _) {
        if (tabs.index == 3) return const SizedBox.shrink();
        return _build(
          context,
          tabs.index == 0 ? StudySetupFlow.practice : StudySetupFlow.recall,
        );
      },
    );
  }

  Widget _build(BuildContext context, StudySetupFlow flow) {
    Widget button(VoidCallback? onPressed) => followLearningTab
        ? FilledButton(
            onPressed: onPressed,
            child: Text(
              flow == StudySetupFlow.practice ? 'Practice' : 'Recall',
            ),
          )
        : builder(onPressed);
    final hasLanguageCards = studyCards.any((card) => card.isLanguageCard);
    if (prompts.isEmpty && studyCards.isEmpty) return button(null);
    if (sourceKind == StudySourceKind.language &&
        (languagePair == null || !hasLanguageCards)) {
      if (prompts.isEmpty) return button(null);
      return button(
        () => openStudy(context, title, prompts, studyScope: studyScope),
      );
    }
    return button(
      () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => StudySetupPage(
            studyScope: studyScope,
            flow: flow,
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
