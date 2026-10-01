import 'package:flutter/material.dart';
import 'package:nx_cards/browser/browser.dart';
import 'package:nx_cards/browser/card_list/bulk_card_selection.dart';
import 'package:nx_cards/browser/card_list/study_launcher.dart';
import 'package:nx_cards/study/study_setup_page.dart';

class PracticeSelectionScope extends StatelessWidget {
  const PracticeSelectionScope({
    super.key,
    required this.title,
    required this.cards,
    required this.child,
    this.languagePair,
    this.sourceKind = StudySourceKind.language,
  });
  final String title;
  final List<StudyCard> cards;
  final Widget child;
  final LanguagePair? languagePair;
  final StudySourceKind sourceKind;
  @override
  Widget build(BuildContext context) => BulkCardSelectionScope(
    cards: cards,
    practiceActionBuilder: (selected) => StudyLauncher(
      flow: StudySetupFlow.practice,
      title: title,
      prompts: [for (final card in selected) ...card.prompts],
      studyCards: selected,
      preferenceKey: 'selected-practice:$title',
      languagePair: languagePair,
      sourceKind: languagePair == null ? StudySourceKind.book : sourceKind,
      builder: (onPressed) => FilledButton.icon(
        key: const ValueKey('bulk-practice'),
        onPressed: onPressed,
        icon: const Icon(Icons.draw_outlined),
        label: const Text('Practice'),
      ),
    ),
    child: child,
  );
}

class PracticeSelectionButton extends StatelessWidget {
  const PracticeSelectionButton({super.key});
  @override
  Widget build(BuildContext context) {
    final selection = bulkCardSelectionOf(context)!;
    return LibraryActionButton(
      key: const ValueKey('practice-select'),
      onPressed: selection.toggleMode,
      icon: selection.selecting ? Icons.close : Icons.draw_outlined,
      label: selection.selecting ? 'Cancel' : 'Practice',
    );
  }
}
